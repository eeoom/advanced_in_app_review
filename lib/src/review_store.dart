import 'package:shared_preferences/shared_preferences.dart';

abstract class ReviewStore {
  Future<void> initialize();
  Future<int?> readInt(String key);
  Future<void> writeInt(String key, int value);
}

class PreferencesReviewStore implements ReviewStore {
  static const installKey = 'advanced_in_app_review_install_date';
  static const launchesKey = 'advanced_in_app_review_launch_times';
  // Keep the historical spelling for existing installations.
  static const attemptKey = 'advanced_in_app_remind_interval';
  static const eventsKey = 'advanced_in_app_review_significant_events';
  static const _migrationKey = 'advanced_in_app_review_v2_migrated';

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<void> initialize() async {
    if (await _preferences.getBool(_migrationKey) == true) return;
    final legacy = await SharedPreferences.getInstance();
    await legacy.reload();
    // Migrate only this package's data, never other application preferences.
    for (final key in [installKey, launchesKey, attemptKey]) {
      if (await _preferences.getInt(key) == null) {
        final value = legacy.getInt(key);
        if (value != null) await _preferences.setInt(key, value);
      }
    }
    await _preferences.setBool(_migrationKey, true);
  }

  @override
  Future<int?> readInt(String key) => _preferences.getInt(key);

  @override
  Future<void> writeInt(String key, int value) =>
      _preferences.setInt(key, value);
}
