"""Mark questions as seen for a user in the DB.

Usage:
  uv run --package fermi-db python scripts/mark_seen.py --user <uid> \
    --question <uid> [--question <uid> ...]
"""

from __future__ import annotations

import argparse
from uuid import UUID

from fermi_db.repositories.user_history_repository import UserHistoryRepository
from fermi_db.session import session_context


async def _run(user_id: str, question_uids: list[str]) -> None:
    async with session_context() as session:
        repo = UserHistoryRepository(session=session)
        await repo.add_questions_to_users_history(
            [user_id],
            [UUID(u) for u in question_uids],
        )


def main() -> None:
    """Mark questions as seen for a user in the DB."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--user', required=True)
    parser.add_argument('--question', action='append', default=[])
    args = parser.parse_args()

    import asyncio

    asyncio.run(_run(args.user, args.question))


if __name__ == '__main__':
    main()
