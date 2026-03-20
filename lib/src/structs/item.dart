import 'package:synk/synk.dart';

/// {@template item}
/// The basic building block of CRDT sequences.
///
/// An [Item] represents an atomic operation/node (like inserting a character
/// or an element). It keeps track of its logical origins to allow the CRDT
/// algorithm to recreate the exact same sequence on all peers, regardless of
/// the order in which they receive updates.
/// {@endtemplate}
class Item {
  /// {@macro item}
  Item({
    required this.id,
    required this.content,
    this.leftOrigin,
    this.rightOrigin,
    this.parentKey,
    this.deleted = false,
    this.left,
    this.right,
  });

  /// The unique identifier of this item.
  final ID id;

  /// The ID of the item this was originally inserted *after*.
  /// Null if it was inserted at the very beginning of a collection.
  final ID? leftOrigin;

  /// The ID of the item this was originally inserted *before*.
  /// Null if it was inserted at the very end of a collection.
  final ID? rightOrigin;

  /// If this item belongs to a Map, this is the string key it is assigned to.
  /// This is critical for network peers to know what key this updates.
  final String? parentKey;

  /// The actual data stored in this item (e.g., a character,
  /// a number, a boolean).
  dynamic content;

  /// True if this item has been deleted.
  /// CRDTs use "tombstones" — we mark items as deleted instead of physically
  /// removing them. This is because other peers might receive our update
  /// *before* they receive the item we are deleting, or they might insert
  /// something next to this item.
  bool deleted;

  /// The runtime reference to the previous neighbor in the doubly-linked list.
  /// This is NOT serialized over the network. It is only maintained locally
  /// in the document state for fast local traversal and modification.
  Item? left;

  /// The runtime reference to the next neighbor in the doubly-linked list.
  /// This is NOT serialized over the network. It is only maintained locally
  /// in the document state for fast local traversal and modification.
  Item? right;

  /// Marks the item as deleted.
  void delete() {
    deleted = true;
  }
}
