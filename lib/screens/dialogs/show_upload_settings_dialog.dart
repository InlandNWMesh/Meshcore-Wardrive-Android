import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/upload_service.dart';

/// Shows the upload settings dialog.
///
/// When [required] is true, the Cancel button is hidden and Save is only
/// enabled after a successful token validation — used on first-run or when
/// the stored token is rejected by the server.
Future<void> showUploadSettingsDialog(
  BuildContext context,
  UploadService uploadService, {
  bool required = false,
  void Function(String)? showSnackBar,
}) async {
  final currentUrl = await uploadService.getApiUrl();
  final currentToken = await uploadService.getContributorToken();
  final urlController = TextEditingController(text: currentUrl);
  final tokenController = TextEditingController(text: currentToken);

  // validation state: null=idle, true=valid, false=invalid
  bool? tokenValid;
  bool tokenValidating = false;
  String? tokenError;
  int validationGeneration = 0;

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: !required,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> runValidation() async {
          final gen = ++validationGeneration;
          setState(() {
            tokenValidating = true;
            tokenValid = null;
            tokenError = null;
          });
          final error = await uploadService.validateToken(
              urlController.text, tokenController.text);
          if (gen != validationGeneration) return; // stale — newer call in flight
          setState(() {
            tokenValidating = false;
            tokenValid = error == null;
            tokenError = error;
          });
        }

        Future<void> save() async {
          await uploadService.setApiUrl(urlController.text);
          await uploadService.setContributorToken(tokenController.text);
          if (context.mounted) Navigator.pop(context);
          showSnackBar?.call('Upload settings saved');
        }

        return AlertDialog(
          title: Text(required ? 'Token Required' : 'Upload Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (required) ...[
                const Text(
                  'A valid contributor token is required to use this app. '
                  'Enter the token from your invite page.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://wardrive.inwmesh.org/api/samples/',
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) =>
                    setState(() {
                      tokenValid = null;
                      tokenError = null;
                    }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tokenController,
                decoration: InputDecoration(
                  labelText: 'Contributor Token',
                  hintText: 'Your token from wardrive.inwmesh.org',
                  isDense: true,
                  suffixIcon: tokenValidating
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : tokenValid == true
                          ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 20)
                          : tokenValid == false
                              ? const Icon(Icons.cancel,
                                  color: Colors.red, size: 20)
                              : null,
                  errorText: tokenError,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  TextInputFormatter.withFunction((oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toUpperCase())),
                ],
                onChanged: (val) {
                  setState(() {
                    tokenValid = null;
                    tokenError = null;
                  });
                  if (val.length >= 8) runValidation();
                },
              ),
            ],
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            TextButton(
              onPressed: tokenValidating ? null : runValidation,
              child: const Text('Test'),
            ),
            TextButton(
              onPressed: (required && tokenValid != true) ? null : save,
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}
