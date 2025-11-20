"""Scoring service for the Fermi-Gen game."""

from typing import TYPE_CHECKING

import pint

if TYPE_CHECKING:
    from fermi_db.schemas import AnswerBare

    from app.schemas.game import ScoreQuantiles


ureg = pint.UnitRegistry()
SCORE_MAX = 6000.0
ALPHA = 0.5


class ScoringService:
    """Service for scoring-related operations."""

    def _compute_bare_score(self, player_value: float, truth_value: float) -> float:
        """Compute the bare score as absolute difference of magnitudes."""
        ratio = max(player_value / truth_value, truth_value / player_value)
        return SCORE_MAX / ratio**ALPHA

    def calculate_score(
        self,
        player_answer: 'AnswerBare',
        correct_answer: 'AnswerBare',
    ) -> float:
        """Calculate the score for a player's answer.

        For now, the score is the absolute difference between magnitudes once
        both answers are expressed in the same unit. If answers are
        dimensionless, it is a plain numeric difference.
        """
        truth_qty = ureg.Quantity(
            correct_answer['number'],
            correct_answer.get('unit'),
        ).to_base_units()
        player_qty = ureg.Quantity(
            player_answer['number'],
            player_answer.get('unit'),
        ).to_base_units()

        return self._compute_bare_score(
            float(player_qty.magnitude),
            float(truth_qty.magnitude),
        )

    def get_score_quantile(
        self,
        score: float,
        quantiles: 'ScoreQuantiles',
    ) -> float:
        """Determine the quantile for a given score based on the distribution."""
        quantile_map = {
            0.99: quantiles['p99'],
            0.95: quantiles['p95'],
            0.90: quantiles['p90'],
            0.85: quantiles['p85'],
            0.80: quantiles['p80'],
            0.75: quantiles['p75'],
            0.60: quantiles['p60'],
            0.50: quantiles['p50'],
            0.25: quantiles['p25'],
            0.10: quantiles['p10'],
            0.05: quantiles['p05'],
            0.01: quantiles['p01'],
        }

        for quantile, value in quantile_map.items():
            if score >= value:
                return quantile

        return 0.0
