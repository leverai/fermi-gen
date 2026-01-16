"""Unit tests for the global percentile computation algorithm.

These tests validate the mathematical correctness of the percentile ranking
logic used in get_overall_avg_percentile without requiring database resources.
"""


def compute_percentile(player_avg: float, all_player_avgs: list[float]) -> int:
    """Pure function to compute global percentile.

    This mirrors the logic in AnswerRepository.get_overall_avg_percentile.

    Args:
        player_avg: The target player's average score.
        all_player_avgs: List of all players' average scores (including target).

    Returns:
        The percentile (0-100).

    """
    if not all_player_avgs:
        return 0

    lower_count = sum(1 for avg in all_player_avgs if avg < player_avg)
    total_count = len(all_player_avgs)

    return int((lower_count / total_count) * 100)


class TestGlobalPercentileComputation:
    """Test cases for the global percentile algorithm."""

    def test_single_player_returns_zero(self) -> None:
        """One player is at 0th percentile (no one below them)."""
        assert compute_percentile(100.0, [100.0]) == 0

    def test_top_player_among_many(self) -> None:
        """Best player should have high percentile."""
        # Player with score 5000 is better than 99 others with scores 100-4999
        all_players = [float(i * 50) for i in range(1, 100)]  # 50 to 4950
        all_players.append(5000.0)  # Our player

        # 99 players below, 100 total -> 99/100 = 99%
        assert compute_percentile(5000.0, all_players) == 99

    def test_bottom_player_among_many(self) -> None:
        """Worst player should have 0 percentile."""
        all_players = [1.0, 100.0, 200.0, 300.0, 400.0]
        # Player with score 1.0 has 0 players below them
        assert compute_percentile(1.0, all_players) == 0

    def test_median_player(self) -> None:
        """Middle player should have ~50% percentile."""
        all_players = [100.0, 200.0, 300.0, 400.0, 500.0]
        # Player with score 300 has 2 below, 5 total -> 40%
        assert compute_percentile(300.0, all_players) == 40

    def test_two_players_better_beats_worse(self) -> None:
        """Better of two players should have 50 percentile."""
        all_players = [100.0, 200.0]
        # Better player (200) has 1 below, 2 total -> 50%
        assert compute_percentile(200.0, all_players) == 50
        # Worse player (100) has 0 below, 2 total -> 0%
        assert compute_percentile(100.0, all_players) == 0

    def test_tied_scores(self) -> None:
        """Players with tied scores get same percentile."""
        all_players = [100.0, 200.0, 200.0, 200.0, 300.0]
        # Players with 200: 1 below (100), 5 total -> 20%
        assert compute_percentile(200.0, all_players) == 20

    def test_near_perfect_player_scenario(self) -> None:
        """Simulate the user's scenario: near-perfect player."""
        # 100 players with average scores ranging from poor (100) to excellent (5000)
        # Our player has an average score of 4800 (near-perfect)
        all_players = [float(50 * i) for i in range(2, 101)]  # 100 to 5000
        player_avg = 4800.0

        # Count how many are below 4800: all multiples of 50 below 4800
        # That's 2*50=100, 3*50=150, ..., 95*50=4750
        # So 94 players below (from 100 to 4750)
        pct = compute_percentile(player_avg, all_players)
        assert pct >= 93  # Should be high 90s

    def test_empty_list_returns_zero(self) -> None:
        """Edge case: no players returns 0."""
        assert compute_percentile(100.0, []) == 0

    def test_large_population(self) -> None:
        """1000 players, verify percentile scales correctly."""
        all_players = [float(i) for i in range(1, 1001)]  # 1 to 1000

        # Top player (1000): 999 below, 1000 total -> 99.9% -> 99
        assert compute_percentile(1000.0, all_players) == 99

        # Player at 900: 899 below, 1000 total -> 89.9% -> 89
        assert compute_percentile(900.0, all_players) == 89

        # Player at 500: 499 below, 1000 total -> 49.9% -> 49
        assert compute_percentile(500.0, all_players) == 49

        # Bottom player (1): 0 below, 1000 total -> 0%
        assert compute_percentile(1.0, all_players) == 0
