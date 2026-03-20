import 'dart:convert';
import 'dart:typed_data';

import 'package:synk/synk.dart';

/// {@template decoder}
/// A simple binary decoder to complement [Encoder].
/// {@endtemplate}
class Decoder {
  /// {@macro decoder}
  Decoder(Uint8List bytes)
    : _data = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.length,
      );

  final ByteData _data;
  int _offset = 0;

  /// Reads an 8-bit unsigned integer.
  int readUint8() {
    final val = _data.getUint8(_offset);
    _offset += 1;
    return val;
  }

  /// Reads a 32-bit unsigned integer.
  int readUint32() {
    final val = _data.getUint32(_offset);
    _offset += 4;
    return val;
  }

  /// Reads a length-prefixed UTF-8 string.
  String readString() {
    final length = readUint32();
    final bytes = _data.buffer.asUint8List(
      _data.offsetInBytes + _offset,
      length,
    );
    _offset += length;
    return utf8.decode(bytes);
  }

  /// Reads a dynamically encoded JSON payload.
  dynamic readJson() {
    final str = readString();
    return jsonDecode(str);
  }

  /// Returns true if there is more data to read.
  bool get hasMore => _offset < _data.lengthInBytes;
}
