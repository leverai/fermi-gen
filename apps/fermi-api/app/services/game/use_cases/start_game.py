"""Use case for starting a game: fetch questions and reveal the first one.

Questions are fetched synchronously here (at start time) rather than at create
or join time. This keeps the work inside the request that triggered it — fully
traced and reliable — at the cost of some tolerable latency after the host hits
Start. Question selection accounts for every active (human) player so serving
stays fair across the whole party.
"""

from typing import TYPE_CHECKING, cast

from fastapi import HTTPException, status
from opentelemetry import trace

import app.logging.attributes as attrs
from app.schemas.endpoints import IdModel, QuestionRoundSettings
from app.schemas.game import GamePlayer, GameState
from app.services.game.bots import is_bot
from app.services.game.errors import (
    SearchEmbeddingError,
    SearchNoResultsError,
    StateConflictError,
)
from app.services.game.repositories.game_repo import GameRepository

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1.async_client import AsyncClient

    from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway
    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )
    from app.services.game.writers.questions_writer import GameQuestionsWriter


class StartGameUseCase:
    """Start the game by fetching questions and revealing the first one."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        repo: GameRepository,
        db_gateway: 'GameAnalyticsGateway',
        lifecycle: 'GameLifecycleWriter',
        questions: 'GameQuestionsWriter',
        players_answers: 'GamePlayersAnswersWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._repo = repo
        self._db_gateway = db_gateway
        self._lifecycle = lifecycle
        self._questions = questions
        self._players_answers = players_answers

    async def execute(
        self,
        *,
        game_id: str,
        current_user: 'User',
    ) -> IdModel:
        """Start the game and reveal the first question for `game_id`."""
        game_ref = self._client.collection('games').document(game_id)

        # Read minimal fields
        data = await self._repo.get_game_fields(
            game_ref,
            fields=[
                'host',
                'players',
                'state',
                'n_questions',
                'question_round_settings',
            ],
        )
        if not data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Game not found',
            )

        # Set OTel attributes after successful read
        span = trace.get_current_span()
        state = GameState(int(data['state']))
        span.set_attribute(attrs.GAME_STATE, state.name)
        players = cast(dict[str, GamePlayer], data.get('players', {}))
        span.set_attribute(attrs.GAME_PLAYER_COUNT, len(players))

        # Enforce host-only access
        if data.get('host') != current_user.firebase_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='Only host can start the game',
            )

        # Reject if the game is not in a startable state (before fetching, so a
        # double-start doesn't trigger a redundant question fetch).
        if state != GameState.LOBBY_READY:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Game is not ready',
            )

        # Fetch questions for all active human players so serving is fair.
        raw_settings = data.get('question_round_settings')
        if raw_settings:
            settings = QuestionRoundSettings.model_validate(raw_settings)
        else:
            # Legacy game created before round settings were persisted on the
            # doc. Fall back to safe defaults so a start can't fail mid-deploy.
            settings = QuestionRoundSettings(
                n_questions=int(data.get('n_questions') or 6),
                categories=None,
                difficulty=None,
            )
        user_ids = [
            pid
            for pid, player in players.items()
            if player.get('is_active', True) and not is_bot(pid)
        ]
        try:
            (
                questions_docs,
                answers_docs,
            ) = await self._db_gateway.get_questions_and_answers_docs(
                question_round_settings=settings,
                user_ids=user_ids,
                game_id=game_id,
                host_user_id=current_user.firebase_uid,
            )
        except SearchEmbeddingError as err:
            # Transient embed failure (OpenAI down/timeout) -> retryable 503.
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Couldn't build your search game, try again",
            ) from err
        except SearchNoResultsError as err:
            # The floor left too few matches. Not retryable for the same query;
            # the host must broaden/change it. Stable `code` lets the frontend
            # branch (vs. the retryable 503 above) instead of parsing the message.
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    'code': 'search_no_results',
                    'message': (
                        f"No questions match '{err.query}' — "
                        'try a broader or different search.'
                    ),
                },
            ) from err
        if not questions_docs:
            # Legacy category path only: the search path's min_results gate already
            # owns the empty/too-few outcome (raising SearchNoResultsError above).
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail='No questions available to start the game',
            )

        # Perform writes in a single batch
        batch = self._client.batch()

        # Set questions/answers docs and question_uids
        question_uids = self._questions.set_questions(
            game_ref=game_ref,
            writer=batch,
            questions_docs=questions_docs,
            answers_docs=answers_docs,
            request_categories=settings.categories,
            game_difficulty=settings.difficulty,
        )

        # Init players results docs for each question
        self._players_answers.init_players_results_docs(
            game_ref=game_ref,
            writer=batch,
            question_uids=question_uids,
        )

        # Reveal first question
        self._questions.reveal_question(
            game_ref=game_ref,
            writer=batch,
            question_uid=question_uids[0],
            question_order=1,
        )

        # Init progress for all players
        self._players_answers.init_progress(
            game_ref=game_ref,
            writer=batch,
            players_ids=players,
        )

        # Start lifecycle (sets started_at and state) using the actual count
        try:
            self._lifecycle.start_game(
                game_ref=game_ref,
                writer=batch,
                state=state,
                n_questions=len(question_uids),
            )
        except StateConflictError as err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(err),
            ) from err

        await batch.commit()
        return IdModel(resource_id=game_id)
