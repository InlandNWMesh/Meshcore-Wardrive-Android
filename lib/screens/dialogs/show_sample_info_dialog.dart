import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../constants/map_constants.dart';

void showSampleInfoDialog(
  BuildContext context,
  Sample sample,
  String? Function(String?) nameResolver,
) {
  final timestamp = DateFormat('MMM d, yyyy HH:mm:ss').format(sample.timestamp);
  final hasSignalData = sample.rssi != null || sample.snr != null;
  final pingStatus = sample.pingSuccess == true
      ? '✅ Success'
      : sample.pingSuccess == false
          ? '❌ Failed'
          : '📍 GPS Only';

  final repeaterName = sample.path != null ? nameResolver(sample.path) : null;
  final idOrName = repeaterName ?? sample.path ?? 'Unknown';
  final repeaterDisplay = (repeaterName != null)
      ? repeaterName
      : (idOrName.length > kRepeaterIdPrefixLength
          ? idOrName.substring(0, kRepeaterIdPrefixLength).toUpperCase()
          : idOrName.toUpperCase());

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sample Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(pingStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text('Time: $timestamp', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text('Lat: ${sample.position.latitude.toStringAsFixed(6)}'),
          Text('Lon: ${sample.position.longitude.toStringAsFixed(6)}'),
          if (sample.path != null) ...[
            const Divider(height: 16),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Repeater: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(repeaterDisplay,
                      style: const TextStyle(fontFamily: 'monospace')),
                ),
              ],
            ),
          ],
          if (hasSignalData) const Divider(height: 16),
          if (hasSignalData) const SizedBox(height: 8),
          if (sample.rssi != null)
            Row(
              children: [
                const Text('RSSI: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${sample.rssi} dBm'),
              ],
            ),
          if (sample.snr != null)
            Row(
              children: [
                const Text('SNR: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${sample.snr} dB'),
              ],
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
