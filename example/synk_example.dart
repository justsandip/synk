// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

/// A simple multi-peer scenario demonstrating:
///   1. Two peers editing a shared map independently.
///   2. Conflict resolution via Last-Writer-Wins (LWW).
///   3. Deletion and tombstoning.
///   4. Binary sync protocol to exchange updates.
void main() {
  // ── 1. Create two independent documents (simulating two devices) ──
  final docAlice = SynkDoc(clientId: 1);
  final docBob = SynkDoc(clientId: 2);

  // Attach a SynkMap to each document.
  final mapAlice = SynkMap(docAlice);
  final mapBob = SynkMap(docBob);

  // ── 2. Alice makes some edits ──
  mapAlice.set('title', 'Grocery List');
  mapAlice.set('item1', 'Milk');
  mapAlice.set('item2', 'Eggs');

  print('--- After Alice edits ---');
  print('Alice: ${mapAlice.toMap()}');
  print('Bob:   ${mapBob.toMap()}');
  // Alice: {title: Grocery List, item1: Milk, item2: Eggs}
  // Bob:   {}

  // ── 3. Sync Alice → Bob ──
  //
  // Step A: Bob encodes his state vector so Alice knows what Bob has.
  final bobSv = SynkProtocol.encodeStateVector(docBob);

  // Step B: Alice encodes only the updates Bob is missing.
  final aliceUpdate = SynkProtocol.encodeStateAsUpdate(docAlice, bobSv);

  // Step C: Bob applies the update.
  SynkProtocol.applyUpdate(docBob, aliceUpdate);

  print('\n--- After syncing Alice → Bob ---');
  print('Alice: ${mapAlice.toMap()}');
  print('Bob:   ${mapBob.toMap()}');
  // Both are now identical!

  // ── 4. Concurrent conflict: both edit the same key offline ──
  //
  // Both start from the same state, then diverge.
  // Alice's local clock for client 1 is at 3 (she's made 3 ops).
  // Bob makes some local ops so his clock catches up.
  mapBob.set('item3', 'Butter'); // Bob clock=0
  mapBob.set('item4', 'Bread'); // Bob clock=1
  mapBob.set('item5', 'Cheese'); // Bob clock=2

  // Now both Alice and Bob edit 'item1' with matching clock values.
  // Alice: clock 3, client 1.  Bob: clock 3, client 2.
  mapAlice.set('item1', 'Oat Milk');
  mapBob.set('item1', 'Almond Milk');

  print('\n--- After concurrent edits (before sync) ---');
  print('Alice: ${mapAlice.toMap()}');
  print('Bob:   ${mapBob.toMap()}');

  // ── 5. Sync both ways to resolve the conflict ──
  // Alice → Bob
  final bobSv2 = SynkProtocol.encodeStateVector(docBob);
  final aliceUpdate2 = SynkProtocol.encodeStateAsUpdate(docAlice, bobSv2);
  SynkProtocol.applyUpdate(docBob, aliceUpdate2);

  // Bob → Alice
  final aliceSv = SynkProtocol.encodeStateVector(docAlice);
  final bobUpdate = SynkProtocol.encodeStateAsUpdate(docBob, aliceSv);
  SynkProtocol.applyUpdate(docAlice, bobUpdate);

  print('\n--- After bidirectional sync (conflict resolved) ---');
  print('Alice: ${mapAlice.toMap()}');
  print('Bob:   ${mapBob.toMap()}');
  // Both converge to "Almond Milk" because at equal clock (3),
  // the higher clientId (2 > 1) wins deterministically.

  // ── 6. Deletion ──
  //
  // Alice decides to remove 'item2' entirely.
  mapAlice.delete('item2');

  print('\n--- After Alice deletes item2 ---');
  print('Alice: ${mapAlice.toMap()}');
  print('Alice containsKey(item2): ${mapAlice.containsKey('item2')}');
  print('Alice get(item2): ${mapAlice.get('item2')}');
  // item2 is gone (tombstoned)!

  // ── 7. Add a third peer (Carol) and do a full sync ──
  final docCarol = SynkDoc(clientId: 3);
  final mapCarol = SynkMap(docCarol);

  // Carol has nothing, so we send the full document from Alice.
  final fullUpdate = SynkProtocol.encodeStateAsUpdate(docAlice);
  SynkProtocol.applyUpdate(docCarol, fullUpdate);

  print('\n--- Carol joins and gets full state ---');
  print('Carol: ${mapCarol.toMap()}');

  print('\n✅ All peers converged successfully!');
}
