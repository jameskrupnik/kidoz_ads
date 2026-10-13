import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart';
import 'package:kidoz_ads/src/kidoz_ads_base.dart';
import 'package:kidoz_ads/src/kidoz_banner_listener.dart';
import 'package:kidoz_ads/src/kidoz_banner_size.dart';
import 'package:kidoz_ads/src/platform.dart';

/// A banner ad, sized by [size] and filled by the native Kidoz SDK.
///
/// The widget always occupies [size], loaded or not. It does not collapse on
/// failure, because a banner slot that changes height when an auction comes
/// back empty reflows the screen under the user's thumb. Wrap it yourself if
/// you want it to disappear — [KidozBannerListener.onAdFailedToLoad] and
/// [KidozBannerListener.onAdClosed] are both signals that it should.
class KidozBannerAd extends StatefulWidget {
  /// Creates a banner of [size] that reports to [listener].
  ///
  /// Throws a [StateError] when first built if [KidozAds.initialize] has not
  /// completed, since both SDKs silently ignore a banner loaded before then.
  const KidozBannerAd({
    this.size = KidozBannerSize.banner,
    this.listener,
    super.key,
  });

  /// How much room the banner takes, in logical pixels.
  final KidozBannerSize size;

  /// Where load and interaction events go.
  final KidozBannerListener? listener;

  @override
  State<KidozBannerAd> createState() => _KidozBannerAdState();
}

class _KidozBannerAdState extends State<KidozBannerAd> {
  static const String _viewType = 'kidoz_ads/banner';

  late final int _adId;

  @override
  void initState() {
    super.initState();
    ensureKidozInitialized('banner ad');
    _adId = KidozAdsPlatform.registerAd(_handleEvent);
  }

  @override
  void dispose() {
    KidozAdsPlatform.unregisterAd(_adId);
    // The native view is torn down by the platform-view host, which closes the
    // KidozBannerView with it, so there is no disposeAd call to make here.
    super.dispose();
  }

  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    final listener = widget.listener;
    if (listener == null) return;
    switch (event) {
      case 'loaded':
        listener.onAdLoaded?.call();
      case 'loadFailed':
      // A Kidoz banner reports show failures through the same listener as
      // load failures, and a caller can do nothing different about the two —
      // either way the slot is empty and should collapse. They are merged
      // here rather than given a callback nobody would implement separately.
      case 'showFailed':
        listener.onAdFailedToLoad?.call(kidozAdErrorFromMap(arguments));
      case 'impression':
        listener.onAdImpression?.call();
      case 'closed':
        listener.onAdClosed?.call();
    }
  }

  Map<String, Object?> get _creationParams => <String, Object?>{
    'adId': _adId,
    // Logical pixels. Android needs these in device pixels and converts on
    // its side, because the density it should use is the one attached to
    // the view's context, not whatever Flutter last reported.
    'width': widget.size.width,
    'height': widget.size.height,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: switch (defaultTargetPlatform) {
        TargetPlatform.android => _buildAndroidView(),
        TargetPlatform.iOS => UiKitView(
          viewType: _viewType,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
        // A banner slot on an unsupported platform renders as empty space of
        // the right size rather than throwing, so a desktop debug run of an
        // app that embeds one still lays out correctly.
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// Hybrid composition, deliberately.
  ///
  /// Ad creatives are WebViews that need real touch targets and their own
  /// input connection. Virtual display — the cheaper mode — mangles both, which
  /// shows up as banners that render correctly and cannot be tapped.
  Widget _buildAndroidView() {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated);

        // Deliberately not awaited: `onCreatePlatformView` returns the
        // controller synchronously and Flutter drives the rest through the
        // creation listener above. Written out rather than left as a third
        // cascade member so the discarding is visible — the documented idiom
        // hides it in `..create()`.
        unawaited(controller.create());
        return controller;
      },
    );
  }
}
