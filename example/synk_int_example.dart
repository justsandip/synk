// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

void main() {
  // ── Local usage ──
  final doc = SynkDoc();
  final counter = SynkInt(doc, 'score');

  counter.increment(10);
  counter.decrement(3);
  print('Score: ${counter.value}'); // 7

  // ── Multi-peer: concurrent increments ──
  final docAlice = SynkDoc(clientId: 1);
  final docBob = SynkDoc(clientId: 2);

  final counterA = SynkInt(docAlice, 'likes');
  final counterB = SynkInt(docBob, 'likes');

  // Both increment independently (offline)
  counterA.increment(5);
  counterB.increment(3);

  // Sync bidirectionally
  SynkProtocol.applyUpdate(docBob, SynkProtocol.encodeStateAsUpdate(docAlice));
  SynkProtocol.applyUpdate(docAlice, SynkProtocol.encodeStateAsUpdate(docBob));

  // PN-Counter commutes: 5 + 3 = 8, no conflicts, no data loss
  print('Alice likes: ${counterA.value}'); // 8
  print('Bob likes:   ${counterB.value}'); // 8
}
