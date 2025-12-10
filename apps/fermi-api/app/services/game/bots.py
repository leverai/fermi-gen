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
}

# Ordered list for selecting N bots (best to worst by capability)
BOT_ORDER: list[str] = ['bot-gpt51', 'bot-gpt5mini', 'bot-gpt5nano']

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
