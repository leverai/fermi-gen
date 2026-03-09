"""Timezone and deadline utilities for Daily Question mode.

All timestamps are stored and processed in UTC. The DQ window is defined as:
- NOT_STARTED: 2AM UTC to 12PM UTC (same day)
- ACTIVE: 12PM UTC to 2AM UTC (next day)
- CLOSED: After 2AM UTC (next day)
"""

import datetime
import logging
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

# Time zone constant
UTC_TZ = ZoneInfo('UTC')

# DQ window constants (in UTC hours)
DQ_DAY_START_HOUR = 2  # 2 AM UTC - when the DQ "day" starts
DQ_WINDOW_OPEN_HOUR = 12  # 12 PM UTC - when DQ becomes ACTIVE

# Deadline constants (in seconds)
ANSWER_TIMEOUT_S = 40  # Time to answer once started
AD_GRACE_S = 60  # Grace period after Answer Deadline
QD_GRACE_S = 60  # Grace period after Question Deadline


def get_dq_date_for_utc(now_utc: datetime.datetime) -> datetime.date:
    """Get the DQ date for a given UTC time.

    The DQ "day" runs from 2AM UTC to 2AM UTC (next day).
    - Between midnight and 2AM UTC: still in previous day's DQ window.
    - From 2AM UTC onwards: new DQ day.

    Args:
        now_utc: Current time in UTC (naive datetime).

    Returns:
        The DQ date.

    """
    if now_utc.hour < DQ_DAY_START_HOUR:
        # Still in previous day's DQ window
        return (now_utc - datetime.timedelta(days=1)).date()
    return now_utc.date()


def get_window_for_date_utc(
    date: datetime.date,
) -> tuple[datetime.datetime, datetime.datetime]:
    """Get the DQ window start and end times in UTC for a given date.

    For a DQ date X:
    - Window starts (ACTIVE) at 12PM UTC on date X
    - Window ends (CLOSED) at 2AM UTC on date X+1

    Args:
        date: The DQ date.

    Returns:
        Tuple of (window_start_utc, window_end_utc) as naive datetimes.

    """
    # Window opens at 12PM UTC on the DQ date
    window_start = datetime.datetime(  # noqa: DTZ001
        date.year,
        date.month,
        date.day,
        DQ_WINDOW_OPEN_HOUR,
        0,
        0,
    )

    # Window closes at 2AM UTC on the next day
    next_day = date + datetime.timedelta(days=1)
    window_end = datetime.datetime(  # noqa: DTZ001
        next_day.year,
        next_day.month,
        next_day.day,
        DQ_DAY_START_HOUR,
        0,
        0,
    )

    return (window_start, window_end)


def get_answer_deadline(
    started_at_utc: datetime.datetime,
    qd_utc: datetime.datetime,
) -> datetime.datetime:
    """Calculate the answer deadline for a user.

    The answer deadline is the earlier of:
    - started_at + ANSWER_TIMEOUT_S
    - Question Deadline (QD)

    Args:
        started_at_utc: When the user started the question (UTC).
        qd_utc: The question deadline (window end) in UTC.

    Returns:
        The answer deadline in UTC.

    """
    timeout_deadline = started_at_utc + datetime.timedelta(seconds=ANSWER_TIMEOUT_S)
    result = min(timeout_deadline, qd_utc)

    logger.info(
        '[get_answer_deadline] started_at=%s, qd=%s, '
        'timeout_deadline=%s, result=%s (using %s)',
        started_at_utc,
        qd_utc,
        timeout_deadline,
        result,
        'timeout' if result == timeout_deadline else 'qd',
    )

    return result


def is_within_ad_grace(
    now_utc: datetime.datetime,
    ad_utc: datetime.datetime,
) -> bool:
    """Check if current time is within Answer Deadline grace period.

    Args:
        now_utc: Current time in UTC.
        ad_utc: The answer deadline in UTC.

    Returns:
        True if within AD + grace period.

    """
    grace_end = ad_utc + datetime.timedelta(seconds=AD_GRACE_S)
    return now_utc.astimezone(UTC_TZ) <= grace_end.astimezone(UTC_TZ)


def is_within_qd_grace(
    now_utc: datetime.datetime,
    qd_utc: datetime.datetime,
) -> bool:
    """Check if current time is within Question Deadline grace period.

    Args:
        now_utc: Current time in UTC.
        qd_utc: The question deadline in UTC.

    Returns:
        True if within QD + grace period.

    """
    grace_end = qd_utc + datetime.timedelta(seconds=QD_GRACE_S)
    return now_utc <= grace_end


def seconds_until(target_utc: datetime.datetime, now_utc: datetime.datetime) -> float:
    """Calculate seconds until a target time.

    Args:
        target_utc: The target time in UTC.
        now_utc: Current time in UTC.

    Returns:
        Seconds until target (negative if target is in the past).

    """
    return (target_utc - now_utc).total_seconds()
