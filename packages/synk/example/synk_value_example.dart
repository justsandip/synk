// ignore_for_file: avoid_print

import 'package:synk/synk.dart';

void main() {
  final docA = SynkDoc(clientId: 1);
  final docB = SynkDoc(clientId: 2);

  print('--- SynkValue Example ---');
  print('SynkValue<T> behaves like a Last-Writer-Wins (LWW) Register');
  print('It stores a single, overwritable generic value.\n');

  // Initialize two peers with the same variable name
  final titleA = SynkValue<String>(docA, 'pageTitle');
  final titleB = SynkValue<String>(docB, 'pageTitle');

  print('Initial titleA value: ${titleA.value}'); // null (unset)
  print('Initial titleB value: ${titleB.value}\n');

  // Peer A edits the document
  titleA.set('Flutter Conference 2026');
  print('Alice set title to: ${titleA.value}');

  // Peer B edits concurrently offline (a conflict!)
  titleB.set('Dart Developer Summit');
  print('Bob set title to:   ${titleB.value}\n');

  // Sync to resolve the conflict completely
  print('--- Synk resolves the tie automatically ---');
  final aliceSv = SynkProtocol.encodeStateVector(docA);
  final bobUpdate = SynkProtocol.encodeStateAsUpdate(docB, aliceSv);
  SynkProtocol.applyUpdate(docA, bobUpdate);

  final bobSv = SynkProtocol.encodeStateVector(docB);
  final aliceUpdate = SynkProtocol.encodeStateAsUpdate(docA, bobSv);
  SynkProtocol.applyUpdate(docB, aliceUpdate);

  print("Alice's final title: ${titleA.value}");
  print("Bob's final title:   ${titleB.value}");
  // Notice that they both converge to 'Dart Developer Summit' because when
  // clocks tie, the higher clientId wins deterministically!

  // They also work seamlessly for numbers and booleans
  final flag = SynkValue<bool>(docA, 'isVisible');
  final opacity = SynkValue<double>(docA, 'opacity');

  flag.set(true);
  opacity.set(0.7);

  print('\nOther types supported:');
  print('bool flag: ${flag.value}');
  print('double opacity: ${opacity.value}');
}
