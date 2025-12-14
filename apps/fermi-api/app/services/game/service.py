"""Game service."""

import uuid
from typing import TYPE_CHECKING, Optional, cast

from fastapi import BackgroundTasks, HTTPException, Request, status
from google.cloud import firestore

from app.core.config import settings
from app.schemas.endpoints import (
    GameAnswerRequest,
    GameConfigResponse,
    GameCreateRequest,
    GameJoinRandomRequest,
    GameRemovePlayerRequest,
    GetPlayerStatsRequest,
    GetPlayerStatsResponse,
    IdModel,
)
from app.services.game.errors import ValidationError
from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway
from app.services.game.repositories.game_repo import GameRepository
from app.services.game.tasks.archive_game_results import archive_game_results
from app.services.game.tasks.fetch_and_set_questions import fetch_and_set_questions
from app.services.game.transactions.runner import TransactionRunner
from app.services.game.use_cases.end_game import EndGameUseCase
from app.services.game.use_cases.join_game import JoinGameUseCase
from app.services.game.use_cases.join_or_create_game import (
    JoinOrCreateGameUseCase,
    PostCommitData,
)
from app.services.game.use_cases.next_question import NextQuestionUseCase
from app.services.game.use_cases.remove_player import RemovePlayerUseCase
from app.services.game.use_cases.start_game import StartGameUseCase
from app.services.game.use_cases.submit_answer import SubmitAnswerUseCase
from app.services.game.utils import get_request_categories, get_request_difficulties
from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
from app.services.game.writers.players_answers_writer import (
    GamePlayersAnswersWriter,
)
from app.services.game.writers.players_writer import GamePlayersWriter
from app.services.game.writers.questions_writer import GameQuestionsWriter

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import (
        AsyncClient,
        AsyncTransaction,
    )


