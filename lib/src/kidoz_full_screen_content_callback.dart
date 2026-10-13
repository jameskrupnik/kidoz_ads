import 'package:flutter/foundation.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart';
import 'package:kidoz_ads/src/kidoz_full_screen_ad.dart';

/// Events from an ad that has already loaded.
///
/// The names follow `google_mobile_ads` and `inmobi_ads` rather than Kidoz's
/// own (`onAdShown`, `onAdClosed`) **on purpose**: an app running more than one
/// network puts these legs behind one interface, and a chain whose legs spell
/// the same event three different ways is a chain nobody can read. The wire
/// protocol underneath uses Kidoz's vocabulary; the translation happens once,
/// natively.
///
/// [onAdDismissedFullScreenContent] is the terminal callback in the normal
/// path — by the time it runs, any reward callback has already fired — and
/// [onAdFailedToShowFullScreenContent] is terminal in the abnormal one.
@immutable
class KidozFullScreenContentCallback<T extends KidozFullScreenAd> {
  /// Creates a content callback in which every handler is optional.
  const KidozFullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
    this.onAdImpression,
  });

  /// Called when the ad has taken over the screen.
  final void Function(T ad)? onAdShowedFullScreenContent;

  /// Called when the user has closed the ad.
  ///
  /// Terminal in the normal path. Dispose the ad here; it cannot be shown again.
  final void Function(T ad)? onAdDismissedFullScreenContent;

  /// Called when a loaded ad could not be presented.
  ///
  /// Terminal in the abnormal path. The error's [KidozAdError.code] is
  /// [KidozAdErrorCode.showFailed] for a failure Kidoz reported, or
  /// [KidozAdErrorCode.internalError] when the plugin itself could not present
  /// (no view controller, or an ad that was never loaded or already spent).
  final void Function(T ad, KidozAdError error)?
      onAdFailedToShowFullScreenContent;

  /// Called when Kidoz counts an impression for the ad.
  final void Function(T ad)? onAdImpression;
}
