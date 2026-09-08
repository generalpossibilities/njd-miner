import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config/bee_config.dart';
import 'bee_miner.dart';

/// [BeeMiner] backed by the official `@teamgosh/bee-sdk` WASM, running inside a
/// hidden [InAppWebView].
///
/// Why a WebView: the Bee Engine miner ships only as a browser-WASM bundle
/// (`wasm-pack --target web`). It is single-threaded and cooperative — a
/// `spawn_local` future that yields to the JS event loop with `setTimeout` — so
/// no SharedArrayBuffer / cross-origin-isolation is required. It does need a
/// real `http://` origin to `fetch()` the `.wasm`, which [InAppLocalhostServer]
/// provides from the bundled assets.
///
/// The WebView must stay attached to the widget tree (see
/// [buildOffstageHost]) — Chromium suspends JS timers in a detached/hidden
/// WebView, and `flutter_foreground_task`'s background isolate has no activity
/// to host one. This is why the product is a *screen-on* clock.
class WebViewBeeMiner implements BeeMiner {
  WebViewBeeMiner();

  static final InAppLocalhostServer _server = InAppLocalhostServer(
    port: BeeConfig.localPort,
    documentRoot: 'assets/bee',
  );

  InAppWebViewController? _controller;
  final Completer<void> _webViewReady = Completer<void>();

  final _stateController = StreamController<MinerState>.broadcast();
  MinerState _state = MinerState.initial;

  Completer<void>? _connectCompleter;
  Timer? _balanceTimer;
  Timer? _minerDataTimer;

  @override
  Stream<MinerState> get states => _stateController.stream;

  @override
  MinerState get state => _state;

