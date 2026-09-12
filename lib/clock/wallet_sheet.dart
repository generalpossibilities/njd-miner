import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../mining/bee_miner.dart';
import '../overlay/overlay_manager.dart';

/// Bottom sheet: connect AN Wallet → authorise mining keys → (mining then
/// arms). When a wallet is already connected it shows balances + a disconnect
/// button instead.
class WalletSheet extends StatefulWidget {
  const WalletSheet({super.key, required this.miner, required this.overlay});

  final BeeMiner miner;
  final OverlayManager overlay;

  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  WalletConnectRequest? _request;
  bool _busy = false;
  String? _error;
  StreamSubscription<MinerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.miner.states.listen((_) {
      if (mounted) setState(() {});
    });
    // Pull a fresh balance so the debug dump is current.
    widget.miner.refreshBalance().catchError((_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _connected =>
      widget.miner.state.phase.index >= MinerPhase.needsMiningKeys.index &&
      widget.miner.state.phase != MinerPhase.crashed;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final req = await widget.miner.connectWallet();
      if (req == null) {
        await _authorise();
        return;
      }
      setState(() => _request = req);
      await req.completed;
      if (!mounted) return;
      setState(() => _request = null);
      await _authorise();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authorise() async {
    setState(() => _busy = true);
    try {
      await widget.miner.requestMiningKeys();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            backgroundColor: const Color(0xFF1B1C1F),
            title: const Text('Disconnect wallet?'),
            content: const Text(
              'Mining stops and the mining keys are removed from this device. '
              'You can reconnect the same wallet later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.miner.disconnect();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.miner.state;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _connected ? 'Wallet' : 'Mining setup',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (!_connected)
            const Text(
              'NACKL is mined with the official Bee Engine and paid to your '
              'Acki Nacki wallet. Connect once, then tap the clock face while '
              'it is on screen to mine.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 20),

          if (_request != null)
            _qr(_request!)
          else if (_connected)
            _connectedBody(state)
          else
            _stepButton(state.phase),

          if (_error != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectedBody(MinerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _balanceRow('Mining rewards (locked)', state.gameBalance, strong: true),
        _balanceRow(
          'Last reward',
          state.lastReward == null ? null : '+${state.lastReward}',
        ),
        _balanceRow('Liquid (unlocked)', state.nacklBalance),
        const Divider(color: Colors.white12, height: 20),
        const Text(
          'On-chain miner state',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 4),
        _balanceRow('Epoch taps (since era start)', state.tapSum),
        _balanceRow('Taps this 5-min epoch', '${state.tapSum5m}'),
        _balanceRow('Sessions this 5-min epoch', '${state.tapsSize}'),
        _balanceRow(
          'Reputation-weighted taps',
          state.modifiedTapSum,
        ),
        _balanceRow('Mining-duration sum', state.miningDurSum),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: _busy ? null : _disconnect,
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Disconnect'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Log',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy log',
              icon: const Icon(Icons.copy, size: 14, color: Colors.white38),
              onPressed: () => Clipboard.setData(
                ClipboardData(text: widget.miner.logLines.join('\n')),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear log',
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.white38,
              ),
              onPressed: () => setState(() => widget.miner.clearLog()),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          // Taller now the floating-clock switch has gone from above it — the
          // log is what this space is actually useful for.
          height: 300,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Builder(
            builder: (_) {
              final lines = widget.miner.logLines;
              if (lines.isEmpty) {
                return const Text(
                  'No log output yet.',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                );
              }
              // Newest first: the interesting line is almost always the last
              // thing that happened, and this panel is short.
              final shown = lines.reversed.toList();
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: shown.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    shown[i],
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _balanceRow(String label, String? value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value ?? '—',
            style: TextStyle(
              color: strong ? const Color(0xFF6BE28B) : Colors.white,
              fontSize: strong ? 16 : 14,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(MinerPhase phase) {
    final (text, action) = switch (phase) {
      MinerPhase.needsMiningKeys => ('Authorise mining keys', _authorise),
      MinerPhase.propagatingKeys => ('Registering keys on-chain…', null),
      _ => ('Connect Acki Nacki wallet', _connect),
    };
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy || action == null ? null : action,
        child:
            _busy
                ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(text),
      ),
    );
  }

  Widget _qr(WalletConnectRequest req) {
    return Column(
      children: [
        const Text(
          'Scan in the Acki Nacki Wallet app',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: QrImageView(data: req.deepLink, size: 220),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed:
              () => launchUrl(
                Uri.parse(req.deepLink),
                mode: LaunchMode.externalApplication,
              ),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open wallet on this phone'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Waiting for wallet confirmation…',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}
