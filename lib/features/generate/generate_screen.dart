import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/job_fetch_hints.dart';
import '../../domain/app_settings.dart';
import '../../domain/providers.dart';
import 'generate_error_banner.dart';
import 'web_fetch_proxy_banner.dart';

/// Generate tab: job URL + source material form that invokes [GenerationService].
class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobUrlController = TextEditingController();
  final _sourceController = TextEditingController();
  final _jobDescriptionController = TextEditingController();

  var _isGenerating = false;
  Object? _lastError;
  var _showJobDescriptionFallback = false;

  @override
  void initState() {
    super.initState();
    _jobUrlController.addListener(_onFieldsChanged);
    _sourceController.addListener(_onFieldsChanged);
    _jobDescriptionController.addListener(_onFieldsChanged);
  }

  @override
  void dispose() {
    _jobUrlController.removeListener(_onFieldsChanged);
    _sourceController.removeListener(_onFieldsChanged);
    _jobDescriptionController.removeListener(_onFieldsChanged);
    _jobUrlController.dispose();
    _sourceController.dispose();
    _jobDescriptionController.dispose();
    super.dispose();
  }

  void _onFieldsChanged() => setState(() {});

  bool _hasApiToken(AppSettings? settings) {
    final token = settings?.apiToken?.trim();
    return token != null && token.isNotEmpty;
  }

  String? _jobDescriptionOverride() {
    if (!_showJobDescriptionFallback) return null;
    final text = _jobDescriptionController.text.trim();
    return text.isEmpty ? null : text;
  }

  /// True when fields pass client-side checks and an API token is available.
  bool _canSubmit(AppSettings? settings) {
    if (_isGenerating) return false;
    if (!_hasApiToken(settings)) return false;
    final url = parseJobUrl(_jobUrlController.text);
    final source = _sourceController.text.trim();
    return url != null && source.isNotEmpty;
  }

  Future<void> _pickSourceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      setState(() {
        _lastError = GenerationException(
          'Could not read "${file.name}". Try another file.',
        );
      });
      return;
    }

    final text = utf8.decode(bytes);
    setState(() {
      _sourceController.text = text;
      _lastError = null;
    });
  }

  Future<void> _onGenerate() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final jobUrl = parseJobUrl(_jobUrlController.text);
    final source = _sourceController.text.trim();
    if (jobUrl == null || source.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _lastError = null;
    });

    try {
      final artifacts = await ref.read(generationServiceProvider).generate(
            jobUrl: jobUrl,
            sourceMaterial: source,
            jobDescriptionOverride: _jobDescriptionOverride(),
          );
      if (!mounted) return;
      ref.read(generationArtifactsProvider.notifier).state = artifacts;
      ref.read(lastGenerationInputProvider.notifier).state = LastGenerationInput(
        jobUrl: jobUrl,
        sourceMaterial: source,
        jobDescriptionOverride: _jobDescriptionOverride(),
      );
      ref.read(selectedTabIndexProvider.notifier).state = 1;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generation complete.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = error;
        if (error is JobFetchException) {
          _showJobDescriptionFallback = true;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget? _settingsBanner(
    BuildContext context,
    AsyncValue<AppSettings> settingsAsync,
  ) {
    final theme = Theme.of(context);
    return settingsAsync.when(
      loading: () => Material(
        key: const Key('settingsLoadingBanner'),
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Loading settings…',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) => Material(
        key: const Key('settingsErrorBanner'),
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Could not load settings. Open the Settings tab and try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      data: (settings) {
        if (_hasApiToken(settings)) return null;
        return Material(
          key: const Key('missingTokenBanner'),
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.key_off_outlined,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add an API token in Settings before generating.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(appSettingsProvider);
    final settings = settingsAsync.asData?.value;
    final canSubmit = _canSubmit(settings);
    final settingsBanner = _settingsBanner(context, settingsAsync);
    final showWebProxyBanner = settings != null &&
        shouldWarnMissingFetchProxy(fetchProxyUrl: settings.fetchProxyUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Generate')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Paste a job posting URL and your source material to generate '
                    'an ATS-optimized resume and cover letter.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (settingsBanner != null) ...[
                    const SizedBox(height: 16),
                    settingsBanner,
                  ],
                  if (showWebProxyBanner) ...[
                    const SizedBox(height: 16),
                    const WebFetchProxyBanner(),
                  ],
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Job posting URL',
                    textField: true,
                    child: TextFormField(
                      key: const Key('jobUrlField'),
                      controller: _jobUrlController,
                      enabled: !_isGenerating,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Job URL',
                        hintText: 'https://example.com/jobs/123',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Job URL is required';
                        }
                        if (parseJobUrl(value) == null) {
                          return 'Enter a valid http(s) URL';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_showJobDescriptionFallback) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Job description pasted as fallback',
                      textField: true,
                      child: TextFormField(
                        key: const Key('jobDescriptionFallbackField'),
                        controller: _jobDescriptionController,
                        enabled: !_isGenerating,
                        minLines: 6,
                        maxLines: 12,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          labelText: 'Job description (paste fallback)',
                          hintText:
                              'Paste the job posting text here to skip fetching…',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          helperText:
                              'Optional: paste the job text to skip fetching. Leave empty to retry the URL.',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    label: 'Source material for resume and cover letter',
                    textField: true,
                    child: TextFormField(
                      key: const Key('sourceMaterialField'),
                      controller: _sourceController,
                      enabled: !_isGenerating,
                      minLines: 8,
                      maxLines: 16,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: 'Source material',
                        hintText:
                            'Paste your resume, notes, or experience highlights…',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Source material is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('loadFileButton'),
                      onPressed: _isGenerating ? null : _pickSourceFile,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Load .txt / .md file'),
                    ),
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 12),
                    GenerateErrorBanner(error: _lastError!),
                  ],
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: 'Generate resume and cover letter',
                    enabled: canSubmit,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('generateButton'),
                        onPressed: canSubmit ? _onGenerate : null,
                        child: _isGenerating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Generate'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Parses a job posting URL. Accepts only absolute http(s) URIs with a host.
Uri? parseJobUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}
