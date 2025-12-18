#!/usr/bin/env python3
"""Local DQ Management Script.

Use this script to manage daily questions when testing locally.
It creates, starts, and ends daily questions in your local PostgreSQL database.

Usage:
    # List available DQ questions
    python scripts/manage_dq.py list

    # Create today's daily question (picks next available question)
    python scripts/manage_dq.py create

    # Manually start the DQ window (set status to ACTIVE)
    python scripts/manage_dq.py start

    # Manually end the DQ window (set status to CLOSED)
    python scripts/manage_dq.py end

    # Advance to next day: close current DQ, shift date back, create new DQ
    python scripts/manage_dq.py advance

    # Mark some fermi questions as daily question candidates
    python scripts/manage_dq.py seed --count 10

Prerequisites:
    - PostgreSQL running (via docker-compose)
    - A DATABASE_URL environment variable or .env file
"""

import asyncio
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fermi_db import DatabaseClient
from fermi_db.models import DailyQuestion, Fermi
from fermi_db.schemas import DailyQuestionStatus, QuestionStatus
from fermi_db.session import DATABASE_URL, get_session
from sqlmodel import select

# Central Time zone for DQ window calculation
CT = ZoneInfo('America/Chicago')


def check_database_url() -> None:
    """Verify DATABASE_URL is set and points to PostgreSQL, not SQLite."""
    if 'sqlite' in DATABASE_URL.lower():
        print('❌ Error: DATABASE_URL is pointing to SQLite.', file=sys.stderr)
        print('', file=sys.stderr)
        print('This script requires a PostgreSQL database.', file=sys.stderr)
        print('Set DATABASE_URL before running:', file=sys.stderr)
        print('', file=sys.stderr)
        print(
            '  export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db',
            file=sys.stderr,
        )
        print('', file=sys.stderr)
        print('Or run via Makefile which sets it automatically:', file=sys.stderr)
        print('  make run-frontend', file=sys.stderr)
        sys.exit(1)


def get_today_ct() -> datetime:
    """Get today's date in Central Time."""
    return datetime.now(CT).replace(hour=0, minute=0, second=0, microsecond=0)


def get_window_times(date: datetime) -> tuple[datetime, datetime]:
    """Get the DQ window start and end times for a given date.

    Window: 12 AM CT to 8 PM CT (8 PM = 20:00)
    Returns UTC naive datetimes.
    """
    # Window start: midnight CT
    start_ct = date.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=CT)
    # Window end: 8 PM CT (20:00)
    end_ct = date.replace(hour=20, minute=0, second=0, microsecond=0, tzinfo=CT)

    # Convert to UTC and make naive
    start_utc = start_ct.astimezone(timezone.utc).replace(tzinfo=None)
    end_utc = end_ct.astimezone(timezone.utc).replace(tzinfo=None)

    return start_utc, end_utc


async def list_dq_questions():
    """List available DQ questions and current DQ status."""
    async for session in get_session():
        # Count available DQ questions
        stmt = select(Fermi).where(
            Fermi.status == QuestionStatus.APPROVED,
            Fermi.is_daily_question == True,  # noqa: E712
        )
        result = await session.exec(stmt)
        dq_questions = result.all()

        print(f'\n📋 DQ-flagged questions: {len(dq_questions)}')
        for q in dq_questions[:5]:
            print(f'  - {q.uid}: {q.text[:50]}...')
        if len(dq_questions) > 5:
            print(f'  ... and {len(dq_questions) - 5} more')

        # Get today's DQ
        today = get_today_ct().date()
        stmt = select(DailyQuestion).where(DailyQuestion.question_date == today)
        result = await session.exec(stmt)
        dq = result.one_or_none()

        if dq:
            print(f"\n📅 Today's DQ (ID: {dq.id}):")
            print(f'  Question UID: {dq.question_uid}')
            print(f'  Status: {dq.status}')
            print(f'  Window: {dq.window_start} - {dq.window_end}')
        else:
            print(f'\n⚠️  No DQ scheduled for today ({today})')

        print()
        break


async def create_dq():
    """Create today's daily question from the next available DQ question."""
    async for session in get_session():
        today = get_today_ct().date()

        # Check if DQ already exists for today
        stmt = select(DailyQuestion).where(DailyQuestion.question_date == today)
        result = await session.exec(stmt)
        existing = result.one_or_none()

        if existing:
            print(f'⚠️  DQ already exists for today (ID: {existing.id})')
            return

        # Find next unused DQ question
        used_uids = select(DailyQuestion.question_uid).subquery()
        stmt = (
            select(Fermi)
            .where(
                Fermi.status == QuestionStatus.APPROVED,
                Fermi.is_daily_question == True,  # noqa: E712
                ~Fermi.uid.in_(select(used_uids)),
            )
            .order_by(Fermi.created_at.desc())
            .limit(1)
        )
        result = await session.exec(stmt)
        question = result.one_or_none()

        if not question:
            print('❌ No unused DQ questions available!')
            print('   Run: python scripts/manage_dq.py seed --count 10')
            return

        # Create DQ for today
        window_start, window_end = get_window_times(get_today_ct())
        dq = DailyQuestion(
            question_uid=question.uid,
            question_date=today,
            status=DailyQuestionStatus.ACTIVE,  # Start as ACTIVE for local testing
            window_start=window_start,
            window_end=window_end,
        )
        session.add(dq)
        await session.commit()
        await session.refresh(dq)

        print(f"✅ Created today's DQ (ID: {dq.id})")
        print(f'   Question: {question.text[:80]}...')
        print(f'   Status: {dq.status}')
        print(f'   Window: {dq.window_start} - {dq.window_end} UTC')


