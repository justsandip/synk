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

  // ── Item Listeners (Internal, Immediate) ──────────────────────────────

  final List<void Function(Item)> _listeners = [];

  /// Adds a listener that triggers whenever a new item is integrated.
  ///
  /// These listeners fire immediately and synchronously inside a transaction.
  /// They are intended for internal use by shared types (like [SynkMap],
  /// [SynkList], etc.) to process incoming items in real time.
  void addListener(void Function(Item) listener) {
    _listeners.add(listener);
  }

  /// Removes an item listener.
  void removeListener(void Function(Item) listener) {
    _listeners.remove(listener);
  }

  // ── Transaction Listeners (External, Batched) ─────────────────────────

  final List<void Function(Transaction)> _transactionListeners = [];

  /// The active transaction, if currently transacting. Null otherwise.
  Transaction? _currentTransaction;

  /// Adds a listener that fires once after a top-level transaction completes.
  ///
  /// Use this for change notifications that should be batched — for example,
  /// updating a UI or emitting on a [Stream]. This listener is guaranteed to
  /// fire at most once per [transact] call, regardless of how many items
  /// were added inside the transaction.
  void addTransactionListener(void Function(Transaction) listener) {
    _transactionListeners.add(listener);
  }

  /// Removes a transaction listener.
  void removeTransactionListener(void Function(Transaction) listener) {
    _transactionListeners.remove(listener);
  }

  // ── Core ───────────────────────────────────────────────────────────────

  /// Adds a new item to the document's global store and notifies data types.
  void addItem(Item item) {
    var clientItems = store[item.id.client];
    if (clientItems == null) {
      clientItems = [];
      store[item.id.client] = clientItems;
    }

    // Assuming sequential insertion for now.
    clientItems.add(item);

    // Track which keys were modified during this transaction
    if (item.parentKey != null && _currentTransaction != null) {
      _currentTransaction!.mutatedKeys.add(item.parentKey!);
    }

    // Notify all attached data types (like SynkMap) to process this item.
    // These fire immediately so types can integrate items in real time.
    for (final listener in _listeners) {
      listener(item);
    }
  }

  /// Executes a block of code within a [Transaction].
  ///
  /// All modifications to the document MUST happen within a transaction.
  /// This ensures that updates are properly batched and that the [StateVector]
  /// is maintained correctly.
  ///
  /// Transaction listeners (registered via [addTransactionListener]) fire
  /// exactly once after the outermost [transact] call completes. Nested
  /// transactions do not trigger additional notifications.
  void transact(void Function(Transaction txn) action) {
    final isNested = _currentTransaction != null;
    final txn = isNested ? _currentTransaction! : Transaction(this);

    if (!isNested) {
      _currentTransaction = txn;
    }

    action(txn);

    if (!isNested) {
      _currentTransaction = null;

      // Notify external observers that a batch of changes completed.
      for (final listener in _transactionListeners) {
        listener(txn);
      }
    }
  }

  /// Generates a random 32-bit positive integer for the `clientId`.
  static int _generateRandomClientId() {
    final rng = math.Random.secure();
    // Generate a number up to 2^31 - 1
    return rng.nextInt(2147483647);
  }
}
