import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vshape_app/core/app_state.dart';
import 'package:vshape_app/services/prayer_service.dart';
import 'package:vshape_app/services/widget_bridge.dart';

/// The whole prayer pipeline is pure Dart, so everything - astronomy,
/// next-prayer selection, the 7-day notification batch, widget payload -
/// is testable without a device.
void main() {
  // A fixed offset (UTC+3, no DST) keeps every assertion deterministic.
  const off = Duration(hours: 3);
  DateTime wall(int y, int m, int d, int h, int min) =>
      DateTime.utc(y, m, d, h, min);

  group('city list', () {
    test('ids are unique', () {
      final ids = kCities.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('coordinates are sane and methods exist', () {
      for (final c in kCities) {
        expect(c.lat, inInclusiveRange(-90, 90), reason: c.id);
        expect(c.lng, inInclusiveRange(-180, 180), reason: c.id);
        expect(kCalcMethods.any((m) => m.id == c.methodId), isTrue,
            reason: '${c.id} -> ${c.methodId}');
      }
    });

    test('lookup finds and misses', () {
      expect(cityById('damascus')?.ar, 'دمشق');
      expect(cityById('nope'), isNull);
      expect(cityById(null), isNull);
    });
  });

  group('astronomy', () {
    // Structure + reference values for several cities/methods/seasons.
    // Each case carries its city's real UTC offset so the wall-clock
    // assertions are meaningful.
    final cases = [
      ('makkah', 'makkah', DateTime(2025, 1, 15), const Duration(hours: 3)),
      ('damascus', 'egyptian', DateTime(2025, 6, 15), const Duration(hours: 3)),
      ('cairo', 'egyptian', DateTime(2025, 3, 20), const Duration(hours: 2)),
      ('london', 'mwl', DateTime(2025, 12, 21), const Duration()),
      ('karachi', 'karachi', DateTime(2025, 9, 23), const Duration(hours: 5)),
      ('newyork', 'isna', DateTime(2025, 7, 1), const Duration(hours: -4)),
    ];

    for (final (cityId, methodId, date, cityOff) in cases) {
      test('$cityId $methodId ${date.toIso8601String()} ordering + ranges', () {
        final city = cityById(cityId)!;
        final day = computeDay(city, date, methodById(methodId), false, offset: cityOff);
        final t = [for (final e in day.entries) e.wall];

        // strictly increasing
        for (var i = 1; i < t.length; i++) {
          expect(t[i].isAfter(t[i - 1]), isTrue,
              reason: '${day.entries[i - 1].id} >= ${day.entries[i].id}');
        }
        // fajr is in the early morning, maghrib in the (late) afternoon/evening
        // (15 = London in deep winter; 21 = Karachi in summer)
        expect(day.entries[0].wall.hour, inInclusiveRange(0, 7));
        expect(day.entries[4].wall.hour, inInclusiveRange(15, 21));
        // every marker lands on the requested calendar day
        for (final e in day.entries) {
          expect(e.wall.day, date.day, reason: e.id.toString());
        }
      });
    }

    test('Makkah 2025-01-15 matches Umm al-Qura reference (±6 min)', () {
      final day = computeDay(cityById('makkah')!, DateTime(2025, 1, 15),
          methodById('makkah'), false,
          offset: off);
      // Reference values from the official Umm al-Qura calendar.
      final expectMin = <PrayerId, int>{
        PrayerId.fajr: 5 * 60 + 38,
        PrayerId.sunrise: 6 * 60 + 59,
        PrayerId.dhuhr: 12 * 60 + 27,
        PrayerId.maghrib: 17 * 60 + 55,
        PrayerId.isha: 19 * 60 + 25,
      };
      for (final e in day.entries) {
        final want = expectMin[e.id];
        if (want == null) continue;
        final got = e.wall.hour * 60 + e.wall.minute;
        expect((got - want).abs(), lessThan(6), reason: e.id.toString());
      }
    });

    test('Damascus 2025-06-15 fajr matches reference exactly', () {
      final day = computeDay(cityById('damascus')!, DateTime(2025, 6, 15),
          methodById('egyptian'), false, offset: off);
      final fajr = day.entries.firstWhere((e) => e.id == PrayerId.fajr).wall;
      expect(fajr.hour, 3);
      expect(fajr.minute, 31);
    });

    test('solar noon: dhuhr tracks the longitude-vs-timezone difference', () {
      // Damascus (36.28E) with UTC+3: solar noon ~ 12:34 + equation-of-time.
      final day = computeDay(cityById('damascus')!, DateTime(2025, 6, 15),
          methodById('egyptian'), false, offset: off);
      final dhuhr = day.entries.firstWhere((e) => e.id == PrayerId.dhuhr).wall;
      final mins = dhuhr.hour * 60 + dhuhr.minute;
      expect(mins, inInclusiveRange(12 * 60 + 20, 12 * 60 + 50));
    });

    test('hanafi asr is later than shafii asr', () {
      final city = cityById('damascus')!;
      final shafi = computeDay(city, DateTime(2025, 6, 15), methodById('egyptian'), false, offset: off);
      final hanafi = computeDay(city, DateTime(2025, 6, 15), methodById('egyptian'), true, offset: off);
      final a = shafi.entries.firstWhere((e) => e.id == PrayerId.asr).wall;
      final b = hanafi.entries.firstWhere((e) => e.id == PrayerId.asr).wall;
      expect(b.isAfter(a), isTrue);
    });

    test('high-latitude London winter resolves every marker', () {
      final day = computeDay(cityById('london')!, DateTime(2025, 12, 21),
          methodById('mwl'), false, offset: off);
      expect(day.entries.length, 6);
      for (var i = 1; i < day.entries.length; i++) {
        expect(day.entries[i].wall.isAfter(day.entries[i - 1].wall), isTrue);
      }
    });

    test('times drift by ~1 min/day (tomorrow vs today)', () {
      final city = cityById('cairo')!;
      final cairoOff = const Duration(hours: 2);
      final today = computeDay(city, DateTime(2025, 3, 20), methodById('egyptian'), false, offset: cairoOff);
      final tomorrow = computeDay(city, DateTime(2025, 3, 21), methodById('egyptian'), false, offset: cairoOff);
      int minsOfDay(DateTime w) => w.hour * 60 + w.minute;
      final d1 = today.entries.firstWhere((e) => e.id == PrayerId.dhuhr).wall;
      final d2 = tomorrow.entries.firstWhere((e) => e.id == PrayerId.dhuhr).wall;
      // compare clock readings, not instants (the instants are 24 h apart!)
      final drift = (minsOfDay(d2) - minsOfDay(d1)).abs();
      final m1 = today.entries.firstWhere((e) => e.id == PrayerId.maghrib).wall;
      final m2 = tomorrow.entries.firstWhere((e) => e.id == PrayerId.maghrib).wall;
      expect(drift, lessThan(3), reason: 'dhuhr drift was $drift min');
      expect((minsOfDay(m2) - minsOfDay(m1)).abs(), lessThan(3));
    });
  });

  group('next prayer selection', () {
    final city = cityById('damascus')!;
    final method = methodById('egyptian');

    NextPrayer? nextAt(DateTime wallClock) {
      // `wallClock` is a local civil-time reading (h/min of the day).
      final nowWall = DateTime.utc(wallClock.year, wallClock.month,
          wallClock.day, wallClock.hour, wallClock.minute);
      final today = computeDay(city, DateTime(nowWall.year, nowWall.month, nowWall.day), method, false, offset: off);
      final tomorrow = computeDay(
          city,
          DateTime(nowWall.year, nowWall.month, nowWall.day).add(const Duration(days: 1)),
          method, false, offset: off);
      return nextAfter([today, tomorrow], nowWall);
    }

    test('morning -> fajr', () {
      final n = nextAt(DateTime(2025, 6, 15, 3, 0));
      expect(n!.id, PrayerId.fajr);
      expect(n.tomorrow, isFalse);
    });

    test('after fajr -> sunrise', () {
      final n = nextAt(DateTime(2025, 6, 15, 4, 0));
      expect(n!.id, PrayerId.sunrise);
    });

    test('midday -> dhuhr or asr', () {
      final n = nextAt(DateTime(2025, 6, 15, 13, 0));
      expect(n!.id == PrayerId.dhuhr || n.id == PrayerId.asr, isTrue);
    });

    test('late night -> tomorrow fajr', () {
      final n = nextAt(DateTime(2025, 6, 15, 23, 30));
      expect(n!.id, PrayerId.fajr);
      expect(n.tomorrow, isTrue);
    });

    test('exactly at a prayer time -> the next one (strictly after)', () {
      final day = computeDay(city, DateTime(2025, 6, 15), method, false, offset: off);
      final fajr = day.entries.firstWhere((e) => e.id == PrayerId.fajr).wall;
      // `fajr` is a UTC-zoned wall clock; rebuild a local-zoned DateTime at
      // the same reading for the comparison.
      final atFajr = DateTime(2025, 6, 15, fajr.hour, fajr.minute);
      final n = nextAt(atFajr);
      expect(n!.id, PrayerId.sunrise);
    });
  });

  group('notification batch', () {
    test('7 days, no sunrise, ids deterministic, all future, sorted', () {
      final city = cityById('damascus')!;
      // 10:00 wall at UTC+3 == 07:00 UTC instant
      final now = DateTime.utc(2025, 6, 15, 7, 0);
      final batch = buildNotificationBatch(city, methodById('egyptian'), false,
          now, offset: off, arabic: true);

      expect(batch.length, 35 - 1); // 7*5 minus today's already-passed fajr

      // no sunrise ever
      for (final b in batch) {
        expect(b['title'], isNot(contains('الشروق')));
      }
      // all in the future
      final nowMs = now.toUtc().millisecondsSinceEpoch;
      for (final b in batch) {
        expect(b['at'] as int, greaterThan(nowMs));
      }
      // ids unique and in the reserved 5000-5064 range
      final ids = batch.map((b) => b['id'] as int).toSet();
      expect(ids.length, batch.length);
      for (final id in ids) {
        expect(id, inInclusiveRange(5000, 5064));
      }
      // sorted by time
      final ats = batch.map((b) => b['at'] as int).toList();
      expect(ats, equals([...ats]..sort()));
      // title/body carry the prayer name and the city
      expect(batch.first['title'], contains('صلاة'));
      expect(batch.first['body'], contains('دمشق'));
    });

    test('wallToInstant round-trips through the offset', () {
      final w = wall(2025, 6, 15, 12, 0);
      final instant = wallToInstant(w, off);
      // 12:00 wall at UTC+3 == 09:00 UTC
      expect(DateTime.fromMillisecondsSinceEpoch(instant, isUtc: true).hour, 9);
    });

    test('english batch copy', () {
      // 10:00 wall at UTC+0 == 10:00 UTC instant
      final batch = buildNotificationBatch(cityById('london')!,
          methodById('mwl'), false, DateTime.utc(2025, 12, 21, 10, 0),
          offset: const Duration(), arabic: false);
      expect(batch.first['title'], contains('It is time for'));
      expect(batch.first['body'], contains('London'));
    });
  });

  group('settings persistence', () {
    test('defaults: unconfigured, notify on', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final s = PrayerSettings.load(prefs);
      expect(s.configured, isFalse);
      expect(s.city, isNull);
      expect(s.notify, isTrue);
      expect(s.hanafi, isFalse);
    });

    test('city default method + override', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        K.prayerCity: 'riyadh',
      });
      final prefs = await SharedPreferences.getInstance();
      final s = PrayerSettings.load(prefs);
      expect(s.method.id, 'makkah'); // riyadh -> umm al-qura

      await prefs.setString(K.prayerMethod, 'mwl');
      final s2 = PrayerSettings.load(prefs);
      expect(s2.method.id, 'mwl');

      // blank override -> falls back to the city default
      await prefs.setString(K.prayerMethod, '');
      expect(PrayerSettings.load(prefs).method.id, 'makkah');
    });

    test('unknown persisted ids fall back safely', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        K.prayerCity: 'atlantis',
        K.prayerMethod: 'no_such_method',
      });
      final prefs = await SharedPreferences.getInstance();
      final s = PrayerSettings.load(prefs);
      expect(s.city, isNull); // unknown city -> unconfigured
      expect(s.method.id, kCalcMethods.first.id); // unknown method -> first
    });
  });

  group('widget payload', () {
    test('prayer line appears once a city is picked, empty otherwise', () async {
      // unconfigured
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var st = await AppState.boot();
      var json = WidgetData.from(st).toJson();
      expect(json['prayer'], '');

      // configured -> line + left populated
      SharedPreferences.setMockInitialValues(<String, Object>{
        K.prayerCity: 'damascus',
      });
      st = await AppState.boot();
      json = WidgetData.from(st).toJson();
      expect(json['prayer'].toString().startsWith('🕋'), isTrue);
      expect(json['prayer'].toString(), contains('·'));
      expect(json['prayerLeft'].toString(), isNotEmpty);
    });
  });

  group('clock formatting', () {
    test('12h clock with arabic/english suffixes', () {
      expect(fmtClock(wall(2025, 1, 1, 0, 5), true), '12:05 ص');
      expect(fmtClock(wall(2025, 1, 1, 13, 0), true), '1:00 م');
      expect(fmtClock(wall(2025, 1, 1, 12, 0), false), '12:00 PM');
      expect(fmtClock(wall(2025, 1, 1, 23, 59), false), '11:59 PM');
      expect(fmtClock(wall(2025, 1, 1, 12, 0), true), '12:00 م');
    });

    test('prayer names bilingual', () {
      expect(prayerName(PrayerId.fajr, true), 'الفجر');
      expect(prayerName(PrayerId.isha, false), 'Isha');
    });
  });
}
