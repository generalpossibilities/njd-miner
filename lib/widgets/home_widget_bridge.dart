import 'package:home_widget/home_widget.dart';

import '../mining/bee_miner.dart';

/// Pushes clock + mining data to the Android home-screen AppWidget.
///
/// The AppWidget itself (a `RemoteViews` layout) cannot run Dart or a WASM
/// miner — it just displays the last values written here. Tapping it opens the
/// full-screen clock, which is where mining actually happens.
class HomeWidgetBridge {
  const HomeWidgetBridge._();

  static const String _androidWidgetName = 'ClockWidgetProvider';
  static const String _qualifiedName = 'com.njd.njd_miner.ClockWidgetProvider';

  static Future<void> update(MinerState state) async {
    await HomeWidget.saveWidgetData<String>(
      'nackl_balance',
      state.nacklBalance ?? '—',
    );
    await HomeWidget.saveWidgetData<String>('mining_status', switch (state
        .phase) {
      MinerPhase.mining => 'mining',
      MinerPhase.idle => 'idle',
      MinerPhase.crashed => 'error',
      MinerPhase.needsWallet => 'connect wallet',
      _ => 'setup',
    });
    await HomeWidget.saveWidgetData<int>(
      'updated_at',
      DateTime.now().millisecondsSinceEpoch,
    );
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      qualifiedAndroidName: _qualifiedName,
    );
  }
}
