"""Use case for joining or creating a game.

Find a public available game matching requested settings and join it within a
single Firestore transaction. If no suitable game exists, signal to the caller
to create one. Background tasks are scheduled by the caller post-commit.
"""

from typing import TYPE_CHECKING, TypedDict

from app.schemas.endpoints import GameJoinRandomRequest, QuestionRoundSettings

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import AsyncClient, AsyncTransaction

    from app.services.game.repositories.game_repo import GameRepository
    from app.services.game.use_cases.join_game import JoinGameUseCase


class PostCommitData(TypedDict):
    """Data required for post-commit background tasks after joining a game."""

    version_uid: str
    question_round_settings: QuestionRoundSettings
    players_uids: list[str]


class JoinOrCreateResult(TypedDict):
    """Result of attempting to join; includes post-commit data when joined."""

    game_id: str | None
    post_commit: PostCommitData | None


class JoinOrCreateGameUseCase:
    """Encapsulates the join-or-create orchestration."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        repo: 'GameRepository',
        join_use_case: 'JoinGameUseCase',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._repo = repo
        self._join_use_case = join_use_case

    async def execute_in_transaction(
        self,
        *,
        tx: 'AsyncTransaction',
        payload: GameJoinRandomRequest,
        current_user: 'User',
    ) -> JoinOrCreateResult:
        """Try to join a matching public game within the provided transaction."""
        games_ref = self._client.collection('games')

        # 1) Find a matching public game
        game = await self._repo.find_public_available_game(
            games_ref=games_ref,
            round_settings=payload.question_round_settings,
            tx=tx,
        )
        if not game:
            return JoinOrCreateResult(game_id=None, post_commit=None)

        # 2) Join the found game using the shared transaction
        join_result = await self._join_use_case.execute_in_transaction(
            tx=tx,
            game_id=game.id,
            current_user=current_user,
        )

        post: PostCommitData = {
            'version_uid': join_result['version_uid'],
            'question_round_settings': join_result['question_round_settings'],
            'players_uids': join_result['players_uids'],
        }
        return JoinOrCreateResult(game_id=join_result['game_id'], post_commit=post)
