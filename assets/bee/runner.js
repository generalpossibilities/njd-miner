// Bee Engine runner — the JS half of the miner.
//
// Loaded by assets/bee/index.html inside a hidden InAppWebView. It wraps the
// official @teamgosh/bee-sdk (built from https://github.com/gosh-sh/bee-engine
// with `wasm-pack build --target web`, output copied to ./pkg/) and exposes
// `window.Bee` for the Dart side (lib/mining/webview_bee_miner.dart).
//
// The continuous-mining re-arm loop lives here on purpose: `Miner.start()` runs
// a bounded session, so "keep mining" is start → await "finished" → start again.
// Keeping that in JS means bridge latency never stalls a session.

import init, {
  BeeConnect,
  ensure_mining_keys_propagated,
  gen_mining_keys,
  get_miner_address_by_wallet_name,
  Miner,
  Wallet,
} from "./pkg/bee_sdk.js";

// ---- config injected by Dart before this script's API is used -------------
// window.__BEE_CFG = { appId, endpoints: [], apiUrl, sessionDurationMs, nacklEccSlot }
const CFG = () => window.__BEE_CFG;

const SESSION_KEY = "njd_miner_session_v1";
const SESSIONS_KEY = "njd_miner_sessions_v2";
const KEYS_PREFIX = "njd_miner_mining_keys_v1";

const logEl = document.getElementById("log");
function log(...args) {
  const line = args
    .map((a) => (typeof a === "string" ? a : JSON.stringify(a)))
    .join(" ");
  if (logEl) logEl.textContent = `${line}\n${logEl.textContent}`.slice(0, 4000);
  console.log("[bee]", ...args);
  // Forward to Dart. The WebView is offstage, so without this the log only
  // exists in a DOM node nobody can see and in adb logcat.
  try {
    emit("log", { line, at: Date.now() });
  } catch {
    // emit() is defined below this point during module init; ignore until ready.
  }
}

/** Post an event to Dart. Buffers until the inappwebview bridge exists — the
 *  bridge (`window.flutter_inappwebview.callHandler`) can be injected slightly
 *  after this module first runs, and a dropped event would strand the UI. */
const _pending = [];
function _flush() {
  if (!window.flutter_inappwebview?.callHandler) return;
  while (_pending.length) {
    window.flutter_inappwebview.callHandler("beeEvent", _pending.shift());
  }
}
function emit(type, payload = {}) {
  _pending.push({ type, ...payload });
  _flush();
}
window.addEventListener("flutter_inappwebview_platform_ready", _flush);
setInterval(_flush, 1000); // cheap safety net for the life of the page

// ---- storage -------------------------------------------------------------
// ---- wallet storage -----------------------------------------------------
//
// v1 stored a single connected wallet under SESSION_KEY. v2 stores a list, so
// several wallets can mine at once. The v1 key is migrated on first read and
// then left alone: an install that downgrades still finds its wallet, and an
// upgrade never lands on the connect screen having silently lost it.
//
// KEYS_PREFIX entries are untouched — keysKey() already keys them by
// profileAddress:appId, so per-wallet mining keys were always multi-wallet
// ready and migrate for free.
function walletId(conn) {
  return conn?.profileAddress || conn?.walletName || null;
}

function readSessions() {
  let list = null;
  try {
    list = JSON.parse(localStorage.getItem(SESSIONS_KEY) || "null");
  } catch {
    list = null;
  }
  if (Array.isArray(list)) return list.filter(Boolean);

  // migrate v1 -> v2
  let one = null;
  try {
    one = JSON.parse(localStorage.getItem(SESSION_KEY) || "null");
  } catch {
    one = null;
  }
  const migrated = one ? [one] : [];
  if (one) writeSessions(migrated);
  return migrated;
}

function writeSessions(list) {
  const arr = (list || []).filter(Boolean);
  localStorage.setItem(SESSIONS_KEY, JSON.stringify(arr));
  // Keep the v1 key pointing at the first wallet so a downgrade still works.
  if (arr.length) localStorage.setItem(SESSION_KEY, JSON.stringify(arr[0]));
  else localStorage.removeItem(SESSION_KEY);
}

