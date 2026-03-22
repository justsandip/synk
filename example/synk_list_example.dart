// ignore_for_file: cascade_invocations, avoid_print

import 'package:synk/synk.dart';

void main() {
  // ── Local usage ──
  final doc = SynkDoc();
  final todos = SynkList(doc, 'todos');

  todos.append('Buy milk');
  todos.append('Buy eggs');
  todos.insert(1, 'Buy bread'); // inserts between the two above
  print('Todos: ${todos.toList()}');
  // [Buy milk, Buy bread, Buy eggs]

  todos.delete(0); // remove 'Buy milk'
  print('After delete: ${todos.toList()}'); // [Buy bread, Buy eggs]
  print('Length: ${todos.length}'); // 2
  print('Item at 0: ${todos.get(0)}'); // Buy bread

  // ── Multi-peer: concurrent inserts resolve deterministically ──
  final docAlice = SynkDoc(clientId: 1);
  final docBob = SynkDoc(clientId: 2);

  final listA = SynkList(docAlice, 'items');
  final listB = SynkList(docBob, 'items');

  // Sync a shared starting point
  listA.append('start');
  SynkProtocol.applyUpdate(docBob, SynkProtocol.encodeStateAsUpdate(docAlice));

  // Both append after 'start' while offline
  listA.insert(1, 'from Alice');
  listB.insert(1, 'from Bob');

  // Bidirectional sync
  SynkProtocol.applyUpdate(
    docBob,
    SynkProtocol.encodeStateAsUpdate(
      docAlice,
      SynkProtocol.encodeStateVector(docBob),
    ),
  );
  SynkProtocol.applyUpdate(
    docAlice,
    SynkProtocol.encodeStateAsUpdate(
      docBob,
      SynkProtocol.encodeStateVector(docAlice),
    ),
  );

  // Both converge to the same order — higher clientId (Bob=2) goes first
  print('Alice list: ${listA.toList()}'); // [start, from Bob, from Alice]
  print('Bob list:   ${listB.toList()}'); // [start, from Bob, from Alice]
  print(
    'Converged: ${listA.toList().toString() == listB.toList().toString()}',
  ); // true

  // ── Late-joining peer gets the full history ──
  final docCarol = SynkDoc(clientId: 3);
  final listC = SynkList(docCarol, 'items');

  SynkProtocol.applyUpdate(
    docCarol,
    SynkProtocol.encodeStateAsUpdate(docAlice),
  );

  print('Carol list: ${listC.toList()}'); // [start, from Bob, from Alice]
}
