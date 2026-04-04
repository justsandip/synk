import 'dart:async';

import 'package:synk/synk.dart';

/// {@template synk_map}
/// A shared CRDT key-value map.
///
/// [SynkMap] implements a Last-Writer-Wins (LWW) Register for map values.
/// When two users modify the same key, the one with the higher logical clock
/// wins. If the clocks are identical, the client with the higher
/// `clientId` wins deterministically.
/// {@endtemplate}
class SynkMap {
  /// {@macro synk_map}
  ///
  /// Creates a new [SynkMap] attached to the given [doc] with a unique [name].
  SynkMap(this.doc, this.name) {
    doc
      ..addListener(_processItem)
      ..addTransactionListener(_processTransaction);
    // Apply existing history
    for (final clientItems in doc.store.values) {
      clientItems.forEach(_processItem);
    }
  }

  /// The document this map belongs to.
  final SynkDoc doc;

  /// The unique key name of this map in the document.
  final String name;

  // Internally stores the active Item for each key.
  final Map<String, Item> _data = {};

  // Stream controller for reactive state updates
  final StreamController<Map<String, dynamic>> _streamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// A stream that emits the map's fully resolved state after every
  /// completed transaction that modifies it.
  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  void _processItem(Item item) {
    if (item.parentKey != null && item.parentKey!.startsWith('$name:')) {
      _applyRemoteItem(item);
    }
  }

  void _applyRemoteItem(Item item) {
    final key = item.parentKey!.substring(name.length + 1);

    if (item.deleted) {
      if (item.leftOrigin != null) {
        final existingItem = _data[key];
        if (existingItem != null && existingItem.id == item.leftOrigin) {
          existingItem.delete();
        }
      }
      return;
    }

    final existingItem = _data[key];

    if (existingItem != null) {
      final a = item.id;
      final b = existingItem.id;

      if (a.clock > b.clock || (a.clock == b.clock && a.client > b.client)) {
        existingItem.delete();
        _data[key] = item;
      } else {
        item.delete();
      }
    } else {
      _data[key] = item;
    }
  }

  void _processTransaction(Transaction txn) {
    var didMutate = false;
    for (final mutatedKey in txn.mutatedKeys) {
      if (mutatedKey.startsWith('$name:')) {
        didMutate = true;
        break;
      }
    }
    if (didMutate) {
      _streamController.add(toMap());
    }
  }

  /// Disposes the [SynkMap] instance.
  ///
  /// Remember to call this to prevent memory leaks.
  void dispose() {
    doc
      ..removeListener(_processItem)
      ..removeTransactionListener(_processTransaction);
    _streamController.close();
  }

  /// Sets a [key] to a new [value].
  ///
  /// This must be executed. If not already in a transaction,
  /// it creates one implicitly.
  void set(String key, dynamic value) {
    doc.transact((txn) {
      final id = txn.getNextId();
      final item = Item(
        id: id,
        parentKey: '$name:$key',
        content: value,
      );

      // Add to global store.
      // This synchronously triggers the `doc.listen` callback in the
      // SynkMap constructor, which safely routes this into `_applyRemoteItem`
      // and guarantees consistency whether the item came from a local keyboard
      // stroke or a network buffer!
      doc.addItem(item);
    });
  }

  /// Retrieves the current value for the given [key], or null
  /// if it doesn't exist.
  dynamic get(String key) {
    final item = _data[key];
    if (item == null || item.deleted) return null;
    return item.content;
  }

  /// Checks if the map contains the [key] with a non-deleted value.
  bool containsKey(String key) {
    final item = _data[key];
    return item != null && !item.deleted;
  }

  /// Removes the [key] from the map by tombstoning the current value.
  void delete(String key) {
    doc.transact((txn) {
      final existingItem = _data[key];
      if (existingItem != null && !existingItem.deleted) {
        // Emit a delete marker: an item with deleted = true whose leftOrigin
        // points to the target. When integrated on any peer, it tombstones
        // the target, making the delete operation fully replicable.
        final marker = Item(
          id: txn.getNextId(),
          parentKey: '$name:$key',
          content: null,
          leftOrigin: existingItem.id,
          deleted: true,
        );
        doc.addItem(marker);
      }
    });
  }

  /// Returns all active key-value pairs as a standard Dart [Map].
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    for (final entry in _data.entries) {
      if (!entry.value.deleted) {
        map[entry.key] = entry.value.content;
      }
    }
    return map;
  }
}
