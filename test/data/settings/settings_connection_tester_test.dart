import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/settings/settings_connection_tester.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SettingsConnectionTester', () {
    test('fails when API token is missing', () async {
      final tester = SettingsConnectionTester(
        client: MockClient((_) async => http.Response('', 500)),
      );
      final result = await tester.test(
        const AppSettings(provider: AiProviderKind.openai),
      );
      expect(result.success, isFalse);
      expect(result.message, contains('API token'));
    });

    test('OpenAI success on 200', () async {
      final tester = SettingsConnectionTester(
        client: MockClient((request) async {
          expect(request.url.host, 'api.openai.com');
          expect(request.headers['Authorization'], 'Bearer sk-test');
          return http.Response(jsonEncode({'data': []}), 200);
        }),
      );
      final result = await tester.test(
        const AppSettings(
          provider: AiProviderKind.openai,
          apiToken: 'sk-test',
        ),
      );
      expect(result.success, isTrue);
      expect(result.message, contains('OpenAI'));
    });

    test('Anthropic failure surfaces status', () async {
      final tester = SettingsConnectionTester(
        client: MockClient((request) async {
          expect(request.headers['x-api-key'], 'anth-key');
          expect(request.headers['anthropic-version'], isNotNull);
          return http.Response(
            jsonEncode({
              'error': {'message': 'invalid x-api-key'},
            }),
            401,
          );
        }),
      );
      final result = await tester.test(
        const AppSettings(
          provider: AiProviderKind.anthropic,
          apiToken: 'anth-key',
        ),
      );
      expect(result.success, isFalse);
      expect(result.message, contains('401'));
      expect(result.message, contains('invalid x-api-key'));
    });

    test('Gemini pings resolved model endpoint', () async {
      late Uri seen;
      final tester = SettingsConnectionTester(
        client: MockClient((request) async {
          seen = request.url;
          return http.Response('{}', 200);
        }),
      );
      final result = await tester.test(
        const AppSettings(
          provider: AiProviderKind.gemini,
          apiToken: 'gem-key',
        ),
      );
      expect(result.success, isTrue);
      expect(seen.path, contains('gemini-2.0-flash'));
      expect(seen.queryParameters['key'], 'gem-key');
    });
  });
}
