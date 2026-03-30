import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshcore_wardrive/services/upload_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _baseUrl = 'https://wardrive.inwmesh.org/api/samples/';

UploadService _serviceWith(MockClient client) =>
    UploadService(httpClient: client);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('UploadService.validateToken', () {
    test('empty token → "Token is required" without making network call', () async {
      bool networkCalled = false;
      final client = MockClient((_) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, '');
      expect(result, 'Token is required');
      expect(networkCalled, isFalse);
    });

    test('HTTP 200 → null (success)', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'valid': true}), 200));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result, isNull);
    });

    test('HTTP 429 → rate limit message', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'valid': false, 'error': 'Too many requests'}), 429));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result, contains('Too many'));
    });

    test('HTTP 401 → invalid token message', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'valid': false, 'error': 'Invalid or disabled token'}), 401));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result, isNotNull);
      expect(result, isNot('Token is required'));
    });

    test('network exception → "Could not reach server"', () async {
      final client = MockClient((_) async {
        throw http.ClientException('Network unreachable');
      });
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result, contains('reach server'));
    });

    test('constructs correct validate URL', () async {
      Uri? calledUrl;
      final client = MockClient((request) async {
        calledUrl = request.url;
        return http.Response(jsonEncode({'valid': true}), 200);
      });
      final svc = _serviceWith(client);
      await svc.validateToken(_baseUrl, 'MYTOKEN1');
      expect(calledUrl?.path, contains('MYTOKEN1'));
      expect(calledUrl?.path, contains('validate'));
    });
  });
}
