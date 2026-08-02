import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../data/ai/ats_plain_text.dart';
import '../../domain/generation_artifacts.dart';
import '../../domain/providers.dart';

/// Builds file contents for Results downloads.
///
/// `.md` keeps raw Markdown; `.txt` runs [AtsPlainText.toPlain] for ATS paste.
@visibleForTesting
String resultsExportText(String markdown, {required String extension}) {
  if (extension == 'txt') {
    return AtsPlainText.toPlain(markdown);
  }
  return markdown;
}

/// Results tab: view, copy, and export generated resume / cover letter.
///
/// **Export:** [FilePicker.platform.saveFile] with UTF-8 [bytes]. Works on web
/// and desktop (save/download dialog). Mobile support varies by platform —
/// Copy always works as a fallback.
///
/// **Regenerate:** enabled when [lastGenerationInputProvider] has values;
/// otherwise disabled with helper text (re-run Generate).
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _isRegenerating = false;
  String? _actionMessage;
  bool _actionIsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _activeDocumentLabel =>
      _tabController.index == 0 ? 'Resume' : 'Cover letter';

  String _activeMarkdown(GenerationArtifacts artifacts) {
    return _tabController.index == 0
        ? artifacts.resumeMarkdown
        : artifacts.coverLetterMarkdown;
  }

  String _baseFileName() =>
      _tabController.index == 0 ? 'resume' : 'cover-letter';

  Future<void> _copyActive(GenerationArtifacts artifacts) async {
    final text = _activeMarkdown(artifacts);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() {
      _actionMessage = '$_activeDocumentLabel copied to clipboard';
      _actionIsError = false;
    });
  }

  Future<void> _downloadActive(
    GenerationArtifacts artifacts, {
    required String extension,
  }) async {
    final text = resultsExportText(
      _activeMarkdown(artifacts),
      extension: extension,
    );
    final fileName = '${_baseFileName()}.$extension';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $fileName',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: utf8.encode(text),
      );
      if (!mounted) return;
      if (path == null) {
        setState(() {
          _actionMessage = 'Save cancelled';
          _actionIsError = false;
        });
        return;
      }
      setState(() {
        _actionMessage = 'Saved $fileName';
        _actionIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionMessage =
            'Could not save file on this platform. Use Copy instead.';
        _actionIsError = true;
      });
    }
  }

  Future<void> _onRegenerate(LastGenerationInput input) async {
    setState(() {
      _isRegenerating = true;
      _actionMessage = null;
    });

    try {
      final artifacts = await ref.read(generationServiceProvider).generate(
            jobUrl: input.jobUrl,
            sourceMaterial: input.sourceMaterial,
          );
      if (!mounted) return;
      ref.read(generationArtifactsProvider.notifier).state = artifacts;
      setState(() {
        _actionMessage = 'Regenerated successfully';
        _actionIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionMessage = _messageForError(error);
        _actionIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  static String _messageForError(Object error) {
    if (error is AppException) return error.message;
    return 'Regeneration failed. Check Settings and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final artifacts = ref.watch(generationArtifactsProvider);
    final lastInput = ref.watch(lastGenerationInputProvider);
    final theme = Theme.of(context);
    final canRegenerate = lastInput != null && !_isRegenerating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        bottom: artifacts == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Resume'),
                  Tab(text: 'Cover Letter'),
                ],
              ),
      ),
      body: artifacts == null
          ? _EmptyResults(theme: theme)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Copy $_activeDocumentLabel to clipboard',
                            child: OutlinedButton.icon(
                              key: const Key('copyButton'),
                              onPressed: _isRegenerating
                                  ? null
                                  : () => _copyActive(artifacts),
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copy'),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Download $_activeDocumentLabel as Markdown',
                            child: OutlinedButton.icon(
                              key: const Key('downloadMdButton'),
                              onPressed: _isRegenerating
                                  ? null
                                  : () => _downloadActive(
                                        artifacts,
                                        extension: 'md',
                                      ),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download .md'),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label:
                                'Download $_activeDocumentLabel as ATS plain text',
                            child: OutlinedButton.icon(
                              key: const Key('downloadTxtButton'),
                              onPressed: _isRegenerating
                                  ? null
                                  : () => _downloadActive(
                                        artifacts,
                                        extension: 'txt',
                                      ),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download ATS .txt'),
                            ),
                          ),
                          Tooltip(
                            message: lastInput == null
                                ? 'Regenerate needs last job URL and source '
                                    'material. Use Generate again.'
                                : 'Re-run generation with the last inputs',
                            child: Semantics(
                              button: true,
                              label: 'Regenerate documents',
                              enabled: canRegenerate,
                              child: FilledButton.tonalIcon(
                                key: const Key('regenerateButton'),
                                onPressed: canRegenerate
                                    ? () => _onRegenerate(lastInput)
                                    : null,
                                icon: _isRegenerating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: const Text('Regenerate'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (lastInput == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Regenerate is unavailable until last generation '
                          'inputs are provided. Re-run Generate to create new '
                          'documents.',
                          key: const Key('regenerateHint'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _AtsChecksPanel(warnings: artifacts.atsWarnings),
                    ),
                    if (_actionMessage != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          color: _actionIsError
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _actionMessage!,
                              key: const Key('resultsActionMessage'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _actionIsError
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _DocumentPane(
                            key: const Key('resumePane'),
                            markdown: artifacts.resumeMarkdown,
                            semanticsLabel: 'Resume markdown',
                          ),
                          _DocumentPane(
                            key: const Key('coverLetterPane'),
                            markdown: artifacts.coverLetterMarkdown,
                            semanticsLabel: 'Cover letter markdown',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AtsChecksPanel extends StatelessWidget {
  const _AtsChecksPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = warnings.isEmpty;
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: 'ATS checks',
      child: Material(
        key: const Key('atsChecksPanel'),
        color: passed
            ? scheme.surfaceContainerHighest
            : scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    passed ? Icons.check_circle_outline : Icons.warning_amber,
                    size: 18,
                    color: passed
                        ? scheme.primary
                        : scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ATS checks',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (passed)
                Text(
                  'Passed basic ATS structure checks',
                  key: const Key('atsChecksPassed'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                ...warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $warning',
                      key: Key('atsWarning:$warning'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No results yet',
                key: const Key('resultsEmptyTitle'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a resume and cover letter from the Generate tab, '
                'then return here to view, copy, or download them.',
                key: const Key('resultsEmptyBody'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPane extends StatelessWidget {
  const _DocumentPane({
    super.key,
    required this.markdown,
    required this.semanticsLabel,
  });

  final String markdown;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SelectableText(
          markdown.isEmpty ? '(empty)' : markdown,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
