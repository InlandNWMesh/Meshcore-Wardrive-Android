import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/upload_service.dart';

/// Shows all unacknowledged admin messages in a single scrollable dialog.
/// Each message is displayed as a distinct block. Tapping "Got it" acknowledges
/// all shown messages so they never appear again.
Future<void> maybeShowAdminMessages(
  BuildContext context,
  List<AdminMessage> messages,
) async {
  if (messages.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final unseen = messages
      .where((m) => prefs.getBool('admin_msg_ack_${m.id}') != true)
      .toList();

  if (unseen.isEmpty) return;
  if (!context.mounted) return;

  final scrollController = ScrollController();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      title: Text(
        unseen.length == 1
            ? (unseen.first.title ?? 'Notice from Admin')
            : 'Messages from Admin',
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < unseen.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (unseen.length > 1 && unseen[i].title != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            unseen[i].title!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      Text(unseen[i].body, style: const TextStyle(height: 1.5)),
                    ],
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            for (final m in unseen) {
              await prefs.setBool('admin_msg_ack_${m.id}', true);
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
