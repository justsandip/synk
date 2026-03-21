// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

void main() {
  // ── Local usage ──
  final doc = SynkDoc();
  final flag = SynkBool(doc, 'isPublished');

  flag.set(true);
  print('Published: ${flag.value}'); // true

  flag.toggle();
  print('Published: ${flag.value}'); // false

  // ── Multi-peer: concurrent conflicting writes ──
  final docAlice = SynkDoc(clientId: 100);
  final docBob = SynkDoc(clientId: 200);

  final flagA = SynkBool(docAlice, 'darkMode');
  final flagB = SynkBool(docBob, 'darkMode');

  // Both set the flag concurrently at the same clock (offline)
  flagA.set(true); // client 100
  flagB.set(false); // client 200

  // Sync bidirectionally
  SynkProtocol.applyUpdate(docBob, SynkProtocol.encodeStateAsUpdate(docAlice));
  SynkProtocol.applyUpdate(docAlice, SynkProtocol.encodeStateAsUpdate(docBob));

  // LWW: higher clientId wins the tie → client 200 (false) wins
  print('Alice darkMode: ${flagA.value}'); // false
  print('Bob darkMode:   ${flagB.value}'); // false
}
