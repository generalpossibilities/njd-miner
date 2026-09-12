import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../config/bee_config.dart';
import '../mining/bee_miner.dart';
import '../mining/webview_bee_miner.dart';
import 'app_control.dart';
import 'overlay_link.dart';

/// The floating always-on-top clock. Runs in the overlay isolate (a separate
/// FlutterEngine), so it builds its **own** [WebViewBeeMiner]. Because both
/// engines are in the same process and hit the same `http://127.0.0.1` origin,
/// this WebView reads the wallet session + mining keys the main app stored.
///
/// If the platform view can't render in an overlay window on this device, the
/// miner never leaves [MinerPhase.loading]; after [_probeTimeout] we fall back
/// to **display-only** and forward taps to the main app.
class OverlayClock extends StatefulWidget {
  const OverlayClock({super.key});

  @override
  State<OverlayClock> createState() => _OverlayClockState();
}

class _OverlayClockState extends State<OverlayClock> {
  static const Duration _probeTimeout = Duration(seconds: 12);

  /// Set when reopening the app failed, so the button is not silently dead.
  bool _restoreFailed = false;

  /// Which size step the clock is on. Tapping the button walks
  /// default -> small -> smaller -> smallest -> default.
  ///
  /// Dragging a corner was fiddly on a window this small — the grip competed
  /// with the drag-to-move gesture and needed precision on a moving target. A
  /// tap is unambiguous.
  int _step = 0;

  /// Screen size in dp. The overlay plugin takes dp (it calls dpToPx itself), so
  /// sizes are computed against this and can never exceed the display — the old
  /// default was a flat 620dp wide, wider than most phones.
  Size get _screenDp {
    final d = WidgetsBinding.instance.platformDispatcher.views.first.display;
    return d.size / d.devicePixelRatio;
  }

  /// The size steps, as fractions of the screen so they hold on any device.
  List<List<int>> get _steps {
    final s = _screenDp;
    int w(double f) => (s.width * f).clamp(96.0, s.width - 8).round();
    int h(double f) => (s.height * f).clamp(44.0, s.height - 8).round();
    return [
      [w(0.95), h(0.26)], // default
      [w(0.62), h(0.16)], // small
      [w(0.42), h(0.11)], // smaller
      [w(0.28), h(0.075)], // smallest
    ];
  }

  int get _w => _steps[_step][0];
  int get _h => _steps[_step][1];

  Future<void> _cycleSize() async {
    setState(() => _step = (_step + 1) % _steps.length);
    await FlutterOverlayWindow.resizeOverlay(_w, _h, true);
  }

  /// Long-press to jump straight back to the default size.
  Future<void> _resetSize() async {
    setState(() => _step = 0);
    await FlutterOverlayWindow.resizeOverlay(_w, _h, true);
  }

  /// True when the window is too short to carry anything but the time.
  bool get _isCompact => _h < 90 || _w < 240;

  Future<void> _restoreApp() async {
    final ok = await AppControl.bringAppToFront();
    if (!ok && mounted) {
      // The bridge is registered on the overlay engine by the main app right
      // after showOverlay; if that did not happen the call is a no-op. There is
      // no Scaffold here to show a SnackBar in, so surface it on the clock.
      setState(() => _restoreFailed = true);
    }
  }

  final WebViewBeeMiner _miner = WebViewBeeMiner();
  MinerState _state = MinerState.initial;
  StreamSubscription<MinerState>? _sub;
  StreamSubscription? _link;
  Timer? _ticker;
  Timer? _probe;
  Timer? _push;
  DateTime _now = DateTime.now();
  bool _displayOnly = false;
  int _localTaps = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _sub = _miner.states.listen((s) {
      setState(() => _state = s);
      if (s.phase != MinerPhase.loading && _probe != null) {
        _probe?.cancel();
        _probe = null;
      }
    });

