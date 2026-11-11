import 'package:in_app_review/in_app_review.dart';

import 'rank_service.dart';

/// Asks for a Play Store rating once, after the player has had a good run
/// (a 3-day streak, 5 wins, and the last match was a win). Google shows its
/// own small sheet and limits how often it can appear. A failure here must
/// never affect the game, so everything is wrapped.
Future<void> maybeAskForRating(RankService rank, {DateTime? now}) async {
  final t = now ?? DateTime.now();
  if (!rank.shouldAskRating(t)) return;
  try {
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;
    await rank.markRatingAsked();
    await review.requestReview();
  } catch (_) {
    // Ignore: the prompt is optional.
  }
}