class GameService:
    """Service for game-related operations."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the game service."""
        self._db_gateway = GameAnalyticsGateway(db_client=db_client)
        self._lifecycle_writer = GameLifecycleWriter()
        self._questions_writer = GameQuestionsWriter()
        self._players_writer = GamePlayersWriter()
        self._players_results_writer = GamePlayersAnswersWriter()

    async def create_game(
        self,
        request: Request,
        payload: GameCreateRequest,
        background_tasks: BackgroundTasks,
        current_user: 'User',
        firestore_client: 'AsyncClient',
    ) -> IdModel:
        """Create a new game."""
        # 0. Prepare resources
        batch = firestore_client.batch()

        # 1. Create game document
        game_ref = await self._lifecycle_writer.create_game(
            games_ref=firestore_client.collection('games'),
            writer=batch,
        )

        # 2. Set players
        try:
            self._players_writer.set_players(
                game_ref=game_ref,
                writer=batch,
                host_id=current_user.firebase_uid,
                users=[current_user],
            )
        except ValidationError as err:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(err),
            ) from err

        # 3. Set misc fields
        version_uid = str(uuid.uuid4())
        base_url = str(request.base_url).rstrip('/')
        misc = {
            'join_url': f'{base_url}{settings.api_v1_str}/game/invite/{game_ref.id}',
            'private': payload.is_private,
            'version_uid': version_uid,
        }
        batch.update(game_ref, misc)

        # 4. Commit the batch
        await batch.commit()

        # 5. Fetch questions in the background and set them
        background_tasks.add_task(
            fetch_and_set_questions,
            lifecycle=self._lifecycle_writer,
            players_answers=self._players_results_writer,
            questions=self._questions_writer,
            game_ref=game_ref,
            batch=firestore_client.batch(),  # New batch
            user_ids=[current_user.firebase_uid],
            question_round_settings=payload.question_round_settings,
            version_uid=version_uid,
        )

        return IdModel(resource_id=game_ref.id)

    async def join_game(
        self,
        payload: IdModel,
        background_tasks: BackgroundTasks,
        current_user: 'User',
        firestore_client: 'AsyncClient',
        transaction: Optional['AsyncTransaction'] = None,
    ) -> IdModel:
        """Join an existing game by delegating to the use case.

        Schedules post-commit question fetching once the transaction completes.
        """
        # Delegate to use case and schedule post-commit task.
        use_case = JoinGameUseCase(
            firestore_client=firestore_client,
            txn_runner=TransactionRunner(firestore_client),
            repo=GameRepository(firestore_client),
            lifecycle=self._lifecycle_writer,
            players=self._players_writer,
            questions=self._questions_writer,
        )
        result = await use_case.execute(
            game_id=payload.resource_id,
            current_user=current_user,
        )

        game_ref = firestore_client.collection('games').document(payload.resource_id)
        background_tasks.add_task(
            fetch_and_set_questions,
            lifecycle=self._lifecycle_writer,
            players_answers=self._players_results_writer,
            questions=self._questions_writer,
            game_ref=game_ref,
            batch=firestore_client.batch(),
            user_ids=result['players_uids'],
            question_round_settings=result['question_round_settings'],
            version_uid=result['version_uid'],
        )

        return IdModel(resource_id=payload.resource_id)

    async def join_or_create_game(
        self,
        request: Request,
        payload: GameJoinRandomRequest,
        background_tasks: BackgroundTasks,
        current_user: 'User',
        firestore_client: 'AsyncClient',
    ) -> IdModel:
        """Join a matching public game or create a new one if none exists."""
        games_ref = firestore_client.collection('games')

        use_case = JoinOrCreateGameUseCase(
            firestore_client=firestore_client,
            repo=GameRepository(firestore_client),
            join_use_case=JoinGameUseCase(
                firestore_client=firestore_client,
                txn_runner=TransactionRunner(firestore_client),
                repo=GameRepository(firestore_client),
                lifecycle=self._lifecycle_writer,
                players=self._players_writer,
                questions=self._questions_writer,
            ),
        )

        @firestore.async_transactional
        async def _txn(
            transaction: 'AsyncTransaction',
        ) -> tuple[str | None, PostCommitData | None]:
            result = await use_case.execute_in_transaction(
                tx=transaction,
                payload=payload,
                current_user=current_user,
            )
            return result['game_id'], result['post_commit']

        transaction = firestore_client.transaction()
        game_id, post = cast(
            tuple[str | None, PostCommitData | None],
            await _txn(transaction),
        )

        # 2. If no game was found, create a new one
        if not game_id:
            response = await self.create_game(
                request=request,
                payload=GameCreateRequest(
                    question_round_settings=payload.question_round_settings,
                    is_private=False,
                ),
                background_tasks=background_tasks,
                current_user=current_user,
                firestore_client=firestore_client,
            )
            game_id = response.resource_id
        else:
            # Schedule post-commit re-fetch for the joined game
            game_ref = games_ref.document(game_id)
            assert post is not None
            background_tasks.add_task(
                fetch_and_set_questions,
                lifecycle=self._lifecycle_writer,
                players_answers=self._players_results_writer,
                questions=self._questions_writer,
                game_ref=game_ref,
                batch=firestore_client.batch(),
                user_ids=post['players_uids'],
                question_round_settings=post['question_round_settings'],
                version_uid=post['version_uid'],
            )

        return IdModel(resource_id=game_id)

    async def start_game(
        self,
        payload: IdModel,
        background_tasks: BackgroundTasks,
        current_user: 'User',
        firestore_client: 'AsyncClient',
    ) -> IdModel:
        """Start a game via the use case orchestration.

        If bots are present, schedules background task to submit their answers
        for the first question.
        """
        from app.services.game.bots import is_bot
        from app.services.game.tasks.submit_bot_answers import submit_bot_answers

        use_case = StartGameUseCase(
            firestore_client=firestore_client,
            repo=GameRepository(firestore_client),
            lifecycle=self._lifecycle_writer,
            questions=self._questions_writer,
            players_answers=self._players_results_writer,
        )
        result = await use_case.execute(
            game_id=payload.resource_id,
            current_user=current_user,
        )

        # Check for bots and schedule their answer submission
        game_ref = firestore_client.collection('games').document(
            payload.resource_id,
        )
        repo = GameRepository(firestore_client)
        game_data = await repo.get_game_fields(
            game_ref,
            fields=['players', 'question_uid'],
        )
        if game_data:
            players = game_data.get('players', {})
            bot_ids = [pid for pid in players if is_bot(pid)]
            question_uid = game_data.get('question_uid')
            if bot_ids and question_uid:
                background_tasks.add_task(
                    submit_bot_answers,
                    firestore_client=firestore_client,
                    game_id=payload.resource_id,
                    question_uid=question_uid,
                    bot_ids=bot_ids,
                )

        return result

    async def add_bots(
        self,
        request: 'Request',
        game_id: str,
        bot_ids: list[str],
        current_user: 'User',
        firestore_client: 'AsyncClient',
    ) -> IdModel:
        """Add bots to a game in lobby state.

        Only the host can add bots. Bots answer automatically when questions
        are revealed.
        """
        from app.services.game.use_cases.add_bots import AddBotsUseCase

        use_case = AddBotsUseCase(
            firestore_client=firestore_client,
            repo=GameRepository(firestore_client),
        )
        await use_case.execute(
            request=request,
            game_id=game_id,
            current_user=current_user,
            bot_ids=bot_ids,
        )
        return IdModel(resource_id=game_id)

    async def submit_answer(
        self,
        payload: GameAnswerRequest,
        current_user: 'User',
        firestore_client: 'AsyncClient',
        background_tasks: BackgroundTasks,
    ) -> IdModel:
        """Submit a player's answer by delegating to the use case.

        Transactional logic is encapsulated in ``SubmitAnswerUseCase``. Any
        follow-up side effects (like ending the game) are executed post-commit
        based on the use case result.
        """
        use_case = SubmitAnswerUseCase(
            firestore_client=firestore_client,
            txn_runner=TransactionRunner(firestore_client),
            repo=GameRepository(firestore_client),
            lifecycle=self._lifecycle_writer,
            players_answers=self._players_results_writer,
            players=self._players_writer,
        )

        result = await use_case.execute(
            game_id=payload.resource_id,
            player_id=current_user.firebase_uid,
            answer=payload.answer,
        )

        if result['questions_finished']:
            await self.end_game(
                payload=IdModel(resource_id=payload.resource_id),
                background_tasks=background_tasks,
                firestore_client=firestore_client,
                force=True,
            )

        return IdModel(resource_id=payload.resource_id)

    async def next_question(
        self,
        payload: IdModel,
        background_tasks: BackgroundTasks,
        current_user: 'User',
        firestore_client: 'AsyncClient',
    ) -> IdModel:
        """Reveal the next question via the use case orchestration.

        If bots are present, schedules background task to submit their answers.
        """
        from app.services.game.bots import is_bot
        from app.services.game.tasks.submit_bot_answers import submit_bot_answers

        use_case = NextQuestionUseCase(
            firestore_client=firestore_client,
            repo=GameRepository(firestore_client),
            lifecycle=self._lifecycle_writer,
            questions=self._questions_writer,
            players_answers=self._players_results_writer,
        )
        result = await use_case.execute(
            game_id=payload.resource_id,
            current_user=current_user,
        )

        # Check for bots and schedule their answer submission
        game_ref = firestore_client.collection('games').document(
            payload.resource_id,
        )
        repo = GameRepository(firestore_client)
        game_data = await repo.get_game_fields(
            game_ref,
            fields=['players', 'question_uid'],
        )
        if game_data:
            players = game_data.get('players', {})
            bot_ids = [pid for pid in players if is_bot(pid)]
            question_uid = game_data.get('question_uid')
            if bot_ids and question_uid:
                background_tasks.add_task(
                    submit_bot_answers,
                    firestore_client=firestore_client,
                    game_id=payload.resource_id,
                    question_uid=question_uid,
                    bot_ids=bot_ids,
                )

        return result

    async def remove_player(
        self,
        payload: GameRemovePlayerRequest,
        background_tasks: BackgroundTasks,
        current_user: 'User',
        firestore_client: 'AsyncClient',
    ) -> IdModel:
        """Remove a player from a game by delegating to the use case.

        Transactional orchestration lives in ``RemovePlayerUseCase`` and returns
        whether the game should be ended post-commit.
        """
        use_case = RemovePlayerUseCase(
            firestore_client=firestore_client,
            txn_runner=TransactionRunner(firestore_client),
            repo=GameRepository(firestore_client),
            lifecycle=self._lifecycle_writer,
            players=self._players_writer,
            players_answers=self._players_results_writer,
        )

        result = await use_case.execute(
            game_id=payload.resource_id,
            actor_user=current_user,
            remove_player_id=payload.player_id,
        )

        if result['should_end_game']:
            await self.end_game(
                payload=IdModel(resource_id=payload.resource_id),
                background_tasks=background_tasks,
                current_user=current_user,
                firestore_client=firestore_client,
            )

        return IdModel(resource_id=payload.resource_id)

    async def end_game(
        self,
        payload: IdModel,
        background_tasks: BackgroundTasks,
        firestore_client: 'AsyncClient',
        *,
        current_user: Optional['User'] = None,
        force: bool = False,
    ) -> IdModel:
        """End a game by delegating to the use case and scheduling archiving."""
        game_ref = firestore_client.collection('games').document(payload.resource_id)

        use_case = EndGameUseCase(
            firestore_client=firestore_client,
            txn_runner=TransactionRunner(firestore_client),
            repo=GameRepository(firestore_client),
            lifecycle=self._lifecycle_writer,
        )

        result = await use_case.execute(
            game_id=payload.resource_id,
            current_user=current_user,
            force=force,
        )

        if not result['started']:
            await game_ref.delete()
            return IdModel(resource_id=payload.resource_id)

        background_tasks.add_task(
            archive_game_results,
            firestore_client=firestore_client,
            repo=GameRepository(firestore_client),
            game_id=payload.resource_id,
        )

        return IdModel(resource_id=payload.resource_id)

    async def get_player_stats(
        self,
        payload: GetPlayerStatsRequest,
    ) -> GetPlayerStatsResponse:
        """Get a player's stats."""
        return GetPlayerStatsResponse(
            player_id=payload.player_id,
            stats=await self._db_gateway.get_player_stats(
                player_id=payload.player_id,
            ),
        )

    async def get_game_config(
        self,
        request: Request | None = None,
    ) -> GameConfigResponse:
        """Get the game config."""
        return GameConfigResponse(
            categories=get_request_categories(request),
            difficulties=get_request_difficulties(request),
        )

    # Legacy: update_votes no longer used; per-user votes are stored in votes table.

    async def vote(
        self,
        *,
        question_uid: str,
        user_firebase_uid: str,
        verdict: int,
    ) -> int:
        """Set a user's vote verdict and return the resulting verdict."""
        return await self._db_gateway.set_user_vote(
            question_uid=question_uid,
            user_firebase_uid=user_firebase_uid,
            verdict=verdict,
        )
