import 'package:flutter/foundation.dart';

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
  /// Creates a size of [width] by [height] logical pixels.
  ///
  /// Both must be positive. Prefer the named constants: Kidoz publishes no
  /// size table, so a custom size is even less certain to fill than they are.
  const KidozBannerSize({required this.width, required this.height})
    : assert(width > 0 && height > 0, 'A banner needs a positive size');

  /// The 320×50 phone banner, and the size Kidoz's own sample uses.
  static const KidozBannerSize banner = KidozBannerSize(width: 320, height: 50);

  /// The 728×90 leaderboard, for tablets only.
  ///
  /// It will not fit a phone in portrait. Unconfirmed to fill.
  static const KidozBannerSize leaderboard = KidozBannerSize(
    width: 728,
    height: 90,
  );

  /// The 300×250 in-feed rectangle.
  ///
  /// Unconfirmed to fill.
  static const KidozBannerSize mediumRectangle = KidozBannerSize(
    width: 300,
    height: 250,
  );

  /// The width, in logical pixels.
  final double width;

  /// The height, in logical pixels.
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
