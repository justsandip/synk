// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

void main() {
  // ── Local usage ──
  final doc = SynkDoc();
  final title = SynkString(doc, 'title');

  title.set('Hello');
  print('Title: ${title.value}'); // Hello

  title.set('Hello, World!');
  print('Title: ${title.value}'); // Hello, World!

  // ── Multi-peer: concurrent conflicting writes ──
  final docAlice = SynkDoc(clientId: 1);
  final docBob = SynkDoc(clientId: 2);

  final titleA = SynkString(docAlice, 'docTitle');
  final titleB = SynkString(docBob, 'docTitle');

  // Alice makes two edits (her clock advances to 1)
  titleA.set('Draft');
  titleA.set('Final Draft');

  // Bob makes one edit (his clock stays at 0)
  titleB.set("Bob's Version");

  // Sync bidirectionally
  SynkProtocol.applyUpdate(docBob, SynkProtocol.encodeStateAsUpdate(docAlice));
  SynkProtocol.applyUpdate(docAlice, SynkProtocol.encodeStateAsUpdate(docBob));

  // LWW: Alice's clock (1) > Bob's clock (0) → Alice wins
  print('Alice: ${titleA.value}'); // Final Draft
  print('Bob:   ${titleB.value}'); // Final Draft
}
