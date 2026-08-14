import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_wardrive/screens/dialogs/show_update_available_dialog.dart';
import 'package:meshcore_wardrive/utils/update_url.dart';

void main() {
  group('resolveUpdateUrl', () {
    // This value is handed to launchUrl(externalApplication) on every
    // contributor's phone, so the scheme check matters more than it looks.

    test('falls back to the default when the server says nothing', () {
      expect(resolveUpdateUrl(null), defaultReleasesUrl);
      expect(resolveUpdateUrl(''), defaultReleasesUrl);
    });

    test('accepts an https URL from the server', () {
      expect(resolveUpdateUrl('https://example.org/build.apk'),
          'https://example.org/build.apk');
    });

    test('rejects non-https schemes rather than launching them', () {
      for (final bad in [
        'http://example.org/x.apk',
        'javascript:alert(1)',
        'file:///data/local/tmp/x.apk',
        'intent://scan/#Intent;scheme=zxing;end',
        'market://details?id=com.example',
      ]) {
        expect(resolveUpdateUrl(bad), defaultReleasesUrl, reason: bad);
      }
    });

    test('rejects malformed or authority-less values', () {
      for (final bad in ['https://', 'not a url', '://nope', 'https:///path']) {
        expect(resolveUpdateUrl(bad), defaultReleasesUrl, reason: bad);
      }
    });

    test('the default points at the SpokaneMesh repo, not an upstream fork', () {
      // A prompt that sends contributors to someone else's releases is worse
      // than no prompt: it looks correct and hands out the wrong build.
      expect(defaultReleasesUrl, contains('SpokaneMesh'));
      expect(defaultReleasesUrl, startsWith('https://'));
    });
  });

  group('maybeShowUpdateAvailable', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Pump a host widget, trigger the nag, and dismiss any dialog it raises.
    ///
    /// The dialog must be dismissed before awaiting: `maybeShowUpdateAvailable`
    /// does not return until `showDialog` closes, so awaiting first would hang.
    Future<bool> run(
      WidgetTester tester, {
      required String current,
      required String? recommended,
      bool dismiss = true,
    }) async {
      Future<bool>? pending;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              pending = maybeShowUpdateAvailable(
                context,
                currentVersion: current,
                recommendedVersion: recommended,
              );
            },
            child: const Text('go'),
          );
        }),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      if (dismiss && find.text('Later').evaluate().isNotEmpty) {
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
      }
      return await pending!;
    }

    testWidgets('does not nag when already up to date', (tester) async {
      expect(await run(tester, current: '1.0.34', recommended: '1.0.34'), isFalse);
      expect(find.text('Update Available'), findsNothing);
    });

    testWidgets('does not nag when ahead of the recommendation', (tester) async {
      expect(await run(tester, current: '1.1.0', recommended: '1.0.34'), isFalse);
    });

    testWidgets('does not nag when the server sets no recommendation', (tester) async {
      expect(await run(tester, current: '1.0.34', recommended: null), isFalse);
      expect(await run(tester, current: '1.0.34', recommended: ''), isFalse);
    });

    testWidgets('nags when behind, offering both Later and Get Update',
        (tester) async {
      Future<bool>? pending;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => pending = maybeShowUpdateAvailable(
              context,
              currentVersion: '1.0.34',
              recommendedVersion: '1.0.35',
            ),
            child: const Text('go'),
          );
        }),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Get Update'), findsOneWidget);
      // The user must be able to carry on and go drive.
      expect(find.textContaining('keep using this version'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update Available'), findsNothing);
      expect(await pending!, isTrue);
    });

    testWidgets('does not repeat the same version within the interval',
        (tester) async {
      expect(await run(tester, current: '1.0.34', recommended: '1.0.35'), isTrue);
      // Second launch, same recommendation — should stay quiet.
      expect(await run(tester, current: '1.0.34', recommended: '1.0.35'), isFalse);
    });

    testWidgets('nags again immediately when a NEWER version is recommended',
        (tester) async {
      expect(await run(tester, current: '1.0.34', recommended: '1.0.35'), isTrue);
      // A fresh release is worth interrupting for even inside the interval.
      expect(await run(tester, current: '1.0.34', recommended: '1.0.36'), isTrue);
    });

    testWidgets('nags again once the interval has elapsed', (tester) async {
      expect(await run(tester, current: '1.0.34', recommended: '1.0.35'), isTrue);
      SharedPreferences.setMockInitialValues({
        'flutter.update_nag_version': '1.0.35',
        'flutter.update_nag_at': DateTime.now()
            .subtract(updateNagInterval + const Duration(minutes: 1))
            .toIso8601String(),
      });
      expect(await run(tester, current: '1.0.34', recommended: '1.0.35'), isTrue);
    });

    testWidgets('stays quiet on a malformed version rather than nagging forever',
        (tester) async {
      // isVersionBelow fails open, so a bad server value must not become a
      // prompt the user can never clear.
      expect(await run(tester, current: '1.0.34', recommended: 'banana'), isFalse);
      expect(await run(tester, current: '1.0.34', recommended: '1.0'), isFalse);
    });
  });
}
