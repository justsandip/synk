import 'dart:math' as math;

/// {@template state_vector}
/// Keeps track of the latest clock values received from each client.
///
/// A State Vector is a fundamental concept in operation-based CRDTs. It is
/// essentially a map of `clientId` to the `clock` of the last operation
/// successfully integrated from that client. By comparing State Vectors, two
/// peers can determine exactly which operations they need to exchange to sync
/// up.
/// {@endtemplate}
class StateVector {
  /// {@macro state_vector}
  StateVector() : _state = {};

  /// Creates a [StateVector] from an existing map of client IDs to clocks.
  StateVector.fromMap(Map<int, int> state) : _state = Map.of(state);

  final Map<int, int> _state;

  /// Returns the latest known clock for the given [clientId].
  ///
  /// If the client is unknown, returns 0.
  int get(int clientId) => _state[clientId] ?? 0;

  /// Updates or sets the latest known [clock] for the given [clientId].
  ///
  /// Only updates if the provided [clock] is greater than the
  /// currently known clock.
  void set(int clientId, int clock) {
    final currentClock = get(clientId);
    _state[clientId] = math.max(currentClock, clock);
  }

  /// Returns true if this state vector knows about the operation
  /// defined by [clientId] and [clock].
  bool has(int clientId, int clock) {
    return get(clientId) > clock;
  }
}
