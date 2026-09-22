import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vshape_app/core/models.dart';
import 'package:vshape_app/services/content_service.dart';
import 'package:vshape_app/services/update_controller.dart';

/// End-to-end reasoning about the in-app updater, without any network:
/// release parsing, version-code normalisation, and - most importantly -
/// whether the historical builds in the wild can actually *see* the 1.2.0
/// release.
void main() {
  /// A release payload shaped exactly like the ones CI publishes.
  Map<String, dynamic> release(String tag, {bool withApks = true}) => {
        'tag_name': tag,
        'name': 'V-System',
        'body': 'notes',
        'html_url': 'https://github.com/o/r/releases/tag/$tag',
        'assets': [
          if (withApks)
            for (final n in [
              'V-System-arm64-v8a.apk',
              'V-System-armeabi-v7a.apk',
              'V-System-universal.apk',
              'V-System-x86_64.apk',
            ])
              {'name': n, 'size': 20000000, 'browser_download_url': 'https://dl/$n'},
          {'name': 'version.json', 'size': 60, 'browser_download_url': 'https://dl/version.json'},
          {'name': 'checksums.sha256', 'size': 355, 'browser_download_url': 'https://dl/checksums.sha256'},
        ],
      };

  ReleaseInfo v12({String abi = 'arm64-v8a'}) => UpdateService.parseRelease(
        release('v1.2.0+5000'),
        abi: abi,
        versionJson: const {'versionName': '1.2.0', 'versionCode': 5000},
      );

  group('installed version normalisation', () {
    test('a universal install keeps its plain base code (regression)', () {
      // README tells users to install V-System-universal.apk, whose
      // versionCode carries NO per-ABI offset. Subtracting the device's
      // offset anyway made the code negative, which lit a permanent false
      // "update available" strip on every launch.
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 7, flavor: 'universal', deviceAbi: 'arm64-v8a'),
        7,
      );
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 5000, flavor: 'universal', deviceAbi: 'arm64-v8a'),
        5000,
      );
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 7, flavor: 'universal', deviceAbi: 'armeabi-v7a'),
        7,
      );
    });

    test('a split install strips its own ABI offset', () {
      // Verified against the real v1.1.0+7 assets: the arm64 APK carries
      // 2007, the universal one carries 7.
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 2007, flavor: 'arm64-v8a', deviceAbi: 'arm64-v8a'),
        7,
      );
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 1007, flavor: 'armeabi-v7a', deviceAbi: 'armeabi-v7a'),
        7,
      );
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 3007, flavor: 'x86_64', deviceAbi: 'x86_64'),
        7,
      );
      // The 1.2.0+5000 scheme (split arm64 carries 7000).
      expect(
        ReleaseInfo.normalizeInstalledCode(
            code: 7000, flavor: 'arm64-v8a', deviceAbi: 'arm64-v8a'),
        5000,
      );
    });

    test('legacy installs (no buildFlavor channel) stay plausible', () {
      // 1.1.0 and older have no buildFlavor handler; the heuristic must keep
      // the split code (strip) and the tiny universal code (keep as-is).
      expect(
        ReleaseInfo.normalizeInstalledCode(code: 2007, deviceAbi: 'arm64-v8a'),
        7,
        reason: 'legacy split build: 2007 - 2000',
      );
      expect(
        ReleaseInfo.normalizeInstalledCode(code: 7, deviceAbi: 'arm64-v8a'),
        7,
        reason: 'legacy universal build: 7 - 2000 would go negative',
      );
    });

    test('a universal 1.2.0 install is not newer than itself', () {
      // The exact state after updating: no false strip.
      final installed = ReleaseInfo.normalizeInstalledCode(
          code: 5000, flavor: 'universal', deviceAbi: 'arm64-v8a');
      expect(UpdateChecker.isNewer(latestCode: 5000, installedCode: installed), isFalse);
    });
  });

  group('the 1.2.0+5000 jump rescues every historical build', () {
    // The updater shipped inside 1.0.2/1.0.3 subtracted the device ABI offset
    // from BOTH sides, including the version.json base code that never
    // carried one. Its comparison therefore reduces to:
    //   base_new - offset  >  installedCode - offset
    // i.e. base_new must simply beat the *raw* installed code. The old
    // updaters could never see +8..+5000 over a split install (2003..2007),
    // which is exactly why the base jumps to 5000.
    test('every published 1.x APK on every device ABI sees the update', () {
      const newBase = 5000;
      // Every APK ever shipped, by flavour (verified from the releases).
      const publishedCodes = <String, List<int>>{
        'universal': [3, 4, 5, 6, 7],
        'armeabi-v7a': [1003, 1004, 1005, 1006, 1007],
        'arm64-v8a': [2003, 2004, 2005, 2006, 2007],
        'x86_64': [3003, 3004, 3005, 3006, 3007],
      };
      for (final deviceAbi in ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86', '']) {
        final offset = ReleaseInfo.abiOffsetFor(deviceAbi);
        for (final codes in publishedCodes.values) {
          for (final installed in codes) {
            // What the OLD (1.0.2/1.0.3) app computes:
            final oldAppLatest = newBase - offset;
            final oldAppInstalled = installed - offset;
            expect(
              UpdateChecker.isNewer(
                  latestCode: oldAppLatest, installedCode: oldAppInstalled),
              isTrue,
              reason: 'deviceAbi=$deviceAbi installed=$installed: '
                  'the 1.0.2 updater must offer v1.2.0+5000',
            );
          }
        }
      }
    });

    test('the 1.0.4+ fixed updaters see it too, on every flavour', () {
      // 1.0.4..1.1.0 compare base-to-base but still mis-normalise universal
      // installs (negative) - which now resolves to "update", correctly.
      for (final installedBase in [3, 4, 5, 6, 7]) {
        expect(
          UpdateChecker.isNewer(latestCode: 5000, installedCode: installedBase),
          isTrue,
        );
        expect(
          UpdateChecker.isNewer(latestCode: 5000, installedCode: installedBase - 2000),
          isTrue,
          reason: 'universal install mis-normalised to a negative code',
        );
      }
    });

    test('and after installing 1.2.0 nothing nags anymore', () {
      for (final flavor in ['universal', 'arm64-v8a', 'armeabi-v7a', 'x86_64']) {
        final installed = ReleaseInfo.normalizeInstalledCode(
            code: flavor == 'universal' ? 5000 : 5000 + ReleaseInfo.abiOffsetFor(flavor),
            flavor: flavor,
            deviceAbi: flavor);
        expect(UpdateChecker.isNewer(latestCode: 5000, installedCode: installed),
            isFalse,
            reason: 'flavor=$flavor must be up to date');
      }
    });
  });

  group('release parsing details', () {
    test('picks the APK that matches the device ABI exactly', () {
      for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
        final info = v12(abi: abi);
        expect(info.apkUrl, 'https://dl/V-System-$abi.apk', reason: 'abi=$abi');
        expect(info.apkAssetName, 'V-System-$abi.apk');
        expect(info.abi, abi);
        expect(info.checksumsUrl, 'https://dl/checksums.sha256');
      }
    });

    test('an x86 device never picks the x86_64 APK (substring trap)', () {
      // 'V-System-x86_64.apk'.contains('x86') is true - the old matcher
      // handed an x86 phone an APK it cannot run.
      final info = v12(abi: 'x86');
      expect(info.apkUrl, 'https://dl/V-System-universal.apk');
      expect(info.abi, 'universal');
    });

    test('a name with some other ABI is never used as the universal fallback',
        () {
      final info = UpdateService.parseRelease({
        'tag_name': 'v1.2.0+5000',
        'html_url': 'https://github.com/o/r/releases/tag/v1.2.0+5000',
        'assets': [
          {'name': 'V-System-arm64-v8a.apk', 'size': 1, 'browser_download_url': 'https://dl/a64'},
          {'name': 'V-System-x86_64.apk', 'size': 1, 'browser_download_url': 'https://dl/x64'},
        ],
      }, abi: 'x86');
      expect(info.hasDownloadableApk, isFalse,
          reason: 'no APK that an x86 phone can run');
    });

    test('version.json wins over the tag, and both are base codes', () {
      final info = v12();
      expect(info.versionCode, 5000);
      expect(info.versionName, '1.2.0');
      expect(info.normalizedCode, 5000);
      expect(info.hasDownloadableApk, isTrue);
    });
  });

  group('downloaded-file hygiene', () {
    test('a file downloaded for an older release is dropped on re-check', () {
      final old = v12(abi: 'arm64-v8a');
      final sameTag = UpdateService.parseRelease(
        release('v1.2.0+5000'),
        abi: 'arm64-v8a',
        versionJson: const {'versionName': '1.2.0', 'versionCode': 5000},
      );
      final next = UpdateService.parseRelease(
        release('v1.2.1+5001'),
        abi: 'arm64-v8a',
        versionJson: const {'versionName': '1.2.1', 'versionCode': 5001},
      );
      expect(UpdateController.isStaleDownload(old, sameTag), isFalse,
          reason: 'same release re-checked: keep the file');
      expect(UpdateController.isStaleDownload(old, next), isTrue,
          reason: 'a NEWER release appeared: the old file must go');
      expect(UpdateController.isStaleDownload(null, next), isFalse);
      expect(UpdateController.isStaleDownload(old, null), isFalse);
    });
  });

  group('checksum verification', () {
    test('expectedSha256 picks the line for the right asset', () {
      const sums = ''
          '1111111111111111111111111111111111111111111111111111111111111111  V-System-universal.apk\n'
          '2222222222222222222222222222222222222222222222222222222222222222  V-System-arm64-v8a.apk\n'
          'garbage line without a hash\n';
      expect(UpdateService.expectedSha256(sums, 'V-System-arm64-v8a.apk'),
          '2'.padRight(64, '2'));
      expect(UpdateService.expectedSha256(sums, 'V-System-x86_64.apk'), '');
      expect(UpdateService.expectedSha256(sums, ''), '');
      expect(UpdateService.expectedSha256('', 'x.apk'), '');
    });

    test('sha256OfBytes matches a known digest', () {
      // sha256("hello") - the standard test vector.
      expect(
        UpdateService.sha256OfBytes(utf8.encode('hello')),
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });
  });

  group('content parsing robustness', () {
    test('one malformed list entry never rejects the whole file', () {
      final c = AppContent.fromMap(<String, dynamic>{
        'version': 5,
        'water': <String, dynamic>{
          'goal_ml': 3000,
          'glass_ml': 500,
          'slots': <dynamic>[
            'nope',
            42,
            null,
            <String, dynamic>{'id': 'w1', 'time': '07:00', 'glasses': 1},
          ],
        },
        'food': <String, dynamic>{
          'meals': <dynamic>[
            'bad',
            <String, dynamic>{'id': 'm1', 'title': 'Breakfast'},
          ],
          'protein_sources': <dynamic>[3, <String, dynamic>{'id': 'p1'}],
        },
        'workout': <String, dynamic>{
          'days': <dynamic>['x', <String, dynamic>{'id': 'd1', 'day': 1, 'title': 'Push'}],
        },
        'routine': <dynamic>[1, <String, dynamic>{'id': 'r1', 'time': '06:00'}],
        'rules': <dynamic>[true, <String, dynamic>{'id': 'g1'}],
        'philosophy': <dynamic>['s', <String, dynamic>{'id': 'ph1'}],
        'progress': <String, dynamic>{
          'kpis': <dynamic>['k', <String, dynamic>{'id': 'k1'}],
        },
      });
      expect(c.water.slots.length, 1);
      expect(c.water.slots.first.id, 'w1');
      expect(c.food.meals.length, 1);
      expect(c.food.sources.length, 1);
      expect(c.workout.days.length, 1);
      expect(c.routine.length, 1);
      expect(c.rules.length, 1);
      expect(c.philosophy.length, 1);
      expect(c.progress.kpis.length, 1);
    });

    test('the bundled asset still parses (guard against regressions)', () {
      final raw = File('assets/content/content.json').readAsStringSync();
      final c = AppContent.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      expect(c.version, greaterThan(0));
      expect(c.water.slots, isNotEmpty);
      expect(c.food.meals, isNotEmpty);
      expect(c.workout.days, isNotEmpty);
    });
  });
}
