import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/bee_config.dart';
import '../mining/bee_miner.dart';
import '../mining/foreground_service.dart';
import '../overlay/overlay_manager.dart';
import '../widgets/home_widget_bridge.dart';
import 'clock_face.dart';
import 'mining_status_bar.dart';
import 'wallet_sheet.dart';

/// Full-screen desk-clock. Mining is automatic — the Bee runner fires ~70
/// taps per 5.5-minute session on its own. The hidden Bee WebView only runs
/// while this activity (or the floating overlay) is visible, so the clock has
/// to stay on screen. A touch on the clock face is an optional bonus tap.
class DigitalClockScreen extends StatefulWidget {
  const DigitalClockScreen({
    super.key,
    required this.miner,
    required this.overlay,
  });

  final BeeMiner miner;
  final OverlayManager overlay;

  @override
  State<DigitalClockScreen> createState() => _DigitalClockScreenState();
}

class _DigitalClockScreenState extends State<DigitalClockScreen> {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  MinerState _miner = MinerState.initial;
  StreamSubscription<MinerState>? _sub;

  Offset? _lastTapAt;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // No WakelockPlus.enable() here. Holding the screen on was compensating for
    // mining that stopped when the display slept; the resumeTimers keepalive in
    // webview_bee_miner now carries it through screen-off, so forcing the
    // display to stay lit only costs battery.

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });

    widget.overlay.addListener(_onOverlay);

    _miner = widget.miner.state;
    _sub = widget.miner.states.listen((s) {
      final wasSettingUp =
          _miner.phase == MinerPhase.propagatingKeys ||
          _miner.phase == MinerPhase.needsMiningKeys;
      setState(() => _miner = s);
      HomeWidgetBridge.update(s);
      _syncForegroundService(s);

      // Keys just propagated → auto-mining kicks off.
      if (wasSettingUp && s.phase == MinerPhase.idle) {
        widget.miner.startMining();
      }
    });

    _boot();
  }

  /// Run the foreground service only while mining is actually happening.
  ///
  /// It used to start at launch and stay up for the app's lifetime, so stopping
  /// mining left a notification claiming work that was not happening, and a
  /// wake lock held for nothing.
  bool _serviceRunning = false;

  Future<void> _syncForegroundService(MinerState s) async {
    if (s.isMining) {
      if (!_serviceRunning) {
        _serviceRunning = true;
        await MiningForegroundService.start(status: _notificationText(s));
      } else {
        await MiningForegroundService.updateStatus(status: _notificationText(s));
      }
    } else if (_serviceRunning) {
      _serviceRunning = false;
      await MiningForegroundService.stop();
    }
  }

  Future<void> _boot() async {
    try {
      await MiningForegroundService.ensurePermissions();
      await widget.miner.initialize();
      if (!mounted) return;
      // If a wallet + keys are already stored, start mining immediately.
      if (widget.miner.state.phase == MinerPhase.idle) {
        await widget.miner.startMining();
      } else if (widget.miner.state.phase == MinerPhase.needsWallet) {
        _openWalletSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _miner = _miner.copyWith(
                phase: MinerPhase.crashed,
                error: 'Startup failed: $e',
              ),
        );
      }
    }
  }

  String _notificationText(MinerState s) {
    final bal = s.gameBalance ?? s.nacklBalance ?? '—';
    final reward = s.lastReward == null ? '' : ' · +${s.lastReward}';
    return switch (s.phase) {
      MinerPhase.mining => 'Mining · $bal NACKL$reward',
      MinerPhase.idle => 'Idle · $bal NACKL',
      MinerPhase.needsWallet => 'Tap to connect your Acki Nacki wallet',
      MinerPhase.crashed => 'Miner stopped — open the app',
      _ => 'Setting up mining…',
    };
  }

  void _onOverlay() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sub?.cancel();
    widget.overlay.removeListener(_onOverlay);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _openWalletSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111214),
      isScrollControlled: true,
      builder: (_) => WalletSheet(miner: widget.miner, overlay: widget.overlay),
    );
  }

  /// Mining is automatic (the runner auto-taps ~70×/session). A touch on the
  /// clock face is just a bonus tap that lands if a session is tapping right
  /// now — and the way into setup when no wallet is connected.
  void _onFaceTap(TapUpDetails d) {
    if (_miner.phase == MinerPhase.needsWallet ||
        _miner.phase == MinerPhase.needsMiningKeys ||
        _miner.phase == MinerPhase.crashed) {
      _openWalletSheet();
      return;
    }
    widget.miner.addTap(d.localPosition.dx, d.localPosition.dy);
    HapticFeedback.selectionClick();
    setState(() {
      _lastTapAt = d.localPosition;
      _lastTapTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            children: [
              Expanded(
                // Tap detector scoped to the clock area so tap coordinates are
                // relative to this box (what the ripple + add_tap expect).
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onFaceTap,
                  onLongPress: _openWalletSheet,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(child: ClockFace(now: _now)),
                      if (_lastTapAt != null)
                        _TapRipple(
                          key: ValueKey(_lastTapTime),
                          at: _lastTapAt!,
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          tooltip: 'Floating clock',
                          onPressed: () => widget.overlay.toggle(),
                          icon: Icon(
                            widget.overlay.active
                                ? Icons.picture_in_picture_alt
                                : Icons.picture_in_picture_alt_outlined,
                            color:
                                widget.overlay.active
                                    ? const Color(0xFFFFC531)
                                    : Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_miner.phase == MinerPhase.crashed && _miner.error != null)
                _ErrorBanner(
                  message: _miner.error!,
                  onRetry: () => widget.miner.reload(),
                ),
              if (widget.overlay.overlayOwnsMining)
                _SessionStatus.overlay(taps: widget.overlay.overlayTaps)
              else if (_miner.isMining || _miner.phase == MinerPhase.idle)
                _SessionStatus(state: _miner),
              MiningStatusBar(
                state: _miner,
                onConnectWallet: _openWalletSheet,
                onToggleMining: () {
                  if (_miner.isMining) {
                    widget.miner.stopMining();
                  } else if (_miner.phase == MinerPhase.idle) {
                    widget.miner.startMining();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auto-mining session status: which phase, taps this session, confirmed,
/// epoch budget used. Mining is automatic — this reports it, doesn't ask for
/// input.
class _SessionStatus extends StatelessWidget {
  const _SessionStatus({required this.state}) : overlayTaps = null;
  const _SessionStatus.overlay({required int taps})
    : state = null,
      overlayTaps = taps;

  final MinerState? state;
  final int? overlayTaps;

  @override
  Widget build(BuildContext context) {
    if (overlayTaps != null) {
      return _wrap(
        'Floating clock mining · $overlayTaps taps',
        (overlayTaps! / BeeConfig.tapsPerSession).clamp(0.0, 1.0),
        const Color(0xFF6BE28B),
      );
    }
    final s = state!;
    final phase = switch (s.sessionPhase) {
      'starting' => 'starting session',
      'tapping' => 'mining',
      'submitting' => 'submitting proof',
      'waiting' => s.sessionNote ?? 'waiting',
      _ => s.phase == MinerPhase.mining ? 'mining' : 'idle',
    };
    final line = StringBuffer(phase);
    if (s.sessionPhase == 'tapping') {
      line.write(' · ${s.tapsSent}/${BeeConfig.tapsPerSession} taps');
    } else if (s.confirmed > 0) {
      line.write(' · +${s.confirmed} confirmed');
    }
    // On-chain figure (not a local counter): taps this era.
    if (s.tapSum != null) {
      line.write(' · ${s.tapSum} epoch taps');
    }
    // Two different session counts, and conflating them read as a broken
    // counter: `sessionsCompleted` is the running total this run, while
    // `tapsSize` is the on-chain count for the current ~5-minute reward epoch
    // and so drops back to zero every epoch. Show both, each labelled for what
    // it is, rather than only the one that keeps resetting.
    if (s.sessionsCompleted > 0) {
      line.write(' · ${s.sessionsCompleted} sessions');
      if (s.tapsSize > 0) {
        line.write(' (${s.tapsSize} this epoch)');
      }
    } else if (s.tapsSize > 0) {
      line.write(' · ${s.tapsSize} sessions this epoch');
    }
    final frac =
        s.sessionPhase == 'tapping'
            ? (s.tapsSent / BeeConfig.tapsPerSession).clamp(0.0, 1.0)
            : null;
    final bar =
        s.sessionPhase == 'waiting'
            ? const Color(0xFFFFA000)
            : const Color(0xFFFFC531);
    return _wrap(line.toString(), frac, bar);
  }

  Widget _wrap(String text, double? frac, Color bar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Text(
            text,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 3,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(bar),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width red banner shown when the miner is in [MinerPhase.crashed].
/// Text is selectable so the error can be copied out for a bug report.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0x22FF5252),
        border: Border.all(color: const Color(0x55FF5252)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(
                color: Color(0xFFFFB4B4),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// A one-shot expanding ring where the user last tapped the clock face.
class _TapRipple extends StatefulWidget {
  const _TapRipple({super.key, required this.at});

  final Offset at;

  @override
  State<_TapRipple> createState() => _TapRippleState();
}

class _TapRippleState extends State<_TapRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_c.value);
            return CustomPaint(
              painter: _RipplePainter(
                center: widget.at,
                radius: 12 + t * 90,
                opacity: (1 - t) * 0.6,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.center,
    required this.radius,
    required this.opacity,
  });

  final Offset center;
  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(
            0xFF6BE28B,
          ).withValues(alpha: opacity.clamp(0, 1));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.radius != radius || old.opacity != opacity;
}
