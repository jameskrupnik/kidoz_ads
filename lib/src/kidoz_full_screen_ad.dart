import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart';
import 'package:kidoz_ads/src/kidoz_ads_base.dart';
import 'package:kidoz_ads/src/platform.dart';

/// Called when the user finishes a rewarded video.
///
/// ### There is no reward payload, and that is Kidoz's design
///
/// Kidoz's callback is `onRewardReceived(ad)` on both platforms — it carries no
/// amount and no name, because Kidoz has no dashboard field to configure one.
/// The reward is a **signal that the video was watched**; what it is worth is
/// entirely the app's business.
///
/// This is the opposite of InMobi and AdMob, which both hand back a
/// server-configured `(name, amount)` pair. Porting reward-granting code across
/// from either of those will compile against a reward object that does not
/// exist here. Grant a constant instead.
typedef KidozOnUserEarnedReward = void Function(KidozRewardedAd ad);

/// The outcome of asking for a full-screen ad.
///
/// Exactly one of [onAdLoaded] and [onAdFailedToLoad] runs, once.
@immutable
class KidozFullScreenAdLoadCallback<T extends KidozFullScreenAd> {
  const KidozFullScreenAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  /// The ad is ready. It is yours to `show()` and then `dispose()`.
  final void Function(T ad) onAdLoaded;

  /// Nothing will be shown. [KidozAdError.isNoFill] distinguishes an empty
  /// auction from an actual failure.
  final void Function(KidozAdError error) onAdFailedToLoad;
}

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
  const KidozFullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
    this.onAdImpression,
  });

  final void Function(T ad)? onAdShowedFullScreenContent;
  final void Function(T ad)? onAdDismissedFullScreenContent;
  final void Function(T ad, KidozAdError error)?
      onAdFailedToShowFullScreenContent;
  final void Function(T ad)? onAdImpression;
}

/// Shared machinery for the two full-screen formats.
///
/// Unlike InMobi — where both formats are one native class and the dashboard
/// decides which you get — Kidoz has genuinely separate `KidozInterstitialAd`
/// and `KidozRewardedAd` types. The `rewarded` flag on the load call picks the
/// native class, so a rewarded ad here really is a rewarded ad and the reward
/// callback cannot silently never fire.
abstract class KidozFullScreenAd {
  KidozFullScreenAd._() {
    _adId = KidozAdsPlatform.registerAd(_handleEvent);
  }

  late final int _adId;

  bool _shown = false;
  bool _disposed = false;

  /// Events for an ad that has loaded. Set this before calling [show].
  KidozFullScreenContentCallback<KidozFullScreenAd>? fullScreenContentCallback;

  void _handleEvent(String event, Map<Object?, Object?> arguments);

  /// Presents the ad.
  ///
  /// Calling this twice on one ad is a no-op with a debug-mode complaint: both
  /// native SDKs require a fresh load after a dismissal, and `show()` on a
  /// spent ad reports nothing at all rather than an error you could react to.
  Future<void> show() async {
    if (_disposed) {
      assert(false, 'show() called on a disposed Kidoz ad');
      return;
    }
    if (_shown) {
      assert(false, 'Kidoz ads are single-use — load a new one to show again');
      return;
    }
    _shown = true;
    await KidozAdsPlatform.channel
        .invokeMethod<void>('showFullScreenAd', {'adId': _adId});
  }

  /// Releases the native ad. Call it once you are done, in every path.
  ///
  /// After this, late events for the ad are dropped rather than delivered.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    KidozAdsPlatform.unregisterAd(_adId);
    await KidozAdsPlatform.channel
        .invokeMethod<void>('disposeAd', {'adId': _adId});
  }

  static Future<void> _load({required int adId, required bool rewarded}) {
    return KidozAdsPlatform.channel.invokeMethod<void>('loadFullScreenAd', {
      'adId': adId,
      'rewarded': rewarded,
    });
  }
}

