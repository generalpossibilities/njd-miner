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
  Timer? _walletPoll;
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
    widget.miner.refreshBalance().catchError((_) {});
    // Re-read the wallet list from the runner rather than trusting whatever the
    // one-shot `ready` event left behind — that is how a second wallet ended up
    // showing alone with the first missing.
    widget.miner.refreshWallets().then((_) {
      if (mounted) setState(() {});
    });
    // Keep the picker's mining/idle chips honest. They come from the runner's
    // live loop state, which changes without the app doing anything — a wallet
    // that stops on an error would otherwise keep showing "mining" until
    // something else happened to refresh the list.
    _walletPoll = Timer.periodic(const Duration(seconds: 5), (_) async {
      await widget.miner.refreshWallets();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _walletPoll?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  bool get _connected =>
      widget.miner.state.phase.index >= MinerPhase.needsMiningKeys.index &&
      widget.miner.state.phase != MinerPhase.crashed;

  Future<void> _connect({bool addAnother = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final req = await widget.miner.connectWallet(addAnother: addAnother);
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
            content: Text(
              widget.miner.wallets.length > 1
                  // Only the selected wallet is dropped — saying "mining stops"
                  // would be wrong while the others keep going.
                  ? 'This wallet stops mining and its mining keys are removed '
                      'from this device. Your other wallets keep mining. You '
                      'can reconnect it later.'
                  : 'Mining stops and the mining keys are removed from this '
                      'device. You can reconnect the same wallet later.',
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
    // The body scrolls. isScrollControlled on showModalBottomSheet only lets the
    // sheet grow taller than half the screen — it does not make the contents
    // scroll, so with a few wallets connected the balances, controls and log ran
    // off the bottom with no way to reach them. Capped at 88% so the sheet never
    // swallows the whole screen.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Padding(
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
        ),
      ),
    );
  }

  /// The connected wallets, each with its own start/stop control.
  ///
  /// A list again rather than a dropdown: per-wallet control is the point, and
  /// burying it one tap deep behind a picker made the common action — start or
  /// stop *that* wallet — harder than it should be. The reason the list was
  /// replaced in the first place was that it grew without limit and pushed the
  /// rest of the sheet off screen; that is fixed by bounding its height and
  /// letting it scroll internally instead, so the balances, controls and log
  /// below stay put however many wallets are connected.
  Widget _walletList() {
    final wallets = widget.miner.wallets;
    final selectedId = widget.miner.selectedWalletId;
    if (wallets.isEmpty) return const SizedBox.shrink();

    final anyMining = wallets.any((w) => w['mining'] == true);
    final selected = wallets.firstWhere(
      (w) => w['walletId'] == selectedId,
      orElse: () => wallets.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              wallets.length > 1 ? '${wallets.length} wallets' : 'Wallet',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : () => _connect(addAnother: true),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add wallet', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFC531),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          // ~4 rows, then it scrolls. Fixed ceiling is what stops a long wallet
          // list from displacing everything under it.
          constraints: const BoxConstraints(maxHeight: 184),
          child: Scrollbar(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: wallets.length,
              itemBuilder: (_, i) =>
                  _walletRow(wallets[i], wallets[i]['walletId'] == selectedId),
            ),
          ),
        ),
        if (wallets.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : () => _setMining(null, start: true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6BE28B),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Start all'),
              ),
              TextButton(
                onPressed: _busy || !anyMining
                    ? null
                    : () => _setMining(null, start: false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Stop all'),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  // The figures below belong to one wallet; with several
                  // connected it is otherwise impossible to tell whose.
                  'Showing ${selected['walletName'] ?? 'wallet'}',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
        const Divider(color: Colors.white12, height: 20),
      ],
    );
  }

  Widget _walletRow(Map<String, dynamic> w, bool isSelected) {
    final mining = w['mining'] == true;
    final keysReady = w['keysReady'] == true;
    final id = '${w['walletId']}';

    return InkWell(
      onTap: _busy || isSelected
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.miner.selectWallet(id);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 15,
              color: isSelected ? const Color(0xFFFFC531) : Colors.white24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${w['walletName'] ?? 'wallet'}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
            if (!keysReady)
              const _Chip(text: 'keys pending', color: Colors.orangeAccent)
            else if (mining)
              const _Chip(text: 'mining', color: Color(0xFF6BE28B))
            else
              const _Chip(text: 'idle', color: Colors.white38),
            // Start/stop sits on the row it acts on, so controlling a wallet
            // never means selecting it first.
            SizedBox(
              width: 36,
              child: keysReady
                  ? IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: mining ? 'Stop this wallet' : 'Start this wallet',
                      icon: Icon(
                        mining
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        size: 20,
                        color: mining
                            ? Colors.redAccent
                            : const Color(0xFF6BE28B),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _setMining(id, start: !mining),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Start or stop one wallet, or every wallet when [id] is null.
  Future<void> _setMining(String? id, {required bool start}) async {
    setState(() => _busy = true);
    try {
      if (start) {
        await widget.miner.startMining(walletId: id);
      } else {
        await widget.miner.stopMining(walletId: id);
      }
      await widget.miner.refreshWallets();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _connectedBody(MinerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _walletList(),
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
              // Name the target: with several wallets connected, an
              // unqualified "Disconnect" reads as dropping all of them.
              child: Text(
                widget.miner.wallets.length > 1
                    ? 'Disconnect this'
                    : 'Disconnect',
              ),
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
              // Chronological top-to-bottom, pinned to the newest line.
              //
              // `reverse: true` builds from the bottom up, so index 0 sits at
              // the bottom: feeding it the list backwards puts the oldest line
              // at the top and the newest at the bottom, and the view opens
              // already scrolled to the latest. Rendering newest-first instead
              // made a session read backwards — the summary above the work that
              // produced it.
              return ListView.builder(
                padding: EdgeInsets.zero,
                reverse: true,
                itemCount: lines.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    lines[lines.length - 1 - i],
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

/// Compact status pill used in the wallet list.
class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9)),
    );
  }
}