function readSession() {
  return readSessions()[0] || null;
}

function writeSession(s) {
  const list = readSessions();
  if (!s) {
    writeSessions([]);
    return;
  }
  const id = walletId(s);
  const i = list.findIndex((w) => walletId(w) === id);
  if (i >= 0) list[i] = s;
  else list.push(s);
  writeSessions(list);
}
function keysKey(conn) {
  return `${KEYS_PREFIX}:${conn.profileAddress}:${CFG().appId}`;
}
function readKeys(conn) {
  try {
    return JSON.parse(localStorage.getItem(keysKey(conn)) || "null");
  } catch {
    return null;
  }
}
function writeKeys(conn, v) {
  if (v) localStorage.setItem(keysKey(conn), JSON.stringify(v));
  else localStorage.removeItem(keysKey(conn));
}

// ---- sdk bootstrap ------------------------------------------------------
let sdkReady = null;
function ensureSdk() {
  if (!sdkReady) {
    sdkReady = init({ module_or_path: new URL("./pkg/bee_sdk_bg.wasm", import.meta.url) });
  }
  return sdkReady;
}

// ---- helpers ----------------------------------------------------------
function nanoToDisplay(value, decimals = 9, frac = 4) {
  let amount;
  try {
    amount = BigInt(value);
  } catch {
    return "0.0000";
  }
  const base = 10n ** BigInt(decimals);
  const whole = amount / base;
  const rem = ((amount % base) * 10n ** BigInt(frac)) / base;
  return `${whole}.${rem.toString().padStart(frac, "0")}`;
}

// ---- miner state ----------------------------------------------------
//
// Auto-tap mining loop, ported from a working reference auto-miner:
//   Miner.new → can_start → read tap_sum → start(session) → tap ~70x with
//   jitter → stop → wait for acceptance → read tap_sum → get_reward → free
// The taps are what earn; the clock face tap is an optional extra.
// Global state. Everything per-wallet lives in a `W` slice inside `wallets`;
// `M` itself now holds only what is genuinely shared.
const M = {
  wallets: new Map(), // walletId -> W
  selected: null, // walletId the UI is showing / manual taps go to
};

/** A single wallet's slice of state. One of these per connected wallet. */
function makeWallet(conn) {
  return {
    conn,
    running: false, // user intent: keep looping
    loopAlive: false, // a loop is currently executing
    currentMiner: null, // the live Miner instance during a session (for add_tap)
    sessions: 0,
    tapsSent: 0,
    confirmed: 0,
    epochTaps: 0,
    epochStart: null, // _epochBigStart; reset budget when it changes
    errors: 0,
    lastGameRaw: null, // previous popitgame[slot] in nano, for the reward delta
    lastRewardEpoch: null, // epoch_5m_start of the last successful get_reward
  };
}

/** Register (or fetch) the state slice for a connection. */
function walletFor(conn) {
  const id = walletId(conn);
  if (!id) return null;
  let W = M.wallets.get(id);
  if (!W) {
    W = makeWallet(conn);
    M.wallets.set(id, W);
    if (!M.selected) M.selected = id;
  } else {
    W.conn = conn;
  }
  return W;
}

/** The wallet the UI is pointed at — manual taps and single-wallet reads. */
function selectedWallet() {
  return (M.selected && M.wallets.get(M.selected)) || M.wallets.values().next().value || null;
}

function allWallets() {
  return [...M.wallets.values()];
}

/** Shape a `get_miner_data()` result into the event payload the Dart side
 *  reads. Everything past the first four keys needs the extended
 *  `MinerAccountData` struct (rebuilt WASM) — the optional-chaining keeps this
 *  safe against an older bundle where the getters don't exist. */
