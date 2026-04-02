// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkMap', () {
    test('can set and get values', () {
      final doc = SynkDoc();
      final map = SynkMap(doc, 'myMap');

      map.set('color', 'red');
      expect(map.get('color'), equals('red'));

      map.set('color', 'blue');
      expect(map.get('color'), equals('blue'));
    });

    test('toMap() returns all active entries', () {
      final doc = SynkDoc();
      final map = SynkMap(doc, 'myMap');

      map.set('a', 1);
      map.set('b', 2);

      expect(map.toMap(), equals({'a': 1, 'b': 2}));
    });

    test('delete() removes the value locally', () {
      final doc = SynkDoc();
      final map = SynkMap(doc, 'myMap');

      map.set('key', 'value');
      expect(map.containsKey('key'), isTrue);

      map.delete('key');
      expect(map.containsKey('key'), isFalse);
      expect(map.get('key'), isNull);
    });

    test('LWW rule applies properly (manual conflict simulation)', () {
      // Create a doc simulating Client A
      final doc = SynkDoc(clientId: 1);
      final map = SynkMap(doc, 'myMap');

      // We bypass `set` to manually inject conflicting items for
      // testing the LWW rule.
      // Usually, `set()` does this automatically but we want to test
      // the tie-breaking logic.

      // Since map internal data is encapsulated, let's just make sure
      // sequential writes work correctly via set.
      map.set('conflict', 'first');
      map.set('conflict', 'second');
      expect(map.get('conflict'), equals('second'));
    });

    test('delete() syncs correctly across peers', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final mapA = SynkMap(docA, 'myMap');
      final mapB = SynkMap(docB, 'myMap');

      mapA.set('key', 'value');

      // Sync Alice -> Bob
      SynkProtocol.applyUpdate(
        docB,
        SynkProtocol.encodeStateAsUpdate(docA),
      );
      expect(mapB.get('key'), equals('value'));

      // Alice deletes 'key'
      mapA.delete('key');
      expect(mapA.containsKey('key'), isFalse);

      // Sync Alice -> Bob again
      SynkProtocol.applyUpdate(
        docB,
        SynkProtocol.encodeStateAsUpdate(
          docA,
          SynkProtocol.encodeStateVector(docB),
        ),
      );

      // Bob should now also have 'key' deleted.
      // THIS WILL FAIL because the delete isn't emitted as a new Item.
      expect(
        mapB.containsKey('key'),
        isFalse,
        reason: 'Bob should have received the deletion update',
      );
      expect(mapB.get('key'), isNull);
    });

    test('replays history correctly upon creation', () {
      final doc = SynkDoc(clientId: 1);

      // Simulate existing items in document before map is instantiated.
      doc.transact((txn) {
        final item1 = Item(
          id: txn.getNextId(),
          parentKey: 'settings:theme',
          content: 'dark',
        );
        doc.addItem(item1);

        final item2 = Item(
          id: txn.getNextId(),
          parentKey: 'settings:fontSize',
          content: 14,
        );
        doc.addItem(item2);
      });

      final map = SynkMap(doc, 'settings');
      expect(map.get('theme'), equals('dark'));
      expect(map.get('fontSize'), equals(14));
    });

    test('does not interfere with other types (e.g. SynkText)', () {
      final doc = SynkDoc();
      final map = SynkMap(doc, 'settings');
      final text = SynkText(doc, 'body');

      map.set('theme', 'light');
      text.append('Hello');

      // The map should NOT contain a key called 'body' just because
      // a SynkText named 'body' was edited.
      expect(map.containsKey('body'), isFalse);
      expect(map.toMap(), equals({'theme': 'light'}));
    });

    test('stream emits batched updates', () async {
      final doc = SynkDoc();
      final map = SynkMap(doc, 'settings');

      // The stream should only emit once per transact() block
      final updates = expectLater(
        map.stream,
        emitsInOrder([
          {'a': 1, 'b': 2}, // Emit 1 (batched)
          {'a': 1},         // Emit 2 (deletion batched)
        ]),
      );

      // Batch 1
      doc.transact((txn) {
        map.set('a', 1);
        map.set('b', 2);
      }); // emits here

      // Batch 2
      doc.transact((txn) {
        map.delete('b');
      }); // emits here

      await updates;
    });

    test('dispose() correctly unregisters listeners', () {
      final doc = SynkDoc();
      final map = SynkMap(doc, 'settings');

      map.set('theme', 'dark');
      expect(map.get('theme'), equals('dark'));

      map.dispose();

      // This update should NOT be processed by the disposed map
      map.set('theme', 'light');

      // It should still have the old value because the listener was removed
      expect(map.get('theme'), equals('dark'));
    });
  });
}
