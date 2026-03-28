// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkString', () {
    test('initializes to empty string', () {
      final doc = SynkDoc();
      final title = SynkString(doc, 'title');
      expect(title.value, equals(''));
    });

    test('sets correctly locally', () {
      final doc = SynkDoc();
      final title = SynkString(doc, 'title');

      title.set('Hello World');
      expect(title.value, equals('Hello World'));

      title.set('Updated');
      expect(title.value, equals('Updated'));
    });

    test('LWW resolves conflicts correctly', () {
      final docA = SynkDoc(clientId: 1);
      final docB = SynkDoc(clientId: 2);

      final titleA = SynkString(docA, 'title');
      final titleB = SynkString(docB, 'title');

      // Alice's clock hits 1
      titleA.set('A1');
      titleA.set('A2');

      // Bob's clock hits 0
      titleB.set('B1');

      final updateA = SynkProtocol.encodeStateAsUpdate(docA);
      final updateB = SynkProtocol.encodeStateAsUpdate(docB);

      SynkProtocol.applyUpdate(docB, updateA);
      SynkProtocol.applyUpdate(docA, updateB);

      // Alice's clock (1) > Bob's clock (0), so Alice wins
      expect(titleA.value, equals('A2'));
      expect(titleB.value, equals('A2'));
    });

    test('initializes correctly from pre-existing timeline', () {
      final doc = SynkDoc();
      final title1 = SynkString(doc, 'title');
      title1.set('Hello');

      // Create a second string bound to the same name AFTER operations
      // occurred
      final title2 = SynkString(doc, 'title');
      expect(title2.value, equals('Hello'));
    });

    test('dispose() correctly unregisters listeners', () {
      final doc = SynkDoc();
      final title = SynkString(doc, 'title');

      title.set('Hello');
      expect(title.value, equals('Hello'));

      title.dispose();

      // This update should NOT be processed by the disposed map
      title.set('Goodbye');

      // It should still have the old value because the listener was removed
      expect(title.value, equals('Hello'));
    });
  });
}
