"""Behavioral tests for AnswerRepository's scoring/percentile SQL.

These run against real Postgres (see conftest). They cover the window-function
and ordered-set aggregates that decide the scores and percentiles players see --
``percentile_cont`` (score quantiles) and ``percent_rank`` (overall percentile) --
none of which SQLite can execute. This is the behavior that the fermi-api unit
test ``test_global_percentile.py`` only checks against a hand-copied Python
*reimplementation*; here we assert the shipped query itself.
"""

import uuid

import pytest
from fermi_db.models import AnswerEvent, AnswersQuantiles
from fermi_db.repositories.answer_repository import (
    MIN_QUANTILE_SAMPLE_SIZE,
    AnswerRepository,
)
from fermi_db.schemas import GameMode, QuestionCategory, QuestionDifficulty
from sqlmodel.ext.asyncio.session import AsyncSession


def _answer_event(
    *,
    question_uid: uuid.UUID,
    user: str,
    score: float,
    game_id: str = 'g1',
    game_mode: GameMode | None = GameMode.PARTY,
) -> AnswerEvent:
    """Build an AnswerEvent with the fields the scoring queries read."""
    return AnswerEvent(
        question_uid=question_uid,
        question_difficulty=QuestionDifficulty.MEDIUM,
        question_category=QuestionCategory.OTHER,
        user_firebase_id=user,
        game_id=game_id,
        answer={'number': 1.0, 'unit': None},
        correct_answer={'number': 1.0, 'unit': None},
        score_number=score,
        score_quantile=0.5,
        game_mode=game_mode,
    )


async def _seed(session: AsyncSession, events: list[AnswerEvent]) -> None:
    session.add_all(events)
    await session.commit()


# --------------------------------------------------------------------------- #
# get_question_quantiles  (percentile_cont, ungrouped, cold-start guard)
# --------------------------------------------------------------------------- #


async def test_quantiles_below_sample_size_return_cold_start_easy(
    session: AsyncSession,
) -> None:
    """Under the sample-size floor, quantiles are the linear ``easy`` curve.

    Even though every score here is 999, a thin sample must NOT be trusted: the
    cold-start guard returns ``AnswersQuantiles.easy`` (p50 == 500), not 999.
    """
    repo = AnswerRepository(session)
    q_uid = uuid.uuid4()
    await _seed(
        session,
        [
            _answer_event(question_uid=q_uid, user=f'u{i}', score=999.0)
            for i in range(MIN_QUANTILE_SAMPLE_SIZE - 1)  # one below the floor
        ],
    )

    quantiles = await repo.get_question_quantiles(q_uid)

    assert quantiles == AnswersQuantiles.easy(q_uid)
    assert quantiles.p50 == 500.0  # cold-start, not the seeded 999


async def test_quantiles_at_sample_size_return_real_distribution(
    session: AsyncSession,
) -> None:
    """At/above the floor, real ``percentile_cont`` values are returned.

    Scores are ``0..N-1``; for that unit-step sequence ``percentile_cont(p)``
    equals ``p*(N-1)`` exactly, so we can assert the SQL output without
    reimplementing the interpolation.
    """
    repo = AnswerRepository(session)
    q_uid = uuid.uuid4()
    n = MIN_QUANTILE_SAMPLE_SIZE  # exactly at the floor -> real quantiles
    await _seed(
        session,
        [
            _answer_event(question_uid=q_uid, user=f'u{i}', score=float(i))
            for i in range(n)
        ],
    )

    quantiles = await repo.get_question_quantiles(q_uid)

    assert quantiles != AnswersQuantiles.easy(q_uid)  # the real branch was taken
    assert quantiles.p01 == pytest.approx(0.01 * (n - 1), abs=1e-6)
    assert quantiles.p50 == pytest.approx(0.50 * (n - 1), abs=1e-6)
    assert quantiles.p90 == pytest.approx(0.90 * (n - 1), abs=1e-6)
    assert quantiles.p99 == pytest.approx(0.99 * (n - 1), abs=1e-6)


async def test_quantiles_for_question_with_no_answers_is_easy(
    session: AsyncSession,
) -> None:
    """A question with zero answers yields cold-start ``easy`` (count 0 < floor)."""
    repo = AnswerRepository(session)
    q_uid = uuid.uuid4()

    quantiles = await repo.get_question_quantiles(q_uid)

    assert quantiles == AnswersQuantiles.easy(q_uid)


async def test_quantiles_isolated_per_question(session: AsyncSession) -> None:
    """One question's many answers do not leak into another's quantiles."""
    repo = AnswerRepository(session)
    busy, quiet = uuid.uuid4(), uuid.uuid4()
    await _seed(
        session,
        [
            _answer_event(question_uid=busy, user=f'u{i}', score=float(i))
            for i in range(MIN_QUANTILE_SAMPLE_SIZE)
        ],
    )

    busy_q = await repo.get_question_quantiles(busy)
    quiet_q = await repo.get_question_quantiles(quiet)

    assert busy_q != AnswersQuantiles.easy(busy)  # real distribution
    assert quiet_q == AnswersQuantiles.easy(quiet)  # untouched -> cold-start


# --------------------------------------------------------------------------- #
# get_questions_quantiles  (bulk GROUP BY variant)
# --------------------------------------------------------------------------- #


async def test_bulk_quantiles_omit_questions_with_no_answers(
    session: AsyncSession,
) -> None:
    """The GROUP BY yields no row for an unanswered uid, so it is ABSENT.

    Callers must default a missing uid to ``easy`` themselves -- pinning this
    contract guards against a refactor that silently returns all-zeros for
    never-answered questions.
    """
    repo = AnswerRepository(session)
    answered, never = uuid.uuid4(), uuid.uuid4()
    await _seed(
        session,
        [_answer_event(question_uid=answered, user='u1', score=10.0)],
    )

    result = await repo.get_questions_quantiles([answered, never])

    assert answered in result
    assert never not in result


