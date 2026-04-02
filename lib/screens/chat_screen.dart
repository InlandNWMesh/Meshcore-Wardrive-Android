import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/chat_service.dart';
import 'channel_manager_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;

  const ChatScreen({super.key, required this.chatService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Query the radio for all channel configs when the chat screen opens.
    widget.chatService.requestAllChannels();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Direct'),
              Tab(icon: Icon(Icons.cell_tower), text: 'Channel'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DirectTab(chatService: widget.chatService),
            _ChannelTab(chatService: widget.chatService),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Direct tab — list of contacts / conversations
// ─────────────────────────────────────────────────────────────

class _DirectTab extends StatelessWidget {
  final ChatService chatService;
  const _DirectTab({required this.chatService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: chatService.getConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? [];
        final contacts = chatService.knownContacts;

        // Merge DB conversations with known contacts (avoid duplicates)
        final seenKeys = <String>{};
        final items = <_ContactItem>[];

        for (final conv in conversations) {
          final key = conv['conversation_key'] as String;
          if (key.startsWith('ch_')) continue;
          seenKeys.add(key);
          items.add(_ContactItem(
            keyHex: key,
            name: conv['sender_name'] as String? ?? key,
          ));
        }

        for (final r in contacts) {
          final repeater = r as dynamic;
          final id = repeater.id as String;
          if (!seenKeys.contains(id)) {
            items.add(_ContactItem(
              keyHex: id,
              name: repeater.name as String? ?? id,
            ));
          }
        }

        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No contacts found.\nScan for repeaters first.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final item = items[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(item.name),
              subtitle: Text(item.keyHex, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationScreen(
                    chatService: chatService,
                    contactKeyHex: item.keyHex,
                    contactName: item.name,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ContactItem {
  final String keyHex;
  final String name;
  _ContactItem({required this.keyHex, required this.name});
}

// ─────────────────────────────────────────────────────────────
// Channel tab — channel selector + flood messages
// ─────────────────────────────────────────────────────────────

class _ChannelTab extends StatefulWidget {
  final ChatService chatService;
  const _ChannelTab({required this.chatService});

  @override
  State<_ChannelTab> createState() => _ChannelTabState();
}

class _ChannelTabState extends State<_ChannelTab> {
  int _selectedChannel = 0;
  Map<int, Map<String, dynamic>> _channelInfo = {};

  @override
  void initState() {
    super.initState();
    _channelInfo = Map.of(widget.chatService.channelInfo);
    widget.chatService.channelInfoStream.listen((info) {
      if (mounted) setState(() => _channelInfo = Map.of(info));
    });
  }

  String _channelLabel(int idx) {
    final info = _channelInfo[idx];
    if (info != null) {
      final name = info['name'] as String? ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Ch $idx';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Channel selector bar
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cell_tower, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(4, (i) {
                      final selected = i == _selectedChannel;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_channelLabel(i)),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedChannel = i),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                tooltip: 'Manage channels',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelManagerScreen(
                      chatService: widget.chatService,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Messages for selected channel
        Expanded(
          child: _ChannelMessageView(
            key: ValueKey(_selectedChannel),
            chatService: widget.chatService,
            channelIndex: _selectedChannel,
          ),
        ),
      ],
    );
  }
}

/// Message view for a single channel — keyed so it rebuilds when channel changes.
class _ChannelMessageView extends StatefulWidget {
  final ChatService chatService;
  final int channelIndex;

  const _ChannelMessageView({
    super.key,
    required this.chatService,
    required this.channelIndex,
  });

  @override
  State<_ChannelMessageView> createState() => _ChannelMessageViewState();
}

class _ChannelMessageViewState extends State<_ChannelMessageView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    widget.chatService.messageStream.listen(_onMessage);
  }

  Future<void> _loadHistory() async {
    final history =
        await widget.chatService.getMessages('ch_${widget.channelIndex}');
    if (mounted) {
      setState(() => _messages.addAll(history));
      _scrollToBottom();
    }
  }

  void _onMessage(ChatMessage msg) {
    if (!msg.isChannel || msg.channelIndex != widget.channelIndex) return;
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.chatService.sendChannel(text, channelIndex: widget.channelIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('No messages yet on this channel.'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) =>
                      _MessageBubble(message: _messages[i]),
                ),
        ),
        _ComposeBar(controller: _controller, onSend: _send),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Conversation screen — single contact thread
// ─────────────────────────────────────────────────────────────

class ConversationScreen extends StatefulWidget {
  final ChatService chatService;
  final String contactKeyHex;
  final String contactName;

  const ConversationScreen({
    super.key,
    required this.chatService,
    required this.contactKeyHex,
    required this.contactName,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    widget.chatService.messageStream.listen(_onMessage);
  }

  Future<void> _loadHistory() async {
    final history =
        await widget.chatService.getMessages(widget.contactKeyHex);
    if (mounted) {
      setState(() => _messages.addAll(history));
      _scrollToBottom();
    }
  }

  void _onMessage(ChatMessage msg) {
    if (msg.conversationKey != widget.contactKeyHex) return;
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.chatService.sendDirect(widget.contactKeyHex, text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.contactName)),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),
          _ComposeBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutgoing = message.isOutgoing;
    final align =
        isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isOutgoing
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isOutgoing ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    final timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (message.isChannel && !isOutgoing)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                message.senderName ?? message.senderKeyHex,
                style: theme.textTheme.labelSmall,
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message.text, style: TextStyle(color: textColor)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              timeStr,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ComposeBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
