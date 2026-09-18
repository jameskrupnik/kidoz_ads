import 'package:flutter/foundation.dart';

/// A failure reported by the Kidoz SDK.
///
/// ### Why [code] is coarse, and why that is not an oversight
///
/// Kidoz's `KidozError` exposes a message and nothing else that is documented
/// or stable — the Android sample app calls `getMessage()` and `toString()`
/// and never reads a status enum, because there is not one to read. InMobi and
/// AdMob both hand back a named status code; Kidoz does not.
///
/// So [code] carries one of this package's **own** names, assigned natively
/// from the only distinctions the SDK actually makes reliably:
///
///  - `NO_FILL` — the load callback fired with no ad. Kidoz does not say
///    "no fill" in so many words, so anything that fails a *load* rather than
///    a *show* is reported this way, which is the useful reading for a caller
///    deciding whether to fall through to another network.
///  - `SHOW_FAILED` — the ad loaded and then failed to present.
///  - `NOT_INITIALIZED` — a load was attempted before the SDK came up.
///  - `INTERNAL_ERROR` — this package's own faults, and anything unclassified.
///
/// [message] is Kidoz's text, passed through untouched. **Do not branch on it.**
/// It is human-facing, undocumented, and free to change between SDK releases.
@immutable
class KidozAdError {
  const KidozAdError({required this.code, required this.message});

  /// Builds an error from the raw platform-channel payload.
  factory KidozAdError.fromMap(Map<Object?, Object?> map) {
    return KidozAdError(
      code: map['code'] as String? ?? 'INTERNAL_ERROR',
      message: map['message'] as String? ?? 'No message provided',
    );
  }

  /// One of the four names documented on this class.
  final String code;

  /// Kidoz's human-facing description. Do not branch on this.
  final String message;

  /// Whether the request failed without an ad to show.
  ///
  /// The common case, and the one worth distinguishing: this is not a bug, it
  /// is an empty auction, and it is the signal to fall through to another
  /// network rather than to retry. On a contextual kids-only network it will
  /// happen more often than it does on AdMob — the demand pool is smaller by
  /// construction, which is the same property that makes the network safe for
  /// this audience.
  bool get isNoFill => code == 'NO_FILL';

  @override
  String toString() => 'KidozAdError($code): $message';

  @override
  bool operator ==(Object other) =>
      other is KidozAdError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}
