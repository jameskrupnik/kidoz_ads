import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidoz_ads/kidoz_ads.dart';
import 'package:kidoz_ads/src/platform.dart';

/// What reaches the caller when the native half refuses a call outright,
/// rather than reporting a failure through an ad event.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final log = <MethodCall>[];

  /// Delivers a native event the way the plugin does, through the channel's own
  /// incoming path, so the routing under test is the real one.
  Future<void> emit(
    int adId,
    String event, [
    Map<String, Object?> extra = const {},
  ]) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'kidoz_ads',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onAdEvent', {...extra, 'adId': adId, 'event': event}),
      ),
      (_) {},
    );
  }

  setUp(() async {
    log.clear();
    KidozAdsPlatform.reset();
    KidozAds.instance.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KidozAdsPlatform.channel, (call) async {
      log.add(call);
      return null;
    });
    await KidozAds.instance.initialize(
      publisherId: 'test-publisher',
      securityToken: 'test-token',
    );
  });

  group('when the native side refuses a call', () {
    /// Makes each of [methods] fail with [error], the way the native half
    /// fails it, and lets every other call through as usual.
    void refuse(List<String> methods, Exception Function() error) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KidozAdsPlatform.channel, (call) async {
        log.add(call);
        if (methods.contains(call.method)) throw error();
        return null;
      });
    }

    // Android answers a load with NO_ACTIVITY when the engine is running with
    // no activity attached. That reply used to escape as an uncaught async
    // error from an unawaited future, and the load callback never ran — so a
    // fallback chain waiting on it stalled instead of moving on.
    test('a refused load reaches onAdFailedToLoad and releases the ad',
        () async {
      refuse(
        ['loadFullScreenAd'],
        () => PlatformException(code: 'NO_ACTIVITY', message: 'no activity'),
      );
      final errors = <KidozAdError>[];

      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: errors.add,
        ),
      );
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.single.code, KidozAdErrorCode.internalError);
      expect(errors.single.isNoFill, isFalse);
      expect(errors.single.message, contains('no activity'));
      expect(log.last.method, 'disposeAd');
    });

    test('a load with no native half fails instead of throwing', () async {
      // The release that follows a failed load must not throw either.
      refuse(['loadFullScreenAd', 'disposeAd'], MissingPluginException.new);
      final errors = <KidozAdError>[];

      KidozRewardedAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: errors.add,
        ),
      );
      await pumpEventQueue();

      expect(errors.single.code, KidozAdErrorCode.internalError);
    });

    test('a refused show reaches onAdFailedToShowFullScreenContent', () async {
      late KidozInterstitialAd ad;
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');
      final failures = <KidozAdError>[];
      ad.fullScreenContentCallback = KidozFullScreenContentCallback(
        onAdFailedToShowFullScreenContent: (_, error) => failures.add(error),
      );
      refuse(
        ['showFullScreenAd'],
        () => PlatformException(code: 'INVALID_ARGUMENTS', message: 'bad'),
      );

      await ad.show();

      expect(failures.single.code, KidozAdErrorCode.internalError);
      expect(failures.single.message, contains('bad'));
    });

    test('a refused release does not throw', () async {
      late KidozInterstitialAd ad;
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');
      refuse(['disposeAd'], MissingPluginException.new);

      await ad.dispose();
    });
  });
}
