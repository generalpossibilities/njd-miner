import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:njd_miner/clock/clock_face.dart';

void main() {
  testWidgets('ClockFace renders the current time and date', (tester) async {
    final t = DateTime(2026, 9, 8, 14, 5, 30);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ClockFace(now: t, showSeconds: true))),
    );

    expect(find.text('14'), findsOneWidget); // hours
    expect(find.text('05'), findsOneWidget); // minutes
    expect(find.text('30'), findsOneWidget); // seconds
    expect(find.textContaining('TUE  8 SEP'), findsOneWidget);
  });

  testWidgets('12-hour mode shows AM/PM and no leading-zero > 12', (
    tester,
  ) async {
    final t = DateTime(2026, 9, 8, 14, 5, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClockFace(now: t, use24h: false, showSeconds: false),
        ),
      ),
    );

    expect(find.text('02'), findsOneWidget);
    expect(find.textContaining('PM'), findsOneWidget);
  });
}
