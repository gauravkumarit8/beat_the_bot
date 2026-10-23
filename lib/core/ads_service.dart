import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ad unit IDs. By default these are Google's official TEST IDs (Android).
/// The release workflow passes your real IDs with --dart-define, so real IDs
/// never need to be written into the code.
class AdIds {
  static const banner = String.fromEnvironment(
    'ADMOB_BANNER',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const interstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const rewarded = String.fromEnvironment(
    'ADMOB_REWARDED',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
}

class AdsService {
  AdsService(this._prefs);

  final SharedPreferences _prefs;

  static const int _matchesBetweenInterstitials = 3;
  static const Duration _minGap = Duration(minutes: 3);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _matchesSinceAd = 0;
  DateTime? _lastInterstitial;

  /// Set to true by the future "Remove ads" purchase.
  /// Banner and interstitial ads stop; optional reward ads stay available.
  bool get adsRemoved => _prefs.getBool('adsRemoved') ?? false;

  /// True once the Mobile Ads SDK has started. Banners wait for this.
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      ready.value = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (_) {
      // Ads are optional. The game keeps working if the SDK cannot start.
    }
  }

  // ---- Interstitial: only between matches, never mid-play ----------------

  void _loadInterstitial() {
    if (adsRemoved) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) => _interstitial = null,
      ),
    );
  }

  void onMatchFinished() => _matchesSinceAd++;

  void showInterstitialIfDue() {
    if (adsRemoved) return;
    if (_matchesSinceAd < _matchesBetweenInterstitials) return;
    final last = _lastInterstitial;
    if (last != null && DateTime.now().difference(last) < _minGap) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    _interstitial = null;
    _matchesSinceAd = 0;
    _lastInterstitial = DateTime.now();
    ad.show();
  }

  // ---- Rewarded: always opt-in, the player chooses to watch --------------

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (error) => _rewarded = null,
      ),
    );
  }

  void showRewarded({
    required VoidCallback onReward,
    required VoidCallback onNotReady,
  }) {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      onNotReady();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewarded();
      },
    );
    _rewarded = null;
    ad.show(onUserEarnedReward: (adView, reward) => onReward());
  }
}

/// Banner for menu screens only. Shows nothing until an ad has loaded.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.ads});

  final AdsService ads;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    if (widget.ads.adsRemoved) return;
    if (widget.ads.ready.value) {
      _createBanner();
    } else {
      widget.ads.ready.addListener(_onReady);
    }
  }

  void _onReady() {
    if (widget.ads.ready.value && !_requested) _createBanner();
  }

  void _createBanner() {
    _requested = true;
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    widget.ads.ready.removeListener(_onReady);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