function minerDataPayload(d) {
  return {
    tapSum: d?.tap_sum?.toString(),
    tapSum5m: d?.tap_sum_5m?.toString(),
    epochStart: d?.epoch_start?.toString(),
    epoch5mStart: d?.epoch_5m_start?.toString(),
    epoch5mStartOld: d?.epoch_5m_start_old?.toString(),
    tapsSize: d?.taps_size?.toString(),
    oldTapsSize: d?.old_taps_size?.toString(),
    modifiedTapSum: d?.modified_tap_sum?.toString(),
    miningDurSum: d?.mining_dur_sum?.toString(),
  };
}
function emitMinerData(d) {
  const p = minerDataPayload(d);
  log("miner_data", JSON.stringify(p));
  emit("miner_data", p);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rint = (a, b) => a + Math.random() * (b - a);
function safeNum(v) {
  try {
    if (v == null) return 0;
    if (typeof v === "bigint") return Number(v);
    if (typeof v === "string") return Number(BigInt(v));
    return Number(v);
  } catch {
    return 0;
  }
}

async function getMinerAddress(walletName) {
  await ensureSdk();
  return get_miner_address_by_wallet_name({
    client_config: { network: { endpoints: CFG().endpoints } },
    wallet_name: walletName,
  });
}

// ---- external-message discipline -------------------------------------
//
// Acki Nacki v0.19.1 replaced the single `ext_messages_cache_size` with
// per-DApp and per-account queue limits, and dropped the per-account default
// from 100 to 5 (node CHANGELOG). Every `cancel_session`, `submit_session_*`
// and `get_reward` is an external message to *our* miner account, so a session
// spends ~3-4 of that budget. Over it, the node answers 621 QUEUE_OVERFLOW
// ("Message queue is full") and the SDK surfaces it wrapped — e.g.
// "Cancel stale session data (KitError { … QUEUE_OVERFLOW … })".
//
// So: never have two of our own external messages in flight at once, and treat
// a queue-full answer as transient with a *long* backoff (retrying fast just
// spends more of the same budget).
const isQueueFull = (e) => {
  const s = String(e?.message || e);
  return s.includes("QUEUE_OVERFLOW") || s.includes("Message queue is full");
};

let _txChain = Promise.resolve();
/** Run `fn` after every previously queued external-message call has settled. */
function tx(fn) {
  const run = _txChain.then(fn, fn);
  _txChain = run.then(
    () => {},
    () => {},
  );
  return run;
}

async function newMiner(k) {
  await ensureSdk();
  // `Miner.new` reads getDetails and, if a previous session left
  // `submit_session_data` on-chain, sends a `cancel_session` external message —
  // which is exactly what hits the per-account queue cap.
  const delays = [20000, 40000, 80000];
  for (let r = 0; ; r++) {
    try {
      return await tx(() =>
        Miner.new(
          CFG().endpoints,
          CFG().appId,
          k.minerAddress,
          k.ownerPublic,
          k.ownerSecret,
        ),
      );
    } catch (e) {
      const s = String(e?.message || e);
      const transient = isQueueFull(e) || s.includes("Failed to fetch");
      if (!transient || r >= delays.length) throw e;
      log("newMiner retry", `${r + 1}/${delays.length}`, s.slice(0, 160));
      emitSession(W, "waiting", {
        reason: isQueueFull(e)
          ? "network message queue full — backing off"
          : "network unreachable — retrying",
      });
      await sleep(delays[r]);
    }
  }
}

function emitSession(W, phase, extra = {}) {
  emit("session", {
    // Which wallet this is about. Dart keys per-wallet rows on it and ignores
    // events for wallets it is not currently showing.
    walletId: walletId(W?.conn),
    walletName: W?.conn?.walletName || null,
    phase, // 'starting' | 'tapping' | 'submitting' | 'accepted' | 'idle' | 'waiting'
    n: W?.sessions ?? 0,
    tapsSent: W?.tapsSent ?? 0,
    confirmed: W?.confirmed ?? 0,
    epochTaps: W?.epochTaps ?? 0,
    epochBudget: CFG().maxTapsPerEpoch,
    ...extra,
  });
}

// One loop per wallet. `W` is that wallet's slice of state — every field the
// loop touches (conn, running, loopAlive, currentMiner, sessions, tapsSent,
// confirmed, epochTaps, epochStart, errors, lastRewardEpoch) is per-wallet, so
// N wallets mine independently without sharing anything but the SDK itself.
//
// The per-account external-message cap is per *miner account*, so each wallet
// has its own budget and the session-root/proof resends do not contend. Event
// polling is the shared resource: each Miner spawns its own poll thread, which
// is why this branch ships the 10s-poll WASM rather than the 2.5s single-wallet
// build.
async function runSessionLoop(W) {
  if (W.loopAlive) return;
  W.loopAlive = true;
  emit("mining_started");

  const cfg = CFG();
  const TAP_INT = cfg.tapIntervalMs;
  const JITTER = cfg.tapJitterPct;
  const SUBMIT_STAGGER = cfg.submitStaggerMs;

  // One `Miner` instance is reused across sessions. Its seed queue starts as
  // [seed, next_seed] and the SDK's own event thread pushes another seed on
  // every SeedUpdated, so a healthy instance keeps going. Reuse matters beyond
  // saving the ~10 s of setup: every `Miner.new` re-reads getDetails and, if a
  // session is still pending on-chain, spends an external message on
  // `cancel_session` — the scarce resource since v0.19.1.
  let miner = null;
  const dropMiner = () => {
    try {
      miner?.free?.();
    } catch {}
    miner = null;
    W.currentMiner = null;
  };

  while (W.running) {
    const k = W.conn ? readKeys(W.conn) : null;
    if (!k?.areKeysPropagated || !k.minerAddress) {
      emit("miner_error", { where: "loop", error: "mining keys not ready" });
      break;
    }

    if (W.epochTaps >= cfg.maxTapsPerEpoch) {
      emitSession(W, "waiting", { reason: "epoch tap budget reached" });
      await sleep(60000);
      continue;
    }

    try {
      if (!miner) {
        miner = await newMiner(k);
        W.currentMiner = miner;
      }

      // Seeds exhausted (or a worker somehow still running): this instance is
      // spent, so build a fresh one on the next pass.
      if (!(await miner.can_start())) {
        emitSession(W, "waiting", { reason: "no seed available yet" });
        dropMiner();
        await sleep(30000);
        continue;
      }

      // tap_sum before + epoch budget reset
      let tapBefore = 0;
      let epoch5m = null;
      try {
        const d = await miner.get_miner_data();
        tapBefore = safeNum(d?.tap_sum);
        epoch5m = d?.epoch_5m_start?.toString() ?? null;
        const es = d?.epoch_start?.toString() ?? null;
        if (es && es !== W.epochStart) {
          W.epochStart = es;
          W.epochTaps = 0;
          emit("epoch_rolled", { epochStart: es });
        }
        emitMinerData(d);
        d?.free?.();
      } catch (e) {
        log("pre tap_sum", String(e?.message || e));
      }

      // start session, wait for the worker's first callback (2s cap)
      let workerReady = false;
      let sessionAccepted = false;
      let proofSubmitted = false;
      let sessionEmpty = false;
      let sessionErr = null;
      await new Promise((resolve) => {
        const t = setTimeout(() => {
          workerReady = true;
          resolve();
        }, 2000);
        miner.start(cfg.sessionDurationMs, (message) => {
          let e;
          try {
            e = JSON.parse(message);
          } catch {
            return;
          }
          if (e.error) {
            // e.error is the worker's own label; the node's actual error text is
            // in e.data.message. Upstream also labelled proof failures "Submit
            // session root failed", so the label alone points at the wrong call.
            sessionErr = `${e.action}: ${e.error}${e.data?.message ? ` — ${e.data.message}` : ""}`;
          } else if (e.action === "submit_session_root_retry" || e.action === "submit_session_proof_retry") {
            // Not a failure: the node's queue is full and the worker is resending
            // the same session. Only a give-up arrives as e.error.
            log(`${e.action === "submit_session_root_retry" ? "session root" : "session proof"} queue-full — resending (attempt ${e.data?.attempt})`);
          } else if (e.action === "computation_completed" && e.data?.empty) {
            sessionEmpty = true;
          } else if (e.action === "submit_session_proof") {
            proofSubmitted = true;
          } else if (e.action === "session_accepted") {
            sessionAccepted = true;
          }
          if (["session_accepted", "submit_session_root", "submit_session_root_retry", "submit_session_proof", "submit_session_proof_retry", "computation_completed"].includes(e.action)) {
            emit("session_event", { action: e.action, error: e.error ?? null });
          }
          if (!workerReady) {
            workerReady = true;
            clearTimeout(t);
            resolve();
          }
        });
      });

      W.sessions += 1;
      W.tapsSent = 0;
      emitSession(W, "tapping");

      // ── auto-tap ──────────────────────────────────────────────
      const sessStart = Date.now();
      const budget = cfg.maxTapsPerEpoch - W.epochTaps;
      const tapCount = Math.min(cfg.tapsPerSession, budget);
      const safeUntil = sessStart + cfg.sessionDurationMs - TAP_INT * 2 - SUBMIT_STAGGER;

      for (let i = 0; i < tapCount && W.running && Date.now() < safeUntil; i++) {
        try {
          miner.add_tap(Math.round(rint(40, 360)), Math.round(rint(80, 640)));
          W.tapsSent++;
        } catch (e) {
          if (String(e?.message || e).includes("No running workers")) {
            await sleep(1000);
            if (Date.now() < safeUntil) {
              try {
                miner.add_tap(Math.round(rint(40, 360)), Math.round(rint(80, 640)));
                W.tapsSent++;
              } catch {}
            }
          }
        }
        if (i % 5 === 0) emitSession(W, "tapping");
        const jitter = TAP_INT * JITTER * (Math.random() * 2 - 1);
        await sleep(Math.max(300, TAP_INT + jitter));
      }

      // ── submit ────────────────────────────────────────────────
      // The 70 taps finish well inside the 330 s session, so stop the worker
      // now and let it submit. Two different waits follow, and the difference
      // matters:
      //
      //  * `submit_session_proof` is emitted by the worker itself the moment
      //    its send resolves — reliable, breaks early, so a long cap is free.
      //    This is a HARD gate: abandoning the session here (or freeing the
      //    miner, which kills the in-flight submission) is what strands
      //    `submit_session_data` on-chain, and the next `Miner.new` then has to
      //    spend an external message cancelling it.
      //  * `session_accepted` arrives via the SDK's 2.5 s GraphQL event poll —
      //    unreliable, so we never block on it. The reward accrues on-chain
      //    regardless; `tap_sum` climbing is the signal we use instead.
      emitSession(W, "submitting");
      await sleep(Math.random() * SUBMIT_STAGGER);
      try {
        miner.stop();
      } catch {}

      for (
        let w = 0;
        w < 60 && W.running && !proofSubmitted && !sessionErr && !sessionEmpty;
        w++
      ) {
        await sleep(3000);
      }
      if (!proofSubmitted && !sessionErr && !sessionEmpty) {
        log("proof never confirmed within 180s — session may be left pending");
      }

      // tap_sum after — poll until it reflects this session (cap ~48 s).
      let tapAfter = tapBefore;
      for (let retry = 0; retry < 12 && W.running; retry++) {
        try {
          const d = await miner.get_miner_data();
          tapAfter = safeNum(d?.tap_sum);
          epoch5m = d?.epoch_5m_start?.toString() ?? epoch5m;
          emitMinerData(d);
          d?.free?.();
          if (tapAfter > tapBefore) break;
        } catch (e) {
          log("post tap_sum", String(e?.message || e));
        }
        await sleep(4000);
      }
      const confirmed = Math.max(0, tapAfter - tapBefore);
      W.confirmed = confirmed;
      W.epochTaps += confirmed;

      // `get_reward` is documented as pointless more than once per reward
      // epoch (~1000 blocks), and it is one more external message against the
      // per-account cap — so skip it if the 5-minute epoch hasn't rolled.
      const rewardDue = !sessionErr && !sessionEmpty && (epoch5m == null || epoch5m !== W.lastRewardEpoch5m);
      if (rewardDue) {
        for (let r = 0; r < 3; r++) {
          try {
            await tx(() => miner.get_reward());
            W.lastRewardEpoch5m = epoch5m;
            break;
          } catch (e) {
            if (isQueueFull(e) && r < 2) {
              await sleep((r + 1) * 20000);
            } else {
              log("get_reward", String(e?.message || e));
              break;
            }
          }
        }
      }

      emit("session_finished", {
        sessions: W.sessions,
        tapsSent: W.tapsSent,
        confirmed,
        epochTaps: W.epochTaps,
        empty: sessionEmpty,
        error: sessionErr,
      });
      emitSession(W, "idle", { empty: sessionEmpty, error: sessionErr });

      window.Bee?.refreshBalance?.().catch(() => {});
      W.errors = 0;

      // Keep the miner: the next session reuses its seed queue.
      if (sessionErr && isQueueFull({ message: sessionErr })) {
        // The node is shedding our messages; give its queue room to drain
        // before spending more of the per-account budget.
        emitSession(W, "waiting", { reason: "network message queue full — backing off" });
        await sleep(60000);
      } else {
        await sleep(2000 + Math.random() * cfg.sessionBoundaryJitterMs);
      }
    } catch (e) {
      W.errors++;
      emit("miner_error", { where: "session", error: String(e?.message || e) });
      dropMiner();
      await sleep(Math.min(15000 * 2 ** Math.min(W.errors - 1, 4), 120000));
    }
  }

  dropMiner();
  W.loopAlive = false;
  emit("mining_stopped");
}

// ---- public API (window.Bee) ---------------------------------------
window.Bee = {
  async init() {
    await ensureSdk();
    // Register every stored wallet (readSessions migrates a v1 install).
    for (const conn of readSessions()) walletFor(conn);
    const sel = selectedWallet();
    emit("ready", {
      connected: !!sel,
      walletName: sel?.conn?.walletName || null,
      wallets: allWallets().map((W) => ({
        walletId: walletId(W.conn),
        walletName: W.conn?.walletName || null,
        keysReady: !!readKeys(W.conn)?.areKeysPropagated,
      })),
    });
    if (sel) {
      if (readKeys(sel.conn)?.areKeysPropagated) emit("keys_ready");
      this.refreshBalance().catch(() => {});
    }
    return { connected: !!sel, wallets: M.wallets.size };
  },

  /** The connected wallets. The UI re-reads this after connect/disconnect
   *  rather than relying on the one-shot `ready` event, which is emitted only
   *  at init and so goes stale the moment a wallet is added. */
  async listWallets() {
    return allWallets().map((W) => ({
      walletId: walletId(W.conn),
      walletName: W.conn?.walletName || null,
      keysReady: !!readKeys(W.conn)?.areKeysPropagated,
      mining: !!W.running,
    }));
  },

  /** Start a wallet-connect session. Returns the deep link for the QR code. */
  async startConnect() {
    await ensureSdk();
    const beeConnect = new BeeConnect();
    const session = beeConnect.create_shared_key_session(
      CFG().appId,
      CFG().connectSessionTtlSec || 1800,
      null,
    );
    emit("connect_pending", { sessionId: session.session_id });

    (async () => {
      try {
        const hello = await beeConnect.wait_wallet_hello(
          CFG().endpoints,
          session.session_id,
          session.description,
          session.client_dh_secret,
          session.created_at,
          180,
          1000,
        );
        const conn = {
          walletName: hello.wallet_name,
          walletAddress: hello.wallet_address,
          profileAddress: hello.profile_address,
          sessionId: session.session_id,
          description: session.description,
          sessionStateJson: hello.session_state_json,
        };
        writeSession(conn); // appends, or updates in place if already known
        walletFor(conn);
        // A freshly connected wallet becomes selected, so the authorise step
        // that follows acts on it.
        M.selected = walletId(conn);
        emit("wallet_connected", { walletId: walletId(conn), walletName: conn.walletName });
        this.refreshBalance().catch(() => {});
      } catch (e) {
        emit("connect_error", { error: String(e?.message || e) });
      }
    })();

    return { deepLink: session.deep_link, sessionId: session.session_id };
  },

  async requestMiningKeys() {
    const conn = selectedWallet()?.conn;
    if (!conn) throw new Error("no wallet connected");

    // A connect session lives 24h. Past that, request_set_mining_keys fails deep
    // in the SDK with "rekey_outbound: Connect session expired at <epoch>",
    // which says nothing about which wallet or what to do. Check first and say
    // it plainly — the wallet has to be reconnected, not re-authorised.
    const expiresAt = (() => {
      try {
        return JSON.parse(conn.sessionStateJson || "{}").expires_at || 0;
      } catch {
        return 0;
      }
    })();
    if (expiresAt && Date.now() / 1000 > expiresAt) {
      throw new Error(
        `The connect session for "${conn.walletName}" expired on ` +
          `${new Date(expiresAt * 1000).toLocaleString()}. Disconnect this ` +
          `wallet and connect it again to re-authorise it.`,
      );
    }

    await ensureSdk();

    const generated = await gen_mining_keys(CFG().appId);
    // TVM SDK serialises uint256 map values WITH a 0x prefix — the mining key
    // must be passed prefixed or it never matches on the miner contract.
    const prefixedPublic = generated.public.startsWith("0x")
      ? generated.public
      : "0x" + generated.public;
    const beeConnect = new BeeConnect();
    const req = await beeConnect.request_set_mining_keys(
      CFG().endpoints,
      conn.sessionId,
      conn.description,
      conn.sessionStateJson,
      CFG().appId,
      prefixedPublic,
      30,
      1000,
    );
    if (req.updated_session_state_json) {
      conn.sessionStateJson = req.updated_session_state_json;
      writeSession(conn);
    }
    writeKeys(conn, {
      ownerPublic: generated.public,
      ownerSecret: generated.secret,
      minerAddress: null,
      areKeysPropagated: false,
    });
    emit("keys_propagating");

    (async () => {
      try {
        const minerAddress = await getMinerAddress(conn.walletName);
        await ensure_mining_keys_propagated({
          client_config: { network: { endpoints: CFG().endpoints } },
          miner_address: minerAddress,
          app_id: CFG().appId,
          expected_owner_public: prefixedPublic,
          max_attempts: 120,
          interval_ms: 2000,
        });
        writeKeys(conn, {
          ownerPublic: generated.public,
          ownerSecret: generated.secret,
          minerAddress,
          areKeysPropagated: true,
        });
        emit("keys_ready");
      } catch (e) {
        emit("keys_error", { error: String(e?.message || e) });
      }
    })();
  },

  /** Start mining. With no id, starts every wallet whose keys are ready.
   *
   *  Wallets are offset at *start*, not only at submit: without it N wallets
   *  march in lockstep and hit the node together on every phase boundary, and
   *  submit-time jitter cannot undo an alignment the sessions began with.
   */
  async startMining(targetId = null) {
    const targets = targetId ? [M.wallets.get(targetId)].filter(Boolean) : allWallets();
    if (!targets.length) throw new Error("no wallet connected");

    const stagger = CFG().walletStartStaggerMs ?? 1500;
    let started = 0;
    for (const W of targets) {
      if (W.running) continue;
      const k = readKeys(W.conn);
      if (!k?.areKeysPropagated || !k.minerAddress) {
        // One unprepared wallet must not stop the others from mining.
        emit("miner_error", {
          where: "start",
          walletId: walletId(W.conn),
          walletName: W.conn?.walletName || null,
          error: "mining keys not ready",
        });
        continue;
      }
      W.running = true;
      if (started) await sleep(stagger + Math.random() * stagger);
      runSessionLoop(W);
      started += 1;
    }
    if (!started && targets.length === 1) throw new Error("mining keys not ready");
    return { started };
  },

  async stopMining(targetId = null) {
    const targets = targetId ? [M.wallets.get(targetId)].filter(Boolean) : allWallets();
    for (const W of targets) {
      W.running = false;
      try {
        W.currentMiner?.stop();
      } catch (e) {
        log("stop error", String(e?.message || e));
      }
    }
  },

  /** Optional bonus tap from a real touch on the clock face. Only lands if a
   *  session is currently tapping. */
  async addTap(x, y) {
    // With several wallets mining at once "the current miner" is ambiguous, so
    // a real touch goes to the wallet the UI is showing — never to whichever
    // session happens to be live.
    const W = selectedWallet();
    try {
      W?.currentMiner?.add_tap(Math.max(0, Math.round(x)), Math.max(0, Math.round(y)));
      if (W) W.tapsSent++;
      emit("tap", { x, y, walletId: walletId(W?.conn) });
    } catch (e) {
      log("addTap error", String(e?.message || e));
    }
  },

  async claimReward(targetId = null) {
    const W = targetId ? M.wallets.get(targetId) : selectedWallet();
    const k = W?.conn ? readKeys(W.conn) : null;
    if (!k?.minerAddress) throw new Error("no miner");
    const miner = W?.currentMiner ?? (await newMiner(k));
    try {
      await tx(() => miner.get_reward());
      emit("reward_claimed");
      window.Bee.refreshBalance().catch(() => {});
    } finally {
      if (miner !== W?.currentMiner) miner.free?.();
    }
  },

  async refreshBalance(targetId = null) {
    const W = targetId ? M.wallets.get(targetId) : selectedWallet();
    if (!W?.conn) return;
    await ensureSdk();
    const wallet = new Wallet(CFG().endpoints, null, CFG().apiUrl, CFG().appId);
    try {
      const native = await wallet.get_multifactor_balances({
        multifactor_address: W.conn.walletAddress,
      });
      let tokens = {};
      try {
        const t = await wallet.get_tokens_balances({
          multifactor_address: W.conn.walletAddress,
        });
        tokens = t.tokens ?? {};
      } catch (e) {
        log("tokens balance err", String(e?.message || e));
      }

      const ecc = native.ecc ?? {};
      const popitgame = native.popitgame ?? {};
      const slot = CFG().nacklEccSlot;
      // `popitgame[slot]` is the locked mining-rewards bucket (confirmed) —
      // that's the headline NACKL number. `ecc[slot]` is liquid/unlocked.
      // Diff successive `popitgame` reads to surface the last reward that
      // landed; do it in BigInt so nano-precision survives.
      const gameRaw = popitgame[slot] != null ? String(popitgame[slot]) : null;
      let lastReward = null;
      if (gameRaw != null && W.lastGameRaw != null) {
        try {
          const delta = BigInt(gameRaw) - BigInt(W.lastGameRaw);
          if (delta > 0n) lastReward = nanoToDisplay(delta.toString(), 9, 4);
        } catch {}
      }
      if (gameRaw != null) W.lastGameRaw = gameRaw;

      emit("balance", {
        liquid: nanoToDisplay(ecc[slot] ?? "0", 9, 4),
        game: gameRaw != null ? nanoToDisplay(gameRaw, 9, 4) : null,
        gameRaw,
        lastReward,
        raw: {
          ecc: Object.fromEntries(Object.entries(ecc)),
          popitgame: Object.fromEntries(Object.entries(popitgame)),
          tokens: Object.fromEntries(Object.entries(tokens)),
        },
      });
    } finally {
      wallet.free?.();
    }
  },

  async minerData(targetId = null) {
    const src = (targetId ? M.wallets.get(targetId) : selectedWallet())?.currentMiner;
    if (!src) return;
    try {
      const d = await src.get_miner_data();
      emitMinerData(d);
      d.free?.();
    } catch (e) {
      log("minerData error", String(e?.message || e));
    }
  },

  async disconnect() {
    // Stop the miner before tearing down the session so no session keeps
    // submitting against keys we're about to revoke.
    const W = selectedWallet();
    if (W) W.running = false;
    try {
      W?.currentMiner?.stop();
    } catch (e) {
      log("disconnect stop err", String(e?.message || e));
    }

    try {
      if (W?.conn) {
        const beeConnect = new BeeConnect();
        await beeConnect.disconnect_session(
          CFG().endpoints,
          W.conn.sessionId,
          W.conn.description,
          W.conn.sessionStateJson,
          "user_requested",
          30,
          1000,
        );
      }
    } catch (e) {
      log("disconnect error", String(e?.message || e));
    }
    try {
      W?.currentMiner?.free?.();
    } catch {}

    // Drop only this wallet — the others keep mining.
    const gone = walletId(W?.conn);
    if (W?.conn) writeKeys(W.conn, null);
    if (gone) {
      M.wallets.delete(gone);
      writeSessions(readSessions().filter((c) => walletId(c) !== gone));
      if (M.selected === gone) M.selected = allWallets().length ? walletId(allWallets()[0].conn) : null;
    }
    emit("disconnected", { walletId: gone, remaining: M.wallets.size });
  },
};

log("runner loaded; waiting for Bee.init()");
emit("runner_loaded");
