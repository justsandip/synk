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
