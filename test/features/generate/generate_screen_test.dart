import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/core/errors.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:gopher_jobs/domain/generation_artifacts.dart';
import 'package:gopher_jobs/domain/generation_service.dart';
import 'package:gopher_jobs/domain/providers.dart';
import 'package:gopher_jobs/features/generate/generate_error_banner.dart';
import 'package:gopher_jobs/features/generate/generate_screen.dart';

const _settingsWithToken = AppSettings(
  provider: AiProviderKind.openai,
  apiToken: 'sk-test',
);

const _settingsWithoutToken = AppSettings(
  provider: AiProviderKind.openai,
);

void main() {
  group('parseJobUrl', () {
    test('accepts absolute http(s) URLs', () {
      expect(parseJobUrl('https://example.com/jobs/1')?.host, 'example.com');
      expect(parseJobUrl('http://jobs.example.org/a')?.scheme, 'http');
      expect(
        parseJobUrl('  https://example.com/jobs/1  ')?.path,
        '/jobs/1',
      );
    });

    test('rejects empty, relative, and non-http schemes', () {
      expect(parseJobUrl(''), isNull);
      expect(parseJobUrl('   '), isNull);
      expect(parseJobUrl('example.com/jobs'), isNull);
      expect(parseJobUrl('/jobs/1'), isNull);
      expect(parseJobUrl('ftp://example.com/jobs'), isNull);
      expect(parseJobUrl('mailto:hi@example.com'), isNull);
    });
  });

  group('GenerateScreen validation', () {
    testWidgets('Generate is disabled when fields are empty', (tester) async {
      await tester.pumpWidget(_wrap(const GenerateScreen()));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('generateButton')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Generate is disabled for invalid URL with source filled',
        (tester) async {
      await tester.pumpWidget(_wrap(const GenerateScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'not-a-url',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'My resume experience…',
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('generateButton')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Generate is enabled for valid URL and non-empty source',
        (tester) async {
      await tester.pumpWidget(_wrap(const GenerateScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'https://example.com/jobs/42',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'Senior engineer with Flutter experience.',
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('generateButton')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Generate is disabled and shows banner when token missing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GenerateScreen(),
          settings: _settingsWithoutToken,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('missingTokenBanner')), findsOneWidget);
      expect(
        find.textContaining('Add an API token in Settings'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'https://example.com/jobs/42',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'Senior engineer with Flutter experience.',
      );
      await tester.pump();

      final generateFinder =
          find.byKey(const Key('generateButton'), skipOffstage: false);
      await tester.ensureVisible(generateFinder);
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(generateFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('validators surface required-field messages on submit attempt',
        (tester) async {
      await tester.pumpWidget(_wrap(const GenerateScreen()));
      await tester.pumpAndSettle();

      // Force validation via FormState even though the button is disabled.
      final formState = tester.state<FormState>(find.byType(Form));
      expect(formState.validate(), isFalse);
      await tester.pump();

      expect(find.text('Job URL is required'), findsOneWidget);
      expect(find.text('Source material is required'), findsOneWidget);
    });

    testWidgets('successful generate stores artifacts and last input',
        (tester) async {
      final service = _FakeGenerationService(
        artifacts: const GenerationArtifacts(
          resumeMarkdown: '# Resume',
          coverLetterMarkdown: '# Cover',
        ),
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) async => _settingsWithToken),
            generationServiceProvider.overrideWithValue(service),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(home: GenerateScreen());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'https://example.com/jobs/42',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'Source material body',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('generateButton')));
      await tester.pumpAndSettle();

      expect(service.lastJobUrl, Uri.parse('https://example.com/jobs/42'));
      expect(service.lastSourceMaterial, 'Source material body');
      expect(
        container.read(generationArtifactsProvider)?.resumeMarkdown,
        '# Resume',
      );

      final lastInput = container.read(lastGenerationInputProvider);
      expect(lastInput, isNotNull);
      expect(lastInput!.jobUrl, Uri.parse('https://example.com/jobs/42'));
      expect(lastInput.sourceMaterial, 'Source material body');
      expect(container.read(selectedTabIndexProvider), 1);

      expect(find.text('Generation complete.'), findsOneWidget);
    });

    testWidgets('JobFetchException shows fallback field and error details',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeGenerationService(
        error: JobFetchException(
          'Could not fetch the job posting (network or CORS).',
          cause: Exception('ClientException: CORS blocked'),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) async => _settingsWithToken),
            generationServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: GenerateScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'https://example.com/jobs/42',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'Source material body',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('generateButton')));
      await tester.pumpAndSettle();

      expect(service.lastJobUrl, isNotNull);
      expect(find.byKey(const Key('jobDescriptionFallbackField')), findsOneWidget);
      expect(find.byType(GenerateErrorBanner), findsOneWidget);
      expect(
        find.textContaining('Could not fetch the job posting'),
        findsOneWidget,
      );
    });

    testWidgets('generate with pasted job description passes override',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeGenerationService(
        artifacts: const GenerationArtifacts(
          resumeMarkdown: '# Resume',
          coverLetterMarkdown: '# Cover',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) async => _settingsWithToken),
            generationServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: GenerateScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'https://example.com/jobs/42',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'Source material body',
      );
      await tester.pump();

      // Trigger fetch failure to reveal fallback field.
      service.error = JobFetchException('fetch failed');
      await tester.tap(find.byKey(const Key('generateButton')));
      await tester.pumpAndSettle();

      service.error = null;
      await tester.enterText(
        find.byKey(const Key('jobDescriptionFallbackField')),
        'Pasted job requirements',
      );
      await tester.pump();

      final generateFinder =
          find.byKey(const Key('generateButton'), skipOffstage: false);
      await tester.ensureVisible(generateFinder);
      await tester.tap(generateFinder);
      await tester.pumpAndSettle();

      expect(service.lastJobDescriptionOverride, 'Pasted job requirements');
      expect(find.text('Generation complete.'), findsOneWidget);
    });

    testWidgets('failed generate shows inline error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) async => _settingsWithToken),
            generationServiceProvider.overrideWithValue(
              _FakeGenerationService(
                error: const GenerationException('boom'),
              ),
            ),
          ],
          child: const MaterialApp(home: GenerateScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('jobUrlField')),
        'https://example.com/jobs/42',
      );
      await tester.enterText(
        find.byKey(const Key('sourceMaterialField')),
        'Source material body',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('generateButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('generateError')), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });
}

Widget _wrap(
  Widget child, {
  AppSettings settings = _settingsWithToken,
}) {
  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith((ref) async => settings),
    ],
    child: MaterialApp(home: child),
  );
}

class _FakeGenerationService implements GenerationService {
  _FakeGenerationService({this.artifacts, this.error});

  final GenerationArtifacts? artifacts;
  Object? error;

  Uri? lastJobUrl;
  String? lastSourceMaterial;
  String? lastJobDescriptionOverride;

  @override
  Future<GenerationArtifacts> generate({
    required Uri jobUrl,
    required String sourceMaterial,
    String? jobDescriptionOverride,
  }) async {
    lastJobUrl = jobUrl;
    lastSourceMaterial = sourceMaterial;
    lastJobDescriptionOverride = jobDescriptionOverride;
    if (error != null) throw error!;
    return artifacts ??
        const GenerationArtifacts(
          resumeMarkdown: '',
          coverLetterMarkdown: '',
        );
  }
}
