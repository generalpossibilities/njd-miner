import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Thin wrapper around `flutter_foreground_task`.
///
/// Scope note: this service exists ONLY to (a) raise the process to foreground
/// priority so Android is less eager to kill the clock while it is docked, and
/// (b) show the required persistent notification. It does **not** run the miner
/// — the miner is a WebView that lives in the main isolate with the clock
/// activity. Chromium freezes WebView JS timers when the activity is not
/// visible, so mining only happens while the clock is actually on screen.
class MiningForegroundService {
  const MiningForegroundService._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'njd_miner_clock',
        channelName: 'NJD Miner clock',
        channelDescription:
            'Keeps the clock alive so NACKL mining can run while docked.',
        onlyAlertOnce: true,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Ask for the runtime permissions the service needs (API 33+ notifications,
  /// and battery-optimisation exemption so a docked clock isn't killed).
  static Future<void> ensurePermissions() async {
    final notif = await FlutterForegroundTask.checkNotificationPermission();
    if (notif != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> start({required String status}) async {
    if (await FlutterForegroundTask.isRunningService) {
      return updateStatus(status: status);
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'NJD Miner',
      notificationText: status,
    );
  }

  static Future<void> updateStatus({required String status}) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'NJD Miner',
      notificationText: status,
    );
  }

  static Future<void> stop() => FlutterForegroundTask.stopService();
}
