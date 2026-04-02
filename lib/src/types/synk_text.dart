import 'dart:async';

import 'package:synk/synk.dart';

/// {@template synk_text}
/// A collaborative plain-text sequence.
///
/// [SynkText] implements a character-level sequence CRDT optimized for text.
/// Like [SynkList], concurrent insertions are resolved deterministically,
/// ensuring that when two peers insert text at the same spot, the result
/// converges identically on all peers.
///
/// Under the hood, characters are stored as individual [Item]s in a
/// doubly-linked list. Deleted characters are tombstoned and simply omitted
/// from the visible [text].
/// {@endtemplate}
class SynkText {
  /// {@macro synk_text}
  ///
  /// Creates a new [SynkText] named [name] attached to [doc].
  SynkText(this.doc, this.name) {
    doc
      ..addListener(_processItem)
      ..addTransactionListener(_processTransaction);
    _replayExisting();
  }

  /// The document this text sequence belongs to.
  final SynkDoc doc;

  /// The unique key name of this text sequence in the document.
  final String name;

  // Head of the internal doubly-linked list (may be deleted characters).
  Item? _start;

  // Tracks which item IDs have been wired into the linked list,
  // used for safe topological replay of existing history.
  final Set<ID> _integrated = {};

  // Cache for the length of the sequence (number of non-deleted characters).
  int _length = 0;

  // Stream controller for reactive state updates
  final StreamController<String> _streamController = 
      StreamController<String>.broadcast();

  /// A stream that emits the text's fully resolved state after every 
  /// completed transaction that modifies it.
  Stream<String> get stream => _streamController.stream;

  // ── Internals ────────────────────────────────────────────────────────────

  void _processItem(Item item) {
    if (item.parentKey == name) {
      _integrate(item);
    }
  }

  void _replayExisting() {
    // Collect all items that belong to this list.
    final pending = <Item>[];
    for (final clientItems in doc.store.values) {
      for (final item in clientItems) {
        if (item.parentKey == name) pending.add(item);
      }
    }

    // Integrate in topological order (leftOrigin must be integrated first).
    // A single pass over pending repeatedly until no more progress.
    var remaining = pending.length;
    while (pending.isNotEmpty) {
      final deferred = <Item>[];
      for (final item in pending) {
        final canIntegrate =
            item.leftOrigin == null || _integrated.contains(item.leftOrigin);
        if (canIntegrate) {
          _integrate(item);
        } else {
          deferred.add(item);
        }
      }
      if (deferred.length == remaining) break; // no progress — stop
      remaining = deferred.length;
      pending
        ..clear()
        ..addAll(deferred);
    }
  }

  Item? _findById(ID id) {
    final clientItems = doc.store[id.client];
    if (clientItems == null || id.clock >= clientItems.length) return null;
    return clientItems[id.clock];
  }

  /// CRDT integration algorithm.
  ///
  /// Inserts [item] into the linked list after its [Item.leftOrigin] and
  /// before [Item.rightOrigin]. When two concurrent items share the same
  /// [Item.leftOrigin], the one with the higher [ID.client] wins and goes
  /// first (to the left).
  void _integrate(Item item) {
    // If this is a pre-deleted item it is a delete marker.
    // Find the target (leftOrigin) and tombstone it; the marker itself
    // never appears in the visible linked list.
    if (item.deleted) {
      if (item.leftOrigin != null) {
        final target = _findById(item.leftOrigin!);
        if (target != null && !target.deleted) {
          target.delete();
          _length--;
        }
      }
      _integrated.add(item.id);
      return;
    }

    var left = item.leftOrigin != null ? _findById(item.leftOrigin!) : null;
    final right = item.rightOrigin != null
        ? _findById(item.rightOrigin!)
        : null;

    // Start scanning from position immediately after `left`.
    var scanning = left != null ? left.right : _start;

    while (scanning != null && scanning != right) {
      // When two items share the same leftOrigin they compete.
      // Higher client goes to the left (earlier position) — deterministic.
      final scanLeft = scanning.leftOrigin != null
          ? _findById(scanning.leftOrigin!)
          : null;
      if (scanLeft == left) {
        if (scanning.id.client > item.id.client) {
          // scanning should stay before item — advance left past it.
          left = scanning;
        } else {
          // item should come before scanning — stop here.
          break;
        }
      }
      scanning = scanning.right;
    }

    // Wire the item into the linked list.
    item
      ..left = left
      ..right = left != null ? left.right : _start;

    if (left != null) {
      left.right = item;
    } else {
      _start = item;
    }
    if (item.right != null) {
      item.right!.left = item;
    }

    _length++;
    _integrated.add(item.id);
  }

