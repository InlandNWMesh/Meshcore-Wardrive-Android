import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'antenna_warning_acknowledged';

Future<void> maybeShowAntennaWarning(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefKey) == true) return;

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
          SizedBox(width: 10),
          Text('Antenna Warning'),
        ],
      ),
      content: const Text(
        'It is STRONGLY recommended that you use a radio with a roof-mounted or '
        'external antenna when wardriving.\n\n'
        'Submitting low-quality data collected with a handheld or dashboard radio '
        'degrades the map for everyone. Please drive with proper antenna setup '
        'before uploading.',
        style: TextStyle(height: 1.5),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefKey, true);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('I Understand'),
        ),
      ],
    ),
  );
}
