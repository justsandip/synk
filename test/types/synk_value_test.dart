// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkValue<T>', () {
    test('String -> resolves concurrent edits using LWW (clock wins)', () {
      final doc1 = SynkDoc(clientId: 1);
      final doc2 = SynkDoc(clientId: 2);

      final title1 = SynkValue<String>(doc1, 'title');
      final title2 = SynkValue<String>(doc2, 'title');

      // Simulate isolated concurrent edits
      title1.set('Alpha');
      title2.set('Beta');

      // Now sync them
      final update1 = SynkProtocol.encodeStateAsUpdate(doc1);
      final update2 = SynkProtocol.encodeStateAsUpdate(doc2);

      SynkProtocol.applyUpdate(doc2, update1);
      SynkProtocol.applyUpdate(doc1, update2);

      // Both should resolve to 'Beta' because Doc 2 has the higher clientId
      // when clocks are completely equal (clock 0 relative to their own state).
      expect(title1.value, equals('Beta'));
      expect(title2.value, equals('Beta'));
    });

    test('double -> resolves identical clock operations', () {
      final doc1 = SynkDoc(clientId: 1);
      final doc2 = SynkDoc(clientId: 2);

      final opacity1 = SynkValue<double>(doc1, 'opacity');
      final opacity2 = SynkValue<double>(doc2, 'opacity');

      opacity1.set(0.5);
      opacity2.set(0.8);

      final u1 = SynkProtocol.encodeStateAsUpdate(doc1);
      final u2 = SynkProtocol.encodeStateAsUpdate(doc2);

      SynkProtocol.applyUpdate(doc2, u1);
      SynkProtocol.applyUpdate(doc1, u2);

      // clientId 2 wins
      expect(opacity1.value, equals(0.8));
      expect(opacity2.value, equals(0.8));
    });

    test('bool -> honors clock superiority', () {
      final doc = SynkDoc(clientId: 1);
      final flag = SynkValue<bool>(doc, 'ready');
      expect(flag.value, isNull);

      flag.set(false); // Clock 0
      flag.set(true); // Clock 1
      expect(flag.value, isTrue);

      // Simulate a highly delayed packet from a completely different doc
      doc.transact((txn) {
        doc.addItem(
          Item(
            // Clock 0 is strictly older than our current clock 1
            id: const ID(55, 0),
            parentKey: 'ready',
            content: false,
          ),
        );
      });

      // It should still be true because our local clock was strictly higher
      expect(flag.value, isTrue);
    });

    test('initialize with historic data', () {
      final doc = SynkDoc(clientId: 1);
      doc.transact((txn) {
        doc.addItem(
          Item(id: txn.getNextId(), content: 100, parentKey: 'price'),
        );
      });

      // Initializes after the item is already present
      final price = SynkValue<int>(doc, 'price');
      expect(price.value, equals(100));
    });

    test('dispose() correctly unregisters listeners', () {
      final doc = SynkDoc();
      final mode = SynkValue<String>(doc, 'mode');

      mode.set('dark');
      expect(mode.value, equals('dark'));

      mode
        ..dispose()
        ..set('system');

      // It should still have the old value because the listener was removed
      expect(mode.value, equals('dark'));
    });

    test('double -> handles integer values from the wire (JSON lossiness)', () {
      final doc = SynkDoc(clientId: 1);
      final opacity = SynkValue<double>(doc, 'opacity');

      // Simulate a remote item where a double was encoded as an int in JSON
      doc.transact((txn) {
        doc.addItem(
          Item(
            id: const ID(2, 0),
            parentKey: 'opacity',
            content: 1, // Int content
          ),
        );
      });

      expect(opacity.value, isA<double>());
      expect(opacity.value, equals(1.0));
    });

    test('stream emits batched updates', () async {
      final doc = SynkDoc();
      final flag = SynkValue<bool>(doc, 'ready');

      final updates = expectLater(
        flag.stream,
        emitsInOrder([
          true, // Only emits the final value of the transaction
          false,
        ]),
      );

      doc.transact((txn) {
        flag.set(false);
        flag.set(true); // Overwrites the previous set in the same batch
      });

      doc.transact((txn) {
        flag.set(false);
      });

      await updates;
    });
  });
}
