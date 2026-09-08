/// Everything environment-specific about the Bee Engine integration lives here.
///
/// The values below are placeholders taken from the official `miner-react`
/// example. You MUST replace [appDappId] with the id issued to your application
/// by the Acki Nacki team before mining will attribute rewards to you.
///
/// See README.md → "1. Get an app_dapp_id".
class BeeConfig {
  const BeeConfig._();

  /// dApp id for your application, issued by the Acki Nacki team.
  static const String appDappId =
      '0x0000000000000000000000000000000000000000000000000000000000000019';

  /// Acki Nacki node endpoints used by the SDK.
  ///
  /// NOTE: the upstream example is internally inconsistent — it points
  /// [endpoints] at mainnet while the UI copy says "shellnet". Confirm the
  /// network you are targeting with the Acki Nacki team and set both of these
  /// accordingly.
  static const List<String> endpoints = <String>[
    'https://mainnet.ackinacki.org',
  ];

  /// App backend used for balance lookups and push notifications.
  static const String apiUrl = 'https://app-backend-dev.ackinacki.org/api';

  /// Loopback host + port the in-app static server binds to. The Bee WASM glue
  /// is fetched over http:// from here (a `file://` origin cannot `fetch()` the
  /// `.wasm` in an Android WebView).
  static const String localHost = '127.0.0.1';
  static const int localPort = 8737;

  // ── Mining session (values from a working reference auto-miner) ──────
  /// Length of one `Miner.start()` session.
  static const int sessionDurationMs = 330000; // 5.5 min

  /// Auto-taps fired per session (70 → maximum session reward).
  static const int tapsPerSession = 70;

  /// Base delay between auto-taps; actual delay is ±[tapJitterPct].
  static const int tapIntervalMs = 4000;
  static const double tapJitterPct = 0.10;

  /// Stagger before submitting session results (desyncs WASM submit calls).
  static const int submitStaggerMs = 5000;

  /// Extra idle between sessions: 5s + rand(0..[sessionBoundaryJitterMs]).
  static const int sessionBoundaryJitterMs = 3000;

  /// On-chain hard cap on taps counted in one global epoch.
  static const int maxTapsPerEpoch = 12000;

  /// Global epoch length in blocks (for the tap-budget reset).
  static const int epochSpanBlocks = 262000;

  /// Wallet-connect session TTL handed to `create_shared_key_session` (seconds).
  static const int connectSessionTtlSec = 1800;

  /// Kept for the on-screen progress bar.
  static const int tapsPerEpochTarget = tapsPerSession;

  /// ECC token slot for NACKL in `wallet.get_multifactor_balances()`.
  static const String nacklEccSlot = '1';
}