  void _set(MinerState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  Uri get _indexUri => Uri.parse(
    'http://${BeeConfig.localHost}:${BeeConfig.localPort}/index.html',
  );

  /// The widget the app must keep mounted somewhere offstage. Sized 1x1 and
  /// wrapped in `Offstage` by the caller; kept in the tree so JS keeps running.
  InAppWebView buildOffstageHost() {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        isInspectable: kDebugMode,
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        // The SDK talks to Acki Nacki nodes over https from the localhost origin.
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
      ),
      onWebViewCreated: (controller) async {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'beeEvent',
          callback: (args) => _onBeeEvent(args.isNotEmpty ? args.first : null),
        );
        if (!_server.isRunning()) {
          await _server.start();
        }
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(_indexUri)),
        );
      },
      onLoadStop: (controller, url) async {
        if (!_webViewReady.isCompleted) _webViewReady.complete();
      },
      onConsoleMessage: (controller, msg) {
        if (kDebugMode) {
          debugPrint('[bee-webview] ${msg.messageLevel}: ${msg.message}');
        }
      },
    );
  }

  Future<T> _call<T>(String expression) async {
    await _webViewReady.future;
    final controller = _controller!;
    // `runner.js` is a module script — it may still be evaluating when
    // onLoadStop fires, so wait for `window.Bee` before touching it.
    final result = await controller.callAsyncJavaScript(
      functionBody: '''
        const deadline = Date.now() + 10000;
        while (!window.Bee) {
          if (Date.now() > deadline) throw new Error('bee runner never loaded');
          await new Promise((r) => setTimeout(r, 50));
        }
        $expression
      ''',
    );
    if (result?.error != null) {
      throw StateError('bee call failed: ${result!.error}');
    }
    return result?.value as T;
  }

  @override
  Future<void> initialize() async {
    await _webViewReady.future;
    // Inject config, then boot the SDK.
    final cfg = jsonEncode({
      'appId': BeeConfig.appDappId,
      'endpoints': BeeConfig.endpoints,
      'apiUrl': BeeConfig.apiUrl,
      'sessionDurationMs': BeeConfig.sessionDurationMs,
      'nacklEccSlot': BeeConfig.nacklEccSlot,
    });
    await _call<void>('window.__BEE_CFG = $cfg; await window.Bee.init();');
  }

  @override
  Future<WalletConnectRequest?> connectWallet() async {
    if (_state.phase.index > MinerPhase.needsWallet.index &&
        _state.phase != MinerPhase.crashed) {
      return null; // already connected
    }
    final res = await _call<Map<dynamic, dynamic>>(
      'return await window.Bee.startConnect();',
    );
    final deepLink = res['deepLink'] as String;
    _connectCompleter = Completer<void>();
    return WalletConnectRequest(
      deepLink: deepLink,
      completed: _connectCompleter!.future,
    );
  }

  @override
  Future<void> requestMiningKeys() =>
      _call<void>('await window.Bee.requestMiningKeys();');

  @override
  Future<void> startMining() async {
    await _call<void>('await window.Bee.startMining();');
    _startPolling();
  }

  @override
  Future<void> stopMining() async {
    await _call<void>('await window.Bee.stopMining();');
    _stopPolling();
  }

  @override
  Future<void> addTap(double x, double y) =>
      _call<void>('await window.Bee.addTap($x, $y);');

  @override
  Future<void> claimReward() => _call<void>('await window.Bee.claimReward();');

  @override
  Future<void> refreshBalance() =>
      _call<void>('await window.Bee.refreshBalance();');

  @override
  Future<void> dispose() async {
    _stopPolling();
    await _stateController.close();
  }

  // ---- event handling ------------------------------------------------

  void _onBeeEvent(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['type'] as String?;
    switch (type) {
      case 'runner_loaded':
        break;
      case 'ready':
        final connected = raw['connected'] == true;
        _set(
          _state.copyWith(
            phase:
                connected ? MinerPhase.needsMiningKeys : MinerPhase.needsWallet,
          ),
        );
        break;
      case 'wallet_connected':
        _connectCompleter?.complete();
        _connectCompleter = null;
        _set(
          _state.copyWith(
            phase: MinerPhase.needsMiningKeys,
            message: 'Wallet ${raw['walletName']} connected',
          ),
        );
        break;
      case 'connect_error':
        _connectCompleter?.completeError(
          StateError(raw['error']?.toString() ?? 'connect failed'),
        );
        _connectCompleter = null;
        _set(_state.copyWith(error: raw['error']?.toString()));
        break;
      case 'keys_propagating':
        _set(_state.copyWith(phase: MinerPhase.propagatingKeys, error: null));
        break;
      case 'keys_ready':
        _set(
          _state.copyWith(
            phase: MinerPhase.idle,
            message: 'Mining keys ready',
            error: null,
          ),
        );
        break;
      case 'keys_error':
        _set(
          _state.copyWith(
            phase: MinerPhase.needsMiningKeys,
            error: raw['error']?.toString(),
          ),
        );
        break;
      case 'mining_started':
        _set(_state.copyWith(phase: MinerPhase.mining, error: null));
        break;
      case 'mining_stopped':
        _set(_state.copyWith(phase: MinerPhase.idle));
        break;
      case 'session_status':
        if (raw['status'] == 'computing' || raw['status'] == 'starting') {
          _set(_state.copyWith(phase: MinerPhase.mining));
        }
        break;
      case 'session_finished':
        _set(
          _state.copyWith(
            sessionsCompleted:
                (raw['sessions'] as num?)?.toInt() ?? _state.sessionsCompleted,
          ),
        );
        break;
      case 'balance':
        _set(_state.copyWith(nacklBalance: raw['nackl']?.toString()));
        break;
      case 'miner_data':
        _set(_state.copyWith(tapSum: raw['tapSum']?.toString()));
        break;
      case 'reward_claimed':
        _set(_state.copyWith(message: 'Reward claimed'));
        break;
      case 'miner_error':
        _set(
          _state.copyWith(
            phase: MinerPhase.crashed,
            error: '${raw['where']}: ${raw['error']}',
          ),
        );
        break;
      case 'disconnected':
        _set(const MinerState(phase: MinerPhase.needsWallet));
        break;
    }
  }

  void _startPolling() {
    _balanceTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => refreshBalance().catchError((_) {}),
    );
    _minerDataTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _call<void>('await window.Bee.minerData();').catchError((_) {}),
    );
  }

  void _stopPolling() {
    _balanceTimer?.cancel();
    _balanceTimer = null;
    _minerDataTimer?.cancel();
    _minerDataTimer = null;
  }
}
