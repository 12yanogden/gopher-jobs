import 'app_settings.dart';

/// Persistence for [AppSettings]. Implemented in Wave 1 (Settings agent).
abstract class SettingsRepository {
  Future<AppSettings> get();
  Future<void> save(AppSettings settings);
}
