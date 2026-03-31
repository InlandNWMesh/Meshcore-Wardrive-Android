import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/models.dart';
import 'show_repeater_info_dialog.dart';

void showRepeatersDialog(
  BuildContext context,
  List<Repeater> repeaters,
  MapController mapController,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Nearby Repeaters (${repeaters.length})'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: repeaters.length,
          itemBuilder: (context, index) {
            final repeater = repeaters[index];
            return ListTile(
              leading: const Icon(Icons.cell_tower, color: Colors.purple),
              title: Text(repeater.name ?? 'Repeater ${repeater.id}'),
              subtitle: Text(
                '${repeater.position.latitude.toStringAsFixed(4)}, '
                '${repeater.position.longitude.toStringAsFixed(4)}'
                '${repeater.snr != null ? " • SNR: ${repeater.snr} dB" : ""}'
                '${repeater.rssi != null ? " • RSSI: ${repeater.rssi} dBm" : ""}',
              ),
              onTap: () {
                Navigator.pop(context);
                showRepeaterInfoDialog(context, repeater, mapController);
              },
              trailing: IconButton(
                icon: const Icon(Icons.location_searching),
                onPressed: () {
                  Navigator.pop(context);
                  mapController.move(repeater.position, 15.0);
                },
              ),
            );
          },
        ),
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