  /// Walks the linked list to find the [index]th non-deleted [Item].
  Item? _findActive(int index) {
    var current = _start;
    var count = 0;
    while (current != null) {
      if (!current.deleted) {
        if (count == index) return current;
        count++;
      }
      current = current.right;
    }
    return null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void _processTransaction(Transaction txn) {
    if (txn.mutatedKeys.contains(name)) {
      _streamController.add(text);
    }
  }

  /// Disposes the [SynkText] instance to prevent memory leaks.
  void dispose() {
    doc
      ..removeListener(_processItem)
      ..removeTransactionListener(_processTransaction);
    _streamController.close();
  }

  /// Inserts a string [value] at character [index] in the active text sequence.
  ///
  /// Providing [index] equal to [length] is equivalent to appending.
  /// Throws [RangeError] if [index] is negative or greater than [length].
  void insert(int index, String value) {
    if (value.isEmpty) return;
    final len = length;
    if (index < 0 || index > len) {
      throw RangeError.index(index, this, 'index', null, len);
    }
    doc.transact((txn) {
      Item? leftItem;
      Item? rightItem;

      if (index == 0) {
        leftItem = null;
        // rightOrigin = first *non-deleted* item (if any).
        var r = _start;
        while (r != null && r.deleted) {
          r = r.right;
        }
        rightItem = r;
      } else {
        leftItem = _findActive(index - 1);
        // rightOrigin = the next non-deleted item after leftItem.
        var r = leftItem?.right;
        while (r != null && r.deleted) {
          r = r.right;
        }
        rightItem = r;
      }

      for (var i = 0; i < value.length; i++) {
        final char = value[i];
        final item = Item(
          id: txn.getNextId(),
          parentKey: name,
          content: char,
          leftOrigin: leftItem?.id,
          rightOrigin: rightItem?.id,
        );
        doc.addItem(item);

        // Advance leftItem so the next character links sequentially
        // after this one.
        leftItem = item;
      }
    });
  }

  /// Appends string [value] to the end of the text.
  void append(String value) => insert(length, value);

  /// Removes [count] characters starting at [index] by tombstoning them.
  ///
  /// The deletion is emitted as replicable operations so remote peers
  /// receive and apply them on sync.
  /// Throws [RangeError] if [index] or [index + count] is out of range.
  void delete(int index, int count) {
    if (count <= 0) return;
    final len = length;
    if (index < 0 || index + count > len) {
      throw RangeError.range(index < 0 ? index : index + count, 0, len);
    }

    doc.transact((txn) {
      var target = _findActive(index);
      for (var i = 0; i < count; i++) {
        if (target == null) break;

        final marker = Item(
          id: txn.getNextId(),
          parentKey: name,
          content: null,
          leftOrigin: target.id,
          deleted: true,
        );
        doc.addItem(marker);

        // advance target to the next non-deleted item for the next character
        target = target.right;
        while (target != null && target.deleted) {
          target = target.right;
        }
      }
    });
  }

  /// The number of active (non-deleted) characters.
  int get length => _length;

  /// Returns the complete visible text string.
  String get text {
    final buffer = StringBuffer();
    var current = _start;
    while (current != null) {
      if (!current.deleted) {
        buffer.write(current.content);
      }
      current = current.right;
    }
    return buffer.toString();
  }
}
