"""Unit tests for daily_question/timing.py."""

import datetime

from app.services.daily_question.timing import (
    AD_GRACE_S,
    ANSWER_TIMEOUT_S,
    DQ_DAY_START_HOUR,
    DQ_WINDOW_OPEN_HOUR,
    get_answer_deadline,
    get_dq_date_for_utc,
    get_window_for_date_utc,
    is_within_ad_grace,
    is_within_qd_grace,
    seconds_until,
)


class TestGetDqDateForUtc:
    """Tests for get_dq_date_for_utc date boundary logic."""

    def test_before_2am_returns_previous_day(self) -> None:  # noqa: D102
        # 1:59 AM on Dec 18 should be Dec 17's DQ
        now = datetime.datetime(2024, 12, 18, 1, 59, 0)  # noqa: DTZ001
        assert get_dq_date_for_utc(now) == datetime.date(2024, 12, 17)

    def test_at_2am_exactly_returns_same_day(self) -> None:  # noqa: D102
        # 2:00 AM on Dec 18 should be Dec 18's DQ
        now = datetime.datetime(2024, 12, 18, DQ_DAY_START_HOUR, 0, 0)  # noqa: DTZ001
        assert get_dq_date_for_utc(now) == datetime.date(2024, 12, 18)

    def test_afternoon_returns_same_day(self) -> None:  # noqa: D102
        now = datetime.datetime(2024, 12, 18, 14, 30, 0)  # noqa: DTZ001
        assert get_dq_date_for_utc(now) == datetime.date(2024, 12, 18)

    def test_midnight_returns_previous_day(self) -> None:  # noqa: D102
        # Midnight on Dec 18 is still Dec 17's DQ window
        now = datetime.datetime(2024, 12, 18, 0, 0, 0)  # noqa: DTZ001
        assert get_dq_date_for_utc(now) == datetime.date(2024, 12, 17)


class TestGetWindowForDateUtc:
    """Tests for get_window_for_date_utc window calculation."""

    def test_window_starts_at_noon_utc(self) -> None:  # noqa: D102
        date = datetime.date(2024, 12, 18)
        start, end = get_window_for_date_utc(date)

        expected_start = datetime.datetime(  # noqa: DTZ001
            2024,
            12,
            18,
            DQ_WINDOW_OPEN_HOUR,
            0,
            0,
        )
        assert start == expected_start

    def test_window_ends_at_2am_next_day(self) -> None:  # noqa: D102
        date = datetime.date(2024, 12, 18)
        start, end = get_window_for_date_utc(date)

        expected_end = datetime.datetime(  # noqa: DTZ001
            2024,
            12,
            19,
            DQ_DAY_START_HOUR,
            0,
            0,
        )
        assert end == expected_end

    def test_window_duration_is_14_hours(self) -> None:  # noqa: D102
        date = datetime.date(2024, 12, 18)
        start, end = get_window_for_date_utc(date)
        duration = (end - start).total_seconds() / 3600
        assert duration == 14.0


class TestGetAnswerDeadline:
    """Tests for get_answer_deadline calculation."""

    def test_returns_timeout_when_before_window_end(self) -> None:  # noqa: D102
        started_at = datetime.datetime(2024, 12, 18, 14, 0, 0)  # noqa: DTZ001
        window_end = datetime.datetime(2024, 12, 19, 2, 0, 0)  # noqa: DTZ001

        deadline = get_answer_deadline(started_at, window_end)
        expected = started_at + datetime.timedelta(seconds=ANSWER_TIMEOUT_S)

        assert deadline == expected

    def test_returns_window_end_when_timeout_exceeds_window(self) -> None:  # noqa: D102
        # Start at 1:59:50 AM, only 10 seconds before window closes
        started_at = datetime.datetime(2024, 12, 19, 1, 59, 50)  # noqa: DTZ001
        window_end = datetime.datetime(2024, 12, 19, 2, 0, 0)  # noqa: DTZ001

        deadline = get_answer_deadline(started_at, window_end)

        # Window end (10s) < timeout (30s), so window end wins
        assert deadline == window_end


class TestIsWithinAdGrace:
    """Tests for is_within_ad_grace grace period check."""

    def test_before_deadline_returns_true(self) -> None:  # noqa: D102
        deadline = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001
        now = datetime.datetime(2024, 12, 18, 14, 0, 25)  # noqa: DTZ001
        assert is_within_ad_grace(now, deadline) is True

    def test_at_deadline_returns_true(self) -> None:  # noqa: D102
        deadline = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001
        now = deadline
        assert is_within_ad_grace(now, deadline) is True

    def test_within_grace_period_returns_true(self) -> None:  # noqa: D102
        deadline = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001
        now = deadline + datetime.timedelta(seconds=AD_GRACE_S)
        assert is_within_ad_grace(now, deadline) is True

    def test_past_grace_period_returns_false(self) -> None:  # noqa: D102
        deadline = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001
        now = deadline + datetime.timedelta(seconds=AD_GRACE_S + 1)
        assert is_within_ad_grace(now, deadline) is False


class TestIsWithinQdGrace:
    """Tests for is_within_qd_grace grace period check."""

    def test_within_qd_grace_returns_true(self) -> None:  # noqa: D102
        qd = datetime.datetime(2024, 12, 19, 2, 0, 0)  # noqa: DTZ001
        now = qd + datetime.timedelta(seconds=55)  # QD_GRACE_S = 60
        assert is_within_qd_grace(now, qd) is True

    def test_past_qd_grace_returns_false(self) -> None:  # noqa: D102
        qd = datetime.datetime(2024, 12, 19, 2, 0, 0)  # noqa: DTZ001
        now = qd + datetime.timedelta(seconds=65)  # QD_GRACE_S = 60
        assert is_within_qd_grace(now, qd) is False


class TestSecondsUntil:
    """Tests for seconds_until calculation."""

    def test_returns_positive_when_target_in_future(self) -> None:  # noqa: D102
        now = datetime.datetime(2024, 12, 18, 14, 0, 0)  # noqa: DTZ001
        target = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001
        assert seconds_until(target, now) == 30.0

    def test_returns_negative_when_target_in_past(self) -> None:  # noqa: D102
        now = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001
        target = datetime.datetime(2024, 12, 18, 14, 0, 0)  # noqa: DTZ001
        assert seconds_until(target, now) == -30.0

    def test_returns_zero_when_equal(self) -> None:  # noqa: D102
        now = datetime.datetime(2024, 12, 18, 14, 0, 0)  # noqa: DTZ001
        assert seconds_until(now, now) == 0.0
