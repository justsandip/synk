// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

void main() {
  print('--- SynkText Example ---');

  // ── Local usage ──
  final doc = SynkDoc();
  final text = SynkText(doc, 'body');

  text.insert(0, 'Hello');
  print('Text: "${text.text}" (length: ${text.length})');

  text.append(' World');
  print('Text: "${text.text}"');

  text.insert(5, ',');
  print('Text: "${text.text}"');

  // Delete ' World' (7 chars starting at index 5)
  text.delete(5, 7);
  text.append('!');
  print('Text: "${text.text}"');

  print('\n--- Multi-peer Sync ---');
  // ── Multi-peer: concurrent text editing ──
  final docAlice = SynkDoc(clientId: 1);
  final docBob = SynkDoc(clientId: 2);

  final textAlice = SynkText(docAlice, 'note');
  final textBob = SynkText(docBob, 'note');

  // Sync a common starting point
  textAlice.append('abc');
  SynkProtocol.applyUpdate(docBob, SynkProtocol.encodeStateAsUpdate(docAlice));
  print('Alice starts with: "${textAlice.text}"');
  print('Bob starts with:   "${textBob.text}"');

  // Both edit concurrently while offline
  // Alice inserts 'X' at index 1 -> "aXbc"
  textAlice.insert(1, 'X');

  // Bob inserts 'Y' at index 1 -> "aYbc"
  textBob.insert(1, 'Y');

  // Bob also deletes 'c' (now at his index 3) -> "aYb"
  textBob.delete(3, 1);

  print('\n(Offline)');
  print('Alice edited to:   "${textAlice.text}"');
  print('Bob edited to:     "${textBob.text}"');

  // Sync bidirectionally
  final aliceUpdate = SynkProtocol.encodeStateAsUpdate(docAlice);
  final bobUpdate = SynkProtocol.encodeStateAsUpdate(docBob);

  SynkProtocol.applyUpdate(docBob, aliceUpdate);
  SynkProtocol.applyUpdate(docAlice, bobUpdate);

  print('\n(After Sync)');
  // Because Bob's client ID (2) > Alice's client ID (1),
  // Bob's 'Y' comes before Alice's 'X'.
  // The deletion of 'c' by Bob is merged without issue.
  print('Alice converged:   "${textAlice.text}"'); // aYXb
  print('Bob converged:     "${textBob.text}"'); // aYXb
}
