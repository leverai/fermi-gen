"""Unit tests for bot utility functions and constants."""

from unittest.mock import Mock

from app.services.game.bots import BOT_IDS, BOTS, get_bot_answer, is_bot


def test_is_bot_returns_true_for_all_bot_ids() -> None:
    """All predefined bot IDs should be recognized as bots."""
    # GPT bots
    assert is_bot('bot-gpt51')
    assert is_bot('bot-gpt5mini')
    assert is_bot('bot-gpt5nano')
    # Gemini Flash bots
    assert is_bot('bot-gemini1')
    assert is_bot('bot-gemini2')
    assert is_bot('bot-gemini3')
    assert is_bot('bot-gemini4')
    assert is_bot('bot-gemini5')


def test_is_bot_returns_false_for_human_player_ids() -> None:
    """Human player IDs should not be recognized as bots."""
    assert not is_bot('user-123')
    assert not is_bot('firebase-uid-abc')
    assert not is_bot('bot')  # Missing hyphen and model name
    assert not is_bot('bot-unknown')


def test_bots_dictionary_structure() -> None:
    """BOTS dictionary should have correct structure with required fields."""
    assert len(BOTS) == 8  # 3 GPT + 5 Gemini Flash

    for bot_id, bot_info in BOTS.items():
        assert bot_id.startswith('bot-')
        assert 'id' in bot_info
        assert 'name' in bot_info
        assert 'picture' in bot_info
        assert 'model_key' in bot_info
        assert bot_info['id'] == bot_id
        assert isinstance(bot_info['name'], str)
        assert bot_info['picture'].startswith('/static/avatars/bots/')
        assert isinstance(bot_info['model_key'], str)


def test_bot_ids_frozenset_contains_all_bots() -> None:
    """BOT_IDS frozenset should contain all bot IDs from BOTS."""
    expected_ids = frozenset(
        [
            'bot-gpt51',
            'bot-gpt5mini',
            'bot-gpt5nano',
            'bot-gemini1',
            'bot-gemini2',
            'bot-gemini3',
            'bot-gemini4',
            'bot-gemini5',
        ],
    )
    assert BOT_IDS == expected_ids
    assert len(BOT_IDS) == 8


def test_get_bot_answer_extracts_gpt_5_1_answer() -> None:
    """get_bot_answer should extract gpt-5.1 answer from Fermi row."""
    fermi_row = Mock()
    fermi_row.gpt_5_1_number = 1234.5
    fermi_row.gpt_5_1_unit = 'meters'

    answer = get_bot_answer(fermi_row, 'bot-gpt51')

    assert answer['number'] == 1234.5
    assert answer['unit'] == 'meters'


def test_get_bot_answer_extracts_gpt_5_mini_answer() -> None:
    """get_bot_answer should extract gpt-5-mini answer from Fermi row."""
    fermi_row = Mock()
    fermi_row.gpt_5_mini_number = 999.0
    fermi_row.gpt_5_mini_unit = 'kilograms'

    answer = get_bot_answer(fermi_row, 'bot-gpt5mini')

    assert answer['number'] == 999.0
    assert answer['unit'] == 'kilograms'


def test_get_bot_answer_extracts_gpt_5_nano_answer() -> None:
    """get_bot_answer should extract gpt-5-nano answer from Fermi row."""
    fermi_row = Mock()
    fermi_row.gpt_5_nano_number = 42.0
    fermi_row.gpt_5_nano_unit = None

    answer = get_bot_answer(fermi_row, 'bot-gpt5nano')

    assert answer['number'] == 42.0
    assert answer['unit'] is None


def test_get_bot_answer_handles_null_unit() -> None:
    """get_bot_answer should handle dimensionless questions (null unit)."""
    fermi_row = Mock()
    fermi_row.gpt_5_1_number = 100.0
    fermi_row.gpt_5_1_unit = None

    answer = get_bot_answer(fermi_row, 'bot-gpt51')

    assert answer['number'] == 100.0
    assert answer['unit'] is None
