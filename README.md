# NJD Miner — a digital clock that mines NACKL

A full-screen Android **digital desk clock** that **auto-mines NACKL** (Acki
Nacki) with the **official Bee Engine**. Keep it on screen while docked or
charging; earnings go to your Acki Nacki wallet. A **floating overlay** mode
keeps it mining over other apps.

There is also a small **home-screen widget** (time + last-known NACKL balance +
mining state) that opens the clock when tapped.

> **How Bee Engine mining works.** A session runs `Miner.start(330 s)` and needs
> **taps** to produce a proof (`bee_miner`'s `worker.rs` submits nothing if the
> tap tree is empty). The runner **auto-taps ~70×/session** on a ~4 s interval
> with jitter and random coordinates — matching a working reference auto-miner.
> Reward scales with confirmed taps per session; ~70 is the session max, capped
> at 12 000 taps per global epoch. A touch on the clock face is an optional
> bonus tap.

---

## ⚠️ Read this before you build

These are structural constraints, not TODOs — they shape what this app can be.

| # | Constraint | Consequence |
|---|---|---|
| 1 | **Bee Engine has no Flutter/native SDK.** It ships only as a browser-WASM bundle (`@teamgosh/bee-sdk`, built from the [`gosh-sh/bee-engine`](https://github.com/gosh-sh/bee-engine) Rust workspace). It is **not on npm**. | This app runs the SDK inside a hidden `InAppWebView`. You must build the WASM yourself (see below). |
| 2 | **The miner is single-threaded and cooperative** (a `spawn_local` future yielding to the JS event loop via `setTimeout`). No `SharedArrayBuffer`, so **no** COOP/COEP cross-origin-isolation headers are needed. | A plain localhost static server is enough. But… |
| 3 | **Chromium freezes WebView JS timers when the activity isn't visible.** A background isolate (`flutter_foreground_task`) cannot host a WebView either. **Battery / "unrestricted" settings do not change this** — it is a Chromium rendering rule, not an OS power-management decision. | **Mining only happens while the clock (or the floating overlay) is on screen and the screen is on.** That's why this is a *screen-on desk clock*, not a silent background miner. The foreground service only buys process priority + the required notification. True 24/7 mining needs a **cloud miner** running `@teamgosh/bee-sdk` in Node (see `dexchatsminermulti/backend/` for a working example), independent of the phone. |
| 4 | **Google Play prohibits on-device cryptocurrency mining** (Developer Program Policy). | Distribution is **sideload / APK / F-Droid only**. Do not expect to ship this on Play. |
| 5 | **`bee-engine` is AGPL-3.0.** Linking it into this app has copyleft implications for the combined work. | Get your own legal read before distributing. This repo's own code is otherwise yours to license. |
| 6 | **`app_dapp_id`** is issued by the Acki Nacki team. This repo is set to `0x…0019` (`lib/config/bee_config.dart`). | If mining attributes nothing, re-confirm the id and network with the team. |
| 7 | **Rewards appear to be gated on ecosystem onboarding** (activating via official apps like Ludo/Batteries/Popits, "first part on Mambaboard"). | A brand-new wallet may show a permanently-zero balance. That is expected, not a bug in this app. |
| 8 | The upstream example is **internally inconsistent about network** — `endpoints` = `mainnet.ackinacki.org` while its UI says "shellnet". | Confirm the target network with the Acki Nacki team and set `lib/config/bee_config.dart` accordingly. |
| 9 | **A mining session only submits a proof if it got taps.** In `bee_miner`'s `worker.rs`, a session builds a `time` tree (auto-filled) and a `tap` tree (filled by `add_tap`). Empty tap tree → nothing submitted. | The runner auto-taps in `assets/bee/runner.js` (`runSessionLoop`); a `computation_completed` event with `data.empty` means the session earned zero. |

A platform-correct v2 would host the FlutterView inside Android's `DreamService`
(the screensaver shown while charging/docked). v1 ships `keepScreenOn` +
`showWhenLocked`.

---

## Architecture

```
┌─────────────────────────────  Flutter (main isolate)  ──────────────────────────┐
│                                                                                 │
│  DigitalClockScreen ── ticks every 1s, renders ClockFace                         │
│        │  real touch on clock face → miner.addTap(x, y)   (never synthesised)    │
│        │  status stream → MiningStatusBar + HomeWidgetBridge + FGS notification  │
│        ▼                                                                         │
│  BeeMiner (interface)  ──  WebViewBeeMiner (impl)                                 │
│        │  callAsyncJavaScript(...)          ▲  callHandler('beeEvent', {...})     │
│        ▼                                    │                                     │
│  ┌──────────────  hidden 1×1 InAppWebView  ─┴───────────────────────────────┐    │
│  │  http://127.0.0.1:8737/index.html  (InAppLocalhostServer → assets/bee/)  │    │
│  │  runner.js  →  window.Bee.{init,startConnect,requestMiningKeys,          │    │
│  │                            startMining,stopMining,addTap,claimReward}    │    │
│  │  ./pkg/bee_sdk.js + bee_sdk_bg.wasm   (@teamgosh/bee-sdk, YOU build it)  │    │
│  │  re-arm loop: start(15s) → 'finished' → can_start() → start() …          │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  MiningForegroundService  ── process priority + persistent notification only     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

The re-arm loop lives in `runner.js` on purpose: `Miner.start()` runs a bounded
session, so "keep mining" is a JS loop where bridge latency can't stall it.

Swapping backends: everything Dart-side is behind `BeeMiner`
(`lib/mining/bee_miner.dart`). If the WebView path ever fails, or true background
mining becomes a requirement, a `flutter_rust_bridge` backend over the
`bee_miner` / `bee_connect` crates (the workspace does target native Rust) drops
in without touching the clock.

---

## What is and isn't verified

Built and checked on this machine:

- ✅ The Bee Engine WASM SDK **builds** from `gosh-sh/bee-engine` with the stock
  toolchain (Rust 1.95, system GCC — the README's "LLVM 21+" note did not bite
  here) → `bee_sdk.js` + a 9.6 MB `bee_sdk_bg.wasm`.
- ✅ The SDK's exports (`BeeConnect`, `Miner`, `Wallet`, `gen_mining_keys`,
  `ensure_mining_keys_propagated`, `get_miner_address_by_wallet_name`, default
  `init`) match what `assets/bee/runner.js` imports.
- ✅ `flutter analyze` is clean; `flutter test` (clock-face formatting) passes.
- ✅ Auto-tap session loop + all timing constants ported from a working
  reference auto-miner (`dexchatsminermulti/`).
- ✅ CI `check` + `ios` jobs pass (unsigned `.ipa` builds). `android` job fixed
  after the first run (Kotlin plugin bump for `package_info_plus`).

Not yet exercised:

- ⛔ A signed Android build end-to-end (needs the four `ANDROID_*` repo secrets set).
- ⛔ The WebView ↔ Dart bridge, the localhost server serving the 9.6 MB wasm,
  the wallet-connect handshake, and mining itself.

## Build

### CI (GitHub Actions)

`.github/workflows/build.yml` runs on every push/PR to `main`:

| Job | Runner | Output |
|---|---|---|
| `check` | ubuntu | `flutter analyze` + `flutter test` |
| `android` | ubuntu | `njd-miner-apk` artifact — one universal `njd-miner.apk` |
| `ios` | macos-14 | `njd-miner-ios-unsigned` artifact — unsigned `.ipa` |
| `release` | ubuntu | on a `v*` tag, attaches both to a GitHub Release |

`.github/workflows/refresh-bee-sdk.yml` (manual) rebuilds the WASM SDK from
upstream and opens a PR — run it when `gosh-sh/bee-engine` ships a change.

### App updates (install-over-the-top)

`--build-number ${{ github.run_number }}` makes every CI build's `versionCode` /
`CFBundleVersion` strictly increase, so newer builds are recognised as updates.

**Android** also needs a stable signing key. CI writes `android/key.properties`
from four repo secrets; if they are unset the APK falls back to **debug signing**
and won't install over a release build.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 njd-upload-keystore.p12` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_PASSWORD` | same (PKCS12, one password) |
| `ANDROID_KEY_ALIAS` | `upload` |

The keystore + the exact `gh secret set` commands are in `SECRETS.txt` (git-ignored).
**Back up `njd-upload-keystore.p12`** — without it you can never ship an update
that installs over existing installs.

**iOS**: the `.ipa` is unsigned. AltStore / Sideloadly resign it with *your*
Apple ID cert (stable), so updates install in place; the version bump above is
handled. For a properly signed build, add Apple signing secrets and switch the
`ios` job to `flutter build ipa --export-options-plist`.

### Local build

The `app_dapp_id` is already set in `lib/config/bee_config.dart` to
`0x…0019`. The built Bee Engine WASM is committed under `assets/bee/pkg/`, so:

```bash
flutter pub get
flutter run                         # real device / emulator with a browser engine
flutter build apk --release         # or: flutter build ios --release --no-codesign
```

To regenerate the WASM SDK (needs Rust + `wasm-pack`; LLVM 21+ only if the
stock `clang` can't build `blst` for wasm):

```bash
git clone https://github.com/gosh-sh/bee-engine.git
tool/sync_bee_sdk.sh ./bee-engine   # builds + copies into assets/bee/pkg/
```

### First launch

Long-press the clock (or the status-bar **Set up** button) → scan the QR in the
**Acki Nacki Wallet** app → approve the connection → approve the mining keys.
Once keys propagate on-chain, tap the clock face to mine.

---

## Project layout

| Path | Role |
|---|---|
| `lib/config/bee_config.dart` | **The one file you edit**: app id, endpoints, session length. |
| `lib/mining/bee_miner.dart` | Backend-agnostic `BeeMiner` interface + `MinerState`. |
| `lib/mining/webview_bee_miner.dart` | WebView + JS-bridge implementation. |
| `lib/mining/foreground_service.dart` | Foreground service (priority + notification only). |
| `assets/bee/runner.js` | JS wrapper around `@teamgosh/bee-sdk`; owns the mining loop. |
| `assets/bee/index.html` | Offstage host page for the WASM. |
| `lib/clock/` | The digital clock UI + status bar + wallet setup sheet. |
| `lib/widgets/home_widget_bridge.dart` | Pushes time/balance/status to the AppWidget. |
| `android/.../ClockWidgetProvider.kt` | Home-screen widget (native `TextClock` + last values). |

### App icon

Derived from `logo.jpg` (the notjustdex ND monogram). Source art is
`assets/icon/`; regenerate the platform icons with
`dart run flutter_launcher_icons` (config in `pubspec.yaml`).

### On the clock UI

The user asked for an open-source Flutter digital clock to integrate into. A
digital clock is a handful of `Text` widgets over a 1-second `Stream` — a
package (most are unmaintained Flutter Clock Challenge entries) would add a
dependency and buy nothing. `lib/clock/clock_face.dart` is written fresh, with
its visual style inspired by the Apache-2.0 `digital_clock` entry in
`flutter/samples`.

---

## Floating clock (overlay)

Wallet sheet → **Floating clock** toggle (needs "display over other apps"). It
shows a small draggable clock on top of every app via `flutter_overlay_window`.

> **This is an always-on-*top* overlay, not a wallpaper-style clock.** Android
> has exactly one window type an ordinary app may use for this
> (`TYPE_APPLICATION_OVERLAY`) and it renders **above** other apps — there is no
> app window type that sits *below* running apps (only the live wallpaper does,
> and a wallpaper cannot host this WebView or run the miner). A clock that is
> visible on the home screen and gets **covered** when you open an app is an
> Android **home-screen AppWidget** — this repo ships one
> (`ClockWidgetProvider`), but an AppWidget is `RemoteViews` and **cannot run
> WASM**, so it displays time + last-known balance only and does not mine.
> Mining always needs a visible Flutter/WebView surface: the full-screen clock
> or this overlay.

The overlay runs in its **own** Flutter engine, so it builds its own
`WebViewBeeMiner`. Same process + same `http://127.0.0.1` origin ⇒ that WebView
reads the wallet session and mining keys the main app stored. **Single-miner
rule:** while the overlay is up it owns mining and the main app's miner stands
down; closing the overlay hands mining back.

**This depends on an Android WebView platform view rendering inside an overlay
window — not guaranteed on every device.** The overlay self-detects: if the
miner doesn't come up within 12 s it switches to **display-only** and forwards
taps to the main app (which then mines only while it's foregrounded). The
overlay's status line says which mode you're in.

## Reward mechanics

Constants below come from a **working reference auto-miner** (`dexchatsminermulti/`,
git-ignored) — not from the official docs, which don't publish them.

| `BeeConfig` | Value | Meaning |
|---|---|---|
| `sessionDurationMs` | 330 000 | one `Miner.start()` session (5.5 min) |
| `tapsPerSession` | 70 | auto-taps per session; 70 = session max reward |
| `tapIntervalMs` / `tapJitterPct` | 4000 / 0.10 | delay between taps, ±10 % |
| `maxTapsPerEpoch` | 12 000 | on-chain cap per **global** epoch (`epochSpanBlocks` 262 000) |
| `submitStaggerMs` | 5000 | random delay before submit, desyncs WASM calls |

Per-session flow (`runSessionLoop` in `runner.js`): `Miner.new` → `can_start` →
read `tap_sum` → `start(330 s)` → auto-tap ~70× (stop early to avoid "No running
workers") → `stop` → wait for the proof to submit (**cap ~60 s** — *not* for a
`session_accepted` event; see below) → poll `tap_sum` until it climbs →
`confirmed = after − before` → `get_reward` → `free` → idle 2–5 s → repeat.
`confirmed` is what counts, not taps sent.

**Reward cadence (~6 min, not 5).** One reward epoch is ~1000 blocks ≈ 5.5 min,
so the ideal is one confirmed session per epoch. The 70 taps alone take ~4.7 min
(70 × 4 s). The old code sat ~10 min because it blocked up to 180 s waiting for a
`session_accepted` event that rides the (flaky) GraphQL events API. The runner no
longer waits on that event — the reward accrues on-chain regardless; it watches
`tap_sum` climb instead.

**Two waits, and the difference matters.** `session_accepted` arrives via the
SDK's 2.5 s `query_events` GraphQL poll — unreliable, so never block on it.
`submit_session_proof` is emitted by the worker itself the moment its send
resolves — reliable and early, so the runner *does* gate on it (cap 180 s, free
in the happy path). That gate is load-bearing: abandoning a session after the
root submitted but before the proof did leaves `submit_session_data` set
on-chain, and the next `Miner.new` then has to spend an external message
cancelling it — see the queue budget below.

**One `Miner`, many sessions.** The instance's seed queue starts as
`[seed, next_seed]` and the SDK's event thread pushes another on every
`SeedUpdated`, so the runner reuses one instance while `can_start()` holds and
only rebuilds when the seeds run dry. Each avoided `Miner.new` is one avoided
`getDetails` round-trip and one avoided `cancel_session` message.

**Locked vs liquid balance (confirmed):** `get_multifactor_balances` returns
`ecc["1"]` (liquid/unlocked NACKL) and `popitgame["1"]` (**locked mining
rewards** — the headline number). The runner diffs successive `popitgame` reads
in BigInt to surface the **last reward** that landed. The wallet sheet still
dumps the raw maps as a diagnostic.

**On-chain miner state.** `get_miner_data()` (extended `MinerAccountData`, needs
the rebuilt WASM) exposes `_tapSum` (taps this 24 h era — shown as "epoch
taps"), `_tapSum5m` (taps this 5-min epoch), `_tapsSize` (sessions this 5-min
epoch), `_modifiedTapSum` (reputation-weighted), `_miningDurSum`. These are the
on-chain figures the clock and wallet sheet show instead of local counters. The
contract has no single "sessions this 24 h" field; the reset behaviour of each
field is logged per session (`adb logcat | grep 'bee.*miner_data'`) to confirm
the labels against real data.

## The external-message budget (Acki Nacki v0.19.1)

Since **v0.19.1** (2026-08-26) the node no longer has one flat message cache. It
tracks the external-message queue per DApp *and per account*, and the
per-account default was cut hard — from the node CHANGELOG:

> Changed the default external-message queue limits in the `block-keeper`
> Ansible role: `EXT_MESSAGES_TOTAL_LIMIT` 250 → 1000, `EXT_MESSAGES_DAPP_LIMIT`
> 200 → 500, **`EXT_MESSAGES_ACCOUNT_LIMIT` 100 → 5**. A deployment needing a
> wider per-account allowance has to set the variable in its inventory.

Every `cancel_session`, `submit_session_root`, `submit_session_proof` and
`get_reward` is an external message to **your** miner contract account, so one
session spends 3–4 of that budget. Over it, the node answers TVM error **621
`QUEUE_OVERFLOW`** — "Message queue is full. Please try to send the message
later." The SDK wraps it, so it surfaces as e.g.:

```
Cancel stale session data (KitError { module: MvSystem(Miner), code: -1,
  message: Send message, tvm_erorr Some(ClientError(... code: 621,
  "Message queue is full. Please try to send the message later." ...
```

What `runner.js` does about it:

| Measure | Why |
|---|---|
| `tx()` serialises every SDK call that sends an external message | never two of ours in flight at once |
| `newMiner()` retries 621 at **20 / 40 / 80 s** | it is transient; retrying *fast* just spends more of the same budget |
| Hard `submit_session_proof` gate before reusing/freeing the miner | stops us stranding a session that then needs a `cancel_session` |
| `Miner` instance reuse | removes most `Miner.new` → most `cancel_session` attempts |
| `get_reward` at most once per ~5-min reward epoch | the docs say more often is pointless; it is one message saved |
| 621 is shown as "Network message queue full — retrying", **not** a crash | it is the network shedding load, and the runner recovers on its own |

This is a client-side mitigation, not a cure. The error text doesn't say *which*
limit tripped, and the miner account sits under `dapp_id …0001` — if every Bee
miner contract shares that DApp, the binding limit may be the DApp-wide 500
rather than your own 5, in which case only backoff helps and it will come and go
with network load. `node_ext_msg_queue_size_by_dapp` is node-side only, so a
client cannot tell the two apart. Since ~4 messages per session is inherent to
the Bee mining flow, this affects **every** Bee miner — worth raising upstream.

## Troubleshooting

**"WebView load error … cleartext" / miner never leaves "Loading Bee Engine…"**
The SDK is served over `http://127.0.0.1`; Android 9+ blocks cleartext by
default. `android/app/src/main/res/xml/network_security_config.xml` whitelists
loopback — make sure the manifest still points `android:networkSecurityConfig`
at it.

**Errors on the clock face** — a red banner shows the failure (selectable text,
plus a Retry). `adb logcat | grep bee-webview` shows the WebView console.

## On auto-tapping

The auto-tap loop uses jittered intervals and randomised `(x, y)` coordinates,
mirroring the reference implementation. The on-chain verifier "fully distrusts
the client" and scores on behaviour; a naive fixed-rate tap stream is the thing
that gets penalised, which is why the jitter and coordinate randomisation are
not optional decoration. If Acki Nacki tightens humanity checks, this is the
first thing that breaks.
