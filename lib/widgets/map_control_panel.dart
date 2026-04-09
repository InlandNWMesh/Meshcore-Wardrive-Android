import 'package:flutter/material.dart';
import '../services/lora_companion_service.dart';
import '../state/map_state_notifier.dart';

class MapControlPanel extends StatefulWidget {
  final MapState state;
  final void Function() onConnect;
  final void Function() onDisconnect;
  final void Function() onManualPing;
  final void Function() onUpload;
  final void Function() onClearData;

  const MapControlPanel({
    super.key,
    required this.state,
    required this.onConnect,
    required this.onDisconnect,
    required this.onManualPing,
    required this.onUpload,
    required this.onClearData,
  });

  @override
  State<MapControlPanel> createState() => _MapControlPanelState();
}

class _MapControlPanelState extends State<MapControlPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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
                    widget.state.loraConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    size: 16,
                    color: widget.state.loraConnected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.state.loraConnected
                        ? (widget.state.connectionType == ConnectionType.usb ? 'USB' : 'BT')
                        : 'No LoRa',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.state.loraConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                  if (widget.state.loraConnected && widget.state.batteryPercent != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _batteryIcon(widget.state.batteryPercent!),
                      size: 14,
                      color: _batteryColor(widget.state.batteryPercent!),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${widget.state.batteryPercent}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: _batteryColor(widget.state.batteryPercent!),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!widget.state.loraConnected)
                    TextButton(
                      onPressed: widget.onConnect,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Connect', style: TextStyle(fontSize: 12)),
                    ),
                  if (widget.state.loraConnected)
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: widget.onDisconnect,
                      tooltip: 'Disconnect',
                    ),
                  if (widget.state.loraConnected)
                    IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      onPressed: widget.onManualPing,
                      tooltip: 'Manual Ping',
                      color: Colors.blue,
                    ),
                ],
              ),
              const Divider(height: 16),
              // Stats row with expand toggle
              Row(
                children: [
                  Text(
                    'Samples: ${widget.state.sampleCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Coverage: ${widget.state.aggregationResult?.coverages.length ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ),
                ],
              ),
              // Expandable actions
              if (_expanded) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: widget.onUpload,
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: widget.onClearData,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Clear Map'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
