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
    this.lastReward,
    this.balanceDebug,
    this.sessionsCompleted = 0,
    this.tapSum,
    this.tapSum5m = 0,
    this.epoch5mStart,
    this.epoch5mStartOld,
    this.tapsSize = 0,
    this.oldTapsSize = 0,
    this.modifiedTapSum,
    this.miningDurSum,
    this.sessionPhase,
    this.sessionNote,
    this.tapsSent = 0,
    this.confirmed = 0,
    this.epochTaps = 0,
    this.epochBudget = 0,
    this.message,
    this.error,
  });

  final MinerPhase phase;

  /// Liquid/unlocked NACKL (`ecc["1"]`), e.g. "12.3456". Null until first poll.
  final String? nacklBalance;

  /// `popitgame["1"]` NACKL — the *locked* mining-reward balance. This is the
  /// headline number. May be null if the wallet has no game bucket yet.
  final String? gameBalance;

  /// The most recent positive jump in [gameBalance] between two balance polls,
  /// formatted like "12.3456". Null until a reward actually lands.
  final String? lastReward;

  /// Raw dump of every balance map (ecc / popitgame / tokens) for one device
  /// round-trip, so we can identify which field holds locked rewards.
  final String? balanceDebug;

  /// Count of mining sessions finished this run (informational).
  final int sessionsCompleted;

  /// `_tapSum` from `miner.get_miner_data()` — total taps the wallet has made
  /// on-chain in the current big (24-hour) epoch. This is the "epoch taps"
  /// figure shown in the UI.
  final String? tapSum;

  /// `tap_sum_5m` — taps counted in the current ~5-minute reward epoch (the
  /// number that actually drives the current reward).
  final int tapSum5m;

  /// `_epochStart` — changes when a new ~5-minute reward epoch begins.
  final String? epoch5mStart;

  /// `_epochStartOld` — start of the immediately previous ~5-minute epoch.
  final String? epoch5mStartOld;

  /// `_tapsSize` — number of mining sessions recorded in the current
  /// ~5-minute reward epoch (on-chain).
  final int tapsSize;

  /// `_oldTapsSize` — session count from the previous ~5-minute epoch.
  final int oldTapsSize;

  /// `_modifiedTapSum` — reputation-weighted tap total (drives the payout).
  final String? modifiedTapSum;

  /// `_miningDurSum` — total mining duration accrued this 24-hour epoch.
  final String? miningDurSum;

  /// Current session sub-phase from the auto-tap loop:
  /// `starting` | `tapping` | `submitting` | `idle` | `waiting`.
  final String? sessionPhase;

  /// Why the loop is in its current sub-phase, when it has something to say —
  /// e.g. "network message queue full — backing off". Null most of the time.
  final String? sessionNote;

  /// Auto-taps sent in the current/last session.
  final int tapsSent;

  /// On-chain confirmed taps from the last session (`tap_sum` delta).
  final int confirmed;

  /// Confirmed taps accumulated in the current global epoch, and the cap.
  final int epochTaps;
  final int epochBudget;

  final String? message;
  final String? error;

  bool get isMining => phase == MinerPhase.mining;

  MinerState copyWith({
    MinerPhase? phase,
    String? nacklBalance,
    Object? gameBalance = _sentinel,
    Object? lastReward = _sentinel,
    String? balanceDebug,
    int? sessionsCompleted,
    String? tapSum,
    int? tapSum5m,
    String? epoch5mStart,
    String? epoch5mStartOld,
    int? tapsSize,
    int? oldTapsSize,
    String? modifiedTapSum,
    String? miningDurSum,
    String? sessionPhase,
    Object? sessionNote = _sentinel,
    int? tapsSent,
    int? confirmed,
    int? epochTaps,
    int? epochBudget,
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
      lastReward:
          identical(lastReward, _sentinel)
              ? this.lastReward
              : lastReward as String?,
      balanceDebug: balanceDebug ?? this.balanceDebug,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      tapSum: tapSum ?? this.tapSum,
      tapSum5m: tapSum5m ?? this.tapSum5m,
      epoch5mStart: epoch5mStart ?? this.epoch5mStart,
      epoch5mStartOld: epoch5mStartOld ?? this.epoch5mStartOld,
      tapsSize: tapsSize ?? this.tapsSize,
      oldTapsSize: oldTapsSize ?? this.oldTapsSize,
      modifiedTapSum: modifiedTapSum ?? this.modifiedTapSum,
      miningDurSum: miningDurSum ?? this.miningDurSum,
      sessionPhase: sessionPhase ?? this.sessionPhase,
      sessionNote:
          identical(sessionNote, _sentinel)
              ? this.sessionNote
              : sessionNote as String?,
      tapsSent: tapsSent ?? this.tapsSent,
      confirmed: confirmed ?? this.confirmed,
      epochTaps: epochTaps ?? this.epochTaps,
      epochBudget: epochBudget ?? this.epochBudget,
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
  /// Begin connecting a wallet. Returns null when there is nothing to do
  /// because a wallet is already set up.
  ///
  /// Pass [addAnother] to connect an *additional* wallet: that skips the
  /// already-connected short-circuit, which otherwise makes "Add wallet" a
  /// no-op that falls through to authorising the wallet you already had.
  Future<WalletConnectRequest?> connectWallet({bool addAnother = false});

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
  /// Wallets the runner knows about: {walletId, walletName, keysReady}.
  /// More than one can mine at once; [selectedWalletId] is the one whose state
  /// [states] describes.
  List<Map<String, dynamic>> get wallets => const [];
  String? get selectedWalletId => null;

  /// Point the UI at [walletId]. Mining on the other wallets is unaffected.
  Future<void> selectWallet(String walletId) async {}

  /// Disconnect the selected wallet. The others keep mining.
  Future<void> disconnect();

  /// Reload the underlying host and re-run [initialize] — used by the on-screen
  /// "Retry" after a crash.
  Future<void> reload();

  Future<void> dispose();
}
