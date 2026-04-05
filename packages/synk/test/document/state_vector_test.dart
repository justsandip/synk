import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('StateVector', () {
    test('initializes empty and returns 0 for unknown clients', () {
      final sv = StateVector();
      expect(sv.get(1), equals(0));
      expect(sv.has(1, 0), isFalse);
    });

    test('sets and gets clocks correctly', () {
      final sv = StateVector()..set(1, 5);
      expect(sv.get(1), equals(5));
      expect(sv.get(2), equals(0));
    });

    test('only updates if new clock is strictly greater', () {
      final sv = StateVector()
        ..set(1, 5)
        ..set(1, 3); // Should be ignored
      expect(sv.get(1), equals(5));

      sv.set(1, 10); // Should update
      expect(sv.get(1), equals(10));
    });

    test('has() works correctly', () {
      final sv = StateVector()..set(1, 5);

      // We have operations up to clock 5
      // state = 5 means we have clocks 0, 1, 2, 3, 4.
      expect(sv.has(1, 4), isTrue);
      expect(sv.has(1, 5), isFalse);
      expect(sv.has(1, 6), isFalse);
    });

    test('initializes from an existing map', () {
      final sv = StateVector.fromMap({1: 10, 2: 20});
      expect(sv.get(1), equals(10));
      expect(sv.get(2), equals(20));
      expect(sv.get(3), equals(0));
    });
  });
}
