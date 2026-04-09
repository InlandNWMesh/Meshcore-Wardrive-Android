import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Plays a sonar ping sound on a configurable interval while active.
/// The sound is generated in-memory as a PCM WAV — no asset file needed.
class SonarPingService {
  final AudioPlayer _player = AudioPlayer();
  late final Uint8List _wavBytes;

  Timer? _timer;
  bool _active = false;

  bool enabled;
  int intervalSeconds; // 5–60

  SonarPingService({this.enabled = false, this.intervalSeconds = 10}) {
    _wavBytes = _generateSonarWav();
  }

  /// Call when tracking starts.
  void start() {
    if (!enabled) return;
    _active = true;
    _scheduleTimer();
  }

  /// Call when tracking stops.
  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void setEnabled(bool value) {
    enabled = value;
    if (!value) {
      stop();
    } else if (_active) {
      _scheduleTimer();
    }
  }

  void setInterval(int seconds) {
    intervalSeconds = seconds.clamp(5, 60);
    if (_active && enabled) {
      _timer?.cancel();
      _scheduleTimer();
    }
  }

  void dispose() {
    stop();
    _player.dispose();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      await _player.play(BytesSource(_wavBytes));
    } catch (_) {
      // Silently ignore audio errors — non-critical feature
    }
  }

  // ---------------------------------------------------------------------------
  // WAV generation — 880 Hz sine wave with exponential decay (~350 ms)
  // ---------------------------------------------------------------------------

  static Uint8List _generateSonarWav() {
    const sampleRate = 22050;
    const frequency = 880.0; // Hz — classic sonar pitch
    const durationMs = 350;
    const numSamples = sampleRate * durationMs ~/ 1000;

    final samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = math.exp(-t * 10.0);
      final sample = (math.sin(2 * math.pi * frequency * t) * envelope * 28000)
          .round()
          .clamp(-32768, 32767);
      samples[i] = sample;
    }

    return _buildWav(samples, sampleRate);
  }

  static Uint8List _buildWav(Int16List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    _setFourCC(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    _setFourCC(buffer, 8, 'WAVE');

    // fmt chunk
    _setFourCC(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little);  // PCM
    buffer.setUint16(22, 1, Endian.little);  // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little);  // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    _setFourCC(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  static void _setFourCC(ByteData buf, int offset, String s) {
    for (int i = 0; i < 4; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
