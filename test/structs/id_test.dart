import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('ID', () {
    test('equality works correctly', () {
      const id1 = ID(1, 0);
      const id2 = ID(1, 0);
      const id3 = ID(2, 0);

      expect(id1, equals(id2));
      expect(id1, isNot(equals(id3)));
    });

    test('hashCode is consistent', () {
      const id1 = ID(1, 100);
      const id2 = ID(1, 100);

      expect(id1.hashCode, equals(id2.hashCode));
    });

    test('toString formats correctly', () {
      const id = ID(42, 5);
      expect(id.toString(), equals('ID(42, 5)'));
    });
  });
}
