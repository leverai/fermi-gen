"""Gateway to external data services used by party games.

This boundary coordinates the Postgres analytics/history repositories and the
query-embedding provider used by smart search. It converts external data into
game documents and archives results, while remaining independent of Firestore
and HTTP semantics.
"""

import logging
import uuid
from dataclasses import dataclass
from typing import TYPE_CHECKING, cast

from fermi_core.op.embed import aget_query_embedding_3small
from fermi_core.units import get_unit_family
from fermi_db.models import AnswerEvent, SmartSearchEvent, SmartSearchOutcome
from fermi_db.models.game import AnswersQuantiles, VoteVerdict
from fermi_db.schemas import GameMode, QuestionCategory

from app.core.config import settings
from app.schemas.game import (
    AnswerDoc,
    PlayersResultsDoc,
    QuestionDoc,
    ScoreQuantiles,
)
from app.services.game.errors import SearchEmbeddingError, SearchNoResultsError

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.models import Fermi
    from fermi_db.schemas import QuestionDifficulty

    from app.schemas.endpoints import QuestionRoundSettings, QuestionSettings

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class _SmartSearchTelemetry:
    """Data needed to persist one smart-search attempt."""

    game_id: str | None
    host_user_id: str | None
    query: str
    difficulty: 'QuestionDifficulty | None'
    returned_uids: list[str]
    returned_similarities: list[float]
    outcome: SmartSearchOutcome
    floor_used: float
    pool_size_used: int


