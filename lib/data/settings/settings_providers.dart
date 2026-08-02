import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_settings.dart';
import '../../domain/providers.dart';
import '../../domain/settings_repository.dart';
import 'settings_connection_tester.dart';

/// Settings-feature aliases for domain providers.
///
/// Defaults delegate to [settingsRepositoryProvider] /
/// [appSettingsProvider] so Save refreshes Generate/AI. Tests may still
/// override these local providers without touching domain wiring.

final settingsRepositoryLocalProvider = Provider<SettingsRepository>((ref) {
  return ref.watch(settingsRepositoryProvider);
});

final appSettingsLocalProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsRepositoryLocalProvider).get();
});

final settingsConnectionTesterProvider =
    Provider<SettingsConnectionTester>((ref) {
  return SettingsConnectionTester();
});
