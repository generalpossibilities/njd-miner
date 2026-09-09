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

  /// Start the shared asset server, tolerating "address already in use" — the
  /// overlay isolate and the main isolate each try, and whichever binds first
  /// serves both (same process, same origin).
  static Future<void> _ensureServer() async {
    if (_server.isRunning()) return;
    try {
      await _server.start();
    } catch (_) {
      // Another engine in this process already bound the port; that's fine.
    }
  }

  InAppWebViewController? _controller;
  Completer<void> _webViewReady = Completer<void>();

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

  /// The Bee Engine host WebView. The caller keeps it mounted full-size at the
  /// bottom of the widget stack (hidden by the opaque clock) so Android keeps
  /// its JS running.
  InAppWebView buildOffstageHost() {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        isInspectable: kDebugMode,
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        transparentBackground: true,
        // http:// loopback origin calling https:// Acki Nacki nodes.
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      onWebViewCreated: (controller) async {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'beeEvent',
          callback: (args) => _onBeeEvent(args.isNotEmpty ? args.first : null),
        );
        try {
          await _ensureServer();
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(_indexUri)),
          );
        } catch (e) {
          _set(
            _state.copyWith(
              phase: MinerPhase.crashed,
              error: 'localhost server failed: $e',
            ),
          );
        }
      },
      onLoadStop: (controller, url) async {
        if (!_webViewReady.isCompleted) _webViewReady.complete();
      },
      onReceivedError: (controller, request, error) {
        debugPrint(
          '[bee-webview] load error ${error.type}: ${error.description}',
        );
        if (request.isForMainFrame ?? false) {
          if (!_webViewReady.isCompleted) _webViewReady.complete();
          _set(
            _state.copyWith(
              phase: MinerPhase.crashed,
              error:
                  'WebView load error: ${error.description} '
                  '(is http://127.0.0.1 reachable? cleartext allowed?)',
            ),
          );
        }
      },
      onReceivedHttpError: (controller, request, response) {
        debugPrint(
          '[bee-webview] http ${response.statusCode} for ${request.url}',
        );
      },
      onConsoleMessage: (controller, msg) {
        debugPrint('[bee-webview] ${msg.messageLevel}: ${msg.message}');
        if (msg.messageLevel == ConsoleMessageLevel.ERROR) {
          _lastConsoleError = msg.message;
        }
      },
    );
  }

  String? _lastConsoleError;

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
      final detail =
          _lastConsoleError != null ? ' (console: $_lastConsoleError)' : '';
      throw StateError('bee call failed: ${result!.error}$detail');
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
      'nacklEccSlot': BeeConfig.nacklEccSlot,
      'sessionDurationMs': BeeConfig.sessionDurationMs,
      'tapsPerSession': BeeConfig.tapsPerSession,
      'tapIntervalMs': BeeConfig.tapIntervalMs,
      'tapJitterPct': BeeConfig.tapJitterPct,
      'submitStaggerMs': BeeConfig.submitStaggerMs,
      'sessionBoundaryJitterMs': BeeConfig.sessionBoundaryJitterMs,
      'maxTapsPerEpoch': BeeConfig.maxTapsPerEpoch,
      'connectSessionTtlSec': BeeConfig.connectSessionTtlSec,
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
  Future<void> disconnect() async {
    _stopPolling();
    await _call<void>('await window.Bee.disconnect();');
  }

  @override
  Future<void> reload() async {
    _lastConsoleError = null;
    if (!_webViewReady.isCompleted) {
      // nothing loaded yet — nothing to reload
    } else {
      _webViewReady = Completer<void>();
    }
    try {
      await _ensureServer();
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri.uri(_indexUri)),
      );
      await initialize();
    } catch (e) {
      _set(
        _state.copyWith(phase: MinerPhase.crashed, error: 'reload failed: $e'),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _stopPolling();
    await _stateController.close();
  }

  // ---- event handling ------------------------------------------------

  /// Acki Nacki answers an over-quota external message with TVM error 621.
  /// The SDK wraps it, so match on the payload text rather than a code.
  static bool _isQueueFull(String s) =>
      s.contains('QUEUE_OVERFLOW') || s.contains('Message queue is full');

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
        _set(_state.copyWith(phase: MinerPhase.idle, sessionPhase: 'idle'));
        break;
      case 'session':
        int i(String k) => (raw[k] as num?)?.toInt() ?? 0;
        _set(
          _state.copyWith(
            phase: MinerPhase.mining,
            sessionPhase: raw['phase']?.toString(),
            sessionNote: raw['reason']?.toString(),
            sessionsCompleted: i('n'),
            tapsSent: i('tapsSent'),
            confirmed: i('confirmed'),
            epochTaps: i('epochTaps'),
            epochBudget: i('epochBudget'),
          ),
        );
        break;
      case 'epoch_rolled':
        _set(_state.copyWith(epochTaps: 0));
        break;
      case 'session_event':
        // computation/submit milestones — informational only for now
        break;
      case 'session_finished':
        _set(
          _state.copyWith(
            sessionsCompleted:
                (raw['sessions'] as num?)?.toInt() ?? _state.sessionsCompleted,
            confirmed: (raw['confirmed'] as num?)?.toInt() ?? _state.confirmed,
            epochTaps: (raw['epochTaps'] as num?)?.toInt() ?? _state.epochTaps,
            message:
                raw['empty'] == true
                    ? 'Last session submitted no taps'
                    : raw['error']?.toString(),
          ),
        );
        break;
      case 'balance':
        var next = _state.copyWith(
          nacklBalance: raw['liquid']?.toString(),
          gameBalance: raw['game']?.toString(),
          balanceDebug: raw['raw'] == null ? null : jsonEncode(raw['raw']),
        );
        // Only overwrite lastReward when the runner reports a fresh jump; a
        // plain poll with no delta leaves the previous value in place.
        final lr = raw['lastReward']?.toString();
        if (lr != null) next = next.copyWith(lastReward: lr);
        _set(next);
        break;
      case 'miner_data':
        int? i(String k) => int.tryParse(raw[k]?.toString() ?? '');
        _set(
          _state.copyWith(
            tapSum: raw['tapSum']?.toString(),
            tapSum5m: i('tapSum5m') ?? _state.tapSum5m,
            epoch5mStart: raw['epoch5mStart']?.toString(),
            epoch5mStartOld: raw['epoch5mStartOld']?.toString(),
            tapsSize: i('tapsSize') ?? _state.tapsSize,
            oldTapsSize: i('oldTapsSize') ?? _state.oldTapsSize,
            modifiedTapSum: raw['modifiedTapSum']?.toString(),
            miningDurSum: raw['miningDurSum']?.toString(),
          ),
        );
        break;
      case 'reward_claimed':
        _set(_state.copyWith(message: 'Reward claimed'));
        break;
      case 'miner_error':
        final detail = raw['error']?.toString() ?? '';
        // A full node message queue is the network shedding load, not a crash.
        // Acki Nacki v0.19.1 caps queued external messages per account, and the
        // runner already backs off and retries — so keep mining and just say so.
        if (_isQueueFull(detail)) {
          _set(
            _state.copyWith(
              sessionPhase: 'waiting',
              sessionNote: 'Network message queue full — retrying',
              message: 'Network busy — the miner is backing off and will retry',
            ),
          );
        } else {
          _set(
            _state.copyWith(
              phase: MinerPhase.crashed,
              error: '${raw['where']}: $detail',
            ),
          );
        }
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
