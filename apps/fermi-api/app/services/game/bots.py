"""Bot player definitions and utilities.

Bots are virtual players powered by LLM-generated answers from the fermi
materialized view. Each bot corresponds to a different LLM model:
- gpt-5.1: Most capable, typically closest to correct answer
- gpt-5-mini: Mid-tier model
- gpt-5-nano: Smallest model, typically furthest from correct answer
"""

from typing import TYPE_CHECKING, TypedDict

from fermi_db.schemas import AnswerBare

if TYPE_CHECKING:
    from fermi_db.models import Fermi


class BotInfo(TypedDict):
    """Bot player information."""

    id: str
    name: str
    picture: str
    model_key: str  # e.g., 'gpt_5_1' for accessing fermi.gpt_5_1_number


# Bot definitions - IDs prefixed with 'bot-' for easy identification
BOTS: dict[str, BotInfo] = {
    # GPT bots (smart, competitive)
    'bot-gpt51': BotInfo(
        id='bot-gpt51',
        name='GPT 5.1',
        picture='/static/avatars/bots/gpt-5.1.svg',
        model_key='gpt_5_1',
    ),
    'bot-gpt5mini': BotInfo(
        id='bot-gpt5mini',
        name='GPT 5 Mini',
        picture='/static/avatars/bots/gpt-5-mini.svg',
        model_key='gpt_5_mini',
    ),
    'bot-gpt5nano': BotInfo(
        id='bot-gpt5nano',
        name='GPT 5 Nano',
        picture='/static/avatars/bots/gpt-5-nano.svg',
        model_key='gpt_5_nano',
    ),
    # Gemini Flash bots (casual, high-temperature, less accurate)
    'bot-gemini1': BotInfo(
        id='bot-gemini1',
        name='RoboMcBotface',
        picture='/static/avatars/bots/gemini-flash-1.svg',
        model_key='gemini_flash_1',
    ),
    'bot-gemini2': BotInfo(
        id='bot-gemini2',
        name='Toast-R2',
        picture='/static/avatars/bots/gemini-flash-2.svg',
        model_key='gemini_flash_2',
    ),
    'bot-gemini3': BotInfo(
        id='bot-gemini3',
        name='Sir Beeps-a-Lot',
        picture='/static/avatars/bots/gemini-flash-3.svg',
        model_key='gemini_flash_3',
    ),
    'bot-gemini4': BotInfo(
        id='bot-gemini4',
        name='GiggleByte',
        picture='/static/avatars/bots/gemini-flash-4.svg',
        model_key='gemini_flash_4',
    ),
    'bot-gemini5': BotInfo(
        id='bot-gemini5',
        name='Wheely Big Cheese',
        picture='/static/avatars/bots/gemini-flash-5.svg',
        model_key='gemini_flash_5',
    ),
}

BOT_IDS = frozenset(BOTS.keys())


def is_bot(player_id: str) -> bool:
    """Check if player_id is a bot."""
    return player_id in BOT_IDS


def get_bot_answer(fermi_row: 'Fermi', bot_id: str) -> AnswerBare:
    """Extract bot's answer from fermi row based on bot_id.

    Args:
        fermi_row: A Fermi model instance with LLM answer columns.
        bot_id: The bot's player ID (e.g., 'bot-gpt51').

    Returns:
        AnswerBare with the bot's number and unit.

    """
    bot = BOTS[bot_id]
    key = bot['model_key']
    return AnswerBare(
        number=getattr(fermi_row, f'{key}_number'),
        unit=getattr(fermi_row, f'{key}_unit'),
    )
