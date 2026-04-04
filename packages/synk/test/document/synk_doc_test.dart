// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkDoc', () {
    test('initializes with a random client ID if none provided', () {
      final doc1 = SynkDoc();
      final doc2 = SynkDoc();

      // The odds of these being the same are statistically zero.
      expect(doc1.clientId, isNot(equals(doc2.clientId)));
      expect(doc1.clientId, greaterThanOrEqualTo(0));
    });

    test('initializes with a specific client ID', () {
      final doc = SynkDoc(clientId: 42);
      expect(doc.clientId, equals(42));
    });

    test('transact() executes code', () {
      final doc = SynkDoc(clientId: 1);
      var ran = false;

      doc.transact((txn) {
        expect(txn.doc, equals(doc));
        ran = true;
      });

      expect(ran, isTrue);
    });

    test('item listeners fire immediately per-item inside a transaction', () {
      final doc = SynkDoc(clientId: 1);
      var itemCount = 0;

      doc.addListener((_) => itemCount++);

      doc.transact((txn) {
        doc.addItem(Item(id: txn.getNextId(), content: 'a', parentKey: 'x'));
        expect(itemCount, equals(1)); // Fires immediately

        doc.addItem(Item(id: txn.getNextId(), content: 'b', parentKey: 'x'));
        expect(itemCount, equals(2)); // Fires immediately again
      });

      expect(itemCount, equals(2));
    });

    test('transaction listeners fire once after transact() completes', () {
      final doc = SynkDoc(clientId: 1);
      var transactionCount = 0;
      var keys = <String>{};

      doc.addTransactionListener((txn) {
        transactionCount++;
        keys = txn.mutatedKeys;
      });

      doc.transact((txn) {
        doc.addItem(
          Item(id: txn.getNextId(), content: 'a', parentKey: 'title'),
        );
        doc.addItem(
          Item(id: txn.getNextId(), content: 'b', parentKey: 'likes'),
        );
        doc.addItem(
          Item(id: txn.getNextId(), content: 'c', parentKey: 'title'),
        );

        // Transaction listener should NOT have fired yet
        expect(transactionCount, equals(0));
      });

      // Now it fires — exactly once
      expect(transactionCount, equals(1));
      // And it tracked the keys!
      expect(keys, containsAll(['title', 'likes']));
      expect(keys.length, equals(2));
    });

    test('nested transactions only fire transaction listeners once', () {
      final doc = SynkDoc(clientId: 1);
      var transactionCount = 0;

      doc.addTransactionListener((_) => transactionCount++);

      doc.transact((outerTxn) {
        doc.addItem(
          Item(id: outerTxn.getNextId(), content: 'a', parentKey: 'x'),
        );

        // Nested transaction
        doc.transact((innerTxn) {
          doc.addItem(
            Item(id: innerTxn.getNextId(), content: 'b', parentKey: 'x'),
          );
          expect(transactionCount, equals(0));
        });

        // Still inside the outer transaction — should not have fired
        expect(transactionCount, equals(0));
      });

      // Only fires once for the outermost transaction
      expect(transactionCount, equals(1));
    });

    test('removeTransactionListener stops notifications', () {
      final doc = SynkDoc(clientId: 1);
      var count = 0;

      void onTransact(Transaction txn) => count++;

      doc.addTransactionListener(onTransact);

      doc.transact((txn) {
        doc.addItem(Item(id: txn.getNextId(), content: 'a', parentKey: 'x'));
      });
      expect(count, equals(1));

      doc.removeTransactionListener(onTransact);

      doc.transact((txn) {
        doc.addItem(Item(id: txn.getNextId(), content: 'b', parentKey: 'x'));
      });
      expect(count, equals(1)); // Did NOT increment
    });
  });

  group('Transaction', () {
    test('getNextId generates sequential IDs for the local client', () {
      final doc = SynkDoc(clientId: 100)
        ..transact((txn) {
          final id1 = txn.getNextId();
          expect(id1, equals(const ID(100, 0)));

          final id2 = txn.getNextId();
          expect(id2, equals(const ID(100, 1)));

          final id3 = txn.getNextId();
          expect(id3, equals(const ID(100, 2)));
        });

      // Assert state vector correctly tracked the changes
      expect(doc.stateVector.get(100), equals(3));
    });
  });
}
