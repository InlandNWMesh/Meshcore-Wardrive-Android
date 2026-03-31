import 'package:flutter/material.dart';
import '../../models/models.dart';

void showCoverageInfoDialog(BuildContext context, Coverage coverage) {
  final total = coverage.received + coverage.lost;
  final successRate = total > 0 ? ((coverage.received / total) * 100).toStringAsFixed(0) : 'N/A';
  final reliabilityText = total > 0 ? '$successRate%' : 'No ping data';

  final receivedDisplay = coverage.received.toStringAsFixed(1);
  final lostDisplay = coverage.lost.toStringAsFixed(1);
  final totalDisplay = total.toStringAsFixed(1);

  final uniquePrefixes = coverage.repeaters
      .map((id) => id.substring(0, id.length >= 2 ? 2 : id.length))
      .toSet()
      .toList()
    ..sort();
  final repeaterText = uniquePrefixes.isNotEmpty ? uniquePrefixes.join(', ') : 'None';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Coverage Square Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Samples: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(totalDisplay),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Success Rate: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(reliabilityText),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Received: ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Flexible(child: Text(receivedDisplay)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Lost: ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              Flexible(child: Text(lostDisplay)),
            ],
          ),
          if (coverage.received > 0) const SizedBox(height: 8),
          if (coverage.received > 0)
            Row(
              children: [
                const Text('Repeaters Heard: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${uniquePrefixes.length}'),
              ],
            ),
          if (coverage.received > 0) const SizedBox(height: 4),
          if (coverage.received > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Repeater IDs: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    repeaterText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
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
