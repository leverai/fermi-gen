#!/usr/bin/env python3
"""Local DQ Management Script.

Use this script to manage daily questions when testing locally.
It creates, starts, and ends daily questions in your local PostgreSQL database
and Firestore emulator.

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
    - Firebase emulators running (via docker-compose)
    - A DATABASE_URL environment variable or .env file
    - FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST,
      GOOGLE_CLOUD_PROJECT env vars

DQ Timing (UTC):
    - DQ "day" runs from 2AM UTC to 2AM UTC (next day)
    - NOT_STARTED phase: 2AM UTC to 12PM UTC
    - ACTIVE phase: 12PM UTC to 2AM UTC (next day)
    - CLOSED phase: After 2AM UTC (next day)
"""

import asyncio
import os
import sys
from datetime import timedelta

import httpx
from fermi_core.utils import utcnow_naive
from fermi_db import DatabaseClient
from fermi_db.models import DailyQuestion, Fermi
from fermi_db.schemas import DailyQuestionStatus, QuestionStatus
from fermi_db.session import get_session
from sqlmodel import select

from app.services.daily_question.timing import (
    get_dq_date_for_utc,
    get_window_for_date_utc,
)

os.environ['DATABASE_URL'] = (
    'postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db'
)
os.environ['FIRESTORE_EMULATOR_HOST'] = '127.0.0.1:8080'
os.environ['FIREBASE_AUTH_EMULATOR_HOST'] = '127.0.0.1:9099'
os.environ['GOOGLE_CLOUD_PROJECT'] = 'fermi-local'


async def get_firestore_writer():
    """Get Firestore writer configured for emulator if env vars are set.

    Returns:
        DQFirestoreWriter instance if Firestore is configured, None otherwise.
    """
    emulator_host = os.getenv('FIRESTORE_EMULATOR_HOST')
    project_id = os.getenv('GOOGLE_CLOUD_PROJECT', 'fermi-local')

    if not emulator_host:
        print('⚠️  Firestore emulator not configured (FIRESTORE_EMULATOR_HOST not set)')
        print('   Firestore documents will NOT be created/updated')
        return None

    try:
        from google.cloud.firestore import AsyncClient

        from app.services.daily_question.firestore_writer import DQFirestoreWriter

        # AsyncClient will automatically use FIRESTORE_EMULATOR_HOST if set
        client = AsyncClient(project=project_id)
        print(f'✓ Connected to Firestore emulator at {emulator_host}')
        return DQFirestoreWriter(client)
    except Exception as e:
        print(f'⚠️  Failed to initialize Firestore: {e}')
        print('   Continuing with database-only mode')
        return None


async def close_and_schedule() -> None:
    """Close the active DQ and schedule a new one."""
    api_url = 'http://localhost:8000/api/v1/daily_question/close_and_schedule'
    print(f'📤 Calling API: POST {api_url}')

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(api_url, timeout=30.0)
            resp.raise_for_status()
            data = resp.json()

        print(f'✅ DQ for {data["closed_date"]} has been closed')
        print(f'   Participants ranked: {data["participants_ranked"]}')

        if data.get('next_date'):
            print(f'   Next DQ scheduled: {data["next_date"]}')
            print(f'   Next question UID: {data["next_question_uid"]}')
        else:
            print('   ⚠️  No next DQ scheduled (no available questions)')

    except httpx.HTTPStatusError as e:
        print(f'❌ API error: {e.response.status_code}')
        print(f'   {e.response.text}')
    except httpx.RequestError as e:
        print(f'❌ Request failed: {e}')
        print('   Is the API server running? (make run-api)')


async def activate_dq() -> None:
    """Activate today's DQ."""
    api_url = 'http://localhost:8000/api/v1/daily_question/activate'
    print(f'📤 Calling API: POST {api_url}')

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(api_url, timeout=30.0)
            resp.raise_for_status()
            data = resp.json()

        print(f'✅ DQ for {data["closed_date"]} has been closed')
        print(f'   Participants ranked: {data["participants_ranked"]}')

        if data.get('next_date'):
            print(f'   Next DQ scheduled: {data["next_date"]}')
            print(f'   Next question UID: {data["next_question_uid"]}')
        else:
            print('   ⚠️  No next DQ scheduled (no available questions)')

    except httpx.HTTPStatusError as e:
        print(f'❌ API error: {e.response.status_code}')
        print(f'   {e.response.text}')
    except httpx.RequestError as e:
        print(f'❌ Request failed: {e}')
        print('   Is the API server running? (make run-api)')


async def advance_dq() -> None:
    """Advance to next day: shift all DQs back, close today's DQ, create new DQ."""
    async for session in get_session():
        now_utc = utcnow_naive()
        today = get_dq_date_for_utc(now_utc)

        # 1. Cascade shift ALL existing DQs back by 1 day (oldest first to avoid
        # conflicts)
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

            # Close and mark results ready in Firestore
            fs_writer = await get_firestore_writer()
            if fs_writer:
                try:
                    await fs_writer.close_dq_document(yesterday)
                    await fs_writer.set_results_ready(yesterday)
                    print('   ✓ Firestore document closed and results ready')
                except Exception as e:
                    print(f'   ⚠️  Firestore update failed: {e}')

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

        # Create DQ for today using UTC-based timing
        window_start, window_end = get_window_for_date_utc(today)
        new_dq = DailyQuestion(
            question_uid=question.uid,
            question_date=today,
            status=DailyQuestionStatus.ACTIVE,  # ACTIVE for testing
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

        # Create Firestore document
        fs_writer = await get_firestore_writer()
        if fs_writer:
            try:
                await fs_writer.create_dq_document(
                    today,
                    str(question.uid),
                    window_start,
                    window_end,
                )
                # Immediately activate it for local testing
                await fs_writer.activate_dq_document(today)
                print('   ✓ Firestore document created and activated')
            except Exception as e:
                print(f'   ⚠️  Firestore update failed: {e}')

        break


async def seed_dq_questions(count: int = 10) -> None:
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
    """Main entry point for the script."""
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]

    if command == 'close_and_schedule':
        asyncio.run(close_and_schedule())
    elif command == 'activate':
        asyncio.run(activate_dq())
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
