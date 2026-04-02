// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkText', () {
    test('inserts characters sequentially', () {
      final doc = SynkDoc(clientId: 1);
      final text = SynkText(doc, 'body');

      text.insert(0, 'Hello');
      expect(text.text, equals('Hello'));
      expect(text.length, equals(5));

      text.append(' World');
      expect(text.text, equals('Hello World'));
      expect(text.length, equals(11));

      text.insert(5, ',');
      expect(text.text, equals('Hello, World'));
      expect(text.length, equals(12));
    });

    test('deletes characters correctly', () {
      final doc = SynkDoc(clientId: 1);
      final text = SynkText(doc, 'body');

      text.insert(0, 'Hello, World!');
      expect(text.text, equals('Hello, World!'));

      // Delete 'o' in 'Hello'
      text.delete(4, 1);
      expect(text.text, equals('Hell, World!'));

      // Delete ', World'
      text.delete(4, 7);
      expect(text.text, equals('Hell!'));
    });

    test('resolves concurrent insertions deterministically', () {
      final doc1 = SynkDoc(clientId: 100);
      final text1 = SynkText(doc1, 'body');
      text1.insert(0, 'A');

      final doc2 = SynkDoc(clientId: 200);
      final text2 = SynkText(doc2, 'body');

      // Sync doc1 -> doc2
      doc1.store.forEach((clientId, items) {
        for (final item in items) {
          doc2.addItem(
            Item(
              id: item.id,
              parentKey: item.parentKey,
              content: item.content,
              leftOrigin: item.leftOrigin,
              rightOrigin: item.rightOrigin,
              deleted: item.deleted,
            ),
          );
        }
      });
      expect(text2.text, equals('A'));

      // Concurrent insert at index 1
      text1.insert(1, 'B'); // 100: A B
      text2.insert(1, 'C'); // 200: A C

      // Sync doc1 -> doc2
      doc1.store.forEach((clientId, items) {
        for (final item in items) {
          if (!doc2.store.containsKey(clientId) ||
              doc2.store[clientId]!.length <= item.id.clock) {
            doc2.addItem(
              Item(
                id: item.id,
                parentKey: item.parentKey,
                content: item.content,
                leftOrigin: item.leftOrigin,
                rightOrigin: item.rightOrigin,
                deleted: item.deleted,
              ),
            );
          }
        }
      });

      // Sync doc2 -> doc1
      doc2.store.forEach((clientId, items) {
        for (final item in items) {
          if (!doc1.store.containsKey(clientId) ||
              doc1.store[clientId]!.length <= item.id.clock) {
            doc1.addItem(
              Item(
                id: item.id,
                parentKey: item.parentKey,
                content: item.content,
                leftOrigin: item.leftOrigin,
                rightOrigin: item.rightOrigin,
                deleted: item.deleted,
              ),
            );
          }
        }
      });

      // Both should converge to exactly the same text.
      // Because client 200 > client 100,
      // 200 ('C') wins and goes first after 'A'.
      // So expected result should be 'A C B'.
      // Because concurrent characters: 'C' from 200, 'B' from 100.
      expect(text1.text, equals(text2.text));
      expect(text1.text, equals('ACB'));
    });

    test('replays history dynamically upon creation', () {
      final doc = SynkDoc(clientId: 1);

      // Simulate existing items in document before text is instantiated.
      doc.transact((txn) {
        // 'H'
        final item1 = Item(
          id: txn.getNextId(),
          parentKey: 'title',
          content: 'H',
        );
        doc.addItem(item1);

        // 'i'
        final item2 = Item(
          id: txn.getNextId(),
          parentKey: 'title',
          content: 'i',
          leftOrigin: item1.id,
        );
        doc.addItem(item2);
      });

      final text = SynkText(doc, 'title');
      expect(text.text, equals('Hi'));
    });

    test('handles concurrent deletes correctly', () {
      final doc1 = SynkDoc(clientId: 1);
      final text1 = SynkText(doc1, 'doc');

      text1.insert(0, 'cat');

      final doc2 = SynkDoc(clientId: 2);
      final text2 = SynkText(doc2, 'doc');

      // Sync
      doc1.store.forEach((clientId, items) {
        for (final item in items) {
          doc2.addItem(
            Item(
              id: item.id,
              parentKey: item.parentKey,
              content: item.content,
              leftOrigin: item.leftOrigin,
              rightOrigin: item.rightOrigin,
              deleted: item.deleted,
            ),
          );
        }
      });

      // Doc1 deletes 'a'
      text1.delete(1, 1);
      expect(text1.text, equals('ct'));

      // Doc2 deletes 't'
      text2.delete(2, 1);
      expect(text2.text, equals('ca'));

      // Sync doc1 changes to doc2
      doc1.store.forEach((clientId, items) {
        for (final item in items) {
          if (!doc2.store.containsKey(clientId) ||
              doc2.store[clientId]!.length <= item.id.clock) {
            doc2.addItem(
              Item(
                id: item.id,
                parentKey: item.parentKey,
                content: item.content,
                leftOrigin: item.leftOrigin,
                rightOrigin: item.rightOrigin,
                deleted: item.deleted,
              ),
            );
          }
        }
      });

      // Sync doc2 changes to doc1
      doc2.store.forEach((clientId, items) {
        for (final item in items) {
          if (!doc1.store.containsKey(clientId) ||
              doc1.store[clientId]!.length <= item.id.clock) {
            doc1.addItem(
              Item(
                id: item.id,
                parentKey: item.parentKey,
                content: item.content,
                leftOrigin: item.leftOrigin,
                rightOrigin: item.rightOrigin,
                deleted: item.deleted,
              ),
            );
          }
        }
      });

      expect(text1.text, equals('c'));
      expect(text2.text, equals('c'));
    });

    test('handles out-of-order characters via deferral', () {
      final doc = SynkDoc(clientId: 1);
      const id1 = ID(1, 0);
      const id2 = ID(1, 1);

      // item2 depends on item1
      final item1 = Item(id: id1, parentKey: 'txt', content: 'A');
      final item2 = Item(
        id: id2,
        parentKey: 'txt',
        content: 'B',
        leftOrigin: id1,
      );

      // Manually inject into store in reverse order
      doc.store[2] = [item2];
      doc.store[1] = [item1];
      doc.stateVector
        ..set(2, 1)
        ..set(1, 1);

      // Initialize text - triggers _replayExisting and hits deferred.add(item)
      final text = SynkText(doc, 'txt');

      expect(text.text, equals('AB'));
    });

    test('insert and delete handle range errors and skip tombstones', () {
      final doc = SynkDoc(clientId: 1);
      final text = SynkText(doc, 'txt');
      text.append('AC'); // text: "AC"

      // 1. Cover RangeErrors
      expect(() => text.insert(-1, 'X'), throwsRangeError);
      expect(() => text.insert(5, 'X'), throwsRangeError);
      expect(() => text.delete(-1, 1), throwsRangeError);
      expect(() => text.delete(1, 10), throwsRangeError);

      // 2. Cover tombstone skipping (r = r.right)
      // Delete 'A' (index 0)
      text.delete(0, 1); // text: "[A]C"

      // Insert at index 0.
      // Loop "while (r != null && r.deleted)" will hit 'A' and move to 'C'.
      text.insert(0, 'B');
      expect(text.text, equals('BC'));

      // 3. Cover deletion walk (target = target.right)
      text.append('D'); // text: "BCD"
      text.delete(1, 1); // delete 'C', text: "B[C]D"

      // Delete 2 chars starting at index 0 ('B' and 'D')
      // This forces the delete loop to skip over the deleted 'C'
      text.delete(0, 2);
      expect(text.text, equals(''));
    });

    test('insert skips tombstones when inserting in the middle', () {
      final doc = SynkDoc(clientId: 1);
      final text = SynkText(doc, 'txt');

      // 1. Create "ABC"
      text.append('ABC');

      // 2. Delete 'B' (the character at index 1)
      // Internal state: A -> [B (deleted)] -> C
      text.delete(1, 1);
      expect(text.text, equals('AC'));

      // 3. Insert 'Z' at index 1 (between A and C)
      // - leftItem will be 'A'
      // - r starts at 'A'.right, which is 'B'
      // - Because 'B' is deleted, "r = r.right" triggers to find 'C'
      text.insert(1, 'Z');

      expect(text.text, equals('AZC'));

      // Verify internal structure: 'Z' should have 'A' as leftOrigin
      // and 'C' as rightOrigin
      final itemZ = doc.store[1]!.last; // The most recent insertion
      final itemA = doc.store[1]![0];
      final itemC = doc.store[1]![2];

      expect(itemZ.content, equals('Z'));
      expect(itemZ.leftOrigin, equals(itemA.id));
      expect(itemZ.rightOrigin, equals(itemC.id));
    });

    test('dispose() correctly unregisters listeners', () {
      final doc = SynkDoc();
      final text = SynkText(doc, 'body');

      text.insert(0, 'Hello');
      expect(text.text, equals('Hello'));

      text.dispose();

      // This update should NOT be processed by the disposed map
      text.insert(0, 'Goodbye');

      // It should still have the old value because the listener was removed
      expect(text.text, equals('Hello'));
    });

    test('stream emits batched updates', () async {
      final doc = SynkDoc();
      final text = SynkText(doc, 'content');

      final updates = expectLater(
        text.stream,
        emitsInOrder([
          'Hi!',    // Emit 1 (batched)
          'Hi! ',   // Emit 2
        ]),
      );

      // Batch 1: insert multiple characters
      doc.transact((txn) {
        text.insert(0, 'H');
        text.insert(1, 'i');
        text.insert(2, '!');
      });

      // Batch 2
      doc.transact((txn) {
        text.append(' ');
      });

      await updates;
    });
  });
}
