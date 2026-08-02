import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/app.dart';
import 'package:gopher_jobs/data/settings/settings_providers.dart';
import 'package:gopher_jobs/data/settings/settings_repository_impl.dart';
import 'package:gopher_jobs/data/settings/token_storage.dart';
import 'package:gopher_jobs/domain/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell shows Generate tab by default', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SettingsRepositoryImpl(
      sharedPreferences: prefs,
      tokenStorage: InMemoryTokenStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          settingsRepositoryLocalProvider.overrideWithValue(repository),
        ],
        child: const GopherJobsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Generate'), findsWidgets);
    expect(
      find.textContaining('Paste a job posting URL'),
      findsOneWidget,
    );

    await tester.tap(find.text('Results').last);
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsWidgets);
    expect(
      find.textContaining('Generate a resume and cover letter'),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Save', skipOffstage: false), findsOneWidget);
  });
}
