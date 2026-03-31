import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/models.dart';
import '../../constants/map_constants.dart';

void showRepeaterInfoDialog(
  BuildContext context,
  Repeater repeater,
  MapController mapController,
) {
  final shortId = (repeater.id.length > kRepeaterIdPrefixLength
      ? repeater.id.substring(0, kRepeaterIdPrefixLength)
      : repeater.id).toUpperCase();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(repeater.name ?? 'Repeater $shortId'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: $shortId', style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Text('Lat: ${repeater.position.latitude.toStringAsFixed(6)}'),
          Text('Lon: ${repeater.position.longitude.toStringAsFixed(6)}'),
          if (repeater.rssi != null) const SizedBox(height: 8),
          if (repeater.rssi != null) Text('RSSI: ${repeater.rssi} dBm'),
          if (repeater.snr != null) Text('SNR: ${repeater.snr} dB'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            mapController.move(repeater.position, 15.0);
          },
          child: const Text('Show on Map'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
