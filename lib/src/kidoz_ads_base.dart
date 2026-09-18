import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kidoz_ads/src/platform.dart';

/// Entry point for the Kidoz SDK.
///
/// [initialize] must complete before any ad is loaded. Ads loaded beforehand
/// fail rather than queue — both Kidoz SDKs gate their load entry points on
/// `isSDKInitialized()` and simply do nothing otherwise, which is
/// indistinguishable from a request that found no fill. This class checks
/// [isInitialized] itself and throws a [StateError] with a real explanation
/// instead.
///
/// ### There is no consent API here, and there is not meant to be
///
/// Every other network in this family needs a privacy signal pushed into it —
/// InMobi takes a GDPR consent dictionary, AdMob needs `childDirected` and a
/// `maxAdContentRating`, Unity needs three consent flags set before `init`.
/// Kidoz needs none of them, because contextual-only *is* the product: the
/// SDKs are verified to contain no advertising identifier at all, so there is
/// no identifier to withhold and no personalisation to turn off.
///
/// That is a real advantage and also a trap for anyone porting an ad service
/// across. **The absence of a consent call here is not a missing feature.**
/// If you find yourself looking for `setChildDirected`, the answer is that the
/// network has no other mode.
class KidozAds {
  KidozAds._();

  /// The one instance. Kidoz's SDKs are process-global singletons — the native
  /// entry point is literally `Kidoz.instance` on iOS and a static `Kidoz` on
  /// Android — so pretending otherwise here would only invite two
  /// initialisations with two publisher ids.
  static final KidozAds instance = KidozAds._();

  Future<bool>? _initialization;
  bool _initialized = false;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// Starts the Kidoz SDK.
  ///
  /// Safe to call repeatedly: the first call does the work and every later one
  /// awaits the same future. A failed start is *not* cached — the next call
  /// retries, because a transient network failure at launch should not disable
  /// ads for the life of the process.
  ///
  /// [publisherId] and [securityToken] are both issued by Kidoz publisher
  /// onboarding. They are a pair and there is no test pair worth shipping: the
  /// sample credentials in Kidoz's own repo are explicitly marked
  /// *"be sure not to publish your app with them"*.
  ///
  /// Returns false rather than throwing when the SDK declines to start, since
  /// a monetisation SDK that will not initialise is a condition to degrade
  /// around, not to crash on.
  Future<bool> initialize({
    required String publisherId,
    required String securityToken,
  }) {
    return _initialization ??= () async {
      try {
        await KidozAdsPlatform.channel.invokeMethod<void>('initialize', {
          'publisherId': publisherId,
          'securityToken': securityToken,
        });
        _initialized = true;
        return true;
      } on PlatformException {
        _initialization = null;
        return false;
      } on MissingPluginException {
        _initialization = null;
        return false;
      }
    }();
  }

  /// Forgets that the SDK was ever started, so the next [initialize] runs for
  /// real.
  ///
  /// This exists because [instance] is process-wide: without it, the first test
  /// in a suite initializes and every later one silently gets the cached
  /// future, which makes tests pass or fail depending on their order. It does
  /// not tear down the native SDK — nothing can, Kidoz's init is one-way — so
  /// it is only useful against a mocked channel.
  @visibleForTesting
  void debugReset() {
    _initialization = null;
    _initialized = false;
  }

  /// Throws unless the SDK is up, with a message that says which call is
  /// missing rather than surfacing as a generic load failure.
  void debugAssertInitialized(String what) {
    if (_initialized) return;
    throw StateError(
      'KidozAds.instance.initialize() must complete before loading a $what. '
      'Both Kidoz SDKs silently ignore a load issued before init, which looks '
      'exactly like no fill, so this is checked here instead.',
    );
  }
}
