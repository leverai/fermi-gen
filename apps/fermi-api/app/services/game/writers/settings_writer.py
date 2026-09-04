"""Write-only lobby settings mutations for game documents."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from google.cloud.firestore_v1.async_document import AsyncDocumentReference

    from app.schemas.endpoints import QuestionRoundSettings
    from app.services.game.utils import Writeable


class GameSettingsWriter:
    """Persist configuration selected while creating a lobby."""

    def set_lobby_settings(
        self,
        *,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        join_url: str,
        round_settings: 'QuestionRoundSettings',
    ) -> None:
        """Store the invite URL and question-round configuration."""
        writer.update(
            game_ref,
            {
                'join_url': join_url,
                'n_questions': round_settings.n_questions,
                'question_round_settings': round_settings.model_dump(mode='json'),
            },
        )
