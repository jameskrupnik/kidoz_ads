import 'package:flutter_test/flutter_test.dart';
import 'package:kidoz_ads/kidoz_ads.dart';
import 'package:kidoz_ads/src/kidoz_ad_error.dart' show kidozAdErrorFromMap;

void main() {
  group('KidozAdError', () {
    test('defaults to an internal error rather than inventing no fill', () {
      // The default matters: a malformed payload read as NO_FILL would tell a
      // chain to move on quietly when something is actually broken.
      final error = kidozAdErrorFromMap(const <Object?, Object?>{});
      expect(error.code, KidozAdErrorCode.internalError);
      expect(error.isNoFill, isFalse);
    });

    test('an unknown code is an internal error too', () {
      final error = kidozAdErrorFromMap(const {'code': 'SOMETHING_NEW'});
      expect(error.code, KidozAdErrorCode.internalError);
    });

    test('reads every wire name the native halves send', () {
      const wire = {
        'NO_FILL': KidozAdErrorCode.noFill,
        'SHOW_FAILED': KidozAdErrorCode.showFailed,
        'NOT_INITIALIZED': KidozAdErrorCode.notInitialized,
        'INTERNAL_ERROR': KidozAdErrorCode.internalError,
      };
      for (final MapEntry(:key, :value) in wire.entries) {
        expect(kidozAdErrorFromMap({'code': key}).code, value, reason: key);
      }
    });

    test('compares by value', () {
      const a = KidozAdError(code: KidozAdErrorCode.noFill, message: 'x');
      const b = KidozAdError(code: KidozAdErrorCode.noFill, message: 'x');
      const c = KidozAdError(code: KidozAdErrorCode.showFailed, message: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('keeps the wire name in toString for logs', () {
      const error = KidozAdError(
        code: KidozAdErrorCode.noFill,
        message: 'No ads',
      );
      expect(error.toString(), 'KidozAdError(NO_FILL): No ads');
    });
  });
}
