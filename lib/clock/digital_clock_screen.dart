import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/bee_config.dart';
import '../mining/bee_miner.dart';
import '../mining/foreground_service.dart';
import '../overlay/overlay_manager.dart';
import '../widgets/home_widget_bridge.dart';
import 'clock_face.dart';
import 'mining_status_bar.dart';
import 'wallet_sheet.dart';

/// Full-screen desk-clock and the mining surface. The hidden Bee WebView only
/// runs while this activity is visible, and — by the engine's design — a mining
/// session only counts if it received taps (see README constraint #9). So the
/// clock face is a tap target: every touch is a real `add_tap`, and an
/// untouched clock is just a clock.
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

  int _tapsThisRun = 0;
  Offset? _lastTapAt;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });

    widget.overlay.addListener(_onOverlay);

    _miner = widget.miner.state;
    _sub = widget.miner.states.listen((s) {
      final wasSettingUp =
          _miner.phase == MinerPhase.propagatingKeys ||
          _miner.phase == MinerPhase.needsMiningKeys;
      // A new ~5-minute epoch → local tap counter restarts. (The authoritative
      // count is s.tapSum5m from the contract; this is just for feel.)
      final epochRolled =
          s.epoch5mStart != null && s.epoch5mStart != _miner.epoch5mStart;
      setState(() {
        _miner = s;
        if (epochRolled) _tapsThisRun = 0;
      });
      HomeWidgetBridge.update(s);
      MiningForegroundService.updateStatus(status: _notificationText(s));

      // Keys just finished propagating → arm the miner so the first tap counts.
      if (wasSettingUp && s.phase == MinerPhase.idle) {
        widget.miner.startMining();
      }
    });

    _boot();
  }

  Future<void> _boot() async {
    try {
      await MiningForegroundService.ensurePermissions();
      await MiningForegroundService.start(status: 'Starting…');
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
    return switch (s.phase) {
      MinerPhase.mining => 'Mining · tap the clock · $bal NACKL',
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
    WakelockPlus.disable();
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

  /// A genuine touch on the clock face — the one legitimate `add_tap` hook.
  /// First tap also kick-starts mining if we're idle; taps are what make a
  /// session count.
  void _onFaceTap(TapUpDetails d) {
    if (_miner.phase == MinerPhase.needsWallet ||
        _miner.phase == MinerPhase.needsMiningKeys) {
      _openWalletSheet();
      return;
    }
    if (_miner.phase == MinerPhase.idle) {
      widget.miner.startMining();
    }
    widget.miner.addTap(d.localPosition.dx, d.localPosition.dy);
    HapticFeedback.selectionClick();
    setState(() {
      _tapsThisRun++;
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
                _TapProgress(
                  taps: widget.overlay.overlayTaps,
                  target: BeeConfig.tapsPerEpochTarget,
                  label: 'floating clock is mining',
                )
              else if (_miner.isMining || _miner.phase == MinerPhase.idle)
                _TapProgress(
                  taps: _miner.tapSum5m > 0 ? _miner.tapSum5m : _tapsThisRun,
                  target: BeeConfig.tapsPerEpochTarget,
                ),
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

/// "43 / 70 taps this epoch" + a thin progress bar. Reward scales with taps in
/// the ~5-minute epoch; hitting the target is the max.
class _TapProgress extends StatelessWidget {
  const _TapProgress({required this.taps, required this.target, this.label});

  final int taps;
  final int target;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final frac = (taps / target).clamp(0.0, 1.0);
    final done = taps >= target;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Text(
            label != null
                ? '$label · $taps taps this epoch'
                : taps == 0
                ? 'Tap the time to mine'
                : '$taps taps this epoch',
            style: TextStyle(
              color: done ? const Color(0xFF6BE28B) : Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 3,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                done ? const Color(0xFF6BE28B) : const Color(0xFFFFC531),
              ),
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
