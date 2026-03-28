import 'package:synk/synk.dart';

/// {@template synk_double}
/// A collaborative single-value double (floating-point) register.
///
/// [SynkDouble] implements a Last-Writer-Wins (LWW) Register.
/// {@endtemplate}
class SynkDouble {
  /// {@macro synk_double}
  SynkDouble(this.doc, this.name) {
    doc.addListener(_processItem);
    // Apply existing history
    for (final clientItems in doc.store.values) {
      clientItems.forEach(_processItem);
    }
  }

  /// The document this register belongs to.
  final SynkDoc doc;

  /// The unique key name of this register in the document.
  final String name;

  Item? _activeItem;

  void _processItem(Item item) {
    if (item.parentKey == name) {
      _applyRemoteItem(item);
    }
  }

  void _applyRemoteItem(Item item) {
    if (item.content is! num) return; // double or int

    final existing = _activeItem;
    if (existing != null) {
      final a = item.id;
      final b = existing.id;
      if (a.clock > b.clock || (a.clock == b.clock && a.client > b.client)) {
        existing.delete();
        _activeItem = item;
      } else {
        item.delete();
      }
    } else {
      _activeItem = item;
    }
  }

  /// Disposes the [SynkDouble] instance.
  void dispose() {
    doc.removeListener(_processItem);
  }

  /// Sets the register to a new [value].
  void set(double value) {
    doc.transact((txn) {
      final item = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: value,
      );
      doc.addItem(item);
    });
  }

  /// Gets the current resolved value. Returns 0 if unset.
  double get value {
    final item = _activeItem;
    if (item == null || item.deleted) return 0;
    return (item.content as num).toDouble();
  }
}
