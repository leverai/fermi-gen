"""Timezone and deadline utilities for Daily Question mode.

All timestamps are stored in UTC. This module handles conversion
to/from US Central time for display and deadline calculations.
"""

import datetime
from zoneinfo import ZoneInfo

# Time zone constants
CENTRAL_TZ = ZoneInfo('America/Chicago')
UTC_TZ = ZoneInfo('UTC')

# DQ window constants (in Central time)
DQ_START_HOUR = 8  # 8 AM Central
DQ_END_HOUR = 20  # 8 PM Central

# Deadline constants (in seconds)
ANSWER_TIMEOUT_S = 30  # Time to answer once started
AD_GRACE_S = 5  # Grace period after Answer Deadline
QD_GRACE_S = 20  # Grace period after Question Deadline


def central_to_utc(dt: datetime.datetime) -> datetime.datetime:
    """Convert a Central time datetime to UTC.

    Args:
        dt: A datetime in Central time (with or without tzinfo).

    Returns:
        The same moment in UTC as a naive datetime.

    """
    if dt.tzinfo is None:
        # Assume it's Central time
        dt = dt.replace(tzinfo=CENTRAL_TZ)
    return dt.astimezone(UTC_TZ).replace(tzinfo=None)


def utc_to_central(dt: datetime.datetime) -> datetime.datetime:
    """Convert a UTC datetime to Central time.

    Args:
        dt: A naive datetime assumed to be UTC.

    Returns:
        The same moment in Central time as a naive datetime.

    """
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC_TZ)
    return dt.astimezone(CENTRAL_TZ).replace(tzinfo=None)


def get_todays_date_central(now_utc: datetime.datetime) -> datetime.date:
    """Get today's date in Central time.

    Args:
        now_utc: Current time in UTC.

    Returns:
        Today's date in Central timezone.

    """
    return utc_to_central(now_utc).date()


def get_window_for_date_utc(
    date: datetime.date,
) -> tuple[datetime.datetime, datetime.datetime]:
    """Get the DQ window start and end times in UTC for a given date.

    Args:
        date: The date (in Central time) for which to get the window.

    Returns:
        Tuple of (window_start_utc, window_end_utc) as naive datetimes.

    """
    # Create Central time datetimes
    window_start_central = datetime.datetime(
        date.year,
        date.month,
        date.day,
        DQ_START_HOUR,
        0,
        0,
        tzinfo=CENTRAL_TZ,
    )
    window_end_central = datetime.datetime(
        date.year,
        date.month,
        date.day,
        DQ_END_HOUR,
        0,
        0,
        tzinfo=CENTRAL_TZ,
    )

    # Convert to UTC
    return (
        window_start_central.astimezone(UTC_TZ).replace(tzinfo=None),
        window_end_central.astimezone(UTC_TZ).replace(tzinfo=None),
    )


def is_window_open(
    now_utc: datetime.datetime, dq_window_end_utc: datetime.datetime,
) -> bool:
    """Check if the DQ window is currently open.

    Args:
        now_utc: Current time in UTC.
        dq_window_end_utc: The DQ window end time in UTC.

    Returns:
        True if the window is open (now < window_end).

    """
    return now_utc < dq_window_end_utc


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
    return min(timeout_deadline, qd_utc)


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
    return now_utc <= grace_end


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
