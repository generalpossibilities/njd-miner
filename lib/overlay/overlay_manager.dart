import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mining/bee_miner.dart';
import 'app_control.dart';
import 'overlay_link.dart';

/// Opening size for the floating clock, in dp.
///
/// The plugin takes dp and converts to px itself. The old default was a flat
/// 620dp wide — wider than most phones, so the window opened larger than the
/// screen. These are computed against the real display instead, and the clock
/// steps down from here via the button on it.
class OverlayStartSize {
  OverlayStartSize._();

  static Size _screenDp() {
    final d = WidgetsBinding.instance.platformDispatcher.views.first.display;
    return d.size / d.devicePixelRatio;
  }

  static int get width {
    final s = _screenDp();
    return (s.width * 0.95).clamp(96.0, s.width - 8).round();
  }

  static int get height {
    final s = _screenDp();
    return (s.height * 0.26).clamp(44.0, s.height - 8).round();
  }
}

/// Main-app side of the floating clock. Owns the show/hide toggle and keeps the
/// single-miner rule: while the overlay is up **and** its own WebView works,
/// the overlay mines and the main app's miner stands down. If the overlay is
/// display-only, the main app keeps mining and receives forwarded taps.
class OverlayManager extends ChangeNotifier {
  OverlayManager(this._miner);

  final BeeMiner _miner;
  StreamSubscription? _link;

  bool _active = false;
  bool _overlayIsMining = false;

  bool get active => _active;

  /// Persisted "the user turned it off" flag. The floating clock is on by
  /// default, so absence of this key means show it — only an explicit toggle
  /// off is remembered. Without persistence, turning it off would silently undo
  /// itself on the next launch.
  static const String _prefDisabled = 'floating_clock_disabled';

  /// Show the clock on startup unless the user has turned it off before.
  ///
  /// Permission is only *requested* when the user has not already refused the
  /// clock — otherwise every cold start would throw a system dialog at someone
  /// who has said no.
  Future<void> restoreOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefDisabled) ?? false) return;
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      if (!await ensurePermission()) return;
    }
    await show();
  }

  Future<void> _rememberEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDisabled, !enabled);
  }

  /// True when the overlay has taken over mining (main app should show its
  /// shared state rather than its own miner state).
  bool get overlayOwnsMining => _active && _overlayIsMining;

  int overlayTaps = 0;
  String? overlayBalance;

  Future<bool> ensurePermission() async {
    if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    return (await FlutterOverlayWindow.requestPermission()) ?? false;
  }

  Future<void> toggle() async {
    final turningOn = !_active;
    await _rememberEnabled(turningOn);
    await (turningOn ? show() : hide());
  }

  Future<void> show() async {
    if (!await ensurePermission()) return;
    _link ??= FlutterOverlayWindow.overlayListener.listen(_onOverlayMessage);
    await FlutterOverlayWindow.showOverlay(
      height: OverlayStartSize.height,
      width: OverlayStartSize.width,
      alignment: OverlayAlignment.topCenter,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      // `auto` snaps the window to the nearest edge, which parked it off the top
      // of the screen behind the status bar where it could not be seen or
      // grabbed. `none` leaves it where it is put, and startPosition drops it
      // clear of the status bar.
      positionGravity: PositionGravity.none,
      startPosition: const OverlayPosition(0, 140),
      overlayTitle: 'NJD Miner',
      overlayContent: 'Floating clock',
    );
    _active = true;
    // The overlay engine only exists once showOverlay has run, so the app-control
    // channel can only be registered on it now. Without this the restore button
    // inside the overlay has no handler.
    await AppControl.attachOverlayBridge();
    notifyListeners();
  }

  Future<void> hide() async {
    await FlutterOverlayWindow.closeOverlay();
    _active = false;
    _overlayIsMining = false;
    // Resume mining in the main app.
    await FlutterOverlayWindow.shareData(OverlayMsg.of(OverlayMsg.mainResumed));
    try {
      await _miner.startMining();
    } catch (_) {}
    notifyListeners();
  }

  void _onOverlayMessage(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case OverlayMsg.overlayMining:
        _overlayIsMining = true;
        overlayTaps = (event['taps'] as num?)?.toInt() ?? overlayTaps;
        overlayBalance = event['balance']?.toString() ?? overlayBalance;
        // Overlay owns mining now — stand down.
        _miner.stopMining().catchError((_) {});
        notifyListeners();
        break;
      case OverlayMsg.overlayDisplayOnly:
        _overlayIsMining = false;
        // Main app stays the miner; make sure it's running.
        _miner.startMining().catchError((_) {});
        notifyListeners();
        break;
      case OverlayMsg.overlayTap:
        final x = (event['x'] as num?)?.toDouble();
        final y = (event['y'] as num?)?.toDouble();
        if (x != null && y != null) _miner.addTap(x, y).catchError((_) {});
        break;
      case OverlayMsg.overlayClosed:
        _active = false;
        _overlayIsMining = false;
        _miner.startMining().catchError((_) {});
        notifyListeners();
        break;
    }
  }

  Future<void> syncActiveState() async {
    try {
      _active = await FlutterOverlayWindow.isActive();
    } catch (e) {
      if (kDebugMode) debugPrint('overlay isActive: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _link?.cancel();
    super.dispose();
  }
}
