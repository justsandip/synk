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
  /// Creates a new [SynkMap] attached to the given [doc].
  SynkMap(this.doc) {
    doc.listen((item) {
      // Filter out items that don't belong to a map (no key),
      // and only process those integrated from remote transactions
      // (local ones are processed directly in `set`).
      // For simplicity, we process all map items. If they are already the
      // active item, they just replace themselves redundantly.
      if (item.parentKey != null) {
        _applyRemoteItem(item);
      }
    });
  }

  /// The document this map belongs to.
  final SynkDoc doc;

  // Internally stores the active Item for each key.
  final Map<String, Item> _data = {};

  void _applyRemoteItem(Item item) {
    final key = item.parentKey!;
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

  /// Sets a [key] to a new [value].
  ///
  /// This must be executed. If not already in a transaction,
  /// it creates one implicitly.
  void set(String key, dynamic value) {
    doc.transact((txn) {
      final id = txn.getNextId();
      final item = Item(
        id: id,
        parentKey: key,
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
        existingItem.delete();
        // Optionally, we could generate a new item with `content = null` and
        // `deleted = true` to properly replicate the deletion across peers as
        // an operation. For now, tombstoning the local item acts as the
        // bare-minimum local delete.
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