async def test_bulk_quantiles_match_single_method(session: AsyncSession) -> None:
    """The bulk query agrees with the per-question method on identical data."""
    repo = AnswerRepository(session)
    q_uid = uuid.uuid4()
    await _seed(
        session,
        [
            _answer_event(question_uid=q_uid, user=f'u{i}', score=float(i))
            for i in range(MIN_QUANTILE_SAMPLE_SIZE)
        ],
    )

    bulk = await repo.get_questions_quantiles([q_uid])
    single = await repo.get_question_quantiles(q_uid)

    assert bulk[q_uid] == single


async def test_bulk_quantiles_empty_input_returns_empty(
    session: AsyncSession,
) -> None:
    """No uids requested -> empty dict, no query error."""
    repo = AnswerRepository(session)
    assert await repo.get_questions_quantiles([]) == {}


# --------------------------------------------------------------------------- #
# get_overall_avg_percentile  (percent_rank over per-player averages)
# --------------------------------------------------------------------------- #


async def test_overall_percentile_ranks_players_by_average(
    session: AsyncSession,
) -> None:
    """percent_rank maps lowest avg -> 0, middle -> 50, highest -> 100."""
    repo = AnswerRepository(session)
    await _seed(
        session,
        [
            _answer_event(question_uid=uuid.uuid4(), user='low', score=100.0),
            _answer_event(question_uid=uuid.uuid4(), user='mid', score=200.0),
            _answer_event(question_uid=uuid.uuid4(), user='high', score=300.0),
        ],
    )

    assert await repo.get_overall_avg_percentile('low') == 0
    assert await repo.get_overall_avg_percentile('mid') == 50
    assert await repo.get_overall_avg_percentile('high') == 100


async def test_overall_percentile_uses_average_and_handles_ties(
    session: AsyncSession,
) -> None:
    """Ranking is on each player's *average*, and ties share the same rank.

    ``a`` averages two events (100, 300) -> 200, tying ``b`` (single 200);
    ``c`` (400) is strictly highest. percent_rank gives both tied players 0 and
    the top player 100 -- a tie behavior the strict ``<`` reimplementation in
    fermi-api's ``test_global_percentile`` does not model.
    """
    repo = AnswerRepository(session)
    await _seed(
        session,
        [
            _answer_event(question_uid=uuid.uuid4(), user='a', score=100.0),
            _answer_event(question_uid=uuid.uuid4(), user='a', score=300.0),
            _answer_event(question_uid=uuid.uuid4(), user='b', score=200.0),
            _answer_event(question_uid=uuid.uuid4(), user='c', score=400.0),
        ],
    )

    assert await repo.get_overall_avg_percentile('a') == 0
    assert await repo.get_overall_avg_percentile('b') == 0
    assert await repo.get_overall_avg_percentile('c') == 100


async def test_overall_percentile_single_player_is_zero(
    session: AsyncSession,
) -> None:
    """A lone player gets percent_rank 0 (defined as 0 for a single row)."""
    repo = AnswerRepository(session)
    await _seed(
        session,
        [_answer_event(question_uid=uuid.uuid4(), user='solo', score=500.0)],
    )

    assert await repo.get_overall_avg_percentile('solo') == 0


async def test_overall_percentile_unknown_user_returns_100(
    session: AsyncSession,
) -> None:
    """A user with no answer events returns 100 (the no-row fallback).

    NOTE: this pins *current* behavior, which contradicts the method's docstring
    ("0 if no games played"). Returning top-percentile for a brand-new user is
    almost certainly a bug -- flagged for the fermi-api follow-up. The test
    documents the real behavior so a fix is a deliberate, visible change.
    """
    repo = AnswerRepository(session)
    await _seed(
        session,
        [_answer_event(question_uid=uuid.uuid4(), user='someone', score=100.0)],
    )

    assert await repo.get_overall_avg_percentile('ghost') == 100


# --------------------------------------------------------------------------- #
# get_overall_avg_percentiles_batch
# --------------------------------------------------------------------------- #


async def test_batch_percentiles_match_single_for_known_users(
    session: AsyncSession,
) -> None:
    """The batch query returns the same percentiles as the per-user method."""
    repo = AnswerRepository(session)
    await _seed(
        session,
        [
            _answer_event(question_uid=uuid.uuid4(), user='low', score=100.0),
            _answer_event(question_uid=uuid.uuid4(), user='mid', score=200.0),
            _answer_event(question_uid=uuid.uuid4(), user='high', score=300.0),
        ],
    )

    result = await repo.get_overall_avg_percentiles_batch(['low', 'mid', 'high'])

    assert result == {'low': 0, 'mid': 50, 'high': 100}


async def test_batch_percentiles_omit_unknown_users(session: AsyncSession) -> None:
    """Unlike the single method (100 fallback), batch OMITS users with no events."""
    repo = AnswerRepository(session)
    await _seed(
        session,
        [_answer_event(question_uid=uuid.uuid4(), user='known', score=100.0)],
    )

    result = await repo.get_overall_avg_percentiles_batch(['known', 'ghost'])

    assert 'known' in result
    assert 'ghost' not in result


async def test_batch_percentiles_empty_input_returns_empty(
    session: AsyncSession,
) -> None:
    """No uids requested -> empty dict, no query error."""
    repo = AnswerRepository(session)
    assert await repo.get_overall_avg_percentiles_batch([]) == {}
