import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidoz_ads/kidoz_ads.dart';
import 'package:kidoz_ads/src/platform.dart';

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

  group('initialize', () {
    test('sends both halves of the credential pair', () {
      expect(log.single.method, 'initialize');
      expect(log.single.arguments, containsPair('publisherId', 'test-publisher'));
      expect(log.single.arguments, containsPair('securityToken', 'test-token'));
    });

    test('is idempotent — a second call does not re-initialize', () async {
      await KidozAds.instance.initialize(
        publisherId: 'other',
        securityToken: 'other',
      );
      expect(log, hasLength(1));
    });

    test('a failed start is not cached, so the next call retries', () async {
      KidozAds.instance.debugReset();
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KidozAdsPlatform.channel, (call) async {
        log.add(call);
        throw PlatformException(code: 'INIT_FAILED');
      });

      expect(
        await KidozAds.instance
            .initialize(publisherId: 'p', securityToken: 't'),
        isFalse,
      );
      expect(KidozAds.instance.isInitialized, isFalse);

      // The retry is the point: a flaky network at launch must not disable ads
      // for the life of the process.
      await KidozAds.instance.initialize(publisherId: 'p', securityToken: 't');
      expect(log, hasLength(2));
    });
  });

  group('KidozInterstitialAd', () {
    test('load asks for a non-rewarded ad and sends no placement id', () {
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_) {},
        ),
      );

      final call = log.last;
      expect(call.method, 'loadFullScreenAd');
      expect(call.arguments, containsPair('rewarded', false));
      // Kidoz has no placement concept. If one ever appears in this payload it
      // came from a copy-paste out of inmobi_ads, where it is required.
      expect(
        (call.arguments as Map).containsKey('placementId'),
        isFalse,
        reason: 'Kidoz keys off publisher credentials, not a placement',
      );
    });

    test('routes loaded to the load callback', () async {
      KidozInterstitialAd? loaded;
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (ad) => loaded = ad,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );

      await emit(0, 'loaded');

      expect(loaded, isNotNull);
    });

    test('surfaces no fill distinguishably', () async {
      KidozAdError? error;
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: (e) => error = e,
        ),
      );

      await emit(0, 'loadFailed', {'code': 'NO_FILL', 'message': 'No ads'});

      expect(error!.isNoFill, isTrue);
    });

    test('a show failure is not mistaken for no fill', () async {
      late KidozInterstitialAd ad;
      KidozAdError? showError;
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = KidozFullScreenContentCallback(
        onAdFailedToShowFullScreenContent: (_, e) => showError = e,
      );
      await emit(0, 'showFailed', {
        'code': 'SHOW_FAILED',
        'message': 'nope',
      });

      // The distinction matters to a chain: no fill means try the next
      // network, a show failure means this attempt is simply over.
      expect(showError!.isNoFill, isFalse);
      expect(showError!.code, 'SHOW_FAILED');
    });
  });

  group('KidozRewardedAd', () {
    test('load asks for a rewarded ad', () {
      KidozRewardedAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_) {},
        ),
      );

      expect(log.last.arguments, containsPair('rewarded', true));
    });

    test('reward arrives before closure, so closure is terminal', () async {
      final order = <String>[];
      late KidozRewardedAd ad;
      KidozRewardedAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = KidozFullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => order.add('closed'),
      );
      await ad.show(onUserEarnedReward: (_) => order.add('rewarded'));

      await emit(0, 'rewardReceived');
      await emit(0, 'closed');

      expect(order, ['rewarded', 'closed']);
    });

    test('a closure with no reward reports only the closure', () async {
      final order = <String>[];
      late KidozRewardedAd ad;
      KidozRewardedAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = KidozFullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => order.add('closed'),
      );
      await ad.show(onUserEarnedReward: (_) => order.add('rewarded'));
      await emit(0, 'closed');

      // Skipping a rewarded video must not pay out. Asserted because the
      // reward carries no payload here, so "did it fire" is the whole signal.
      expect(order, ['closed']);
    });
  });

  group('event routing', () {
    test('a disposed ad stops receiving events', () async {
      var closures = 0;
      late KidozInterstitialAd ad;
      KidozInterstitialAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = KidozFullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => closures++,
      );
      await ad.dispose();
      await emit(0, 'closed');

      expect(closures, 0);
    });

    test('events reach the right ad when two are in flight', () async {
      final loaded = <int>[];
      for (var i = 0; i < 2; i++) {
        final index = i;
        KidozInterstitialAd.load(
          adLoadCallback: KidozFullScreenAdLoadCallback(
            onAdLoaded: (_) => loaded.add(index),
            onAdFailedToLoad: (_) {},
          ),
        );
      }

      await emit(1, 'loaded');

      expect(loaded, [1]);
    });
  });

  group('KidozAdError', () {
    test('defaults to an internal error rather than inventing no fill', () {
      // The default matters: a malformed payload read as NO_FILL would tell a
      // chain to move on quietly when something is actually broken.
      final error = KidozAdError.fromMap(const {});
      expect(error.code, 'INTERNAL_ERROR');
      expect(error.isNoFill, isFalse);
    });
  });

  group('KidozBannerSize', () {
    test("defaults to the size Kidoz's own sample app uses", () {
      expect(KidozBannerSize.banner.width, 320);
      expect(KidozBannerSize.banner.height, 50);
    });
  });
}
