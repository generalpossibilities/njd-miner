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

  /// Length of one `Miner.start()` session. Bee accounts taps in a ~5-minute
  /// epoch window (`_epoch5mStart` / `_tapSum5m` in `MinerAccountData`), so a
  /// session is aligned to that; the JS runner re-arms at the boundary.
  /// The upstream demo uses 15s — that's a demo button, not a real session.
  static const int sessionDurationMs = 300000; // 5 min

  /// Taps in one epoch that yield the maximum reward; fewer taps → less.
  /// User-reported (~70); not stated in the official docs. Drives only the
  /// on-screen progress hint — the contract's `tap_sum_5m` is the real figure.
  static const int tapsPerEpochTarget = 70;

  /// ECC token slot for NACKL in `wallet.get_multifactor_balances()`.
  static const String nacklEccSlot = '1';
}
