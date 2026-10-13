import 'package:flutter/foundation.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart';
import 'package:kidoz_ads/src/kidoz_full_screen_ad.dart';

/// The outcome of asking for a full-screen ad.
///
/// Exactly one of [onAdLoaded] and [onAdFailedToLoad] runs, once.
@immutable
class KidozFullScreenAdLoadCallback<T extends KidozFullScreenAd> {
  /// Creates a load callback that handles both outcomes.
  const KidozFullScreenAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  /// Called with the ad once it is ready.
  ///
  /// It is yours to `show()` and then `dispose()`.
  final void Function(T ad) onAdLoaded;

  /// Called when no ad will be shown.
  ///
  /// [KidozAdError.isNoFill] distinguishes an empty auction from an actual
  /// failure.
  final void Function(KidozAdError error) onAdFailedToLoad;
}
