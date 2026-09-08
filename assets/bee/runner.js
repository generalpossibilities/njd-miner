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
const KEYS_PREFIX = "njd_miner_mining_keys_v1";

const logEl = document.getElementById("log");
function log(...args) {
  const line = args
    .map((a) => (typeof a === "string" ? a : JSON.stringify(a)))
    .join(" ");
  if (logEl) logEl.textContent = `${line}\n${logEl.textContent}`.slice(0, 4000);
  console.log("[bee]", ...args);
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
function readSession() {
  try {
    return JSON.parse(localStorage.getItem(SESSION_KEY) || "null");
  } catch {
    return null;
  }
}
function writeSession(s) {
  if (s) localStorage.setItem(SESSION_KEY, JSON.stringify(s));
  else localStorage.removeItem(SESSION_KEY);
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
const M = {
  conn: null,
  miner: null,
  running: false, // user intent: keep the re-arm loop going
  sessionActive: false, // a start() session is currently in flight
  sessions: 0,
};

async function getMinerAddress(walletName) {
  await ensureSdk();
  return get_miner_address_by_wallet_name({
    client_config: { network: { endpoints: CFG().endpoints } },
    wallet_name: walletName,
  });
}

async function initMinerInstance(minerAddress, ownerPublic, ownerSecret) {
  await ensureSdk();
  return Miner.new(CFG().endpoints, CFG().appId, minerAddress, ownerPublic, ownerSecret);
}

function handleMinerCallback(message) {
  let payload;
  try {
    payload = JSON.parse(message);
  } catch {
    return;
  }
  if (payload.error) {
    emit("miner_error", { where: payload.action || "miner", error: payload.error });
    M.sessionActive = false;
    return;
  }
  if (payload.action === "status_updated" && payload.data?.status) {
    const status = payload.data.status;
    emit("session_status", { status });
    if (status === "finished" || status === "removed") {
      M.sessionActive = false;
      if (status === "finished") {
        M.sessions += 1;
        emit("session_finished", { sessions: M.sessions });
      }
      // Re-arm.
      if (M.running) queueMicrotask(runLoopTick);
    }
  }
}

async function runLoopTick() {
  if (!M.running || M.sessionActive || !M.miner) return;
  try {
    if (!M.miner.can_start()) {
      // Not ready yet; poll again shortly.
      setTimeout(runLoopTick, 1500);
      return;
    }
    M.sessionActive = true;
    emit("session_status", { status: "starting" });
    M.miner.start(CFG().sessionDurationMs, handleMinerCallback);
  } catch (e) {
    M.sessionActive = false;
    emit("miner_error", { where: "start", error: String(e?.message || e) });
    if (M.running) setTimeout(runLoopTick, 3000);
  }
}

// ---- public API (window.Bee) ---------------------------------------
window.Bee = {
  async init() {
    await ensureSdk();
    M.conn = readSession();
    emit("ready", { connected: !!M.conn, walletName: M.conn?.walletName || null });
    if (M.conn) {
      const k = readKeys(M.conn);
      if (k?.areKeysPropagated) emit("keys_ready");
      this.refreshBalance().catch(() => {});
    }
    return { connected: !!M.conn };
  },

  /** Start a wallet-connect session. Returns the deep link for the QR code. */
  async startConnect() {
    await ensureSdk();
    const beeConnect = new BeeConnect();
    const session = beeConnect.create_shared_key_session(CFG().appId, 300, null);
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
        M.conn = {
          walletName: hello.wallet_name,
          walletAddress: hello.wallet_address,
          profileAddress: hello.profile_address,
          sessionId: session.session_id,
          description: session.description,
          sessionStateJson: hello.session_state_json,
        };
        writeSession(M.conn);
        emit("wallet_connected", { walletName: M.conn.walletName });
        this.refreshBalance().catch(() => {});
      } catch (e) {
        emit("connect_error", { error: String(e?.message || e) });
      }
    })();

    return { deepLink: session.deep_link, sessionId: session.session_id };
  },

  async requestMiningKeys() {
    if (!M.conn) throw new Error("no wallet connected");
    await ensureSdk();

    const generated = await gen_mining_keys(CFG().appId);
    const beeConnect = new BeeConnect();
    const req = await beeConnect.request_set_mining_keys(
      CFG().endpoints,
      M.conn.sessionId,
      M.conn.description,
      M.conn.sessionStateJson,
      CFG().appId,
      generated.public,
      30,
      1000,
    );
    if (req.updated_session_state_json) {
      M.conn.sessionStateJson = req.updated_session_state_json;
      writeSession(M.conn);
    }
    writeKeys(M.conn, {
      ownerPublic: generated.public,
      ownerSecret: generated.secret,
      minerAddress: null,
      areKeysPropagated: false,
    });
    emit("keys_propagating");

    (async () => {
      try {
        const minerAddress = await getMinerAddress(M.conn.walletName);
        await ensure_mining_keys_propagated({
          client_config: { network: { endpoints: CFG().endpoints } },
          miner_address: minerAddress,
          app_id: CFG().appId,
          expected_owner_public: generated.public,
          max_attempts: 120,
          interval_ms: 2000,
        });
        writeKeys(M.conn, {
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

  async startMining() {
    if (M.running) return;
    if (!M.conn) throw new Error("no wallet connected");
    const k = readKeys(M.conn);
    if (!k?.areKeysPropagated || !k.minerAddress) throw new Error("mining keys not ready");

    if (!M.miner) {
      emit("session_status", { status: "init" });
      M.miner = await initMinerInstance(k.minerAddress, k.ownerPublic, k.ownerSecret);
    }
    M.running = true;
    emit("mining_started");
    runLoopTick();
  },

  async stopMining() {
    M.running = false;
    try {
      M.miner?.stop();
    } catch (e) {
      log("stop error", String(e?.message || e));
    }
    M.sessionActive = false;
    emit("mining_stopped");
  },

  /** Real touch on the clock face. x/y are logical pixels. */
  async addTap(x, y) {
    try {
      M.miner?.add_tap(Math.max(0, Math.round(x)), Math.max(0, Math.round(y)));
      emit("tap", { x, y });
    } catch (e) {
      log("addTap error", String(e?.message || e));
    }
  },

  async claimReward() {
    if (!M.miner) throw new Error("miner not initialised");
    await M.miner.get_reward();
    emit("reward_claimed");
    this.refreshBalance().catch(() => {});
  },

  async refreshBalance() {
    if (!M.conn) return;
    await ensureSdk();
    const wallet = new Wallet(CFG().endpoints, null, CFG().apiUrl, CFG().appId);
    try {
      const native = await wallet.get_multifactor_balances({
        multifactor_address: M.conn.walletAddress,
      });
      let tokens = {};
      try {
        const t = await wallet.get_tokens_balances({
          multifactor_address: M.conn.walletAddress,
        });
        tokens = t.tokens ?? {};
      } catch (e) {
        log("tokens balance err", String(e?.message || e));
      }

      const ecc = native.ecc ?? {};
      const popitgame = native.popitgame ?? {};
      const slot = CFG().nacklEccSlot;
      // We don't yet know which bucket holds *locked* mining rewards — surface
      // all of them so the UI can show a debug dump and we can pick the right
      // one. `ecc[slot]` is the liquid/unlocked NACKL.
      emit("balance", {
        liquid: nanoToDisplay(ecc[slot] ?? "0", 9, 4),
        game: popitgame[slot] != null ? nanoToDisplay(popitgame[slot], 9, 4) : null,
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

  async minerData() {
    if (!M.miner) return;
    try {
      const d = await M.miner.get_miner_data();
      emit("miner_data", {
        tapSum: d.tap_sum?.toString(),
        tapSum5m: d.tap_sum_5m?.toString(),
        epochStart: d.epoch_start?.toString(),
        epoch5mStart: d.epoch_5m_start?.toString(),
      });
      d.free?.();
    } catch (e) {
      log("minerData error", String(e?.message || e));
    }
  },

  async disconnect() {
    // Stop the miner before tearing down the session so no session keeps
    // submitting against keys we're about to revoke.
    M.running = false;
    try {
      M.miner?.stop();
    } catch (e) {
      log("disconnect stop err", String(e?.message || e));
    }
    M.sessionActive = false;

    try {
      if (M.conn) {
        const beeConnect = new BeeConnect();
        await beeConnect.disconnect_session(
          CFG().endpoints,
          M.conn.sessionId,
          M.conn.description,
          M.conn.sessionStateJson,
          "user_requested",
          30,
          1000,
        );
      }
    } catch (e) {
      log("disconnect error", String(e?.message || e));
    }
    M.running = false;
    try {
      M.miner?.free?.();
    } catch {}
    M.miner = null;
    writeKeys(M.conn, null);
    writeSession(null);
    M.conn = null;
    emit("disconnected");
  },
};

log("runner loaded; waiting for Bee.init()");
emit("runner_loaded");
