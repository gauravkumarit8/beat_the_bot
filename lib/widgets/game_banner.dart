import 'package:flutter/material.dart';

import '../core/ads_service.dart';

/// A banner for the bottom of game screens, shown only on tall phones where it
/// fits without squeezing the game, and with extra space above it so it cannot
/// be tapped by accident during play.
class GameBanner extends StatelessWidget {
  const GameBanner({super.key, required this.ads});

  final AdsService? ads;

  static const double minHeight = 740;

  @override
  Widget build(BuildContext context) {
    final service = ads;
    if (service == null || MediaQuery.of(context).size.height < minHeight) {
      return const SizedBox.shrink();
    }
    return AdBanner(ads: service, topGap: 24);
  }
}