/// A rewarded video ad.
///
/// ```dart
/// KidozRewardedAd.load(
///   adLoadCallback: KidozFullScreenAdLoadCallback(
///     onAdLoaded: (ad) {
///       ad.fullScreenContentCallback = KidozFullScreenContentCallback(
///         onAdDismissedFullScreenContent: (ad) => ad.dispose(),
///       );
///       ad.show(onUserEarnedReward: (_) => grantOneExtraLife());
///     },
///     onAdFailedToLoad: (error) => fallBackToAnotherNetwork(error),
///   ),
/// );
/// ```
///
/// **Before wiring this into a child-directed app, read the audience note in
/// the README.** Kidoz permits rewarded video, but a reward a nine-year-old
/// can only get by watching an ad is a design decision with consequences, and
/// the fact that the format is available here is not an argument for using it.
class KidozRewardedAd extends KidozFullScreenAd {
  KidozRewardedAd._({
    required KidozFullScreenAdLoadCallback<KidozRewardedAd> loadCallback,
  })  : _loadCallback = loadCallback,
        super._();

  final KidozFullScreenAdLoadCallback<KidozRewardedAd> _loadCallback;

  KidozOnUserEarnedReward? _onUserEarnedReward;

  /// Requests a rewarded ad.
  ///
  /// There is no placement id. Kidoz keys everything off the publisher
  /// credentials passed to [KidozAds.initialize] and decides the creative
  /// contextually, which is why this signature is so much shorter than the
  /// equivalent on any other network.
  static void load({
    required KidozFullScreenAdLoadCallback<KidozRewardedAd> adLoadCallback,
  }) {
    KidozAds.instance.debugAssertInitialized('rewarded ad');
    final ad = KidozRewardedAd._(loadCallback: adLoadCallback);
    unawaited(KidozFullScreenAd._load(adId: ad._adId, rewarded: true));
  }

  /// Presents the ad, reporting the reward to [onUserEarnedReward].
  ///
  /// The reward callback fires before `onAdDismissedFullScreenContent`, so by
  /// the time dismissal arrives you already know whether one was earned.
  @override
  Future<void> show({KidozOnUserEarnedReward? onUserEarnedReward}) {
    _onUserEarnedReward = onUserEarnedReward;
    return super.show();
  }

  @override
  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    switch (event) {
      case 'loaded':
        _loadCallback.onAdLoaded(this);
      case 'loadFailed':
        _loadCallback.onAdFailedToLoad(KidozAdError.fromMap(arguments));
        // Nothing is waiting on the native teardown of an ad that never loaded.
        unawaited(dispose());
      case 'rewardReceived':
        _onUserEarnedReward?.call(this);
      default:
        _dispatchContentEvent(
          this,
          fullScreenContentCallback,
          event,
          arguments,
        );
    }
  }
}

/// A full-screen interstitial ad.
class KidozInterstitialAd extends KidozFullScreenAd {
  KidozInterstitialAd._({
    required KidozFullScreenAdLoadCallback<KidozInterstitialAd> loadCallback,
  })  : _loadCallback = loadCallback,
        super._();

  final KidozFullScreenAdLoadCallback<KidozInterstitialAd> _loadCallback;

  /// Requests an interstitial ad. There is no placement id — see
  /// [KidozRewardedAd.load].
  static void load({
    required KidozFullScreenAdLoadCallback<KidozInterstitialAd> adLoadCallback,
  }) {
    KidozAds.instance.debugAssertInitialized('interstitial ad');
    final ad = KidozInterstitialAd._(loadCallback: adLoadCallback);
    unawaited(KidozFullScreenAd._load(adId: ad._adId, rewarded: false));
  }

  @override
  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    switch (event) {
      case 'loaded':
        _loadCallback.onAdLoaded(this);
      case 'loadFailed':
        _loadCallback.onAdFailedToLoad(KidozAdError.fromMap(arguments));
        // Nothing is waiting on the native teardown of an ad that never loaded.
        unawaited(dispose());
      default:
        _dispatchContentEvent(
          this,
          fullScreenContentCallback,
          event,
          arguments,
        );
    }
  }
}

/// Routes the events both formats share onto [callback].
void _dispatchContentEvent<T extends KidozFullScreenAd>(
  T ad,
  KidozFullScreenContentCallback<KidozFullScreenAd>? callback,
  String event,
  Map<Object?, Object?> arguments,
) {
  if (callback == null) return;
  switch (event) {
    case 'shown':
      callback.onAdShowedFullScreenContent?.call(ad);
    case 'showFailed':
      callback.onAdFailedToShowFullScreenContent
          ?.call(ad, KidozAdError.fromMap(arguments));
    case 'closed':
      callback.onAdDismissedFullScreenContent?.call(ad);
    case 'impression':
      callback.onAdImpression?.call(ad);
  }
}
