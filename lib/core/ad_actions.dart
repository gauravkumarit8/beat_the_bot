import 'package:flutter/material.dart';

import 'ads_service.dart';
import 'rank_service.dart';

/// Rewarded ad (always the player's choice): Zed is easier next match.
void watchToWeakenZed(
  BuildContext context,
  RankService rank,
  AdsService ads,
  VoidCallback onDone,
) {
  ads.showRewarded(
    onReward: () async {
      await rank.setZedWeakened(true);
      onDone();
    },
    onNotReady: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ad not ready yet. Try again in a moment.')),
      );
    },
  );
}
