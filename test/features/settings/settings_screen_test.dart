import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/settings/settings_connection_tester.dart';
import 'package:gopher_jobs/data/settings/settings_providers.dart';
import 'package:gopher_jobs/data/settings/settings_repository_impl.dart';
import 'package:gopher_jobs/data/settings/token_storage.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:gopher_jobs/domain/providers.dart';
import 'package:gopher_jobs/features/settings/settings_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validateFetchProxyUrl', () {
    test('allows empty', () {
      expect(validateFetchProxyUrl(null), isNull);
      expect(validateFetchProxyUrl(''), isNull);
      expect(validateFetchProxyUrl('  '), isNull);
    });

    test('requires http(s)', () {
      expect(validateFetchProxyUrl('https://proxy.example.com'), isNull);
      expect(validateFetchProxyUrl('http://localhost:8080'), isNull);
      expect(validateFetchProxyUrl('ftp://bad'), isNotNull);
      expect(validateFetchProxyUrl('not-a-url'), isNotNull);
    });
  });

  group('SettingsScreen', () {
    late InMemoryTokenStorage tokenStorage;
    late SettingsRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = InMemoryTokenStorage();
      final prefs = await SharedPreferences.getInstance();
      repository = SettingsRepositoryImpl(
        sharedPreferences: prefs,
        tokenStorage: tokenStorage,
      );
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      SettingsConnectionTester? connectionTester,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Keep domain + local on the same in-memory repo so Save's
            // appSettingsProvider invalidate stays off FlutterSecureStorage.
            settingsRepositoryProvider.overrideWithValue(repository),
            settingsRepositoryLocalProvider.overrideWithValue(repository),
            if (connectionTester != null)
              settingsConnectionTesterProvider
                  .overrideWithValue(connectionTester),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders provider, token, model, proxy, and actions',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byKey(const Key('privacyNote')), findsOneWidget);
      expect(find.textContaining('AI provider you select'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('API token'), findsOneWidget);
      expect(find.textContaining('Model override'), findsOneWidget);
      expect(find.textContaining('Job fetch proxy URL'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
    });

    testWidgets('saves settings via repository', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'API token'),
        'sk-live',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Model override (optional)'),
        'gpt-4o-mini',
      );
      final save = find.text('Save', skipOffstage: false);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('Settings saved', skipOffstage: false),
        findsOneWidget,
      );

      final loaded = await repository.get();
      expect(loaded.apiToken, 'sk-live');
      expect(loaded.modelOverride, 'gpt-4o-mini');
      expect(loaded.provider, AiProviderKind.openai);
    });

    testWidgets('test connection without token shows error', (tester) async {
      await pumpScreen(tester);

      final testConnection = find.text('Test connection', skipOffstage: false);
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'API token is required to test the connection',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('test connection shows success from tester', (tester) async {
      final testerClient = SettingsConnectionTester(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await repository.save(
        const AppSettings(
          provider: AiProviderKind.openai,
          apiToken: 'sk-ok',
        ),
      );

      await pumpScreen(tester, connectionTester: testerClient);

      final testConnection = find.text('Test connection', skipOffstage: false);
      await tester.ensureVisible(testConnection);
      await tester.tap(testConnection);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('successful', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('rejects invalid proxy URL on save', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Job fetch proxy URL (optional)'),
        'not-a-url',
      );
      final save = find.text('Save', skipOffstage: false);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid http(s) URL'), findsOneWidget);
      expect(find.text('Settings saved'), findsNothing);
    });
  });
}