    _link = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && event['type'] == OverlayMsg.mainResumed) {
        _miner.stopMining();
      }
    });

    _push = Timer.periodic(const Duration(seconds: 3), (_) => _shareState());
    _probe = Timer(_probeTimeout, () {
      if (_state.phase == MinerPhase.loading) {
        setState(() => _displayOnly = true);
        FlutterOverlayWindow.shareData(
          OverlayMsg.of(OverlayMsg.overlayDisplayOnly),
        );
      }
    });

    _boot();
  }

  Future<void> _boot() async {
    try {
      await _miner.initialize();
      if (!mounted) return;
      // Tell the main app to yield, then take over mining.
      await FlutterOverlayWindow.shareData(
        OverlayMsg.of(OverlayMsg.overlayMining),
      );
      if (_miner.state.phase == MinerPhase.idle) {
        await _miner.startMining();
      }
    } catch (_) {
      if (mounted) setState(() => _displayOnly = true);
    }
  }

  void _shareState() {
    FlutterOverlayWindow.shareData(
      OverlayMsg.of(
        _displayOnly ? OverlayMsg.overlayDisplayOnly : OverlayMsg.overlayMining,
        {
          'taps': _state.tapSum5m,
          'balance': _state.gameBalance ?? _state.nacklBalance,
          'phase': _state.phase.name,
        },
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _probe?.cancel();
    _push?.cancel();
    _sub?.cancel();
    _link?.cancel();
    FlutterOverlayWindow.shareData(OverlayMsg.of(OverlayMsg.overlayClosed));
    _miner.dispose();
    super.dispose();
  }

  void _onTap(TapUpDetails d) {
    HapticFeedback.selectionClick();
    setState(() => _localTaps++);
    if (_displayOnly) {
      FlutterOverlayWindow.shareData(
        OverlayMsg.of(OverlayMsg.overlayTap, {
          'x': d.localPosition.dx,
          'y': d.localPosition.dy,
        }),
      );
    } else {
      if (_state.phase == MinerPhase.idle) _miner.startMining();
      _miner.addTap(d.localPosition.dx, d.localPosition.dy);
    }
  }

  String get _hhmm =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final taps = _state.tapSum5m > 0 ? _state.tapSum5m : _localTaps;
    final mining = !_displayOnly && _state.phase == MinerPhase.mining;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(
        children: [
          // Hidden miner host — full-size so the platform view is laid out.
          if (!_displayOnly)
            Positioned.fill(
              child: IgnorePointer(child: _miner.buildOffstageHost()),
            ),
          GestureDetector(
            onTapUp: _onTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF00A0A12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: _isCompact ? 8 : 14,
                vertical: _isCompact ? 4 : 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hhmm,
                        style: TextStyle(
                          color: Colors.white,
                          // At tiny the clock is most of the window, so the time
                          // shrinks with it rather than overflowing.
                          fontSize: _isCompact ? 18 : 30,
                          fontWeight: FontWeight.w200,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        mining ? Icons.bolt : Icons.bolt_outlined,
                        size: 14,
                        color:
                            mining ? const Color(0xFF6BE28B) : Colors.white38,
                      ),
                      const Spacer(),
                      // Reopen the app. With the main body minimised the clock
                      // is the only thing on screen, and there was no way back
                      // without finding the launcher icon.
                      _iconButton(
                        _restoreFailed
                            ? Icons.error_outline
                            : Icons.open_in_full,
                        _restoreFailed ? 'Could not reopen app' : 'Reopen app',
                        _restoreApp,
                      ),
                      // Tap to step down through the sizes and wrap back to
                      // default; long-press to jump straight back.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _cycleSize,
                        onLongPress: _resetSize,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _step == 0
                                ? Icons.close_fullscreen
                                : Icons.open_in_full,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // The status line is the first thing to go when the window is
                  // too small to carry it.
                  if (!_isCompact) ...[
                    const SizedBox(height: 2),
                    Text(
                      _displayOnly
                          ? 'display only · tap sends to app'
                          : '$taps / ${BeeConfig.tapsPerEpochTarget} taps · ${_state.gameBalance ?? _state.nacklBalance ?? '—'}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small tap target that does not swallow the tap-to-mine gesture behind it.
  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) {
    // GestureDetector, not InkWell: the overlay's home is a bare Stack with no
    // Material ancestor, and InkWell would throw at runtime looking for one.
    // opaque so the tap does not fall through to the tap-to-mine handler behind.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: Colors.white54),
        ),
      ),
    );
  }
}
