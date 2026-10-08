import 'package:flutter/foundation.dart';

/// Why a Kidoz request failed, in this package's own terms.
///
/// ### Why these are coarse, and why that is not an oversight
///
/// Kidoz's `KidozError` exposes a message and nothing else that is documented
/// or stable — the Android sample app calls `getMessage()` and `toString()`
/// and never reads a status enum, because there is not one to read. InMobi and
/// AdMob both hand back a named status code; Kidoz does not.
///
/// So these values are assigned natively from the only distinctions the SDK
/// actually makes reliably: *which callback fired*.
///
/// More values may be added in a minor release if Kidoz starts reporting a
/// distinction worth surfacing, so a `switch` over this enum should keep a
/// fallback branch rather than relying on exhaustiveness.
enum KidozAdErrorCode {
  /// The load callback fired with no ad.
  ///
  /// Kidoz does not say "no fill" in so many words, so anything that fails a
  /// *load* rather than a *show* is reported this way, which is the useful
  /// reading for a caller deciding whether to fall through to another network.
  noFill('NO_FILL'),

  /// The ad loaded and then failed to present.
  showFailed('SHOW_FAILED'),

  /// A load was attempted before the SDK came up.
  notInitialized('NOT_INITIALIZED'),

  /// This package's own faults, and anything unclassified.
  internalError('INTERNAL_ERROR');

  const KidozAdErrorCode(this._wireName);

  /// The name the native halves send over the channel.
  final String _wireName;
}

/// A failure reported by the Kidoz SDK.
///
/// Branch on [code]. [message] is Kidoz's text, passed through untouched —
/// **do not branch on it.** It is human-facing, undocumented, and free to
/// change between SDK releases.
@immutable
class KidozAdError {
  /// Creates an error with the given [code] and [message].
  ///
  /// The plugin builds these itself; the constructor is public so that code
  /// consuming this package can construct one in its own tests.
  const KidozAdError({required this.code, required this.message});

  /// Which of the distinctions Kidoz reliably makes this failure falls under.
  final KidozAdErrorCode code;

  /// Kidoz's human-facing description.
  ///
  /// Do not branch on this; branch on [code].
  final String message;

  /// Whether the request failed without an ad to show.
  ///
  /// The common case, and the one worth distinguishing: this is not a bug, it
  /// is an empty auction, and it is the signal to fall through to another
  /// network rather than to retry. On a contextual kids-only network it will
  /// happen more often than it does on AdMob — the demand pool is smaller by
  /// construction, which is the same property that makes the network safe for
  /// this audience.
  bool get isNoFill => code == KidozAdErrorCode.noFill;

  @override
  String toString() => 'KidozAdError(${code._wireName}): $message';

  @override
  bool operator ==(Object other) =>
      other is KidozAdError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Builds an error from the raw platform-channel payload.
///
/// Not exported: the payload shape is the wire protocol between this package's
/// Dart and native halves, and nothing outside it should depend on that.
///
/// An unknown or missing code becomes [KidozAdErrorCode.internalError] rather
/// than [KidozAdErrorCode.noFill] — a malformed payload read as no fill would
/// tell a chain to move on quietly when something is actually broken.
KidozAdError kidozAdErrorFromMap(Map<Object?, Object?> map) {
  final wireName = map['code'] as String?;
  return KidozAdError(
    code: KidozAdErrorCode.values.firstWhere(
      (code) => code._wireName == wireName,
      orElse: () => KidozAdErrorCode.internalError,
    ),
    message: map['message'] as String? ?? 'No message provided',
  );
}
