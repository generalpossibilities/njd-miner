import 'dart:async';

/// Lifecycle of the miner as surfaced to the UI.
enum MinerPhase {
  /// SDK WASM not loaded yet.
  loading,

  /// WASM ready, but no wallet connected.
  needsWallet,

  /// Wallet connected, mining keys not yet written to the Miner contract.
  needsMiningKeys,

  /// Mining keys requested, waiting for on-chain propagation.
  propagatingKeys,

  /// Ready to mine, currently not running.
  idle,

  /// A mining session is computing / submitting.
  mining,

  /// The miner crashed; needs re-init.
  crashed,
}

/// A snapshot of miner state for the clock overlay + home widget.
class MinerState {
  const MinerState({
    required this.phase,
    this.nacklBalance,
    this.gameBalance,
    this.balanceDebug,
    this.sessionsCompleted = 0,
    this.tapSum,
    this.tapSum5m = 0,
    this.epoch5mStart,
    this.message,
    this.error,
  });

  final MinerPhase phase;

  /// Liquid/unlocked NACKL (`ecc["1"]`), e.g. "12.3456". Null until first poll.
  final String? nacklBalance;

  /// `popitgame["1"]` NACKL — candidate for the *locked* mining-reward balance.
  /// May be null if the wallet has no game bucket. See [balanceDebug].
  final String? gameBalance;

  /// Raw dump of every balance map (ecc / popitgame / tokens) for one device
  /// round-trip, so we can identify which field holds locked rewards.
  final String? balanceDebug;

  /// Count of mining sessions finished this run (informational).
  final int sessionsCompleted;

  /// `tap_sum` from `miner.get_miner_data()` — lifetime tap work.
  final String? tapSum;

  /// `tap_sum_5m` — taps counted in the current ~5-minute epoch (the number
  /// that actually drives the reward). Source of truth for tap progress.
  final int tapSum5m;

  /// `_epoch5mStart` — changes when a new 5-minute epoch begins.
  final String? epoch5mStart;

  final String? message;
  final String? error;

  bool get isMining => phase == MinerPhase.mining;

  MinerState copyWith({
    MinerPhase? phase,
    String? nacklBalance,
    Object? gameBalance = _sentinel,
    String? balanceDebug,
    int? sessionsCompleted,
    String? tapSum,
    int? tapSum5m,
    String? epoch5mStart,
    String? message,
    Object? error = _sentinel,
  }) {
    return MinerState(
      phase: phase ?? this.phase,
      nacklBalance: nacklBalance ?? this.nacklBalance,
      gameBalance:
          identical(gameBalance, _sentinel)
              ? this.gameBalance
              : gameBalance as String?,
      balanceDebug: balanceDebug ?? this.balanceDebug,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      tapSum: tapSum ?? this.tapSum,
      tapSum5m: tapSum5m ?? this.tapSum5m,
      epoch5mStart: epoch5mStart ?? this.epoch5mStart,
      message: message ?? this.message,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();

  static const MinerState initial = MinerState(phase: MinerPhase.loading);
}

/// A pending wallet-connect handshake: show [deepLink] as a QR / open button,
/// then await [completed].
class WalletConnectRequest {
  WalletConnectRequest({required this.deepLink, required this.completed});

  final String deepLink;
  final Future<void> completed;
}

/// Backend-agnostic contract for the NACKL miner.
///
/// The only implementation today is [WebViewBeeMiner], which drives the official
/// `@teamgosh/bee-sdk` WASM inside a hidden WebView. A native flutter_rust_bridge
/// backend could implement the same interface later without touching the clock.
abstract class BeeMiner {
  Stream<MinerState> get states;

  MinerState get state;

  /// Boot the SDK. Safe to call more than once.
  Future<void> initialize();

  /// Begin (or resume) the wallet-connect handshake. Returns null if a wallet is
  /// already connected.
  Future<WalletConnectRequest?> connectWallet();

  /// Generate mining keys and ask the connected wallet to write them to the
  /// Miner contract, then wait for on-chain propagation.
  Future<void> requestMiningKeys();

  /// Start the continuous mining loop (short sessions, auto re-armed).
  Future<void> startMining();

  /// Stop after the current session.
  Future<void> stopMining();

  /// Register a real user touch on the clock face with the miner
  /// (`add_tap`, signed with the mining key). Coordinates are logical pixels.
  ///
  /// Only ever call this from a genuine pointer event — synthesised taps are
  /// exactly what the on-chain verifier scores miners down for.
  Future<void> addTap(double x, double y);

  /// Claim rewards from finished sessions.
  Future<void> claimReward();

  /// Refresh the NACKL balance now.
  Future<void> refreshBalance();

  /// Disconnect the wallet: stop mining, revoke the session, clear stored keys.
  Future<void> disconnect();

  /// Reload the underlying host and re-run [initialize] — used by the on-screen
  /// "Retry" after a crash.
  Future<void> reload();

  Future<void> dispose();
}
