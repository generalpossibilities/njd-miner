import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'clock/digital_clock_screen.dart';
import 'mining/foreground_service.dart';
import 'mining/webview_bee_miner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  MiningForegroundService.init();
  runApp(const NjdMinerApp());
}

class NjdMinerApp extends StatefulWidget {
  const NjdMinerApp({super.key});

  @override
  State<NjdMinerApp> createState() => _NjdMinerAppState();
}

class _NjdMinerAppState extends State<NjdMinerApp> {
  final WebViewBeeMiner _miner = WebViewBeeMiner();

  @override
  void dispose() {
    _miner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NJD Miner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFFC531)),
      ),
      home: WithForegroundTask(
        child: Stack(
          children: [
            DigitalClockScreen(miner: _miner),
            // The Bee Engine host. Must stay in the tree (JS timers freeze in a
            // detached WebView) but is 1x1 and behind everything.
            Positioned(
              width: 1,
              height: 1,
              left: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Opacity(opacity: 0, child: _miner.buildOffstageHost()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
