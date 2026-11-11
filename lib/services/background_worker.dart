import 'package:workmanager/workmanager.dart';
import '../models/queue_models.dart';
import 'queue_engine.dart';

const String kWallpaperRotationTaskUnique = 'pinwall_auto_wallpaper_task';
const String kWallpaperRotationTaskName = 'pinwallAutoWallpaper';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == kWallpaperRotationTaskName) {
        await QueueEngine.instance.runAutoRotationCycle();
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundScheduler {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> syncWithSettings(AppSettings settings) async {
    if (!settings.autoChangeEnabled) {
      await Workmanager().cancelByUniqueName(kWallpaperRotationTaskUnique);
      return;
    }

    final minutes = settings.intervalMinutes < 15 ? 15 : settings.intervalMinutes;
    await Workmanager().registerPeriodicTask(
      kWallpaperRotationTaskUnique,
      kWallpaperRotationTaskName,
      frequency: Duration(minutes: minutes),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }
}

