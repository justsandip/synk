// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

void main() {
  // ── Local usage ──
  final doc = SynkDoc();
  final price = SynkDouble(doc, 'price');

  price.set(9.99);
  print('Price: ${price.value}'); // 9.99

  price.set(14.99);
  print('Price: ${price.value}'); // 14.99

  // ── Multi-peer: concurrent conflicting writes ──
  final docAlice = SynkDoc(clientId: 1);
  final docBob = SynkDoc(clientId: 2);

  final sliderA = SynkDouble(docAlice, 'volume');
  final sliderB = SynkDouble(docBob, 'volume');

  // Alice makes two edits (clock advances to 1)
  sliderA.set(0.5);
  sliderA.set(0.8);

  // Bob makes one edit (clock stays at 0)
  sliderB.set(0.2);

  // Sync bidirectionally
  SynkProtocol.applyUpdate(docBob, SynkProtocol.encodeStateAsUpdate(docAlice));
  SynkProtocol.applyUpdate(docAlice, SynkProtocol.encodeStateAsUpdate(docBob));

  // LWW: Alice's clock (1) > Bob's clock (0) → Alice wins
  print('Alice volume: ${sliderA.value}'); // 0.8
  print('Bob volume:   ${sliderB.value}'); // 0.8
}
