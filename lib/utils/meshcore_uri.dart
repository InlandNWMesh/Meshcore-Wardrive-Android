import 'dart:convert';
import 'dart:typed_data';

/// Parses and generates meshcore:// channel sharing URIs.
///
/// Supported formats (all equivalent):
///   meshcore://channel?name=wardrive&key=<hex-or-base64>
///   meshcore://ch/<name>/<hex-or-base64-key>
///   meshcore://channel/<name>/<hex-or-base64-key>
class MeshcoreChannelUri {
  final String name;
  final Uint8List key; // 16 bytes

  const MeshcoreChannelUri({required this.name, required this.key});

  /// Parse a meshcore:// URI string. Returns null if invalid.
  static MeshcoreChannelUri? parse(String raw) {
    try {
      final trimmed = raw.trim();
      final uri = Uri.parse(trimmed);

      if (uri.scheme != 'meshcore') return null;

      String? name;
      Uint8List? key;

      // Query-param style: meshcore://channel?name=X&key=Y
      if (uri.queryParameters.containsKey('name') &&
          uri.queryParameters.containsKey('key')) {
        name = uri.queryParameters['name'];
        key = _decodeKey(uri.queryParameters['key']!);
      } else {
        // Path style: meshcore://ch/<name>/<key> or meshcore://channel/<name>/<key>
        // uri.host = 'ch' or 'channel', uri.pathSegments contains [name, key]
        // But Uri may parse meshcore://ch/name/key as host=ch, path=/name/key
        final segments = [uri.host, ...uri.pathSegments]
            .where((s) => s.isNotEmpty)
            .toList();

        // segments[0] = 'ch' or 'channel', segments[1] = name, segments[2..] = key
        // Note: standard base64 keys containing '/' get split by URI into multiple
        // path segments, so we join them back before decoding.
        if (segments.length >= 3 &&
            (segments[0] == 'ch' || segments[0] == 'channel')) {
          name = Uri.decodeComponent(segments[1]);
          // Try the third segment alone first (hex / base64url), then joined
          key = _decodeKey(segments[2]);
          if (key == null && segments.length > 3) {
            key = _decodeKey(segments.sublist(2).join('/'));
          }
        } else if (segments.length >= 2) {
          name = Uri.decodeComponent(segments[segments.length - 2]);
          key = _decodeKey(segments[segments.length - 1]);
        }
      }

      if (name == null || name.isEmpty || key == null || key.length != 16) {
        return null;
      }

      return MeshcoreChannelUri(name: name, key: key);
    } catch (_) {
      return null;
    }
  }

  /// Generate a meshcore:// URI for this channel.
  String toUri() {
    final keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final encodedName = Uri.encodeComponent(name);
    return 'meshcore://channel/$encodedName/$keyHex';
  }

  /// Key as lowercase hex string (32 chars).
  String get keyHex =>
      key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Decode a key from hex (32 chars) or base64 (22–24 chars) into 16 bytes.
  static Uint8List? _decodeKey(String raw) {
    final s = raw.trim();
    // Hex: exactly 32 hex chars
    if (s.length == 32 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) {
      final result = Uint8List(16);
      for (int i = 0; i < 16; i++) {
        result[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return result;
    }
    // Base64 / base64url (standard or URL-safe, with or without padding)
    try {
      String b64 = s.replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if needed
      while (b64.length % 4 != 0) {
        b64 += '=';
      }
      final decoded = base64.decode(b64);
      if (decoded.length == 16) return Uint8List.fromList(decoded);
    } catch (_) {}
    return null;
  }
}
