// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkBool', () {
    test('initializes to false', () {
      final doc = SynkDoc();
      final flag = SynkBool(doc, 'isActive');
      expect(flag.value, isFalse);
    });

    test('sets and toggles correctly locally', () {
      final doc = SynkDoc();
      final flag = SynkBool(doc, 'isActive');

      flag.set(true);
      expect(flag.value, isTrue);

      flag.toggle();
      expect(flag.value, isFalse);
    });

    test('LWW rule applies over the network deterministically', () {
      final docA = SynkDoc(clientId: 100);
      final docB = SynkDoc(clientId: 200);

      final flagA = SynkBool(docA, 'flag');
      final flagB = SynkBool(docB, 'flag');

      // Both set it concurrently (clock = 0 for both)
      flagA.set(true);
      flagB.set(false);

      final updateA = SynkProtocol.encodeStateAsUpdate(docA);
      final updateB = SynkProtocol.encodeStateAsUpdate(docB);

      SynkProtocol.applyUpdate(docB, updateA);
      SynkProtocol.applyUpdate(docA, updateB);

      // Client 200 > Client 100, so Bob's `false` should win the tie!
      expect(flagA.value, isFalse);
      expect(flagB.value, isFalse);
    });

    test('initializes correctly from pre-existing timeline', () {
      final doc = SynkDoc();
      final flag1 = SynkBool(doc, 'isActive');
      flag1.set(true);

      // Create a second flag bound to the same name AFTER operations
      // occurred
      final flag2 = SynkBool(doc, 'isActive');
      expect(flag2.value, isTrue);
    });
  });
}
