import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart';
import 'package:kidoz_ads/src/kidoz_ads_base.dart';
import 'package:kidoz_ads/src/platform.dart';

/// A banner size, in logical pixels.
///
/// ### Kidoz does not publish a size table, and [banner] is the measured one
///
/// Neither platform README documents a size API or a list of supported
/// dimensions. What there is instead is Kidoz's own iOS sample app, which
/// constrains its `KidozBannerView` to a hard-coded **320×50** and nothing
/// else. That is the size this class defaults to and the only one Kidoz's own
/// code demonstrates.
///
/// [mediumRectangle] and [leaderboard] are here because the underlying view is
/// an ordinary `UIView` / Android `View` that takes the frame it is given, so
/// asking for them costs nothing — but **neither is confirmed to fill.** Check
/// the dashboard before shipping one, and treat a banner that reports `loaded`
/// and renders blank as a size mismatch first.
@immutable
class KidozBannerSize {
  const KidozBannerSize({required this.width, required this.height});

  /// 320×50. The standard phone banner, and the size Kidoz's own sample uses.
  static const KidozBannerSize banner = KidozBannerSize(width: 320, height: 50);

  /// 728×90. Tablets only; it will not fit a phone in portrait. Unconfirmed.
  static const KidozBannerSize leaderboard =
      KidozBannerSize(width: 728, height: 90);

  /// 300×250. The in-feed rectangle. Unconfirmed.
  static const KidozBannerSize mediumRectangle =
      KidozBannerSize(width: 300, height: 250);

  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is KidozBannerSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'KidozBannerSize(${width}x$height)';
}

/// Events from a [KidozBannerAd].
@immutable
class KidozBannerListener {
  const KidozBannerListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdImpression,
    this.onAdClosed,
  });

  final VoidCallback? onAdLoaded;
  final void Function(KidozAdError error)? onAdFailedToLoad;
  final VoidCallback? onAdImpression;

  /// The banner took itself down. Kidoz creatives can carry a close affordance,
  /// which AdMob's banners do not — so unlike every other network in this
  /// family, a banner slot here can empty itself while the widget is still
  /// mounted. Collapse the slot on this, not just on [onAdFailedToLoad].
  final VoidCallback? onAdClosed;
}

/// A banner ad, sized by [size] and filled by the native Kidoz SDK.
///
/// The widget always occupies [size], loaded or not. It does not collapse on
/// failure, because a banner slot that changes height when an auction comes
/// back empty reflows the screen under the user's thumb. Wrap it yourself if
/// you want it to disappear — [KidozBannerListener.onAdFailedToLoad] and
/// [KidozBannerListener.onAdClosed] are both signals that it should.
class KidozBannerAd extends StatefulWidget {
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
    KidozAds.instance.debugAssertInitialized('banner ad');
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
        listener.onAdFailedToLoad?.call(KidozAdError.fromMap(arguments));
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
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
