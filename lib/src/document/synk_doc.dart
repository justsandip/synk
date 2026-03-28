import 'dart:math' as math;
import 'package:synk/synk.dart';

/// {@template synk_doc}
/// The central container for shared CRDT data.
///
/// A [SynkDoc] manages the logical [clientId], keeps track of the [StateVector]
/// and serves as the entry point for all transactions and data types.
/// {@endtemplate}
class SynkDoc {
  /// {@macro synk_doc}
  ///
  /// The [clientId] is optional. If omitted, a random 32-bit positive integer
  /// will be generated.
  SynkDoc({int? clientId})
    : clientId = clientId ?? _generateRandomClientId(),
      stateVector = StateVector();

  /// The globally unique client identifier for this local document peer.
  /// It is typically randomly generated when the document is instantiated.
  final int clientId;

  /// Tracks the latest clocks of all clients that have contributed
  /// to this document.
  final StateVector stateVector;

  /// A global record of every single item (operation) that exists in this
  /// document.
  /// Mapped by [clientId] -> List of [Item]s.
  ///
  /// Since items created by a specific client always have sequentially
  /// incrementing clock values starting from 0, the clock value perfectly
  /// matches the item's index in the list.
  final Map<int, List<Item>> store = {};

  final List<void Function(Item)> _listeners = [];

  /// Adds a listener that triggers whenever a new item is integrated.
  void addListener(void Function(Item) listener) {
    _listeners.add(listener);
  }

  /// Removes a listener.
  void removeListener(void Function(Item) listener) {
    _listeners.remove(listener);
  }

  /// Adds a new item to the document's global store and notifies data types.
  void addItem(Item item) {
    var clientItems = store[item.id.client];
    if (clientItems == null) {
      clientItems = [];
      store[item.id.client] = clientItems;
    }

    // Assuming sequential insertion for now.
    clientItems.add(item);

    // Notify all attached data types (like SynkMap) to process this item.
    for (final listener in _listeners) {
      listener(item);
    }
  }

  /// Executes a block of code within a [Transaction].
  ///
  /// All modifications to the document MUST happen within a transaction.
  /// This ensures that updates are properly batched and that the [StateVector]
  /// is maintained correctly.
  void transact(void Function(Transaction txn) action) {
    final txn = Transaction(this);
    action(txn);
    // In the future: emit events or delta updates after the transaction
    // completes.
  }

  /// Generates a random 32-bit positive integer for the `clientId`.
  static int _generateRandomClientId() {
    final rng = math.Random.secure();
    // Generate a number up to 2^31 - 1
    return rng.nextInt(2147483647);
  }
}
