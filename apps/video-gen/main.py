"""Main entry point for video-gen Cloud Run job.

Reads DATE from environment variable, fetches the daily question,
generates a video, and uploads to GCS.
"""

import asyncio
import datetime
import logging
import os
import sys
import tempfile
from pathlib import Path

from fermi_db.dal import DatabaseClient
from fermi_db.models.game import Fermi
from fermi_db.session import session_context

from app.gcs import upload_to_gcs
from app.generator import VideoGenerator
from app.logging import setup_logging

logger = logging.getLogger(__name__)

# GCS bucket name matches app name per requirements
GCS_BUCKET = os.environ.get('GCS_BUCKET', 'fermi-video-gen')


def parse_date(date_str: str) -> datetime.date:
    """Parse a date string in YYYY-MM-DD format."""
    try:
        return datetime.datetime.strptime(date_str, '%Y-%m-%d').date()  # noqa: DTZ007
    except ValueError as e:
        msg = f"Invalid date format '{date_str}'. Expected YYYY-MM-DD."
        raise ValueError(msg) from e


def get_target_date() -> datetime.date:
    """Get the target date from environment or default to today."""
    date_str = os.environ.get('DATE')
    if date_str:
        return parse_date(date_str)

    # Default to today (UTC)
    return datetime.datetime.now(tz=datetime.UTC).date()


async def fetch_fermi_for_date(target_date: datetime.date) -> Fermi:
    """Fetch the Fermi object for a given date."""
    async with session_context() as session:
        db = DatabaseClient(session)

        dq = await db.daily_questions.get_dq_for_date(target_date)
        if not dq:
            msg = f'No daily question found for date {target_date}'
            raise ValueError(msg)

        logger.info(
            'Found DailyQuestion',
            extra={
                'json_fields': {
                    'date': str(target_date),
                    'question_uid': str(dq.question_uid),
                },
            },
        )

        fermi = await db.fermi.get_by_uid(dq.question_uid)
        if not fermi:
            msg = (
                f'Fermi question with UID {dq.question_uid} not found. '
                'Database integrity issue.'
            )
            raise ValueError(msg)

        logger.info('Fetched Fermi', extra={'json_fields': {'text': fermi.text[:50]}})
        return fermi


def main() -> None:
    """Generate video for daily question and upload to GCS."""
    setup_logging()

    logger.info('Starting video-gen job')

    # Get target date
    target_date = get_target_date()
    logger.info('Target date', extra={'json_fields': {'date': str(target_date)}})

    # Fetch Fermi from database
    fermi = asyncio.run(fetch_fermi_for_date(target_date))

    # Generate video in temp directory
    with tempfile.TemporaryDirectory() as tmpdir:
        output_dir = Path(tmpdir)
        assets_dir = Path(__file__).parent / 'assets'

        generator = VideoGenerator(output_dir=output_dir, assets_dir=assets_dir)
        video_path = generator.create_video(fermi)

        # Upload to GCS
        destination = f'{target_date.strftime("%Y-%m-%d")}/fermi_{fermi.uid}.mp4'
        gcs_uri = upload_to_gcs(
            local_path=video_path,
            bucket_name=GCS_BUCKET,
            destination_blob_name=destination,
        )

        logger.info('Job complete', extra={'json_fields': {'gcs_uri': gcs_uri}})


if __name__ == '__main__':
    try:
        main()
    except Exception:
        logger.exception('Job failed')
        sys.exit(1)
