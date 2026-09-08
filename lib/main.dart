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
          fit: StackFit.expand,
          children: [
            // The Bee Engine host runs full-size at the bottom of the stack so
            // Android actually lays it out and keeps its JS timers alive; the
            // opaque clock on top hides it. (A 1x1 / offstage WebView gets
            // throttled or never initialises on some devices.)
            IgnorePointer(child: _miner.buildOffstageHost()),
            DigitalClockScreen(miner: _miner),
          ],
        ),
      ),
    );
  }
}