async def start_dq():
    """Set today's DQ status to ACTIVE."""
    async for session in get_session():
        today = get_today_ct().date()

        stmt = select(DailyQuestion).where(DailyQuestion.question_date == today)
        result = await session.exec(stmt)
        dq = result.one_or_none()

        if not dq:
            print(f'❌ No DQ found for today ({today})')
            print('   Run: python scripts/manage_dq.py create')
            return

        dq.status = DailyQuestionStatus.ACTIVE
        session.add(dq)
        await session.commit()

        print(f'✅ DQ {dq.id} is now ACTIVE')


async def end_dq():
    """Set today's DQ status to CLOSED and compute ranks."""
    async for session in get_session():
        today = get_today_ct().date()

        stmt = select(DailyQuestion).where(DailyQuestion.question_date == today)
        result = await session.exec(stmt)
        dq = result.one_or_none()

        if not dq:
            print(f'❌ No DQ found for today ({today})')
            return

        dq.status = DailyQuestionStatus.CLOSED
        session.add(dq)
        await session.flush()

        # Compute and update ranks for all participants
        if dq.id:
            db_client = DatabaseClient(session)
            count = await db_client.dq_answers.compute_and_update_ranks(dq.id)
            print(f'   Computed ranks for {count} participants')

        await session.commit()

        print(f'✅ DQ {dq.id} is now CLOSED')


async def advance_dq():
    """Advance to next day: shift all DQs back, close today's DQ, create new DQ."""
    async for session in get_session():
        today = get_today_ct().date()

        # 1. Cascade shift ALL existing DQs back by 1 day (oldest first to avoid conflicts)
        stmt = select(DailyQuestion).order_by(DailyQuestion.question_date.asc())
        result = await session.exec(stmt)
        all_dqs = result.all()

        if all_dqs:
            print(f'📦 Shifting {len(all_dqs)} existing DQ(s) back by 1 day...')
            for dq in all_dqs:
                old_date = dq.question_date
                dq.question_date = old_date - timedelta(days=1)
                session.add(dq)
            await session.flush()

        # 2. Find and close the DQ that was at today (now at yesterday)
        yesterday = today - timedelta(days=1)
        stmt = select(DailyQuestion).where(DailyQuestion.question_date == yesterday)
        result = await session.exec(stmt)
        current_dq = result.one_or_none()

        if current_dq and current_dq.status != DailyQuestionStatus.CLOSED:
            # Close and compute ranks
            current_dq.status = DailyQuestionStatus.CLOSED
            session.add(current_dq)
            await session.flush()

            # Compute and update ranks
            if current_dq.id:
                db_client = DatabaseClient(session)
                count = await db_client.dq_answers.compute_and_update_ranks(
                    current_dq.id,
                )
                print(f'   Computed ranks for {count} participants')
            print(f'✅ Closed DQ {current_dq.id} (now at {current_dq.question_date})')

        # 3. Create new DQ for today
        # Find next unused DQ question
        used_uids = select(DailyQuestion.question_uid).subquery()
        stmt = (
            select(Fermi)
            .where(
                Fermi.status == QuestionStatus.APPROVED,
                Fermi.is_daily_question == True,  # noqa: E712
                ~Fermi.uid.in_(select(used_uids)),
            )
            .order_by(Fermi.created_at.asc())
            .limit(1)
        )
        result = await session.exec(stmt)
        question = result.one_or_none()

        if not question:
            print('❌ No unused DQ questions available!')
            print('   Run: python scripts/manage_dq.py seed --count 10')
            await session.commit()
            return

        # Create DQ for today
        window_start, window_end = get_window_times(get_today_ct())
        new_dq = DailyQuestion(
            question_uid=question.uid,
            question_date=today,
            status=DailyQuestionStatus.ACTIVE,  # Start as ACTIVE for local testing
            window_start=window_start,
            window_end=window_end,
        )
        session.add(new_dq)
        await session.commit()
        await session.refresh(new_dq)

        print(f"✅ Created today's DQ (ID: {new_dq.id})")
        print(f'   Question: {question.text[:80]}...')
        print(f'   Status: {new_dq.status}')
        print(f'   Window: {new_dq.window_start} - {new_dq.window_end} UTC')
        break


async def seed_dq_questions(count: int = 10):
    """Mark some APPROVED questions as daily question candidates."""
    async for session in get_session():
        # Find APPROVED questions that aren't already DQ-flagged
        stmt = (
            select(Fermi)
            .where(
                Fermi.status == QuestionStatus.APPROVED,
                Fermi.is_daily_question == False,  # noqa: E712
            )
            .order_by(Fermi.created_at.asc())
            .limit(count)
        )
        result = await session.exec(stmt)
        questions = result.all()

        if not questions:
            print('⚠️  No APPROVED questions available to mark as DQ')
            return

        for q in questions:
            q.is_daily_question = True
            session.add(q)

        await session.commit()

        print(f'✅ Marked {len(questions)} questions as daily question candidates')
        for q in questions:
            print(f'  - {q.uid}: {q.text[:50]}...')


def main() -> None:
    check_database_url()

    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]

    if command == 'list':
        asyncio.run(list_dq_questions())
    elif command == 'create':
        asyncio.run(create_dq())
    elif command == 'start':
        asyncio.run(start_dq())
    elif command == 'end':
        asyncio.run(end_dq())
    elif command == 'advance':
        asyncio.run(advance_dq())
    elif command == 'seed':
        count = 10
        if '--count' in sys.argv:
            idx = sys.argv.index('--count')
            if idx + 1 < len(sys.argv):
                count = int(sys.argv[idx + 1])
        asyncio.run(seed_dq_questions(count))
    else:
        print(f'Unknown command: {command}')
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
