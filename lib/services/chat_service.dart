import '../models/models.dart';
import 'database_service.dart';
import 'lora_companion_service.dart';

/// Thin orchestration layer between the LoRa radio service, the SQLite database,
/// and the chat UI. Incoming messages are persisted automatically.
class ChatService {
  final LoRaCompanionService _lora;
  final DatabaseService _db = DatabaseService();

  ChatService(this._lora) {
    _lora.messageStream.listen(_onMessage);
  }

  Future<void> _onMessage(ChatMessage msg) => _db.insertMessage(msg);

  Stream<ChatMessage> get messageStream => _lora.messageStream;

  Future<List<ChatMessage>> getMessages(String conversationKey) =>
      _db.getMessages(conversationKey);

  Future<List<Map<String, dynamic>>> getConversations() =>
      _db.getConversations();

  /// Send a direct message and persist an outgoing copy.
  Future<void> sendDirect(String recipientKeyHex, String text) async {
    await _lora.sendDirectMessage(recipientKeyHex, text);
    final now = DateTime.now();
    await _db.insertMessage(ChatMessage(
      id: '${now.millisecondsSinceEpoch}_me',
      conversationKey: recipientKeyHex,
      senderKeyHex: 'me',
      text: text,
      timestamp: now,
      isOutgoing: true,
      isChannel: false,
    ));
  }

  /// Send a channel message and persist an outgoing copy.
  Future<void> sendChannel(String text, {int channelIndex = 0}) async {
    await _lora.sendChannelMessage(text, channelIndex: channelIndex);
    final now = DateTime.now();
    await _db.insertMessage(ChatMessage(
      id: '${now.millisecondsSinceEpoch}_me',
      conversationKey: 'ch_$channelIndex',
      senderKeyHex: 'me',
      text: text,
      timestamp: now,
      isOutgoing: true,
      isChannel: true,
      channelIndex: channelIndex,
    ));
  }

  List<dynamic> get knownContacts => _lora.discoveredRepeaters;
}
