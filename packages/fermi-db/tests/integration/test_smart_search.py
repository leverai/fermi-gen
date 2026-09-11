"""Behavioral tests for FermiRepository.get_unseen_similar_questions.

Run against a real Postgres+pgvector (see conftest). These assert the actual
cosine-distance floor, the distance ordering, and the fairness interaction --
none of which SQLite can execute.

Embeddings are crafted in a 2D plane (padded to 1536 dims) so cosine similarity
to the query is exact: for query ``q = [1, 0, ...]`` and candidate
``c = [s, sqrt(1 - s^2), 0, ...]`` the cosine similarity is exactly ``s`` and the
cosine distance is ``1 - s``.
"""

import datetime
import math
import uuid

import pytest
import pytest_asyncio
from fermi_db.models import Fermi, UserQuestionHistory
from fermi_db.repositories.fermi_repository import FermiRepository
from fermi_db.schemas import QuestionDifficulty, QuestionStatus
from sqlmodel.ext.asyncio.session import AsyncSession

EMBED_DIM = 1536
SIMILARITY_FLOOR = 0.30  # -> max cosine distance 0.70
POOL_SIZE = 25
USER = 'user-1'


def _embedding(similarity: float) -> list[float]:
    """Return a unit 1536-vector at cosine similarity ``similarity`` to the query.

    The query is ``[1, 0, 0, ...]``; this returns ``[s, sqrt(1 - s^2), 0, ...]``.
    """
    head = [similarity, math.sqrt(max(0.0, 1.0 - similarity * similarity))]
    return head + [0.0] * (EMBED_DIM - len(head))


QUERY_EMBEDDING = _embedding(1.0)  # [1, 0, 0, ...]


def _make_fermi(
    similarity: float | None,
    *,
    difficulty: QuestionDifficulty | None = QuestionDifficulty.MEDIUM,
    status: QuestionStatus = QuestionStatus.APPROVED,
    is_daily_question: bool = False,
) -> Fermi:
    """Build a Fermi row with a crafted embedding (or None) and required fields."""
    now = datetime.datetime(2026, 1, 1)  # noqa: DTZ001 - naive, matches schema
    return Fermi(
        uid=uuid.uuid4(),
        question_id=int(uuid.uuid4().int % 2_000_000_000),
        text=f'q sim={similarity}',
        question_source={},
        answer_id=int(uuid.uuid4().int % 2_000_000_000),
        number=1.0,
        unit=None,
        snippet='snippet',
        used_ai_overview=False,
        difficulty=difficulty,
        category=None,
        embedding=None if similarity is None else _embedding(similarity),
        random_sort_key=0,
        created_at=now,
        updated_at=now,
        status=status,
        is_daily_question=is_daily_question,
        gpt_5_1_number=1.0,
        gpt_5_1_unit=None,
        gpt_5_mini_number=1.0,
        gpt_5_mini_unit=None,
        gpt_5_nano_number=1.0,
        gpt_5_nano_unit=None,
        gemini_flash_1_number=1.0,
        gemini_flash_1_unit=None,
        gemini_flash_2_number=1.0,
        gemini_flash_2_unit=None,
        gemini_flash_3_number=1.0,
        gemini_flash_3_unit=None,
        gemini_flash_4_number=1.0,
        gemini_flash_4_unit=None,
        gemini_flash_5_number=1.0,
        gemini_flash_5_unit=None,
    )


@pytest_asyncio.fixture
async def repo(session: AsyncSession) -> FermiRepository:
    """FermiRepository bound to the clean per-test session."""
    return FermiRepository(session)


async def _seed(session: AsyncSession, rows: list[Fermi]) -> None:
    session.add_all(rows)
    await session.commit()


async def _mark_seen(session: AsyncSession, user_id: str, uid: uuid.UUID) -> None:
    session.add(UserQuestionHistory(user_id=user_id, question_uid=uid))
    await session.commit()


