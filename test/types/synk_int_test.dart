// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkInt (PN-Counter)', () {
    test('initializes to 0', () {
      final doc = SynkDoc();
      final counter = SynkInt(doc, 'score');
      expect(counter.value, equals(0));
    });

    test('increments and decrements correctly locally', () {
      final doc = SynkDoc();
      final counter = SynkInt(doc, 'score');

      counter.increment(5);
      expect(counter.value, equals(5));

      counter.decrement(2);
      expect(counter.value, equals(3));
    });

    test('converges commutatively without conflicts', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final counterA = SynkInt(docA, 'score');
      final counterB = SynkInt(docB, 'score');

      // Alice adds 10
      counterA.increment(10);

      // Bob adds 5 and subtracts 2
      counterB.increment(5);
      counterB.decrement(2);

      // Sync A -> B
      final updateA = SynkProtocol.encodeStateAsUpdate(docA);
      SynkProtocol.applyUpdate(docB, updateA);

      // Sync B -> A
      final updateB = SynkProtocol.encodeStateAsUpdate(docB);
      SynkProtocol.applyUpdate(docA, updateB);

      // Both should exactly equal 13 (10 + 5 - 2)
      expect(counterA.value, equals(13));
      expect(counterB.value, equals(13));
    });

    test('initializes correctly from pre-existing timeline', () {
      final doc = SynkDoc();
      final counter1 = SynkInt(doc, 'likes');
      counter1.increment(42);

      // Create a second counter bound to the same name AFTER operations
      // occurred
      final counter2 = SynkInt(doc, 'likes');
      expect(counter2.value, equals(42));
    });

    test('dispose() correctly unregisters listeners', () {
      final doc = SynkDoc();
      final counter = SynkInt(doc, 'score');

      counter.increment(42);
      expect(counter.value, equals(42));

      counter.dispose();

      // This update should NOT be processed by the disposed map
      counter.increment(100);

      // It should still have the old value because the listener was removed
      expect(counter.value, equals(42));
    });
  });
}
