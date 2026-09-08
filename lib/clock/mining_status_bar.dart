import 'package:flutter/material.dart';

import '../mining/bee_miner.dart';

/// The thin strip under the clock: mining state + NACKL balance + a control.
class MiningStatusBar extends StatelessWidget {
  const MiningStatusBar({
    super.key,
    required this.state,
    required this.onConnectWallet,
    required this.onToggleMining,
  });

  final MinerState state;
  final VoidCallback onConnectWallet;
  final VoidCallback onToggleMining;

  /// Prefer the mining/game bucket (where rewards accrue) when the wallet has
  /// one; otherwise fall back to the liquid balance.
  String? get _balance => state.gameBalance ?? state.nacklBalance;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state.phase) {
      MinerPhase.loading => (
        'Loading Bee Engine…',
        Colors.white38,
        Icons.hourglass_empty,
      ),
      MinerPhase.needsWallet => (
        'Connect wallet',
        Colors.amber,
        Icons.account_balance_wallet_outlined,
      ),
      MinerPhase.needsMiningKeys => (
        'Authorise mining',
        Colors.amber,
        Icons.key_outlined,
      ),
      MinerPhase.propagatingKeys => (
        'Registering keys on-chain…',
        Colors.white54,
        Icons.sync,
      ),
      MinerPhase.idle => ('Idle', Colors.white70, Icons.play_arrow),
      MinerPhase.mining => (
        'Mining NACKL',
        const Color(0xFF6BE28B),
        Icons.bolt,
      ),
      MinerPhase.crashed => (
        state.error ?? 'Miner error',
        Colors.redAccent,
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 14, letterSpacing: 0.4),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_balance != null) ...[
            Text(
              '$_balance  NACKL',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
          ],
          _action(context),
        ],
      ),
    );
  }

  Widget _action(BuildContext context) {
    switch (state.phase) {
      case MinerPhase.needsWallet:
      case MinerPhase.needsMiningKeys:
        return TextButton(
          onPressed: onConnectWallet,
          child: const Text('Set up'),
        );
      case MinerPhase.idle:
        return IconButton(
          onPressed: onToggleMining,
          icon: const Icon(Icons.play_circle_fill, color: Colors.white),
        );
      case MinerPhase.mining:
        return IconButton(
          onPressed: onToggleMining,
          icon: const Icon(Icons.pause_circle_filled, color: Colors.white70),
        );
      default:
        return const SizedBox(width: 8);
    }
  }
}