async def test_floor_excludes_just_below_includes_just_above(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """A row just above the floor is returned; one just below is excluded."""
    above = _make_fermi(0.35)  # distance 0.65 <= 0.70 -> kept
    below = _make_fermi(0.25)  # distance 0.75 >  0.70 -> dropped
    await _seed(session, [above, below])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    returned_uids = {f.uid for f, _ in rows}
    assert above.uid in returned_uids
    assert below.uid not in returned_uids


async def test_floor_boundary_is_inclusive(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """A row exactly at the floor (distance == max_distance) is kept (``<=``).

    Guards against an inverted comparison: distance == 1 - floor must pass.
    """
    at_floor = _make_fermi(SIMILARITY_FLOOR)  # distance == 0.70 == max_distance
    await _seed(session, [at_floor])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert {f.uid for f, _ in rows} == {at_floor.uid}
    # Carried distance ~= 1 - similarity, available for telemetry.
    ((_, distance),) = rows
    assert distance == pytest.approx(1 - SIMILARITY_FLOOR, abs=1e-6)


async def test_negative_one_floor_keeps_even_opposite_candidates(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """The minimum cosine similarity disables relevance filtering."""
    close = _make_fermi(0.90)
    opposite = _make_fermi(-0.75)
    await _seed(session, [close, opposite])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=2,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=-1.0,
    )

    assert {f.uid for f, _ in rows} == {close.uid, opposite.uid}


async def test_distances_carried_out_for_telemetry(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """Each returned row carries its cosine distance (so sim = 1 - distance)."""
    high = _make_fermi(0.95)  # distance ~0.05
    mid = _make_fermi(0.50)  # distance ~0.50
    await _seed(session, [high, mid])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    by_uid = {f.uid: d for f, d in rows}
    assert by_uid[high.uid] == pytest.approx(0.05, abs=1e-6)
    assert by_uid[mid.uid] == pytest.approx(0.50, abs=1e-6)


async def test_fairness_order_within_floored_pool(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """Within the floored pool, less-seen questions come first (not nearest-first).

    ``nearer`` is closer to the query but has been seen by the user; ``farther``
    (still above the floor) is unseen. Fairness must rank ``farther`` first,
    proving the order is on seen-stats, not distance.
    """
    nearer_seen = _make_fermi(0.90)  # closest, but seen
    farther_unseen = _make_fermi(0.40)  # above floor, unseen
    await _seed(session, [nearer_seen, farther_unseen])
    await _mark_seen(session, USER, nearer_seen.uid)

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    ordered_uids = [f.uid for f, _ in rows]
    assert ordered_uids == [farther_unseen.uid, nearer_seen.uid]


async def test_difficulty_filter(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """The difficulty filter restricts the candidate pool."""
    easy = _make_fermi(0.90, difficulty=QuestionDifficulty.EASY)
    hard = _make_fermi(0.90, difficulty=QuestionDifficulty.HARD)
    await _seed(session, [easy, hard])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
        difficulty=QuestionDifficulty.EASY,
    )

    assert {f.uid for f, _ in rows} == {easy.uid}


async def test_embedding_null_excluded(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """Rows with a NULL embedding never appear (even though they are APPROVED)."""
    has_embedding = _make_fermi(0.90)
    null_embedding = _make_fermi(None)
    await _seed(session, [has_embedding, null_embedding])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert {f.uid for f, _ in rows} == {has_embedding.uid}


async def test_non_approved_and_daily_excluded(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """Only APPROVED, non-daily questions are eligible."""
    approved = _make_fermi(0.90)
    pending = _make_fermi(0.90, status=QuestionStatus.PENDING_REVIEW)
    daily = _make_fermi(0.90, is_daily_question=True)
    await _seed(session, [approved, pending, daily])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert {f.uid for f, _ in rows} == {approved.uid}


async def test_k_zero_when_nothing_clears_floor(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """Empty (k = 0): every candidate is below the floor -> [], no exception."""
    await _seed(session, [_make_fermi(0.10), _make_fermi(0.20)])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert rows == []


async def test_partial_pool_returns_fewer_than_count(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """0 < k < count: only some clear the floor; return them all, raise nothing."""
    above = [_make_fermi(0.90), _make_fermi(0.50)]  # 2 above floor
    below = [_make_fermi(0.10)]  # below floor
    await _seed(session, [*above, *below])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,  # ask for more than clear the floor
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert len(rows) == 2
    assert {f.uid for f, _ in rows} == {above[0].uid, above[1].uid}


async def test_count_limits_result_size(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """Capped (k = count): more clear the floor than asked -> exactly count."""
    rows_in = [_make_fermi(0.80) for _ in range(5)]
    await _seed(session, rows_in)

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=3,
        for_user_ids=[USER],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert len(rows) == 3


async def test_empty_user_ids_returns_empty(
    session: AsyncSession,
    repo: FermiRepository,
) -> None:
    """The for_user_ids guard short-circuits to [] like the sibling method."""
    await _seed(session, [_make_fermi(0.90)])

    rows = await repo.get_unseen_similar_questions(
        query_embedding=QUERY_EMBEDDING,
        count=6,
        for_user_ids=[],
        candidate_pool_size=POOL_SIZE,
        similarity_floor=SIMILARITY_FLOOR,
    )

    assert rows == []
