# NJD Miner — quick guide

Mines NACKL on Acki Nacki from your phone, using the wallet you already have in
the AN Wallet app.

## Setup (once)

1. **Connect wallet** — tap it on the clock screen. Scan the QR with AN Wallet,
   or tap the deep link if AN Wallet is on the same phone.
2. **Authorise mining** — approve the request in AN Wallet. This registers a
   mining key on-chain and takes up to a minute; the app waits for it.
3. Done. The wallet stays connected — you only do this again if you disconnect.

## Running it

- **Start / Stop** on the clock screen controls mining.
- Tap the clock face to add a bonus tap while a session is running.
- **Long-press the clock** (or use the wallet panel) to open your balances and log.

Each mining session runs about 5½ minutes: it taps, submits the result, and the
chain confirms it. Rewards are claimed automatically once per reward epoch, and
again when you press Stop.

## Keep it mining

**Mining only runs while the app is open and the screen is on.** Android
suspends the mining engine when the screen sleeps, so:

- Set **Settings → Display → Screen timeout** to a long value (or Never) while mining.
- Keep the app in the foreground, or use the **floating clock** so it keeps
  running over other apps.
- Allow the battery-optimisation prompt on first launch.

Best used plugged in — mining is continuous work and will warm the phone.

## Floating clock

A small always-on-top clock that keeps mining while you use other apps.

- Toggle it from the clock screen.
- **Tap the resize button** to step through sizes: default → small → smaller →
  smallest, then back. Long-press it to jump back to default.
- **Tap the reopen button** to bring the main app back when it's minimised.
- Drag it anywhere on screen.

## What the numbers mean

| Row | Meaning |
|---|---|
| Mining rewards (locked) | NACKL earned, still locked on-chain |
| Liquid (unlocked) | NACKL you can spend |
| Epoch taps (since era start) | Your total taps this era |
| Taps this 5-min epoch | Taps counted in the current reward epoch |
| Sessions this 5-min epoch | Sessions the chain recorded this epoch |

## If something looks wrong

**Nothing happens after Start** — check the log in the wallet panel. `keys
pending` means step 2 never completed; disconnect and reconnect the wallet.

**"Connect session expired"** — the link to AN Wallet lasts 24 hours. Disconnect
the wallet and connect it again.

**"queue-full — resending"** — normal. The network limits how many messages an
account can send at once; the app waits and retries on its own.

**Mining stopped on its own** — the screen almost certainly turned off. See
*Keep it mining*.
