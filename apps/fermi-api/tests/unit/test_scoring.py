"""Unit tests for services/scoring.py."""

# ruff: noqa: D103
from typing import Any, cast

from fermi_db.schemas import AnswerBare

from app.services.scoring import ScoringService


def test_calculate_score_dimensionless_identical_values() -> None:
    s = ScoringService()
    score = s.calculate_score(
        AnswerBare(number=100.0, unit=None),
        AnswerBare(number=100.0, unit=None),
    )
    # Identical magnitudes → max score
    assert score > 0


def test_calculate_score_unit_conversion_equivalent_magnitudes() -> None:
    s = ScoringService()
    # 1 kilometer equals 1000 meters → magnitudes equal after conversion
    score_km = s.calculate_score(
        AnswerBare(number=1.0, unit='kilometer'),
        AnswerBare(number=1000.0, unit='meter'),
    )
    score_m = s.calculate_score(
        AnswerBare(number=1000.0, unit='meter'),
        AnswerBare(number=1000.0, unit='meter'),
    )
    assert abs(score_km - score_m) < 1e-9


def test_get_score_quantile_selection_and_floor() -> None:
    s = ScoringService()
    quantiles = cast(
        Any,
        {
            'p01': 10.0,
            'p05': 20.0,
            'p10': 30.0,
            'p25': 40.0,
            'p50': 50.0,
            'p60': 60.0,
            'p75': 70.0,
            'p80': 80.0,
            'p85': 90.0,
            'p90': 100.0,
            'p95': 110.0,
            'p99': 120.0,
        },
    )

    assert s.get_score_quantile(125.0, quantiles) == 0.99
    assert s.get_score_quantile(95.0, quantiles) == 0.85
    assert s.get_score_quantile(5.0, quantiles) == 1.0
