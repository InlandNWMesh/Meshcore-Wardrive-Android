import 'package:latlong2/latlong.dart';

class Sample {
  final String id;
  final LatLng position;
  final DateTime timestamp;
  final String? path;
  final String geohash;
  final int? rssi;
  final int? snr;
  final bool? pingSuccess;

  Sample({
    required this.id,
    required this.position,
    required this.timestamp,
    this.path,
    required this.geohash,
    this.rssi,
    this.snr,
    this.pingSuccess,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lon': position.longitude,
        'timestamp': timestamp.toIso8601String(),
        'path': path,
        'geohash': geohash,
        'rssi': rssi,
        'snr': snr,
        'pingSuccess': pingSuccess,
      };

  factory Sample.fromJson(Map<String, dynamic> json) {
    return Sample(
      id: json['id'] as String,
      position: LatLng(json['lat'] as double, json['lon'] as double),
      timestamp: DateTime.parse(json['timestamp'] as String),
      path: json['path'] as String?,
      geohash: json['geohash'] as String,
      rssi: json['rssi'] as int?,
      snr: json['snr'] as int?,
      pingSuccess: json['pingSuccess'] as bool?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'lat': position.latitude,
        'lon': position.longitude,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'path': path,
        'geohash': geohash,
        'rssi': rssi,
        'snr': snr,
        'pingSuccess': pingSuccess == true ? 1 : (pingSuccess == false ? 0 : null),
      };

  factory Sample.fromMap(Map<String, dynamic> map) {
    final pingSuccessInt = map['pingSuccess'] as int?;
    return Sample(
      id: map['id'] as String,
      position: LatLng(map['lat'] as double, map['lon'] as double),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      path: map['path'] as String?,
      geohash: map['geohash'] as String,
      rssi: map['rssi'] as int?,
      snr: map['snr'] as int?,
      pingSuccess: pingSuccessInt == null ? null : pingSuccessInt == 1,
    );
  }
}

class Coverage {
  final String id; // geohash
  final LatLng position;
  double received; // Changed to double to support weighted samples
  double lost;     // Changed to double to support weighted samples
  DateTime? lastReceived;
  DateTime? updated;
  List<String> repeaters;

  Coverage({
    required this.id,
    required this.position,
    this.received = 0.0,
    this.lost = 0.0,
    this.lastReceived,
    this.updated,
    List<String>? repeaters,
  }) : repeaters = repeaters ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lon': position.longitude,
        'rcv': received,
        'lost': lost,
        'lht': lastReceived?.millisecondsSinceEpoch,
        'ut': updated?.millisecondsSinceEpoch,
        'rptr': repeaters,
      };

  factory Coverage.fromJson(Map<String, dynamic> json) {
    return Coverage(
      id: json['id'] as String,
      position: LatLng(json['lat'] as double, json['lon'] as double),
      received: (json['rcv'] as num?)?.toDouble() ?? 0.0,
      lost: (json['lost'] as num?)?.toDouble() ?? 0.0,
      lastReceived: json['lht'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lht'] as int)
          : null,
      updated: json['ut'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['ut'] as int)
          : null,
      repeaters: (json['rptr'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class Repeater {
  final String id;
  final LatLng position;
  final double? elevation;
  final DateTime? timestamp;
  final String? name;
  final int? rssi;
  final int? snr;
  final double? distance;

  Repeater({
    required this.id,
    required this.position,
    this.elevation,
    this.timestamp,
    this.name,
    this.rssi,
    this.snr,
    this.distance,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lon': position.longitude,
        'elevation': elevation,
        'timestamp': timestamp?.toIso8601String(),
        'name': name,
        'rssi': rssi,
        'snr': snr,
        'distance': distance,
      };

  factory Repeater.fromJson(Map<String, dynamic> json) {
    return Repeater(
      id: json['id'] as String,
      position: LatLng(json['lat'] as double, json['lon'] as double),
      elevation: json['elevation'] as double?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      name: json['name'] as String?,
      rssi: json['rssi'] as int?,
      snr: json['snr'] as int?,
      distance: json['distance'] as double?,
    );
  }
}

class Edge {
  final Coverage coverage;
  final Repeater repeater;
  /// Timestamp of the most recent successful response for this (coverage, repeater) pair.
  final DateTime? timestamp;

  Edge({
    required this.coverage,
    required this.repeater,
    this.timestamp,
  });
}

class NodeData {
  final List<Sample> samples;
  final List<Repeater> repeaters;

  NodeData({
    required this.samples,
    required this.repeaters,
  });

  factory NodeData.fromJson(Map<String, dynamic> json) {
    return NodeData(
      samples: (json['samples'] as List<dynamic>?)
              ?.map((s) => Sample.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      repeaters: (json['repeaters'] as List<dynamic>?)
              ?.map((r) => Repeater.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ChatMessage {
  final String id;               // '${timestampSec}_${senderKeyHex}'
  final String conversationKey;  // senderKeyHex (direct) OR 'ch_$idx' (channel)
  final String senderKeyHex;     // 6-byte sender pubkey prefix as hex, or 'me'
  final String? senderName;      // resolved from contacts, nullable
  final String text;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isChannel;
  final int? channelIndex;       // only for channel messages

  const ChatMessage({
    required this.id,
    required this.conversationKey,
    required this.senderKeyHex,
    this.senderName,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    required this.isChannel,
    this.channelIndex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_key': conversationKey,
        'sender_key_hex': senderKeyHex,
        'sender_name': senderName,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
        'is_outgoing': isOutgoing ? 1 : 0,
        'is_channel': isChannel ? 1 : 0,
        'channel_index': channelIndex,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationKey: map['conversation_key'] as String,
      senderKeyHex: map['sender_key_hex'] as String,
      senderName: map['sender_name'] as String?,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int) * 1000),
      isOutgoing: (map['is_outgoing'] as int) == 1,
      isChannel: (map['is_channel'] as int) == 1,
      channelIndex: map['channel_index'] as int?,
    );
  }
}

