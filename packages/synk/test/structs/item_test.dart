import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('Item', () {
    test('initializes correctly with required parameters', () {
      const id = ID(1, 0);
      final item = Item(id: id, content: 'A');

      expect(item.id, equals(id));
      expect(item.content, equals('A'));
      expect(item.deleted, isFalse);
      expect(item.leftOrigin, isNull);
      expect(item.rightOrigin, isNull);
      expect(item.left, isNull);
      expect(item.right, isNull);
    });

    test('initializes with origins', () {
      const id = ID(1, 1);
      const leftId = ID(1, 0);
      const rightId = ID(2, 0);

      final item = Item(
        id: id,
        leftOrigin: leftId,
        rightOrigin: rightId,
        content: 'B',
      );

      expect(item.leftOrigin, equals(leftId));
      expect(item.rightOrigin, equals(rightId));
    });

    test('can be deleted (tombstoned)', () {
      final item = Item(id: const ID(1, 0), content: 'C');
      expect(item.deleted, isFalse);

      item.delete();
      expect(item.deleted, isTrue);
    });
  });
}
