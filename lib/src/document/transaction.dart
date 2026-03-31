import 'package:synk/synk.dart';

/// {@template transaction}
/// Represents a distinct batch of changes made to a [SynkDoc].
///
/// Transactions are essential for performance and network efficiency.
/// Instead of syncing every single character keystroke individually,
/// a transaction allows you to bundle related modifications together.
/// {@endtemplate}
class Transaction {
  /// {@macro transaction}
  ///
  /// Note: End-users should not instantiate this directly.
  /// They should use `doc.transact()`.
  Transaction(this.doc);

  /// The document this transaction is modifying.
  final SynkDoc doc;

  /// Keeps track of the `parentKey` (the name of the shared type) for every
  /// item that was added or modified during this transaction.
  ///
  /// This is used by external listeners to avoid unnecessary rebuilds. For
  /// example, if a `SynkList` named "todos" was the only thing modified,
  /// a `SynkText` named "title" shouldn't emit a stream event.
  final Set<String> mutatedKeys = {};

  /// Generates the next available [ID] for the local document's client.
  ///
  /// This methods consults the document's [StateVector] to find the latest
  /// clock value for the local `clientId`, returns it as an [ID], and then
  /// automatically increments the clock safely.
  ID getNextId() {
    final clock = doc.stateVector.get(doc.clientId);

    // Advance the local state vector right away so subsequent calls
    // get the next incremented clock value.
    doc.stateVector.set(doc.clientId, clock + 1);

    return ID(doc.clientId, clock);
  }
}
