import 'dart:async';
import 'dart:typed_data';
import '../models/models.dart';
import 'database_service.dart';
import 'lora_companion_service.dart';

/// Orchestration layer between the LoRa radio service, SQLite, and the chat UI.
/// Exposes a unified [messageStream] that emits both incoming and outgoing messages,
/// and a [heardUpdateStream] that fires when a repeater echoes one of our outgoing
/// channel messages.
class ChatService {
  final LoRaCompanionService _lora;
  final DatabaseService _db = DatabaseService();
  final _streamController = StreamController<ChatMessage>.broadcast();

  // Echo tracking: message id → heard count
  final Map<String, int> _heardCounts = {};
  // text → list of message ids that sent this text (outgoing channel only)
  final Map<String, List<String>> _outgoingByText = {};
  final _heardController =
      StreamController<Map<String, int>>.broadcast();

  ChatService(this._lora) {
    _lora.messageStream.listen(_onIncoming);
    _lora.echoStream.listen(_onEcho);
  }

  Future<void> _onIncoming(ChatMessage msg) async {
    await _db.insertMessage(msg);
    _streamController.add(msg);
  }

  void _onEcho(Map<String, dynamic> echo) {
    final text = echo['text'] as String? ?? '';
    final ids = _outgoingByText[text];
    if (ids == null || ids.isEmpty) return;
    // Increment heard count for every outgoing message with this text
    for (final id in ids) {
      _heardCounts[id] = (_heardCounts[id] ?? 0) + 1;
    }
    _heardController.add(Map.unmodifiable(_heardCounts));
  }

  /// Unified stream of all messages (incoming + outgoing).
  Stream<ChatMessage> get messageStream => _streamController.stream;

  /// Fires whenever a heard-repeats count changes. Emits the full id→count map.
  Stream<Map<String, int>> get heardUpdateStream => _heardController.stream;

  /// Current heard-repeat counts by message id.
  Map<String, int> get heardCounts => Map.unmodifiable(_heardCounts);

  Future<List<ChatMessage>> getMessages(String conversationKey) =>
      _db.getMessages(conversationKey);

  Future<List<Map<String, dynamic>>> getConversations() =>
      _db.getConversations();

  /// Request channel info for all 4 channel slots from the radio.
  Future<void> requestAllChannels() => _lora.requestAllChannels();

  /// Channel info cache: index → {index, name, key}
  Map<int, Map<String, dynamic>> get channelInfo => _lora.channelInfo;

  /// Stream that fires whenever channel info is updated.
  Stream<Map<int, Map<String, dynamic>>> get channelInfoStream =>
      _lora.channelInfoStream;

  List<dynamic> get knownContacts => _lora.discoveredRepeaters;

  /// Write a channel configuration to the radio and refresh.
  Future<void> setChannel(int slotIdx, String name, Uint8List key) =>
      _lora.setChannel(slotIdx, name, key);

  /// Send a direct message and persist + emit an outgoing copy.
  Future<void> sendDirect(String recipientKeyHex, String text) async {
    await _lora.sendDirectMessage(recipientKeyHex, text);
    final msg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_me',
      conversationKey: recipientKeyHex,
      senderKeyHex: 'me',
      text: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
      isChannel: false,
    );
    await _db.insertMessage(msg);
    _streamController.add(msg);
  }

  /// Send a channel message and persist + emit an outgoing copy.
  Future<void> sendChannel(String text, {int channelIndex = 0}) async {
    await _lora.sendChannelMessage(text, channelIndex: channelIndex);
    final msg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_me',
      conversationKey: 'ch_$channelIndex',
      senderKeyHex: 'me',
      text: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
      isChannel: true,
      channelIndex: channelIndex,
    );
    await _db.insertMessage(msg);
    _streamController.add(msg);
    // Register for echo correlation
    _outgoingByText.putIfAbsent(text, () => []).add(msg.id);
  }

  void dispose() {
    _streamController.close();
    _heardController.close();
  }
}
