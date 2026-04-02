// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkList — local operations', () {
    test('starts empty', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');
      expect(list.length, equals(0));
      expect(list.toList(), isEmpty);
    });

    test('append adds values to the end', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      list.append('a');
      list.append('b');
      list.append('c');

      expect(list.toList(), equals(['a', 'b', 'c']));
      expect(list.length, equals(3));
    });

    test('insert at beginning', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      list.append('b');
      list.insert(0, 'a');

      expect(list.toList(), equals(['a', 'b']));
    });

    test('insert in the middle', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      list.append('a');
      list.append('c');
      list.insert(1, 'b');

      expect(list.toList(), equals(['a', 'b', 'c']));
    });

    test('get returns value at index', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      list.append('x');
      list.append('y');

      expect(list.get(0), equals('x'));
      expect(list.get(1), equals('y'));
    });

    test('get throws RangeError for out-of-bounds index', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');
      expect(() => list.get(0), throwsRangeError);
    });

    test('delete tombstones an element', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      list.append('a');
      list.append('b');
      list.append('c');
      list.delete(1); // remove 'b'

      expect(list.toList(), equals(['a', 'c']));
      expect(list.length, equals(2));
    });

    test('delete throws RangeError for out-of-bounds index', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');
      expect(() => list.delete(0), throwsRangeError);
    });

    test('insert throws RangeError on invalid indices', () {
      final list = SynkList(SynkDoc(), 'items');
      expect(() => list.insert(-1, 'something'), throwsRangeError);
      expect(() => list.insert(1, 'another thing'), throwsRangeError);
    });
  });

  group('SynkList — multi-peer sync', () {
    test('sequential appends sync correctly', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final listA = SynkList(docA, 'todos');
      final listB = SynkList(docB, 'todos');

      listA.append('Buy milk');
      listA.append('Buy eggs');

      // Sync A → B
      SynkProtocol.applyUpdate(
        docB,
        SynkProtocol.encodeStateAsUpdate(docA),
      );

      expect(listB.toList(), equals(['Buy milk', 'Buy eggs']));
    });

    test('concurrent appends from different peers merge without data loss', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final listA = SynkList(docA, 'todos');
      final listB = SynkList(docB, 'todos');

      // Both peers append independently (offline)
      listA.append('Alice item');
      listB.append('Bob item');

      // Bidirectional sync
      final updateA = SynkProtocol.encodeStateAsUpdate(docA);
      final updateB = SynkProtocol.encodeStateAsUpdate(docB);

      SynkProtocol.applyUpdate(docB, updateA);
      SynkProtocol.applyUpdate(docA, updateB);

      // Both peers must have the same list (no data loss)
      expect(listA.toList(), equals(listB.toList()));
      expect(listA.length, equals(2));
    });

    test(
      'concurrent inserts at the same position converge deterministically',
      () {
        final docA = SynkDoc(clientId: 1);
        final docB = SynkDoc(clientId: 2);

        final listA = SynkList(docA, 'items');
        final listB = SynkList(docB, 'items');

        // Sync a common first item
        listA.append('start');
        SynkProtocol.applyUpdate(docB, SynkProtocol.encodeStateAsUpdate(docA));

        // Now both insert AFTER 'start' concurrently
        listA.insert(1, 'from Alice');
        listB.insert(1, 'from Bob');

        // Bidirectional sync
        final svB = SynkProtocol.encodeStateVector(docB);
        final updateA = SynkProtocol.encodeStateAsUpdate(docA, svB);
        SynkProtocol.applyUpdate(docB, updateA);

        final svA = SynkProtocol.encodeStateVector(docA);
        final updateB = SynkProtocol.encodeStateAsUpdate(docB, svA);
        SynkProtocol.applyUpdate(docA, updateB);

        // Both peers converge to the exact same order
        expect(listA.toList(), equals(listB.toList()));

        // Higher clientId (2 = Bob) wins the tie → Bob's item goes first
        expect(listA.toList(), equals(['start', 'from Bob', 'from Alice']));
      },
    );

    test('delete syncs correctly across peers', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final listA = SynkList(docA, 'items');
      final listB = SynkList(docB, 'items');

      listA.append('keep');
      listA.append('remove me');

      SynkProtocol.applyUpdate(docB, SynkProtocol.encodeStateAsUpdate(docA));

      listA.delete(1); // remove 'remove me'

      SynkProtocol.applyUpdate(
        docB,
        SynkProtocol.encodeStateAsUpdate(
          docA,
          SynkProtocol.encodeStateVector(docB),
        ),
      );

      expect(listB.toList(), equals(['keep']));
    });

    test('late-joining peer receives full history', () {
      final docA = SynkDoc(clientId: 1);
      final listA = SynkList(docA, 'items');

      listA.append('one');
      listA.append('two');
      listA.append('three');

      final docC = SynkDoc(clientId: 3);
      final listC = SynkList(docC, 'items');

      SynkProtocol.applyUpdate(docC, SynkProtocol.encodeStateAsUpdate(docA));

      expect(listC.toList(), equals(['one', 'two', 'three']));
    });

    test('applyUpdate is idempotent', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final listA = SynkList(docA, 'items');
      SynkList(docB, 'items');

      listA.append('x');
      listA.append('y');

      final update = SynkProtocol.encodeStateAsUpdate(docA);

      // Apply the same update twice — should be safe
      SynkProtocol.applyUpdate(docB, update);
      SynkProtocol.applyUpdate(docB, update);

      final listB = SynkList(docB, 'items');
      expect(listB.toList(), equals(['x', 'y']));
    });

    test('insert skips tombstones when determining rightOrigin', () {
      final list = SynkList(SynkDoc(), 'list');

      list.append('A'); // index 0
      list.append('B'); // index 1
      list.append('C'); // index 2

      // Delete 'B' to create a tombstone in the middle
      list.delete(1);

      // Now insert at index 1 (between A and C)
      // Inside insert():
      // leftItem will be 'A'
      // r starts at 'B' (deleted), so 'r = r.right' executes to move to 'C'
      list.insert(1, 'NEW');

      expect(list.toList(), equals(['A', 'NEW', 'C']));

      // Also test index 0 skip:
      list.delete(0); // Delete 'A'
      // Insert at index 0: r starts at 'A' (deleted), walks to 'NEW'
      list.insert(0, 'START');

      expect(list.toList(), equals(['START', 'NEW', 'C']));
    });

    test('handles out-of-order items via deferral', () {
      // Build a doc where client 2's items reference client 1's items
      // as leftOrigin. By inserting client 2 into doc.store FIRST,
      // _replayExisting will encounter them before client 1's items
      // on the first pass — forcing the deferred.add(item) branch (L63).
      final doc = SynkDoc(clientId: 99);

      // Client 1's item: 'first' (no leftOrigin, goes at the start)
      const id1 = ID(1, 0);
      final item1 = Item(id: id1, parentKey: 'list', content: 'first');

      // Client 2's item: 'second', depends on id1 as leftOrigin
      const id2 = ID(2, 0);
      final item2 = Item(
        id: id2,
        parentKey: 'list',
        content: 'second',
        leftOrigin: id1,
      );

      // Insert client 2 FIRST so _replayExisting processes it before client 1.
      // item2's leftOrigin (id1) is not yet in _integrated on the first pass
      // → hits the else branch → deferred.add(item2).
      // On the second pass, item1 is integrated first, then item2 succeeds.
      doc.store[2] = [item2];
      doc.store[1] = [item1];
      doc.stateVector
        ..set(2, 1)
        ..set(1, 1);

      final list = SynkList(doc, 'list');

      expect(list.toList(), equals(['first', 'second']));
    });

    test('dispose() correctly unregisters listeners', () {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      list.append('A');
      list.append('B');
      expect(list.toList(), equals(['A', 'B']));

      list.dispose();

      // This update should NOT be processed by the disposed map
      list.append('C');

      // It should still have the old value because the listener was removed
      expect(list.toList(), equals(['A', 'B']));
    });

    test('stream emits batched updates', () async {
      final doc = SynkDoc();
      final list = SynkList(doc, 'items');

      final updates = expectLater(
        list.stream,
        emitsInOrder([
          ['A', 'B'],       // Emit 1 (batched inserts)
          ['A', 'C', 'B'],  // Emit 2 (single insert)
        ]),
      );

      // Batch 1: two appends in a single transaction
      doc.transact((txn) {
        list.append('A');
        list.append('B');
      });

      // Batch 2: one insert
      doc.transact((txn) {
        list.insert(1, 'C');
      });

      await updates;
    });
  });
}
