import 'package:meta/meta.dart';

/// {@template id}
/// Represents a unique identifier for any operation in the CRDT.
///
/// Every operation (like inserting a character or an element in an array)
/// must have a universally unique [ID]. In a CRDT like Synk, this is composed
/// of the [client] ID that created it, and a [clock] value that increments for
/// each new operation from that client.
/// {@endtemplate}
@immutable
class ID {
  /// {@macro id}
  const ID(this.client, this.clock);

  /// The globally unique ID of the client that created this operation.
  /// Usually a large random integer to avoid collisions.
  final int client;

  /// The logical clock value. This is a sequence number that strictly
  /// increments for every new operation created by
  /// the [client] starting from 0.
  final int clock;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ID && other.client == client && other.clock == clock;
  }

  @override
  int get hashCode => client.hashCode ^ clock.hashCode;

  @override
  String toString() => 'ID($client, $clock)';
}
