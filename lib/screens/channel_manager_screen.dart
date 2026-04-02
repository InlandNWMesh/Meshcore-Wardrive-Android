import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/chat_service.dart';
import '../utils/meshcore_uri.dart';

/// Screen listing all 4 channel slots with options to view QR, edit, or
/// configure via scanned QR / pasted meshcore:// URI.
class ChannelManagerScreen extends StatefulWidget {
  final ChatService chatService;

  const ChannelManagerScreen({super.key, required this.chatService});

  @override
  State<ChannelManagerScreen> createState() => _ChannelManagerScreenState();
}

class _ChannelManagerScreenState extends State<ChannelManagerScreen> {
  Map<int, Map<String, dynamic>> _channelInfo = {};

  @override
  void initState() {
    super.initState();
    _channelInfo = Map.of(widget.chatService.channelInfo);
    widget.chatService.channelInfoStream.listen((info) {
      if (mounted) setState(() => _channelInfo = Map.of(info));
    });
    // Refresh from radio
    widget.chatService.requestAllChannels();
  }

  String _slotName(int idx) {
    final info = _channelInfo[idx];
    if (info != null) {
      final name = info['name'] as String? ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Empty';
  }

  bool _slotHasKey(int idx) {
    final info = _channelInfo[idx];
    if (info == null) return false;
    final key = info['key'];
    if (key is Uint8List) return key.any((b) => b != 0);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh from radio',
            onPressed: () => widget.chatService.requestAllChannels(),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: 4,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final name = _slotName(idx);
          final hasKey = _slotHasKey(idx);
          final info = _channelInfo[idx];

          return ListTile(
            leading: CircleAvatar(
              child: Text('$idx', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(name),
            subtitle: Text(hasKey ? 'Encrypted key set' : 'No key configured'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (info != null && hasKey)
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    tooltip: 'Show QR',
                    onPressed: () => _showQR(context, idx, info),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Configure channel',
                  onPressed: () => _configureChannel(context, idx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQR(BuildContext context, int idx, Map<String, dynamic> info) {
    final key = info['key'] as Uint8List;
    final name = info['name'] as String? ?? 'ch$idx';
    final uri = MeshcoreChannelUri(name: name, key: key).toUri();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: uri, size: 220),
            const SizedBox(height: 12),
            Text(uri,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy URI'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uri));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _configureChannel(BuildContext context, int slotIdx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ChannelConfigSheet(
        slotIdx: slotIdx,
        chatService: widget.chatService,
        onConfigured: () {
          Navigator.pop(context);
          widget.chatService.requestAllChannels();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Channel configuration bottom sheet
// ─────────────────────────────────────────────────────────────

class _ChannelConfigSheet extends StatefulWidget {
  final int slotIdx;
  final ChatService chatService;
  final VoidCallback onConfigured;

  const _ChannelConfigSheet({
    required this.slotIdx,
    required this.chatService,
    required this.onConfigured,
  });

  @override
  State<_ChannelConfigSheet> createState() => _ChannelConfigSheetState();
}

// Well-known MeshCore public channel
const _publicChannelName = 'Public';
const _publicChannelKeyHex = '8b3387e9c5cdea6ac9e5edbaa115cd72';

class _ChannelConfigSheetState extends State<_ChannelConfigSheet> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _showScanner = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing channel info if available
    final info = widget.chatService.channelInfo[widget.slotIdx];
    if (info != null) {
      _nameController.text = info['name'] as String? ?? '';
      final key = info['key'];
      if (key is Uint8List) {
        _keyController.text =
            key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      }
    }
  }

  void _applyUri(String raw) {
    final parsed = MeshcoreChannelUri.parse(raw);
    if (parsed == null) {
      setState(() => _error = 'Invalid meshcore:// URI');
      return;
    }
    setState(() {
      _nameController.text = parsed.name;
      _keyController.text = parsed.keyHex;
      _error = null;
      _showScanner = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final keyStr = _keyController.text.trim().replaceAll(' ', '');

    if (name.isEmpty) {
      setState(() => _error = 'Channel name required');
      return;
    }
    if (keyStr.length != 32 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(keyStr)) {
      setState(() => _error = 'Key must be 32 hex characters (16 bytes)');
      return;
    }

    final keyBytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      keyBytes[i] = int.parse(keyStr.substring(i * 2, i * 2 + 2), radix: 16);
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.chatService.setChannel(widget.slotIdx, name, keyBytes);
      widget.onConfigured();
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Configure Channel ${widget.slotIdx}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // QR scan / paste URI row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                  onPressed: () => setState(() => _showScanner = !_showScanner),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste URI'),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) _applyUri(data!.text!);
                  },
                ),
              ),
            ],
          ),

          if (_showScanner) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MobileScanner(
                  onDetect: (capture) {
                    final raw = capture.barcodes.firstOrNull?.rawValue;
                    if (raw != null) _applyUri(raw);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.public, size: 18),
            label: const Text('Reset to MeshCore Public Channel'),
            onPressed: () => setState(() {
              _nameController.text = _publicChannelName;
              _keyController.text = _publicChannelKeyHex;
              _error = null;
            }),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Manual fields
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Channel name',
              hintText: '#general',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: '16-byte key (32 hex chars)',
              hintText: '00112233445566778899aabbccddeeff',
              border: OutlineInputBorder(),
            ),
            maxLength: 32,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),

          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],

          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save to Radio'),
          ),
        ],
      ),
    );
  }
}
