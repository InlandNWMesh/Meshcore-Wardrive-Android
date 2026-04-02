import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_wardrive/utils/meshcore_uri.dart';

void main() {
  const testKeyHex = '00112233445566778899aabbccddeeff';
  final testKeyBytes = Uint8List.fromList([
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
  ]);

  group('MeshcoreChannelUri.parse', () {
    test('parses path-style URI (meshcore://channel/name/key)', () {
      final uri = MeshcoreChannelUri.parse(
          'meshcore://channel/wardrive/$testKeyHex');
      expect(uri, isNotNull);
      expect(uri!.name, 'wardrive');
      expect(uri.key, testKeyBytes);
    });

    test('parses short path-style URI (meshcore://ch/name/key)', () {
      final uri =
          MeshcoreChannelUri.parse('meshcore://ch/general/$testKeyHex');
      expect(uri, isNotNull);
      expect(uri!.name, 'general');
      expect(uri.key, testKeyBytes);
    });

    test('parses query-param style URI', () {
      final uri = MeshcoreChannelUri.parse(
          'meshcore://channel?name=wardrive&key=$testKeyHex');
      expect(uri, isNotNull);
      expect(uri!.name, 'wardrive');
      expect(uri.key, testKeyBytes);
    });

    test('parses base64url-encoded key (no padding, URL-safe)', () {
      // base64url replaces '+' with '-' and '/' with '_' — safe in URL paths
      const b64urlKey = 'ABEiM0RVZneImaq7zN3u_w';
      final uri =
          MeshcoreChannelUri.parse('meshcore://channel/test/$b64urlKey');
      expect(uri, isNotNull);
      expect(uri!.key, testKeyBytes);
    });

    test('parses standard base64 key with slash (split across path segments)', () {
      // Standard base64 may contain '/' which Uri splits into extra segments.
      // Parser rejoins them before decoding.
      const b64Key = 'ABEiM0RVZneImaq7zN3u/w==';
      final uri =
          MeshcoreChannelUri.parse('meshcore://channel/test/$b64Key');
      expect(uri, isNotNull);
      expect(uri!.key, testKeyBytes);
    });

    test('returns null for non-meshcore scheme', () {
      expect(MeshcoreChannelUri.parse('https://example.com'), isNull);
    });

    test('returns null for wrong key length', () {
      expect(
          MeshcoreChannelUri.parse('meshcore://channel/name/deadbeef'), isNull);
    });

    test('returns null for empty string', () {
      expect(MeshcoreChannelUri.parse(''), isNull);
    });

    test('handles URL-encoded channel name with spaces', () {
      final uri = MeshcoreChannelUri.parse(
          'meshcore://channel/my%20channel/$testKeyHex');
      expect(uri, isNotNull);
      expect(uri!.name, 'my channel');
    });

    test('trims whitespace', () {
      final uri = MeshcoreChannelUri.parse(
          '  meshcore://channel/wardrive/$testKeyHex  ');
      expect(uri, isNotNull);
    });
  });

  group('MeshcoreChannelUri.toUri', () {
    test('round-trips through parse', () {
      final original =
          MeshcoreChannelUri(name: 'wardrive', key: testKeyBytes);
      final uriStr = original.toUri();
      final parsed = MeshcoreChannelUri.parse(uriStr);
      expect(parsed, isNotNull);
      expect(parsed!.name, original.name);
      expect(parsed.key, original.key);
    });

    test('generates meshcore://channel/... format', () {
      final uri =
          MeshcoreChannelUri(name: 'general', key: testKeyBytes);
      expect(uri.toUri(), startsWith('meshcore://channel/'));
      expect(uri.toUri(), contains(testKeyHex));
    });
  });

  group('MeshcoreChannelUri.keyHex', () {
    test('returns lowercase hex', () {
      final uri =
          MeshcoreChannelUri(name: 'test', key: testKeyBytes);
      expect(uri.keyHex, testKeyHex);
    });
  });
}
