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
    test('empty token → error without making network call', () async {
      bool networkCalled = false;
      final client = MockClient((_) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, '');
      expect(result.error, 'Token is required');
      expect(networkCalled, isFalse);
    });

    test('HTTP 200 → isValid, no error, empty messages', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'valid': true, 'min_version': null, 'messages': []}), 200));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result.isValid, isTrue);
      expect(result.error, isNull);
      expect(result.messages, isEmpty);
    });

    test('HTTP 200 with messages → messages parsed correctly', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'valid': true,
            'min_version': null,
            'messages': [
              {'id': 1, 'title': 'Hello', 'body': 'World'},
              {'id': 2, 'title': null, 'body': 'Second message'},
            ],
          }),
          200));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result.isValid, isTrue);
      expect(result.messages.length, 2);
      expect(result.messages[0].title, 'Hello');
      expect(result.messages[1].title, isNull);
    });

    test('HTTP 200 with min_version → minVersion parsed', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'valid': true, 'min_version': '1.0.99', 'messages': []}), 200));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result.minVersion, '1.0.99');
    });

    test('HTTP 429 → rate limit error', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'valid': false, 'error': 'Too many requests'}), 429));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result.error, contains('Too many'));
    });

    test('HTTP 401 → invalid token error', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'valid': false, 'error': 'Invalid or disabled token'}), 401));
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, isNot('Token is required'));
    });

    test('network exception → isOffline', () async {
      final client = MockClient((_) async {
        throw http.ClientException('Network unreachable');
      });
      final svc = _serviceWith(client);
      final result = await svc.validateToken(_baseUrl, 'ABCD1234');
      expect(result.isOffline, isTrue);
      expect(result.error, contains('reach server'));
    });

    test('constructs correct validate URL', () async {
      Uri? calledUrl;
      final client = MockClient((request) async {
        calledUrl = request.url;
        return http.Response(
            jsonEncode({'valid': true, 'min_version': null, 'messages': []}), 200);
      });
      final svc = _serviceWith(client);
      await svc.validateToken(_baseUrl, 'MYTOKEN1');
      expect(calledUrl?.path, contains('MYTOKEN1'));
      expect(calledUrl?.path, contains('validate'));
    });
  });
}
