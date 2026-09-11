import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../mining/bee_miner.dart';
import 'app_control.dart';
import 'overlay_link.dart';

/// The sizes the floating clock can be cycled through.
///
/// [tiny] is deliberately small enough to be little more than the time — the
/// point of the floating clock is to sit over another app without taking it
/// over. The overlay also hosts the mining WebView offstage, which keeps
/// running at any of these sizes because the work is JavaScript, not layout.
enum OverlaySize {
  tiny(width: 132, height: 64),
  small(width: 300, height: 108),
  normal(width: 620, height: 220);

  const OverlaySize({required this.width, required this.height});

  final int width;
  final int height;

  OverlaySize get next => switch (this) {
    OverlaySize.normal => OverlaySize.small,
    OverlaySize.small => OverlaySize.tiny,
    OverlaySize.tiny => OverlaySize.normal,
  };
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

  /// True when the overlay has taken over mining (main app should show its
  /// shared state rather than its own miner state).
  bool get overlayOwnsMining => _active && _overlayIsMining;

  int overlayTaps = 0;
  String? overlayBalance;

  Future<bool> ensurePermission() async {
    if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    return (await FlutterOverlayWindow.requestPermission()) ?? false;
  }

  Future<void> toggle() => _active ? hide() : show();

  Future<void> show() async {
    if (!await ensurePermission()) return;
    _link ??= FlutterOverlayWindow.overlayListener.listen(_onOverlayMessage);
    await FlutterOverlayWindow.showOverlay(
      height: OverlaySize.normal.height,
      width: OverlaySize.normal.width,
      alignment: OverlayAlignment.topCenter,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
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
