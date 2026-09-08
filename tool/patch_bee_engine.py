#!/usr/bin/env python3
"""Extend `MinerAccountData` in a bee-engine checkout so `get_miner_data()`
returns the on-chain session / epoch fields the NJD Miner UI shows.

`serde` silently drops account-data keys that aren't in the struct, so the stock
SDK only ever hands JS four fields (`epoch_start`, `epoch_5m_start`, `tap_sum`,
`tap_sum_5m`). This adds `_epochStartOld`, `_tapsSize`, `_oldTapsSize`,
`_modifiedTapSum` and `_miningDurSum` as extra aliased fields.

Idempotent. Run by tool/sync_bee_sdk.sh and .github/workflows/refresh-bee-sdk.yml
before the wasm-pack build. If upstream restructures the struct so the anchor
text below no longer matches, this exits non-zero so the drift is noticed.
"""
from __future__ import annotations

import sys
from pathlib import Path

ANCHOR = '''    #[serde(alias = "_tapSum5m", deserialize_with = "deserialize_u128")]
    pub tap_sum_5m: u128,
}'''

REPLACEMENT = '''    #[serde(alias = "_tapSum5m", deserialize_with = "deserialize_u128")]
    pub tap_sum_5m: u128,

    // ── NJD Miner extension (tool/patch_bee_engine.py) ──────────────────────
    #[serde(alias = "_epochStartOld", deserialize_with = "deserialize_u64", default)]
    pub epoch_5m_start_old: u64,

    /// `_tapsSize` — mining sessions recorded in the current ~5-minute reward
    /// epoch. Resets when `epoch_5m_start` rolls.
    #[serde(alias = "_tapsSize", deserialize_with = "deserialize_u128", default)]
    pub taps_size: u128,

    /// `_oldTapsSize` — session count from the previous ~5-minute epoch.
    #[serde(alias = "_oldTapsSize", deserialize_with = "deserialize_u128", default)]
    pub old_taps_size: u128,

    /// `_modifiedTapSum` — reputation-weighted tap total (drives the payout).
    #[serde(alias = "_modifiedTapSum", deserialize_with = "deserialize_u128", default)]
    pub modified_tap_sum: u128,

    /// `_miningDurSum` — total mining duration accrued this 24-hour epoch.
    #[serde(alias = "_miningDurSum", deserialize_with = "deserialize_u128", default)]
    pub mining_dur_sum: u128,
}'''

MARKER = "NJD Miner extension"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_bee_engine.py /path/to/bee-engine", file=sys.stderr)
        return 2

    target = Path(sys.argv[1]) / "bee_miner" / "src" / "wasm" / "mod.rs"
    if not target.is_file():
        print(f"!! {target} not found", file=sys.stderr)
        return 1

    src = target.read_text()
    if MARKER in src:
        print("   already patched")
        return 0
    if ANCHOR not in src:
        print(
            "!! MinerAccountData anchor not found — upstream layout changed, "
            "update tool/patch_bee_engine.py",
            file=sys.stderr,
        )
        return 1

    target.write_text(src.replace(ANCHOR, REPLACEMENT, 1))
    print("   patched", target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
