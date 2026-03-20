// ignore_for_file: avoid_redundant_argument_values, prefer_const_constructors,
// ignore_for_file: cascade_invocations

import 'package:synk/synk.dart';
import 'package:test/test.dart';

void main() {
  group('SynkProtocol', () {
    test('two simulated clients can sync their state', () {
      // 1. Client A creates a document and makes changes
      final docA = SynkDoc(clientId: 1);
      final mapA = SynkMap(docA);

      mapA.set('username', 'alice');
      mapA.set('theme', 'dark');

      // 2. Client B creates an empty document
      final docB = SynkDoc(clientId: 2);
      final mapB = SynkMap(docB);

      // 3. Handshake protocol
      // Bob asks Alice for her updates by sending his empty State Vector
      final bobsStateVector = SynkProtocol.encodeStateVector(docB);

      // Alice generates a delta using Bob's State Vector
      final aliceUpdate = SynkProtocol.encodeStateAsUpdate(
        docA,
        bobsStateVector,
      );

      // Bob applies Alice's delta
      SynkProtocol.applyUpdate(docB, aliceUpdate);

      // 4. Assert Bob now has everything!
      expect(mapB.get('username'), equals('alice'));
      expect(mapB.get('theme'), equals('dark'));
      expect(
        docB.stateVector.get(1),
        equals(2),
      ); // Bob knows Alice is at clock 2
    });

    test('Conflict resolution over the network (LWW)', () {
      // Alice
      final docA = SynkDoc(clientId: 100);
      final mapA = SynkMap(docA);

      // Bob
      final docB = SynkDoc(clientId: 200); // Bob has higher client ID
      final mapB = SynkMap(docB);

      // Concurrent edits while offline!
      mapA.set('color', 'red');
      mapB.set('color', 'blue');

      // Sync Alice -> Bob
      final svB = SynkProtocol.encodeStateVector(docB);
      final updateA = SynkProtocol.encodeStateAsUpdate(docA, svB);
      SynkProtocol.applyUpdate(docB, updateA);

      // Sync Bob -> Alice
      final svA = SynkProtocol.encodeStateVector(docA);
      final updateB = SynkProtocol.encodeStateAsUpdate(docB, svA);
      SynkProtocol.applyUpdate(docA, updateB);

      // Both should resolve to 'blue' because Bob has a higher
      // Client ID (200 > 100)
      expect(mapA.get('color'), equals('blue'));
      expect(mapB.get('color'), equals('blue'));
    });
  });

  test('encodeStateAsUpdate handles null remote state vector (Full Sync)', () {
    final docA = SynkDoc(clientId: 1);
    final mapA = SynkMap(docA);
    mapA.set('key', 'value'); // This creates an Item with a specific parentKey

    final docB = SynkDoc(clientId: 2);
    final mapB = SynkMap(docB);

    // Alice encodes everything
    final fullUpdate = SynkProtocol.encodeStateAsUpdate(docA, null);

    // Bob applies it BEFORE creating the map handler
    SynkProtocol.applyUpdate(docB, fullUpdate);

    // If mapA and mapB use a default "root" parentKey, this should now work
    expect(mapB.get('key'), equals('value'));
  });

  test('encodes items without parentKey correctly', () {
    final doc = SynkDoc(clientId: 1);

    // Directly add an item to the doc that doesn't have a parentKey
    // (Manual injection to trigger Line 97)
    final item = Item(
      id: ID(1, 0),
      parentKey: null,
      content: 'root-level-data',
    );
    doc.addItem(item);
    // Update state vector so the encoder sees it
    doc.stateVector.set(1, 1);

    final update = SynkProtocol.encodeStateAsUpdate(doc);

    // If this encodes/decodes without crashing, Line 97 is covered and verified
    final doc2 = SynkDoc(clientId: 2);
    SynkProtocol.applyUpdate(doc2, update);

    // Check that the item exists in the store
    expect(doc2.store[1]!.first.content, equals('root-level-data'));
    expect(doc2.store[1]!.first.parentKey, isNull);
  });
}
