import 'package:synk/synk.dart';

/// {@template synk_list}
/// A collaborative ordered list.
///
/// [SynkList] implements a sequence CRDT where concurrent insertions at the
/// same position are resolved deterministically: when two peers insert at the
/// same spot, the item from the peer with the higher [ID.client] is placed
/// first. This guarantees every peer converges to the exact same order.
///
/// Items are never removed from memory — deleted elements are tombstoned (see
/// [Item.deleted]) and simply omitted from [toList], [get], and [length].
/// {@endtemplate}
class SynkList {
  /// {@macro synk_list}
  ///
  /// Creates a new [SynkList] named [name] attached to [doc].
  SynkList(this.doc, this.name) {
    doc.addListener(_processItem);
    _replayExisting();
  }

  /// The document this list belongs to.
  final SynkDoc doc;

  /// The unique key name of this list in the document.
  final String name;

  // Head of the internal doubly-linked list (may be deleted).
  Item? _start;

  // Tracks which item IDs have been wired into the linked list,
  // used for safe topological replay of existing history.
  final Set<ID> _integrated = {};

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
        target?.delete();
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

  /// Disposes the [SynkList] instance.
  void dispose() {
    doc.removeListener(_processItem);
  }

  /// Inserts [value] at position [index] in the active (visible) list.
  ///
  /// Providing [index] equal to [length] is equivalent to [append].
  /// Throws [RangeError] if [index] is negative or greater than [length].
  void insert(int index, dynamic value) {
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

      final item = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: value,
        leftOrigin: leftItem?.id,
        rightOrigin: rightItem?.id,
      );
      doc.addItem(item);
    });
  }

  /// Appends [value] to the end of the list.
  void append(dynamic value) => insert(length, value);

  /// Removes the element at [index] from the active list by tombstoning it.
  ///
  /// The deletion is emitted as a replicable operation so remote peers
  /// receive and apply it on sync.
  /// Throws [RangeError] if [index] is out of range.
  void delete(int index) {
    final target = _findActive(index);
    if (target == null) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    doc.transact((txn) {
      // Emit a delete marker: an item with deleted = true whose leftOrigin
      // points to the target. When integrated on any peer, it tombstones
      // the target — this makes the delete operation fully replicable.
      final marker = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: null,
        leftOrigin: target.id,
        deleted: true,
      );
      doc.addItem(marker);
    });
  }

  /// Returns the value at [index] in the active list.
  ///
  /// Throws [RangeError] if [index] is out of range.
  dynamic get(int index) {
    final item = _findActive(index);
    if (item == null) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    return item.content;
  }

  /// The number of non-deleted elements.
  int get length {
    var count = 0;
    var current = _start;
    while (current != null) {
      if (!current.deleted) count++;
      current = current.right;
    }
    return count;
  }

  /// Returns all non-deleted values as an ordered [List].
  List<dynamic> toList() {
    final result = <dynamic>[];
    var current = _start;
    while (current != null) {
      if (!current.deleted) result.add(current.content);
      current = current.right;
    }
    return result;
  }
}
