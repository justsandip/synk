import 'dart:async';

import 'package:synk/synk.dart';

/// {@template synk_value}
/// A collaborative single-value register.
///
/// [SynkValue] implements a Last-Writer-Wins (LWW) Register.
/// When two users modify the generic value `T` concurrently, the one with the
/// higher logical clock (or client ID tie-breaker) wins.
///
/// Supported generic types include standard JSON-serializable types:
/// `String`, `num` (and `double`), and `bool`.
/// {@endtemplate}
class SynkValue<T> {
  /// {@macro synk_value}
  SynkValue(this.doc, this.name) {
    doc
      ..addListener(_processItem)
      ..addTransactionListener(_processTransaction);
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

  // Stream controller for reactive state updates
  final StreamController<T?> _streamController =
      StreamController<T?>.broadcast();

  /// A stream that emits the register's fully resolved state after every
  /// completed transaction that modifies it.
  Stream<T?> get stream => _streamController.stream;

  void _processItem(Item item) {
    if (item.parentKey == name) {
      _applyRemoteItem(item);
    }
  }

  void _applyRemoteItem(Item item) {
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

  void _processTransaction(Transaction txn) {
    if (txn.mutatedKeys.contains(name)) {
      _streamController.add(value);
    }
  }

  /// Disposes the [SynkValue] instance.
  void dispose() {
    doc
      ..removeListener(_processItem)
      ..removeTransactionListener(_processTransaction);
    _streamController.close();
  }

  /// Sets the register to a new [value].
  void set(T value) {
    doc.transact((txn) {
      final item = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: value,
      );
      doc.addItem(item);
    });
  }

  /// Gets the current resolved value.
  T? get value {
    final item = _activeItem;
    if (item == null || item.deleted) return null;

    // Type casting logic for numbers as JSON encodes them lossily
    if (T == double && item.content is int) {
      return (item.content as int).toDouble() as T;
    }

    return item.content as T;
  }
}
