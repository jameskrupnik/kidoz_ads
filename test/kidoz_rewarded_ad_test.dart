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

    test('a load failure reaches the callback and releases the ad', () async {
      KidozAdError? error;
      KidozRewardedAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: (e) => error = e,
        ),
      );

      await emit(0, 'loadFailed', {'code': 'NO_FILL', 'message': 'No ads'});

      expect(error!.isNoFill, isTrue);
      expect(log.last.method, 'disposeAd');
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

    test(
      'content callbacks receive the rewarded ad, not the base type',
      () async {
        late KidozRewardedAd ad;
        KidozRewardedAd? shown;
        KidozRewardedAd.load(
          adLoadCallback: KidozFullScreenAdLoadCallback(
            onAdLoaded: (loaded) => ad = loaded,
            onAdFailedToLoad: (_) => fail('should not fail'),
          ),
        );
        await emit(0, 'loaded');

        // Typed explicitly: with a field typed to the base class this compiled
        // and then threw a TypeError when the event arrived.
        ad.fullScreenContentCallback =
            KidozFullScreenContentCallback<KidozRewardedAd>(
              onAdShowedFullScreenContent: (shownAd) => shown = shownAd,
            );
        await emit(0, 'shown');

        expect(shown, same(ad));
      },
    );

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

    test('a refused second show keeps the first reward callback', () async {
      // A double-tap on a "watch ad" button calls show() twice. The second
      // call is a no-op, so it must not replace — or, passing nothing, clear —
      // the callback the user is about to earn a reward through.
      final rewards = <String>[];
      late KidozRewardedAd ad;
      KidozRewardedAd.load(
        adLoadCallback: KidozFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      await ad.show(onUserEarnedReward: (_) => rewards.add('first'));
      await expectLater(ad.show(), throwsAssertionError);
      await emit(0, 'rewardReceived');

      expect(rewards, ['first']);
    });
  });
}
