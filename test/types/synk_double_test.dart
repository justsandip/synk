// ignore_for_file: prefer_int_literals, cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkDouble', () {
    test('initializes to 0.0', () {
      final doc = SynkDoc();
      final weight = SynkDouble(doc, 'weight');
      expect(weight.value, equals(0.0));
    });

    test('sets correctly locally', () {
      final doc = SynkDoc();
      final weight = SynkDouble(doc, 'weight');

      weight.set(75.5);
      expect(weight.value, equals(75.5));
    });

    test('gracefully handles integer casting internally', () {
      final doc = SynkDoc();
      final weight = SynkDouble(doc, 'weight');

      // When sending json encoded payload, 75.0 can become 75 (int).
      // Our implementation does `(content as num).toDouble()`
      // Let's test by manually injecting an int item.
      doc.transact((txn) {
        doc.addItem(
          Item(
            id: txn.getNextId(),
            parentKey: 'weight',
            content: 42, // pure int
          ),
        );
      });

      expect(weight.value, equals(42.0));
    });

    test('LWW resolves conflicts correctly', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final sliderA = SynkDouble(docA, 'slider');
      final sliderB = SynkDouble(docB, 'slider');

      // Alice's clock hits 1
      sliderA.set(1.0);
      sliderA.set(2.0);

      // Bob's clock hits 0
      sliderB.set(0.5);

      final updateA = SynkProtocol.encodeStateAsUpdate(docA);
      final updateB = SynkProtocol.encodeStateAsUpdate(docB);

      SynkProtocol.applyUpdate(docB, updateA);
      SynkProtocol.applyUpdate(docA, updateB);

      // Alice's clock (1) > Bob's clock (0), so Alice wins
      expect(sliderA.value, equals(2.0));
      expect(sliderB.value, equals(2.0));
    });

    test('initializes correctly from pre-existing timeline', () {
      final doc = SynkDoc();
      final weight1 = SynkDouble(doc, 'weight');
      weight1.set(42.5);

      // Create a second weight bound to the same name AFTER operations
      // occurred
      final weight2 = SynkDouble(doc, 'weight');
      expect(weight2.value, equals(42.5));
    });
  });
}
