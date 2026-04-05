import 'dart:typed_data';

import 'package:synk/synk.dart';

/// {@template synk_protocol}
/// Handles the binary encoding and merging of document state
/// across the network.
/// {@endtemplate}
class SynkProtocol {
  /// Encodes the document's [StateVector] into binary.
  ///
  /// Format: [numberOfClients: Uint32],
  /// then for each: [clientId: Uint32, clock: Uint32]
  static Uint8List encodeStateVector(SynkDoc doc) {
    final encoder = Encoder();

    // We access the internal map conceptually. Since we don't expose it
    // directly, let's add a quick getter or we can just iterate the `doc.store`
    // keys. For now, we will use doc.store to find all known clients
    // and their clocks.
    final clients = doc.store.keys.toList();
    encoder.writeUint32(clients.length);

    for (final client in clients) {
      encoder
        ..writeUint32(client)
        ..writeUint32(doc.stateVector.get(client));
    }

    return encoder.toBytes();
  }

  /// Decodes a binary state vector back into a [StateVector] object.
  static StateVector decodeStateVector(Uint8List bytes) {
    final decoder = Decoder(bytes);
    final sv = StateVector();

    if (!decoder.hasMore) return sv;

    final length = decoder.readUint32();
    for (var i = 0; i < length; i++) {
      final client = decoder.readUint32();
      final clock = decoder.readUint32();
      sv.set(client, clock);
    }

    return sv;
  }

  /// Encodes all new operations from [doc] that the remote peer doesn't have
  /// yet, based on their [remoteStateVectorBytes].
  ///
  /// If [remoteStateVectorBytes] is null, it encodes the entire document.
  static Uint8List encodeStateAsUpdate(
    SynkDoc doc, [
    Uint8List? remoteStateVectorBytes,
  ]) {
    final remoteSv = remoteStateVectorBytes != null
        ? decodeStateVector(remoteStateVectorBytes)
        : StateVector();

    final encoder = Encoder();

    // 1. Find which clients have updates that the remote missing
    final clientsWithUpdates = <int>[];
    for (final client in doc.store.keys) {
      final localClock = doc.stateVector.get(client);
      final remoteClock = remoteSv.get(client);
      if (localClock > remoteClock) {
        clientsWithUpdates.add(client);
      }
    }

    // 2. Write number of clients
    encoder.writeUint32(clientsWithUpdates.length);

    // 3. Write updates for each client
    for (final client in clientsWithUpdates) {
      encoder.writeUint32(client);

      final remoteClock = remoteSv.get(client);
      final allItems = doc.store[client]!;

      // The items are sequentially ordered by clock (0, 1, 2...)
      // So items starting at index `remoteClock` are exactly the missing ones!
      final missingItems = allItems.sublist(remoteClock);

      encoder.writeUint32(missingItems.length);

      for (final item in missingItems) {
        encoder.writeUint32(item.id.clock);

        // Write parentKey (1 byte flag + string if present)
        if (item.parentKey != null) {
          encoder
            ..writeUint8(1)
            ..writeString(item.parentKey!);
        } else {
          encoder.writeUint8(0);
        }

        // Write leftOrigin (1 byte flag + clientId + clock if present)
        if (item.leftOrigin != null) {
          encoder
            ..writeUint8(1)
            ..writeUint32(item.leftOrigin!.client)
            ..writeUint32(item.leftOrigin!.clock);
        } else {
          encoder.writeUint8(0);
        }

        // Write rightOrigin (1 byte flag + clientId + clock if present)
        if (item.rightOrigin != null) {
          encoder
            ..writeUint8(1)
            ..writeUint32(item.rightOrigin!.client)
            ..writeUint32(item.rightOrigin!.clock);
        } else {
          encoder.writeUint8(0);
        }

        // Write content as JSON
        encoder
          ..writeJson(item.content)
          // Write deleted status
          ..writeUint8(item.deleted ? 1 : 0);
      }
    }

    return encoder.toBytes();
  }

  /// Applies a binary update received from another peer to the local [doc].
  static void applyUpdate(SynkDoc doc, Uint8List updateBytes) {
    if (updateBytes.isEmpty) return;

    final decoder = Decoder(updateBytes);
    final clientsLength = decoder.readUint32();

    doc.transact((txn) {
      for (var i = 0; i < clientsLength; i++) {
        final client = decoder.readUint32();
        final itemsLength = decoder.readUint32();

        for (var j = 0; j < itemsLength; j++) {
          final clock = decoder.readUint32();

          final hasParentKey = decoder.readUint8() == 1;
          String? parentKey;
          if (hasParentKey) {
            parentKey = decoder.readString();
          }

          final hasLeftOrigin = decoder.readUint8() == 1;
          ID? leftOrigin;
          if (hasLeftOrigin) {
            leftOrigin = ID(decoder.readUint32(), decoder.readUint32());
          }

          final hasRightOrigin = decoder.readUint8() == 1;
          ID? rightOrigin;
          if (hasRightOrigin) {
            rightOrigin = ID(decoder.readUint32(), decoder.readUint32());
          }

          final content = decoder.readJson();
          final isDeleted = decoder.readUint8() == 1;

          final item = Item(
            id: ID(client, clock),
            parentKey: parentKey,
            leftOrigin: leftOrigin,
            rightOrigin: rightOrigin,
            content: content,
            deleted: isDeleted,
          );

          // Only apply the item if we don't already have it.
          // This ensures idempotency (safe to receive the same update
          // twice).
          if (!doc.stateVector.has(client, clock)) {
            doc.addItem(item);
            doc.stateVector.set(client, clock + 1);
          }
        }
      }
    });
  }
}
