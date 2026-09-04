"""Unit tests for lobby-settings Firestore writes."""

# ruff: noqa: D103
from typing import Any, cast

from tests.unit.conftest import RecorderWriter

from app.schemas.endpoints import QuestionRoundSettings
from app.services.game.writers.settings_writer import GameSettingsWriter


def test_set_lobby_settings_persists_round_configuration(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
) -> None:
    settings = QuestionRoundSettings(
        n_questions=3,
        categories=None,
        difficulty=None,
        search_query='deep sea animals',
    )

    GameSettingsWriter().set_lobby_settings(
        game_ref=cast(Any, fake_doc_ref),
        writer=cast(Any, recorder_writer),
        join_url='https://example.test/invite/game-1',
        round_settings=settings,
    )

    assert recorder_writer.updates == [
        (
            fake_doc_ref,
            {
                'join_url': 'https://example.test/invite/game-1',
                'n_questions': 3,
                'question_round_settings': settings.model_dump(mode='json'),
            },
        ),
    ]
