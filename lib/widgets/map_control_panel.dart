import 'package:flutter/material.dart';
import '../services/lora_companion_service.dart';
import '../state/map_state_notifier.dart';

Widget buildMapControlPanel(
  MapState state, {
  required void Function() onConnect,
  required void Function() onDisconnect,
  required void Function() onManualPing,
  required void Function() onExport,
  required void Function() onImport,
  required void Function() onClearData,
}) {
  return Positioned(
    top: 16,
    left: 16,
    right: 16,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Connection Status
            Row(
              children: [
                Icon(
                  state.loraConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  size: 16,
                  color: state.loraConnected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  state.loraConnected
                      ? (state.connectionType == ConnectionType.usb ? 'USB' : 'BT')
                      : 'No LoRa',
                  style: TextStyle(
                    fontSize: 12,
                    color: state.loraConnected ? Colors.green : Colors.grey,
                  ),
                ),
                if (state.loraConnected && state.batteryPercent != null)
                  const SizedBox(width: 4),
                if (state.loraConnected && state.batteryPercent != null)
                  Icon(
                    _batteryIcon(state.batteryPercent!),
                    size: 14,
                    color: _batteryColor(state.batteryPercent!),
                  ),
                if (state.loraConnected && state.batteryPercent != null)
                  const SizedBox(width: 2),
                if (state.loraConnected && state.batteryPercent != null)
                  Text(
                    '${state.batteryPercent}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _batteryColor(state.batteryPercent!),
                    ),
                  ),
                const Spacer(),
                if (!state.loraConnected)
                  TextButton(
                    onPressed: onConnect,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Connect', style: TextStyle(fontSize: 12)),
                  ),
                if (state.loraConnected)
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: onDisconnect,
                    tooltip: 'Disconnect',
                  ),
                if (state.loraConnected)
                  IconButton(
                    icon: const Icon(Icons.send, size: 20),
                    onPressed: onManualPing,
                    tooltip: 'Manual Ping',
                    color: Colors.blue,
                  ),
              ],
            ),
            const Divider(height: 16),
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Samples: ${state.sampleCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Coverage: ${state.aggregationResult?.coverages.length ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Import'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onClearData,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Clear Map'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

IconData _batteryIcon(int percent) {
  if (percent > 90) return Icons.battery_full;
  if (percent > 70) return Icons.battery_5_bar;
  if (percent > 50) return Icons.battery_4_bar;
  if (percent > 30) return Icons.battery_3_bar;
  if (percent > 15) return Icons.battery_2_bar;
  return Icons.battery_1_bar;
}

Color _batteryColor(int percent) {
  if (percent > 30) return Colors.green;
  if (percent > 15) return Colors.orange;
  return Colors.red;
}
