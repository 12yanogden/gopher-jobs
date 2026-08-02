import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings/default_models.dart';
import '../../data/settings/settings_providers.dart';
import '../../domain/ai_provider_kind.dart';
import '../../domain/app_settings.dart';
import '../../domain/providers.dart';

/// Settings tab: AI provider, API token, optional overrides, save & test.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _modelController = TextEditingController();
  final _proxyController = TextEditingController();

  AiProviderKind _provider = AiProviderKind.openai;
  bool _obscureToken = true;
  bool _hydrated = false;
  bool _saving = false;
  bool _testing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _modelController.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  void _hydrateFrom(AppSettings settings) {
    if (_hydrated) return;
    _hydrated = true;
    _provider = settings.provider;
    _tokenController.text = settings.apiToken ?? '';
    _modelController.text = settings.modelOverride ?? '';
    _proxyController.text = settings.fetchProxyUrl ?? '';
  }

  AppSettings _draftSettings() {
    return AppSettings(
      provider: _provider,
      apiToken: _emptyToNull(_tokenController.text),
      modelOverride: _emptyToNull(_modelController.text),
      fetchProxyUrl: _emptyToNull(_proxyController.text),
    );
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      final repo = ref.read(settingsRepositoryLocalProvider);
      await repo.save(_draftSettings());
      // Refresh Settings UI and domain consumers (Generate / AI clients).
      ref.invalidate(appSettingsLocalProvider);
      ref.invalidate(appSettingsProvider);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Settings saved';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to save settings. Please try again.';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onTestConnection() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _statusMessage = 'API token is required to test the connection';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = null;
    });

    try {
      final tester = ref.read(settingsConnectionTesterProvider);
      final result = await tester.test(_draftSettings());
      if (!mounted) return;
      setState(() {
        _statusMessage = result.message;
        _statusIsError = !result.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Test failed: $e';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsLocalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load settings: $error'),
          ),
        ),
        data: (settings) {
          _hydrateFrom(settings);
          return _SettingsForm(
            formKey: _formKey,
            provider: _provider,
            onProviderChanged: (value) {
              if (value == null) return;
              setState(() => _provider = value);
            },
            tokenController: _tokenController,
            modelController: _modelController,
            proxyController: _proxyController,
            obscureToken: _obscureToken,
            onToggleObscure: () {
              setState(() => _obscureToken = !_obscureToken);
            },
            saving: _saving,
            testing: _testing,
            statusMessage: _statusMessage,
            statusIsError: _statusIsError,
            onSave: _onSave,
            onTestConnection: _onTestConnection,
          );
        },
      ),
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.formKey,
    required this.provider,
    required this.onProviderChanged,
    required this.tokenController,
    required this.modelController,
    required this.proxyController,
    required this.obscureToken,
    required this.onToggleObscure,
    required this.saving,
    required this.testing,
    required this.statusMessage,
    required this.statusIsError,
    required this.onSave,
    required this.onTestConnection,
  });

  final GlobalKey<FormState> formKey;
  final AiProviderKind provider;
  final ValueChanged<AiProviderKind?> onProviderChanged;
  final TextEditingController tokenController;
  final TextEditingController modelController;
  final TextEditingController proxyController;
  final bool obscureToken;
  final VoidCallback onToggleObscure;
  final bool saving;
  final bool testing;
  final String? statusMessage;
  final bool statusIsError;
  final VoidCallback onSave;
  final VoidCallback onTestConnection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = saving || testing;
    final defaultModel = DefaultModels.forProvider(provider);

    return Form(
      key: formKey,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Privacy',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Your API token and job/source content are sent to the '
                'AI provider you select. If you configure a fetch proxy, '
                'job URLs are requested through that proxy as well. '
                'Nothing is stored on a Gopher Jobs server.',
                key: const Key('privacyNote'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI provider',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AiProviderKind>(
                key: ValueKey(provider),
                initialValue: provider,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Provider',
                ),
                items: const [
                  DropdownMenuItem(
                    value: AiProviderKind.openai,
                    child: Text('OpenAI'),
                  ),
                  DropdownMenuItem(
                    value: AiProviderKind.anthropic,
                    child: Text('Anthropic'),
                  ),
                  DropdownMenuItem(
                    value: AiProviderKind.gemini,
                    child: Text('Gemini'),
                  ),
                ],
                onChanged: busy ? null : onProviderChanged,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: tokenController,
                obscureText: obscureToken,
                enabled: !busy,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'API token',
                  hintText: 'Required for generation',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: onToggleObscure,
                    tooltip: obscureToken ? 'Show token' : 'Hide token',
                  ),
                ),
                validator: (_) => null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: modelController,
                enabled: !busy,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Model override (optional)',
                  hintText: 'Default: $defaultModel',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: proxyController,
                enabled: !busy,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Job fetch proxy URL (optional)',
                  hintText: 'https://example.com/proxy',
                  helperText:
                      'Used when the browser blocks direct job fetches (CORS).',
                ),
                validator: validateFetchProxyUrl,
              ),
              const SizedBox(height: 24),
              if (statusMessage != null) ...[
                Text(
                  statusMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusIsError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140),
                    child: FilledButton(
                      onPressed: busy ? null : onSave,
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140),
                    child: OutlinedButton(
                      onPressed: busy ? null : onTestConnection,
                      child: testing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test connection'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared proxy URL validation used by the settings form.
@visibleForTesting
String? validateFetchProxyUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return 'Enter a valid http(s) URL';
  }
  return null;
}