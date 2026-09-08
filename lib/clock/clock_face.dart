import 'package:flutter/material.dart';

/// The digital time readout. Deliberately dependency-free: a digital clock is a
/// few `Text` widgets and a `Stream` of ticks — a package buys nothing.
///
/// Visual style is inspired by the Flutter Clock Challenge `digital_clock`
/// entry (Apache-2.0, flutter/samples), rebuilt here for current Flutter.
class ClockFace extends StatelessWidget {
  const ClockFace({
    super.key,
    required this.now,
    this.use24h = true,
    this.showSeconds = true,
    this.accent = const Color(0xFFFFC531),
  });

  final DateTime now;
  final bool use24h;
  final bool showSeconds;
  final Color accent;

  String get _hh {
    final h = use24h ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    return h.toString().padLeft(2, '0');
  }

  String get _mm => now.minute.toString().padLeft(2, '0');
  String get _ss => now.second.toString().padLeft(2, '0');
  bool get _colonOn => now.second.isEven;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w200,
      color: Colors.white,
      height: 1,
    );

    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_hh, style: base.copyWith(fontSize: 160)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Opacity(
                  opacity: _colonOn ? 1 : 0.15,
                  child: Text(
                    ':',
                    style: base.copyWith(fontSize: 140, color: accent),
                  ),
                ),
              ),
              Text(_mm, style: base.copyWith(fontSize: 160)),
              if (showSeconds) ...[
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    _ss,
                    style: base.copyWith(fontSize: 64, color: accent),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _dateLine(now) +
                (use24h
                    ? ''
                    : now.hour < 12
                    ? '   AM'
                    : '   PM'),
            style: base.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w300,
              color: Colors.white70,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLine(DateTime d) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${days[d.weekday - 1]}  ${d.day} ${months[d.month - 1]}';
  }
}
