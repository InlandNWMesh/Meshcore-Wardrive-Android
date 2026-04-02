// BufferReader/BufferWriter pattern adapted from meshcore-open
// (github.com/zjs81/meshcore-open, MIT © zjs81)

import 'dart:convert';
import 'dart:typed_data';

/// Ergonomic binary parser over a fixed byte array.
class BufferReader {
  final Uint8List _data;
  int _offset = 0;

  BufferReader(this._data);

  bool get hasMore => _offset < _data.length;
  int get remaining => _data.length - _offset;

  int readByte() {
    if (_offset >= _data.length) throw RangeError('BufferReader: out of bounds at $_offset');
    return _data[_offset++];
  }

  Uint8List readBytes(int count) {
    if (_offset + count > _data.length) {
      throw RangeError('BufferReader: out of bounds reading $count bytes at $_offset');
    }
    final result = Uint8List.fromList(_data.sublist(_offset, _offset + count));
    _offset += count;
    return result;
  }

  int readUInt32LE() {
    if (_offset + 4 > _data.length) throw RangeError('BufferReader: out of bounds reading uint32 at $_offset');
    final result = _data[_offset] |
        (_data[_offset + 1] << 8) |
        (_data[_offset + 2] << 16) |
        (_data[_offset + 3] << 24);
    _offset += 4;
    return result;
  }

  /// Reads bytes until a null terminator, then advances past it.
  String readCString() {
    final start = _offset;
    while (_offset < _data.length && _data[_offset] != 0) {
      _offset++;
    }
    final result = utf8.decode(_data.sublist(start, _offset), allowMalformed: true);
    if (_offset < _data.length) _offset++; // skip null terminator
    return result;
  }

  void skipBytes(int count) {
    _offset = (_offset + count).clamp(0, _data.length);
  }
}

/// Ergonomic binary builder.
class BufferWriter {
  final BytesBuilder _builder = BytesBuilder();

  void writeByte(int value) => _builder.addByte(value & 0xFF);

  void writeBytes(Uint8List bytes) => _builder.add(bytes);

  void writeUInt32LE(int value) {
    _builder.addByte(value & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte((value >> 16) & 0xFF);
    _builder.addByte((value >> 24) & 0xFF);
  }

  /// Writes UTF-8 encoded string followed by a null byte.
  void writeCString(String text) {
    _builder.add(utf8.encode(text));
    _builder.addByte(0);
  }

  Uint8List toBytes() => _builder.toBytes();
}

/// Convert a hex string (e.g. "deadbeef") to bytes.
Uint8List hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
