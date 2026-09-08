import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../mining/bee_miner.dart';

/// Bottom sheet that walks the user through: connect AN Wallet → authorise
/// mining keys → (mining then starts automatically).
class WalletSheet extends StatefulWidget {
  const WalletSheet({super.key, required this.miner});

  final BeeMiner miner;

  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  WalletConnectRequest? _request;
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final req = await widget.miner.connectWallet();
      if (req == null) {
        // Already connected — move straight to key authorisation.
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
      // WebViewBeeMiner emits keys_ready → clock auto-starts mining.
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.miner.state.phase;
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
          const Text(
            'Mining setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'NACKL is mined with the official Bee Engine and paid to your '
            'Acki Nacki wallet. Connect once, then tap the clock face while it '
            'is on screen to mine.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (_request != null) _qr(_request!) else _stepButton(phase),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
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
