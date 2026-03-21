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
    doc.listen((item) {
      if (item.parentKey == name && item.content is int) {
        _value += item.content as int;
      }
    });

    // Compute initial value from existing items in case this type
    // is instantiated after items were already synced.
    for (final clientItems in doc.store.values) {
      for (final item in clientItems) {
        if (item.parentKey == name && item.content is int) {
          _value += item.content as int;
        }
      }
    }
  }

  /// The document this counter belongs to.
  final SynkDoc doc;

  /// The unique key name of this counter in the document.
  final String name;

  int _value = 0;

  /// The current sum of all increments and decrements.
  int get value => _value;

  /// Increments the counter by [by] (defaults to 1).
  void increment([int by = 1]) {
    if (by == 0) return;
    doc.transact((txn) {
      final item = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: by,
      );
      doc.addItem(item);
    });
  }

  /// Decrements the counter by [by] (defaults to 1).
  void decrement([int by = 1]) => increment(-by);
}
