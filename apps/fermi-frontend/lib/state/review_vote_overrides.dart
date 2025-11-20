import 'package:fermi_frontend/widgets/animated_like_dislike.dart';

/// Holds local (ephemeral) overrides for per-question vote verdict and likes
/// to keep UI consistent while paging through review mode.
class ReviewVoteOverrides {
  final Map<String, VoteState> _verdictByUid = <String, VoteState>{};
  final Map<String, int> _likesByUid = <String, int>{};

  /// Returns the effective verdict for [questionUid], falling back to
  /// [backendVerdict] when no override exists.
  VoteState effectiveVerdict(String questionUid, VoteState backendVerdict) {
    return _verdictByUid[questionUid] ?? backendVerdict;
  }

  /// Returns the effective likes count for [questionUid], falling back to
  /// [backendLikes] when no override exists.
  int effectiveLikes(String questionUid, int backendLikes) {
    return _likesByUid[questionUid] ?? backendLikes;
  }

  /// Persist a new local verdict and likes count for [questionUid].
  void setOverrides({
    required String questionUid,
    required VoteState verdict,
    required int likes,
  }) {
    _verdictByUid[questionUid] = verdict;
    _likesByUid[questionUid] = likes;
  }

  /// Clear stored overrides (optional, e.g., when leaving screen).
  void clear() {
    _verdictByUid.clear();
    _likesByUid.clear();
  }
}
