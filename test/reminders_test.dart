// Tests for the logic that runs *outside* the UI:
//   - reminder scheduling built from the content file (remind flags, dedupe),
//   - the release/versionCode normalisation the in-app updater depends on,
//   - the "is there a newer version?" decision,
//   - root/bundled content.json staying in sync.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vshape_app/core/models.dart';
import 'package:vshape_app/core/native_bridge.dart';
import 'package:vshape_app/services/content_service.dart';
import 'package:vshape_app/services/update_controller.dart';

AppContent _bundled() => AppContent.fromMap(
    jsonDecode(File('assets/content/content.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  group('Reminders.buildAlarms', () {
    test('skips water slots flagged remind:false and keeps workout + sleep', () {
      final c = _bundled();
      final silent = c.water.slots.where((s) => !s.remind).toList();
      expect(silent, isNotEmpty,
          reason: 'the bundled content must contain a remind:false slot for this test');

      final alarms = Reminders.buildAlarms(c, true);

      for (final s in silent) {
        final hits = alarms.where((a) => a['slot'] == s.id).toList();
        expect(hits, isEmpty, reason: 'slot ${s.id} has remind:false but was scheduled');
      }

      // expected schedule = (slots with remind:true) U (reminders.water)
      //                     U workout U sleep, deduplicated by normalised time
      String norm(String t) {
        final p = t.split(':');
        return '${int.parse(p[0]) % 24}:${int.parse(p[1]) % 60}';
      }

      final wanted = <String>{
        for (final s in c.water.slots)
          if (s.remind) norm(s.time),
        for (final t in c.reminders.water) norm(t),
        norm(c.reminders.workout),
        norm(c.reminders.sleep),
      };
      for (final a in alarms) {
        final at = '${a['hour']}:${a['minute']}';
        expect(wanted.contains(at), isTrue, reason: 'unexpected alarm $at');
      }

      final scheduled = alarms.map((a) => '${a['hour']}:${a['minute']}').toList();
      expect(scheduled.toSet().length, alarms.length, reason: 'nothing scheduled twice');
      expect(alarms.length, wanted.length, reason: 'no duplicates and nothing dropped');
      expect(alarms.map((a) => a['id']).toSet().length, alarms.length,
          reason: 'alarm ids must be unique or AlarmManager overwrites them');
      expect(alarms.last['title'].toString(), contains('📵'));
    });

    test('an override time that duplicates a slot is not scheduled twice', () {
      final c = _bundled();
      final first = c.water.slots.firstWhere((s) => s.remind);
      final dup = '${int.parse(first.time.split(':')[0])}:${first.time.split(':')[1]}';

      final alarms = Reminders.buildAlarms(
        AppContent.fromMap({
          ...c.raw,
          'reminders': {...c.raw['reminders'] as Map, 'water': [dup, '03:04']},
        }),
        false,
      );

      final atDup = alarms.where((a) => '${a['hour']}:${a['minute']}' == dup).toList();
      expect(atDup.length, 1, reason: 'the slot already covers $dup');
      expect(alarms.any((a) => a['hour'] == 3 && a['minute'] == 4), isTrue);
    });

    test('Arabic and English produce the same schedule, different copy', () {
      final c = _bundled();
      final ar = Reminders.buildAlarms(c, true);
      final en = Reminders.buildAlarms(c, false);
      expect(ar.length, en.length);
      for (var i = 0; i < ar.length; i++) {
        expect(ar[i]['hour'], en[i]['hour']);
        expect(ar[i]['minute'], en[i]['minute']);
      }
      expect(ar.first['body'], isNot(en.first['body']));
    });
  });

  group('release version codes', () {
    test('per-ABI offsets are stripped so split and universal compare equal', () {
      ReleaseInfo info(String abi, int code) => ReleaseInfo(
            tagName: 'v1.0.3+$code',
            name: 'x',
            versionCode: code,
            versionName: '1.0.3',
            notes: '',
            apkUrl: 'https://example/app.apk',
            apkSize: 1,
            abi: abi,
          );

      // what CI publishes for pubspec `version: 1.0.3+4`
      expect(info('arm64-v8a', 2004).normalizedCode, 4);
      expect(info('armeabi-v7a', 1004).normalizedCode, 4);
      expect(info('x86_64', 3004).normalizedCode, 4);
      expect(info('universal', 4).normalizedCode, 4);
      expect(ReleaseInfo.abiOffsetFor(''), 0);
    });

    test('the updater offers a build only when it is genuinely newer', () {
      expect(UpdateChecker.isNewer(latestCode: 4, installedCode: 3), isTrue);
      expect(UpdateChecker.isNewer(latestCode: 3, installedCode: 3), isFalse,
          reason: 'same build must not nag');
      expect(UpdateChecker.isNewer(latestCode: 3, installedCode: 2003), isFalse,
          reason: 'an unnormalised arm64 code must not look ancient');
      expect(UpdateChecker.isNewer(latestCode: 12, installedCode: 9), isTrue);
    });
  });

  group('content.json hygiene', () {
    test('root copy and bundled asset are identical', () {
      final root = File('content.json').readAsStringSync();
      final asset = File('assets/content/content.json').readAsStringSync();
      expect(jsonDecode(root), jsonDecode(asset),
          reason: 'cp content.json assets/content/content.json');
    });

    test('remind flags, times and ids are well formed', () {
      final c = _bundled();
      final timeRe = RegExp(r'^\d{1,2}:\d{2}$');
      for (final s in c.water.slots) {
        expect(timeRe.hasMatch(s.time), isTrue, reason: s.id);
        expect(s.glasses, greaterThan(0), reason: s.id);
      }
      final ids = c.water.slots.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(timeRe.hasMatch(c.reminders.workout), isTrue);
      expect(timeRe.hasMatch(c.reminders.sleep), isTrue);
      // at least 60% of the goal must be reachable from the schedule alone
      expect(c.water.slotTotalMl, greaterThanOrEqualTo(c.water.goalMl * 0.9));
    });
  });
}
