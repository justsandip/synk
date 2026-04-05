import 'dart:async';

import 'package:synk/synk.dart';

/// {@template synk_int}
/// A collaborative integer counter.
///
/// [SynkInt] acts as a PN-Counter (Positive-Negative Counter).
/// Concurrent increments and decrements are combined commutatively,
/// completely avoiding conflicts.
/// {@endtemplate}
class SynkInt {
  /// {@macro synk_int}
  SynkInt(this.doc, this.name) {
    doc
      ..addListener(_processItem)
      ..addTransactionListener(_processTransaction);
    // Compute initial value from existing items in case this type
    // is instantiated after items were already synced.
    for (final clientItems in doc.store.values) {
      clientItems.forEach(_processItem);
    }
  }

  /// The document this counter belongs to.
  final SynkDoc doc;

  /// The unique key name of this counter in the document.
  final String name;

  int _value = 0;

  // Stream controller for reactive state updates
  final StreamController<int> _streamController =
      StreamController<int>.broadcast();

  /// A stream that emits the counter's fully resolved state after every
  /// completed transaction that modifies it.
  Stream<int> get stream => _streamController.stream;

  void _processItem(Item item) {
    if (item.parentKey == name && item.content is int) {
      _value += item.content as int;
    }
  }

  void _processTransaction(Transaction txn) {
    if (txn.mutatedKeys.contains(name)) {
      _streamController.add(value);
    }
  }

  /// Disposes the [SynkInt] instance.
  void dispose() {
    doc
      ..removeListener(_processItem)
      ..removeTransactionListener(_processTransaction);
    _streamController.close();
  }

  /// The current sum of all increments and decrements.
  int get value => _value;

  /// Increments the counter by [by] (defaults to 1).
  void increment([int by = 1]) {
    if (by == 0) return;
    doc.transact((txn) {
      final item = Item(id: txn.getNextId(), parentKey: name, content: by);
      doc.addItem(item);
    });
  }

  /// Decrements the counter by [by] (defaults to 1).
  void decrement([int by = 1]) => increment(-by);
}
