import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/ai/ats_plain_text.dart';
import 'package:gopher_jobs/domain/generation_artifacts.dart';
import 'package:gopher_jobs/domain/generation_service.dart';
import 'package:gopher_jobs/domain/providers.dart';
import 'package:gopher_jobs/features/results/results_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleArtifacts = GenerationArtifacts(
    resumeMarkdown: '# Sample Resume\n\n- Experience A',
    coverLetterMarkdown: '# Cover Letter\n\nDear Hiring Manager,',
  );

  const regeneratedArtifacts = GenerationArtifacts(
    resumeMarkdown: '# Regenerated Resume',
    coverLetterMarkdown: '# Regenerated Cover',
  );

  const warnedArtifacts = GenerationArtifacts(
    resumeMarkdown: '# Sample Resume\n\n| Col |\n| --- |\n| x |',
    coverLetterMarkdown: '# Cover Letter\n\nDear Hiring Manager,',
    atsWarnings: [
      'Resume contains a markdown table; ATS parsers often skip table cells.',
      'Cover letter length is outside the recommended range.',
    ],
  );

  Widget wrap({
    GenerationArtifacts? artifacts,
    LastGenerationInput? lastInput,
    GenerationService? generationService,
  }) {
    return ProviderScope(
      overrides: [
        generationArtifactsProvider.overrideWith((ref) => artifacts),
        lastGenerationInputProvider.overrideWith((ref) => lastInput),
        if (generationService != null)
          generationServiceProvider.overrideWithValue(generationService),
      ],
      child: const MaterialApp(home: ResultsScreen()),
    );
  }

  group('ResultsScreen empty state', () {
    testWidgets('shows empty messaging when artifacts are null',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Results'), findsOneWidget);
      expect(find.byKey(const Key('resultsEmptyTitle')), findsOneWidget);
      expect(find.byKey(const Key('resultsEmptyBody')), findsOneWidget);
      expect(find.text('No results yet'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Cover Letter'), findsNothing);
      expect(find.byKey(const Key('copyButton')), findsNothing);
      expect(find.byKey(const Key('atsChecksPanel')), findsNothing);
    });
  });

  group('ResultsScreen with artifacts', () {
    testWidgets('shows tabs, documents, and actions', (tester) async {
      await tester.pumpWidget(wrap(artifacts: sampleArtifacts));
      await tester.pumpAndSettle();

      expect(find.text('Resume'), findsWidgets);
      expect(find.text('Cover Letter'), findsWidgets);
      expect(find.byKey(const Key('copyButton')), findsOneWidget);
      expect(find.byKey(const Key('downloadMdButton')), findsOneWidget);
      expect(find.byKey(const Key('downloadTxtButton')), findsOneWidget);
      expect(find.text('Download ATS .txt'), findsOneWidget);
      expect(find.text('Download .md'), findsOneWidget);
      expect(find.byKey(const Key('regenerateButton')), findsOneWidget);
      expect(find.byKey(const Key('regenerateHint')), findsOneWidget);

      expect(find.textContaining('Sample Resume'), findsOneWidget);
      expect(find.textContaining('Experience A'), findsOneWidget);

      final regenerate = tester.widget<FilledButton>(
        find.byKey(const Key('regenerateButton')),
      );
      expect(regenerate.onPressed, isNull);
    });

    testWidgets('ATS checks panel shows passed when warnings empty',
        (tester) async {
      await tester.pumpWidget(wrap(artifacts: sampleArtifacts));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('atsChecksPanel')), findsOneWidget);
      expect(find.text('ATS checks'), findsOneWidget);
      expect(find.byKey(const Key('atsChecksPassed')), findsOneWidget);
      expect(
        find.text('Passed basic ATS structure checks'),
        findsOneWidget,
      );
    });

    testWidgets('ATS checks panel lists each warning', (tester) async {
      await tester.pumpWidget(wrap(artifacts: warnedArtifacts));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('atsChecksPanel')), findsOneWidget);
      expect(find.byKey(const Key('atsChecksPassed')), findsNothing);
      for (final warning in warnedArtifacts.atsWarnings) {
        expect(find.byKey(Key('atsWarning:$warning')), findsOneWidget);
        expect(find.textContaining(warning), findsOneWidget);
      }
    });

    testWidgets('Cover Letter tab shows cover letter content', (tester) async {
      await tester.pumpWidget(wrap(artifacts: sampleArtifacts));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cover Letter').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Dear Hiring Manager'), findsOneWidget);
      expect(find.textContaining('Cover Letter'), findsWidgets);
    });

    testWidgets('Copy puts active document on the clipboard', (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(wrap(artifacts: sampleArtifacts));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('copyButton')));
      await tester.pump();

      expect(clipboardText, sampleArtifacts.resumeMarkdown);
      expect(find.byKey(const Key('resultsActionMessage')), findsOneWidget);
      expect(find.textContaining('copied to clipboard'), findsOneWidget);
    });

    testWidgets('Regenerate uses last inputs when available', (tester) async {
      final service = _FakeGenerationService(artifacts: regeneratedArtifacts);
      final lastInput = LastGenerationInput(
        jobUrl: Uri.parse('https://example.com/jobs/1'),
        sourceMaterial: 'prior source',
      );

      await tester.pumpWidget(
        wrap(
          artifacts: sampleArtifacts,
          lastInput: lastInput,
          generationService: service,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('regenerateHint')), findsNothing);

      await tester.tap(find.byKey(const Key('regenerateButton')));
      await tester.pumpAndSettle();

      expect(service.lastJobUrl, lastInput.jobUrl);
      expect(service.lastSourceMaterial, lastInput.sourceMaterial);
      expect(find.textContaining('Regenerated Resume'), findsOneWidget);
      expect(find.textContaining('Regenerated successfully'), findsOneWidget);
    });
  });

  group('resultsExportText', () {
    test('keeps raw Markdown for .md', () {
      const markdown = '# Title\n\n**Bold** and - item';
      expect(
        resultsExportText(markdown, extension: 'md'),
        markdown,
      );
    });

    test('emits AtsPlainText.toPlain for .txt', () {
      const markdown = '# Sample Resume\n\n- Experience A';
      expect(
        resultsExportText(markdown, extension: 'txt'),
        AtsPlainText.toPlain(markdown),
      );
      expect(
        resultsExportText(markdown, extension: 'txt'),
        isNot(contains('#')),
      );
      expect(
        resultsExportText(markdown, extension: 'txt'),
        contains('Sample Resume'),
      );
      expect(
        resultsExportText(markdown, extension: 'txt'),
        contains('- Experience A'),
      );
    });
  });
}

class _FakeGenerationService implements GenerationService {
  _FakeGenerationService({this.artifacts});

  final GenerationArtifacts? artifacts;

  Uri? lastJobUrl;
  String? lastSourceMaterial;

  @override
  Future<GenerationArtifacts> generate({
    required Uri jobUrl,
    required String sourceMaterial,
    String? jobDescriptionOverride,
  }) async {
    lastJobUrl = jobUrl;
    lastSourceMaterial = sourceMaterial;
    return artifacts ??
        const GenerationArtifacts(
          resumeMarkdown: '',
          coverLetterMarkdown: '',
        );
  }
}