class GameDataGateway:
    """Coordinate external question, embedding, and analytics data operations."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the game analytics gateway."""
        self._db_client = db_client

    async def get_questions_and_answers_docs(
        self,
        user_ids: list[str],
        question_round_settings: 'QuestionRoundSettings',
        *,
        game_id: str | None = None,
        host_user_id: str | None = None,
    ) -> tuple[list[QuestionDoc], list[AnswerDoc]]:
        """Get questions and their answers from the database.

        When ``question_round_settings.search_query`` is set, the questions come
        from a semantic smart-search (embed the query, then the similarity-gated
        unseen-fairness pool); otherwise the legacy random-by-category path runs.

        ``game_id`` and ``host_user_id`` are used only for best-effort smart-search
        telemetry on the search path; they are ignored on the legacy path.
        """
        # 1. Fetch questions (with correct answers): smart-search vs legacy path.
        if question_round_settings.search_query:
            questions = await self._get_smart_search_questions(
                user_ids=user_ids,
                question_round_settings=question_round_settings,
                game_id=game_id,
                host_user_id=host_user_id,
            )
        else:
            # Cast directly - RequestCategory values map onto QuestionCategory.
            request_categories = cast(
                list[QuestionCategory] | None,
                question_round_settings.categories,
            )
            questions = await self._db_client.fermi.get_unseen_random_questions(
                count=question_round_settings.n_questions,
                for_user_ids=user_ids,
                categories=request_categories,
                difficulty=question_round_settings.difficulty,
            )

        # 2. Bulk-fetch all per-question aggregates in 3 round-trips (not ~3N).
        # The repositories share ONE AsyncSession, which cannot run concurrent
        # operations on its single connection, so these are awaited sequentially
        # (NOT gathered). Each bulk call replaces an N-iteration loop with a single
        # IN (:uids) query, keyed by question_uid so we reassemble in input order
        # below. Missing-uid handling mirrors the per-uid methods exactly:
        #   - quantiles: a uid with no answer rows is absent -> easy() cold-start
        #     quantiles. This matches get_question_quantiles: its UNGROUPED
        #     aggregate always returns one row with cnt=0 for a no-answer question,
        #     which is < MIN_QUANTILE_SAMPLE_SIZE and falls through to easy() (the
        #     `row is None` branch never fires for an ungrouped aggregate).
        #   - upvotes: a uid with no upvotes is absent -> default 0.
        #   - verdicts: every requested uid is pre-seeded NO_VOTE for all user_ids.
        question_uids = [question.uid for question in questions]
        quantiles_by_uid = await self._db_client.answers.get_questions_quantiles(
            question_uids,
        )
        upvotes_by_uid = await self._db_client.question_votes.get_upvotes_bulk(
            question_uids,
        )
        verdicts_by_uid = (
            await self._db_client.question_votes.get_players_vote_verdicts_bulk(
                question_uids,
                user_ids,
            )
        )

        # 3. Create docs, preserving the input order (order = enumerate start=1).
        questions_docs: list[QuestionDoc] = []
        answers_docs: list[AnswerDoc] = []
        for idx, question in enumerate(questions, start=1):
            # Absent uid == "no answer rows": cold-start easy() quantiles, matching
            # get_question_quantiles (cnt=0 < MIN_QUANTILE_SAMPLE_SIZE -> easy(),
            # NOT all-zeros — an all-zeros distribution would break cold-start
            # scoring for never-answered questions).
            q_quantiles = quantiles_by_uid.get(
                question.uid,
                AnswersQuantiles.easy(question.uid),
            )
            units = get_unit_family(question.unit) if question.unit else None
            # Aggregate upvotes from votes table (absent uid -> 0).
            upvotes = upvotes_by_uid.get(question.uid, 0)
            # Aggregate players votes from votes table (uid always pre-seeded).
            players_votes = verdicts_by_uid[question.uid]
            questions_docs.append(
                QuestionDoc(
                    question_uid=str(question.uid),
                    text=question.text,
                    category=question.category,
                    difficulty=question.difficulty,
                    year=question.updated_at.year,
                    order=idx,
                    units=units,
                    upvotes=upvotes,
                    revealed=False,
                    players_votes=players_votes,
                ),
            )
            answers_docs.append(
                AnswerDoc(
                    number=question.number,
                    unit=question.unit,
                    paragraph=question.snippet,
                    quantiles=cast(
                        ScoreQuantiles,
                        q_quantiles.model_dump(exclude={'question_uid'}),
                    ),
                    revealed=False,
                ),
            )

        return questions_docs, answers_docs

    async def _get_smart_search_questions(
        self,
        *,
        user_ids: list[str],
        question_round_settings: 'QuestionRoundSettings',
        game_id: str | None,
        host_user_id: str | None,
    ) -> list['Fermi']:
        """Run the semantic smart-search path and return the questions to serve.

        Embeds the query (same cleaning + model as the corpus), fetches the
        similarity-gated unseen-fairness pool, and enforces the ``min_results``
        gate. Records best-effort telemetry on every outcome. Raises:

        - ``SearchEmbeddingError`` if the embed call fails (transient -> 503).
        - ``SearchNoResultsError`` if fewer than ``max(min_results, n_questions)``
          questions clear the floor (query-actionable -> 4xx).
        """
        query = question_round_settings.search_query
        assert query is not None  # guarded by the caller's `if search_query`
        n_questions = question_round_settings.n_questions
        floor = settings.smart_search_similarity_floor
        pool_size = settings.smart_search_pool_size
        # Gate on max(min_results, n_questions) so a custom n_questions still gets a
        # full game rather than a short one.
        min_results = max(settings.smart_search_min_results, n_questions)
        effective_pool_size = max(pool_size, min_results)

        # Embed the query. A failure here is transient (OpenAI down/timeout): the
        # same query may succeed on retry, so it becomes a retryable 503 upstream.
        try:
            vec = await aget_query_embedding_3small(query)
        except Exception as exc:
            await self._record_smart_search_event(
                _SmartSearchTelemetry(
                    game_id=game_id,
                    host_user_id=host_user_id,
                    query=query,
                    difficulty=question_round_settings.difficulty,
                    returned_uids=[],
                    returned_similarities=[],
                    outcome=SmartSearchOutcome.EMBED_ERROR,
                    floor_used=floor,
                    pool_size_used=effective_pool_size,
                ),
            )
            raise SearchEmbeddingError(
                f'Failed to embed search query {query!r}',
            ) from exc

        # Fetch enough candidates to enforce the configured quality floor even
        # when the host requests fewer questions than ``smart_search_min_results``.
        rows = await self._db_client.fermi.get_unseen_similar_questions(
            query_embedding=vec,
            count=min_results,
            for_user_ids=user_ids,
            candidate_pool_size=effective_pool_size,
            similarity_floor=floor,
            difficulty=question_round_settings.difficulty,
        )
        questions = [fermi for fermi, _ in rows]
        # Cosine similarity = 1 - distance; carried to telemetry to tune the floor.
        similarities = [1 - distance for _, distance in rows]

        # too-few / no-match gate. Fewer than the required minimum means the floor
        # left an incomplete game; do NOT backfill below the floor or play a
        # degenerate short game -- surface a query-actionable 4xx instead.
        if len(rows) < min_results:
            await self._record_smart_search_event(
                _SmartSearchTelemetry(
                    game_id=game_id,
                    host_user_id=host_user_id,
                    query=query,
                    difficulty=question_round_settings.difficulty,
                    returned_uids=[str(fermi.uid) for fermi in questions],
                    returned_similarities=similarities,
                    outcome=SmartSearchOutcome.TOO_FEW,
                    floor_used=floor,
                    pool_size_used=effective_pool_size,
                ),
            )
            raise SearchNoResultsError(query=query, found=len(rows))

        questions = questions[:n_questions]
        similarities = similarities[:n_questions]

        # Success: record telemetry (game_id is the game being started).
        await self._record_smart_search_event(
            _SmartSearchTelemetry(
                game_id=game_id,
                host_user_id=host_user_id,
                query=query,
                difficulty=question_round_settings.difficulty,
                returned_uids=[str(fermi.uid) for fermi in questions],
                returned_similarities=similarities,
                outcome=SmartSearchOutcome.OK,
                floor_used=floor,
                pool_size_used=effective_pool_size,
            ),
        )
        return questions

    async def _record_smart_search_event(
        self,
        event: _SmartSearchTelemetry,
    ) -> None:
        """Insert a SmartSearchEvent, best-effort.

        Telemetry must never break a game start, so any failure (incl. a missing
        host id) is swallowed and logged rather than propagated. ``returned_uids``
        are strings (not ``uuid.UUID``): they land in a JSON column whose default
        serializer can't encode ``uuid.UUID``.
        """
        if event.host_user_id is None:
            # No host to attribute the event to; skip rather than fail the start.
            logger.warning('Skipping smart-search telemetry: missing host_user_id')
            return
        try:
            await self._db_client.fermi.insert_smart_search_event(
                SmartSearchEvent(
                    user_id=event.host_user_id,
                    game_id=event.game_id,
                    query=event.query,
                    difficulty=event.difficulty,
                    returned_uids=event.returned_uids,
                    n=len(event.returned_uids),
                    returned_similarities=event.returned_similarities,
                    outcome=event.outcome,
                    floor_used=event.floor_used,
                    pool_size_used=event.pool_size_used,
                ),
            )
        except Exception:
            logger.exception('Failed to record smart-search telemetry')
            # A failed insert/commit leaves the shared AsyncSession in a
            # pending-rollback state; without this, the next DB op in the
            # surrounding request (e.g. get_question_quantiles) would raise
            # PendingRollbackError and turn a successful search into a 500.
            # This is the recovery path, so the rollback must never raise out.
            try:
                await self._db_client.session.rollback()
            except Exception:
                logger.exception(
                    'Failed to roll back session after telemetry failure',
                )

    def _create_answer_events(
        self,
        game_id: str,
        players_results_docs: list[PlayersResultsDoc],
        questions_settings: dict[str, 'QuestionSettings'],
    ) -> list[AnswerEvent]:
        """Create answer events from players answers docs and questions settings.

        Note: Bot answers are skipped to preserve quantile statistics integrity.
        """
        from app.services.game.bots import is_bot

        answer_events = []
        for players_results_doc in players_results_docs:
            question_uid = players_results_doc['question_uid']
            for player_id, player_result in players_results_doc[
                'players_results'
            ].items():
                # Skip bot answers to preserve quantile statistics
                if is_bot(player_id):
                    continue
                answer_events.append(
                    AnswerEvent(
                        question_uid=uuid.UUID(question_uid),
                        question_difficulty=questions_settings[question_uid].difficulty,
                        question_category=questions_settings[question_uid].category,
                        user_firebase_id=player_id,
                        game_id=game_id,
                        answer=player_result['answer'],
                        correct_answer=player_result['correct_answer'],
                        score_number=player_result['score']['number'],
                        score_quantile=player_result['score']['quantile'],
                        game_mode=GameMode.PARTY,
                    ),
                )
        return answer_events

    async def archive_game_results(
        self,
        game_id: str,
        players_results_docs: list[PlayersResultsDoc],
        questions_settings: dict[str, 'QuestionSettings'],
    ) -> None:
        """Archive game results to the database.

        Done sequentially to avoid AsyncSession concurrency hazards and to
        guarantee history writes happen after answer events are stored.

        Note: Bot answers are skipped from both answer_events and user history.
        """
        from app.services.game.bots import is_bot

        # 1) Add users' answer events (bots filtered out in _create_answer_events)
        answer_events = self._create_answer_events(
            game_id=game_id,
            players_results_docs=players_results_docs,
            questions_settings=questions_settings,
        )
        await self._db_client.answers.add_answers(answer_events)

        # 2) Increment XP for each player based on their total score
        # Aggregate total score per player
        player_total_scores: dict[str, float] = {}
        for event in answer_events:
            player_id = event.user_firebase_id
            if player_id not in player_total_scores:
                player_total_scores[player_id] = 0.0
            player_total_scores[player_id] += event.score_number

        # Increment XP and points for each player
        for player_id, total_score in player_total_scores.items():
            xp_increment = int(total_score // 100)
            if xp_increment > 0:
                await self._db_client.users.increment_xp(player_id, xp_increment)
                await self._db_client.users.increment_points(player_id, xp_increment)

        # 3) Add questions to users' histories (skip bots)
        for players_results_doc in players_results_docs:
            user_ids = [
                pid
                for pid in players_results_doc['players_results'].keys()
                if not is_bot(pid)
            ]
            if user_ids:
                await self._db_client.users_history.add_questions_to_users_history(
                    user_ids=user_ids,
                    question_uids=(uuid.UUID(players_results_doc['question_uid']),),
                )

    async def get_player_stats(self, player_id: str) -> dict:
        """Get a player's raw stats.

        Returns a dict containing:
            - total_party_games: int
            - total_daily_guesses: int
            - average_percentile: int
            - xp: int
            - level: int (computed from xp)
            - points: int
        """
        avg_pct = await self._db_client.answers.get_overall_avg_percentile(
            player_id,
        )
        xp = await self._db_client.users.get_xp(player_id)
        level = (xp // 100) + 1
        points = await self._db_client.users.get_points(player_id)
        return {
            'total_party_games': await self._db_client.answers.count_user_party_games(
                player_id,
            ),
            'total_daily_guesses': await self._db_client.dq_answers.count_user_answers(
                player_id,
            ),
            'total_survival_runs': await self._db_client.survival_runs.count_user_survival_runs(  # noqa: E501
                player_id,
            ),
            'average_percentile': avg_pct,
            'xp': xp,
            'level': level,
            'points': points,
        }

    async def set_user_vote(
        self,
        *,
        question_uid: str,
        user_firebase_uid: str,
        verdict: int,
    ) -> int:
        """Set a user's verdict on a question and update aggregates.

        Returns the resulting verdict value.
        """
        result = await self._db_client.question_votes.set_verdict(
            question_uid=uuid.UUID(question_uid),
            user_firebase_uid=user_firebase_uid,
            verdict=VoteVerdict(verdict),
        )
        return int(result)
