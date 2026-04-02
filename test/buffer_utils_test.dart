import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_wardrive/utils/buffer_utils.dart';

void main() {
  group('BufferWriter / BufferReader round-trip', () {
    test('writeByte / readByte', () {
      final w = BufferWriter();
      w.writeByte(0xAB);
      w.writeByte(0x00);
      w.writeByte(0xFF);
      final r = BufferReader(w.toBytes());
      expect(r.readByte(), 0xAB);
      expect(r.readByte(), 0x00);
      expect(r.readByte(), 0xFF);
      expect(r.hasMore, isFalse);
    });

    test('writeBytes / readBytes', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final w = BufferWriter();
      w.writeBytes(data);
      final r = BufferReader(w.toBytes());
      expect(r.readBytes(5), data);
    });

    test('writeUInt32LE / readUInt32LE', () {
      final w = BufferWriter();
      w.writeUInt32LE(0x12345678);
      w.writeUInt32LE(0);
      w.writeUInt32LE(0xFFFFFFFF);
      final r = BufferReader(w.toBytes());
      expect(r.readUInt32LE(), 0x12345678);
      expect(r.readUInt32LE(), 0);
      // Dart integers are 64-bit so 0xFFFFFFFF is safe
      expect(r.readUInt32LE(), 0xFFFFFFFF);
    });

    test('writeCString / readCString', () {
      final w = BufferWriter();
      w.writeCString('hello');
      w.writeCString('');
      w.writeCString('world');
      final r = BufferReader(w.toBytes());
      expect(r.readCString(), 'hello');
      expect(r.readCString(), '');
      expect(r.readCString(), 'world');
    });

    test('mixed types round-trip', () {
      final w = BufferWriter();
      w.writeByte(7);
      w.writeUInt32LE(1234567890);
      w.writeBytes(Uint8List.fromList([0xDE, 0xAD]));
      w.writeCString('test');

      final r = BufferReader(w.toBytes());
      expect(r.readByte(), 7);
      expect(r.readUInt32LE(), 1234567890);
      expect(r.readBytes(2), Uint8List.fromList([0xDE, 0xAD]));
      expect(r.readCString(), 'test');
      expect(r.hasMore, isFalse);
    });

    test('skipBytes advances offset', () {
      final w = BufferWriter();
      w.writeByte(1);
      w.writeByte(2);
      w.writeByte(3);
      final r = BufferReader(w.toBytes());
      r.skipBytes(2);
      expect(r.readByte(), 3);
    });

    test('remaining decrements correctly', () {
      final w = BufferWriter();
      w.writeByte(0);
      w.writeByte(0);
      w.writeByte(0);
      final r = BufferReader(w.toBytes());
      expect(r.remaining, 3);
      r.readByte();
      expect(r.remaining, 2);
    });

    test('readByte throws when out of bounds', () {
      final r = BufferReader(Uint8List(0));
      expect(() => r.readByte(), throwsA(isA<RangeError>()));
    });

    test('readBytes throws when out of bounds', () {
      final r = BufferReader(Uint8List.fromList([1, 2]));
      expect(() => r.readBytes(5), throwsA(isA<RangeError>()));
    });
  });

  group('hexToBytes', () {
    test('converts lowercase hex', () {
      expect(hexToBytes('deadbeef'),
          Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]));
    });

    test('converts uppercase hex', () {
      expect(hexToBytes('DEADBEEF'),
          Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]));
    });

    test('converts all zeros', () {
      expect(hexToBytes('00000000'), Uint8List(4));
    });

    test('empty string gives empty bytes', () {
      expect(hexToBytes(''), Uint8List(0));
    });
  });
}
