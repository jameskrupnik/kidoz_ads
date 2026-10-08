import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidoz_ads/kidoz_ads.dart';
import 'package:kidoz_ads/src/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Every `create` the engine was asked for, with its decoded params.
  final created = <Map<Object?, Object?>>[];

  /// The engine-side id of the most recently created platform view.
  int? lastViewId;

  Future<void> emit(
    int adId,
    String event, [
    Map<String, Object?> extra = const {},
  ]) {
    return messenger.handlePlatformMessage(
      'kidoz_ads',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onAdEvent', {...extra, 'adId': adId, 'event': event}),
      ),
      (_) {},
    );
  }

  setUp(() async {
    created.clear();
    KidozAdsPlatform.reset();
    KidozAds.instance.debugReset();
    messenger
      ..setMockMethodCallHandler(KidozAdsPlatform.channel, (_) async => null)
      // Stands in for the engine's platform-view host, so the Android and iOS
      // branches build for real instead of throwing on a missing channel.
      ..setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map<Object?, Object?>;
          lastViewId = arguments['id'] as int?;
          final params = arguments['params']! as Uint8List;
          created.add(
            const StandardMessageCodec().decodeMessage(
              ByteData.sublistView(params),
            ) as Map<Object?, Object?>,
          );
        }
        return null;
      });
    await KidozAds.instance.initialize(
      publisherId: 'test-publisher',
      securityToken: 'test-token',
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Widget host(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      );

  group('KidozBannerAd', () {
    testWidgets('throws when the SDK has not been initialized', (
      tester,
    ) async {
      KidozAds.instance.debugReset();

      await tester.pumpWidget(host(const KidozBannerAd()));

      expect(tester.takeException(), isStateError);
    });

    testWidgets(
      'occupies its size on a platform Kidoz does not support',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          host(const KidozBannerAd(size: KidozBannerSize.mediumRectangle)),
        );

        expect(
          tester.getSize(find.byType(KidozBannerAd)),
          const Size(300, 250),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'routes every banner event to its listener',
      (tester) async {
        final events = <String>[];
        final errors = <KidozAdError>[];

        await tester.pumpWidget(
          host(
            KidozBannerAd(
              listener: KidozBannerListener(
                onAdLoaded: () => events.add('loaded'),
                onAdFailedToLoad: (error) {
                  events.add('failed');
                  errors.add(error);
                },
                onAdImpression: () => events.add('impression'),
                onAdClosed: () => events.add('closed'),
              ),
            ),
          ),
        );

        await emit(0, 'loaded');
        await emit(0, 'impression');
        await emit(0, 'loadFailed', {'code': 'NO_FILL', 'message': 'none'});
        await emit(0, 'showFailed', {'code': 'SHOW_FAILED', 'message': 'no'});
        await emit(0, 'closed');

        expect(events, ['loaded', 'impression', 'failed', 'failed', 'closed']);
        // Show failures share the load-failure callback but keep their code.
        expect(errors.map((e) => e.code), [
          KidozAdErrorCode.noFill,
          KidozAdErrorCode.showFailed,
        ]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'ignores events when it has no listener',
      (tester) async {
        await tester.pumpWidget(host(const KidozBannerAd()));
        await emit(0, 'loaded');

        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'stops receiving events once removed from the tree',
      (
        tester,
      ) async {
        var loads = 0;

        await tester.pumpWidget(
          host(
            KidozBannerAd(
              listener: KidozBannerListener(onAdLoaded: () => loads++),
            ),
          ),
        );
        await tester.pumpWidget(host(const SizedBox()));
        await emit(0, 'loaded');

        expect(loads, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'creates an Android view with its id and logical size',
      (
        tester,
      ) async {
        await tester.pumpWidget(host(const KidozBannerAd()));
        await tester.pump();

        expect(created, [
          {'adId': 0, 'width': 320.0, 'height': 50.0},
        ]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'takes Flutter focus when the native Android view does',
      (tester) async {
        await tester.pumpWidget(host(const KidozBannerAd()));
        await tester.pump();

        // A creative's WebView taking focus is reported by the engine like
        // this, and the banner must hand Flutter's focus to the platform view
        // or the creative's text input never receives keys.
        await messenger.handlePlatformMessage(
          SystemChannels.platform_views.name,
          SystemChannels.platform_views.codec.encodeMethodCall(
            MethodCall('viewFocused', lastViewId),
          ),
          (_) {},
        );
        await tester.pump();

        expect(FocusManager.instance.primaryFocus, isNotNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'creates an iOS view with its id and logical size',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          host(const KidozBannerAd(size: KidozBannerSize.leaderboard)),
        );
        await tester.pump();

        expect(created, [
          {'adId': 0, 'width': 728.0, 'height': 90.0},
        ]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('KidozBannerSize', () {
    test('compares by value, not identity', () {
      // Built at run time so it is not the canonical const instance.
      final width = KidozBannerSize.banner.width;
      final size = KidozBannerSize(width: width, height: 50);

      expect(size, KidozBannerSize.banner);
      expect(size.hashCode, KidozBannerSize.banner.hashCode);
      expect(size, isNot(KidozBannerSize.leaderboard));
    });

    test('describes itself as width by height', () {
      expect(KidozBannerSize.banner.toString(), 'KidozBannerSize(320.0x50.0)');
    });
  });
}
