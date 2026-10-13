/// @docImport 'package:kidoz_ads/src/kidoz_banner_ad.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart';

/// Events from a [KidozBannerAd].
@immutable
class KidozBannerListener {
  /// Creates a listener in which every callback is optional.
  const KidozBannerListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdImpression,
    this.onAdClosed,
  });

  /// Called when a creative has loaded into the banner.
  final VoidCallback? onAdLoaded;

  /// Called when the banner has nothing to show.
  ///
  /// Covers show failures as well as load failures: a Kidoz banner reports
  /// both through one listener, and either way the slot is empty. Check
  /// [KidozAdError.isNoFill] to tell an empty auction from a fault.
  final void Function(KidozAdError error)? onAdFailedToLoad;

  /// Called when Kidoz counts an impression for the banner.
  final VoidCallback? onAdImpression;

  /// Called when the banner took itself down.
  ///
  /// Kidoz creatives can carry a close affordance,
  /// which AdMob's banners do not — so unlike every other network in this
  /// family, a banner slot here can empty itself while the widget is still
  /// mounted. Collapse the slot on this, not just on [onAdFailedToLoad].
  final VoidCallback? onAdClosed;
}
