import 'dart:convert';
import 'dart:typed_data';

import 'package:synk/synk.dart';

/// {@template encoder}
/// A simple binary encoder for CRDT serialization.
///
/// Uses [BytesBuilder] internally to dynamically grow the buffer
/// as we encode complex structures like [StateVector] or [Item].
/// {@endtemplate}
class Encoder {
  /// {@macro encoder}
  Encoder() : _builder = BytesBuilder();

  final BytesBuilder _builder;

  /// Writes an 8-bit unsigned integer.
  void writeUint8(int value) {
    _builder.addByte(value);
  }

  /// Writes a 32-bit unsigned integer (Endian-independent by
  /// using DataView style).
  void writeUint32(int value) {
    final bData = ByteData(4)..setUint32(0, value);
    _builder.add(bData.buffer.asUint8List());
  }

  /// Writes a standard UTF-8 string. Includes length prefix.
  void writeString(String str) {
    final bytes = utf8.encode(str);
    writeUint32(bytes.length);
    _builder.add(bytes);
  }

  /// Writes a dynamic JSON-compatible object.
  /// Standard CRDTs use custom encoding for every type, but for dynamic map
  /// values, JSON encoding the payload is the most rock-solid approach in Dart.
  void writeJson(dynamic obj) {
    final str = jsonEncode(obj);
    writeString(str);
  }

  /// Returns the final compressed byte array for transmission.
  Uint8List toBytes() {
    return _builder.toBytes();
  }
}
