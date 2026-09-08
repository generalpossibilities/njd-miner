import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../config/bee_config.dart';
import '../mining/bee_miner.dart';
import '../mining/webview_bee_miner.dart';
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _hhmm,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        mining ? Icons.bolt : Icons.bolt_outlined,
                        size: 16,
                        color:
                            mining ? const Color(0xFF6BE28B) : Colors.white38,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _displayOnly
                        ? 'display only · tap sends to app'
                        : '$taps / ${BeeConfig.tapsPerEpochTarget} taps · ${_state.gameBalance ?? _state.nacklBalance ?? '—'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
