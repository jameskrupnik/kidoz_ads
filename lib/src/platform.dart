import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Signature of the per-ad event sink registered with [KidozAdsPlatform].
typedef KidozAdEventHandler = void Function(
  String event,
  Map<Object?, Object?> arguments,
);

/// The single method channel this package talks over, and the routing table
/// that gets a native callback back to the Dart object that asked for it.
///
/// ### Why ad ids rather than one channel per ad
///
/// Both Kidoz SDKs deliver events through a callback bound to an ad instance,
/// not to a request. Flutter has no handle to a native object, so every ad gets
/// an integer id minted here, passed down at load, and echoed back on every
/// event. [_handlers] turns that id back into the Dart object.
///
/// Ids are allocated in Dart rather than returned by the native side so that a
/// caller can register its handler *before* the ad exists. An event arriving
/// for an id with no handler is dropped, which is what should happen after
/// `dispose()`.
///
/// Kidoz makes this indirection more necessary than most, not less: its load
/// entry points are **static** (`KidozInterstitialAd.load(...)`) and hand the
/// ad object to the callback rather than returning it, so there is no moment
/// at which native could mint an id and return it synchronously.
abstract final class KidozAdsPlatform {
  static const MethodChannel channel = MethodChannel('kidoz_ads');

  static final Map<int, KidozAdEventHandler> _handlers =
      <int, KidozAdEventHandler>{};

  static int _nextAdId = 0;
  static bool _listening = false;

  /// Mints an id for a new ad and registers where its events should go.
  static int registerAd(KidozAdEventHandler handler) {
    _ensureListening();
    final adId = _nextAdId++;
    _handlers[adId] = handler;
    return adId;
  }

  /// Stops routing events for [adId]. Safe to call more than once.
  static void unregisterAd(int adId) => _handlers.remove(adId);

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler(_dispatch);
  }

  static Future<void> _dispatch(MethodCall call) async {
    if (call.method != 'onAdEvent') return;

    final arguments = call.arguments as Map<Object?, Object?>;
    final adId = arguments['adId'] as int?;
    final event = arguments['event'] as String?;
    if (adId == null || event == null) return;

    // A late event for a disposed ad is normal — a video dismissed after the
    // widget went away, say — so it is dropped rather than treated as an error.
    _handlers[adId]?.call(event, arguments);
  }

  /// Test seam: forget every registration and reset the id counter.
  @visibleForTesting
  static void reset() {
    _handlers.clear();
    _nextAdId = 0;
  }
}
