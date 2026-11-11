import 'package:shared_preferences/shared_preferences.dart';
import '../models/queue_models.dart';

class SettingsService {
  static const _kAutoChange = 'auto_change_enabled';
  static const _kIntervalMinutes = 'interval_minutes';
  static const _kQueueMode = 'queue_mode';
  static const _kAutoDownload = 'auto_download_enabled';
  static const _kQueueMaxSize = 'queue_max_size';
  static const _kAutoDelete = 'auto_delete_applied';
  static const _kLastRunAt = 'last_run_at';
  static const _kLastStatus = 'last_status_message';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIdx = prefs.getInt(_kQueueMode) ?? 0;
    final safeIdx = (modeIdx >= 0 && modeIdx < QueueMode.values.length)
        ? modeIdx
        : 0;
    return AppSettings(
      autoChangeEnabled: prefs.getBool(_kAutoChange) ?? false,
      intervalMinutes: prefs.getInt(_kIntervalMinutes) ?? 60,
      queueMode: QueueMode.values[safeIdx],
      autoDownloadEnabled: prefs.getBool(_kAutoDownload) ?? true,
      queueMaxSize: prefs.getInt(_kQueueMaxSize) ?? 20,
      autoDeleteApplied: prefs.getBool(_kAutoDelete) ?? true,
      lastRunAt: prefs.getInt(_kLastRunAt),
      lastStatusMessage: prefs.getString(_kLastStatus),
    );
  }

  static Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoChange, s.autoChangeEnabled);
    await prefs.setInt(_kIntervalMinutes, s.intervalMinutes);
    await prefs.setInt(_kQueueMode, s.queueMode.index);
    await prefs.setBool(_kAutoDownload, s.autoDownloadEnabled);
    await prefs.setInt(_kQueueMaxSize, s.queueMaxSize);
    await prefs.setBool(_kAutoDelete, s.autoDeleteApplied);
    if (s.lastRunAt != null) {
      await prefs.setInt(_kLastRunAt, s.lastRunAt!);
    }
    if (s.lastStatusMessage != null) {
      await prefs.setString(_kLastStatus, s.lastStatusMessage!);
    }
  }

  static Future<void> updateLastRun(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastRunAt, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_kLastStatus, message);
  }
}

