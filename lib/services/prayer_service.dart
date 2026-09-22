import 'dart:async';
import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';

/// ---------------------------------------------------------------------------
/// Prayer times for V-System.
///
/// Everything here is pure Dart (the `adhan` astronomy package) so it works
/// fully offline and is unit-testable. The wall-clock convention used
/// throughout: a DateTime in the **UTC zone whose clock reading is local
/// civil time** - the same convention `adhan`'s `utcOffset` parameter
/// produces. `wallToInstant()` converts it back to a real moment in time
/// for the Android alarm scheduler.
/// ---------------------------------------------------------------------------

/// The six daily markers. `sunrise` is *not* a prayer (it marks the end of
/// the fajr window) so it never fires a notification - it is shown on screen
/// so the user knows when to stop eating on fast days.
enum PrayerId { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// A city the user can pick (the app is offline-first: no GPS, no permission,
/// just a bundled list of coordinates + the default method for that city).
class City {
  final String id;
  final String ar;
  final String en;
  final double lat;
  final double lng;
  final String methodId; // default calculation method for this city
  final String flag;
  const City(this.id, this.ar, this.en, this.lat, this.lng, this.methodId, this.flag);

  String name(bool ar) => ar ? this.ar : en;
}

/// Calculation methods exposed in the UI. The ids are persisted, so they are
/// part of the stored-data contract - never rename them.
class CalcMethod {
  final String id;
  final String ar;
  final String en;
  final CalculationMethod method;
  const CalcMethod(this.id, this.ar, this.en, this.method);
  String name(bool ar) => ar ? this.ar : en;
}

const kCalcMethods = <CalcMethod>[
  CalcMethod('makkah', 'أم القرى (مكة)', 'Umm al-Qura (Makkah)', CalculationMethod.umm_al_qura),
  CalcMethod('egyptian', 'الهيئة المصرية العامة للمساحة', 'Egyptian General Authority of Survey', CalculationMethod.egyptian),
  CalcMethod('mwl', 'رابطة العالم الإسلامي', 'Muslim World League', CalculationMethod.muslim_world_league),
  CalcMethod('karachi', 'جامعة كراتشي', 'University of Islamic Sciences, Karachi', CalculationMethod.karachi),
  CalcMethod('dubai', 'الخليج (دبي)', 'Gulf region (Dubai)', CalculationMethod.dubai),
  CalcMethod('kuwait', 'الكويت', 'Kuwait', CalculationMethod.kuwait),
  CalcMethod('qatar', 'قطر', 'Qatar', CalculationMethod.qatar),
  CalcMethod('singapore', 'جنوب شرق آسيا (سنغافورة)', 'South-East Asia (Singapore)', CalculationMethod.singapore),
  CalcMethod('turkey', 'ديانت (تركيا)', 'Diyanet (Turkey)', CalculationMethod.turkey),
  CalcMethod('tehran', 'طهران', 'Institute of Geophysics, Tehran', CalculationMethod.tehran),
  CalcMethod('isna', 'أمريكا الشمالية (ISNA)', 'North America (ISNA)', CalculationMethod.north_america),
];

CalcMethod methodById(String id) =>
    kCalcMethods.firstWhere((m) => m.id == id, orElse: () => kCalcMethods.first);

/// Bundled city list: every Arab capital + the big Muslim-world cities +
/// the main diaspora hubs. Ordered roughly west -> east, Arabic first class.
const kCities = <City>[
  // --- Morocco / Mauritania / Maghreb west
  City('casablanca', 'الدار البيضاء', 'Casablanca', 33.5731, -7.5898, 'mwl', '🇲🇦'),
  City('rabat', 'الرباط', 'Rabat', 34.0209, -6.8416, 'mwl', '🇲🇦'),
  City('nouakchott', 'نواكشوط', 'Nouakchott', 18.0735, -15.9582, 'mwl', '🇲🇷'),
  // --- Algeria / Tunisia
  City('algiers', 'الجزائر', 'Algiers', 36.7538, 3.0588, 'mwl', '🇩🇿'),
  City('oran', 'وهران', 'Oran', 35.6971, -0.6308, 'mwl', '🇩🇿'),
  City('tunis', 'تونس', 'Tunis', 36.8065, 10.1815, 'mwl', '🇹🇳'),
  // --- Libya / Egypt / Sudan
  City('tripoli', 'طرابلس', 'Tripoli', 32.8872, 13.1913, 'mwl', '🇱🇾'),
  City('benghazi', 'بنغازي', 'Benghazi', 32.1167, 20.0667, 'mwl', '🇱🇾'),
  City('cairo', 'القاهرة', 'Cairo', 30.0444, 31.2357, 'egyptian', '🇪🇬'),
  City('alexandria', 'الإسكندرية', 'Alexandria', 31.2001, 29.9187, 'egyptian', '🇪🇬'),
  City('asyut', 'أسيوط', 'Asyut', 27.1809, 31.1837, 'egyptian', '🇪🇬'),
  City('khartoum', 'الخرطوم', 'Khartoum', 15.5007, 32.5599, 'mwl', '🇸🇩'),
  // --- Levant
  City('jerusalem', 'القدس', 'Jerusalem', 31.7683, 35.2137, 'egyptian', '🇵🇸'),
  City('gaza', 'غزة', 'Gaza', 31.5017, 34.4668, 'egyptian', '🇵🇸'),
  City('amman', 'عمّان', 'Amman', 31.9539, 35.9106, 'egyptian', '🇯🇴'),
  City('beirut', 'بيروت', 'Beirut', 33.8938, 35.5018, 'egyptian', '🇱🇧'),
  City('damascus', 'دمشق', 'Damascus', 33.5138, 36.2765, 'egyptian', '🇸🇾'),
  City('aleppo', 'حلب', 'Aleppo', 36.2021, 37.1343, 'egyptian', '🇸🇾'),
  City('homs', 'حمص', 'Homs', 34.7324, 36.7137, 'egyptian', '🇸🇾'),
  // --- Iraq
  City('baghdad', 'بغداد', 'Baghdad', 33.3152, 44.3661, 'mwl', '🇮🇶'),
  City('basra', 'البصرة', 'Basra', 30.5085, 47.7804, 'mwl', '🇮🇶'),
  City('mosul', 'الموصل', 'Mosul', 36.335, 43.1189, 'mwl', '🇮🇶'),
  // --- Gulf
  City('riyadh', 'الرياض', 'Riyadh', 24.7136, 46.6753, 'makkah', '🇸🇦'),
  City('jeddah', 'جدة', 'Jeddah', 21.4858, 39.1925, 'makkah', '🇸🇦'),
  City('makkah', 'مكة المكرمة', 'Makkah', 21.3891, 39.8579, 'makkah', '🇸🇦'),
  City('madinah', 'المدينة المنورة', 'Madinah', 24.5247, 39.5692, 'makkah', '🇸🇦'),
  City('dammam', 'الدمام', 'Dammam', 26.4207, 50.0888, 'makkah', '🇸🇦'),
  City('kuwait', 'مدينة الكويت', 'Kuwait City', 29.3759, 47.9774, 'kuwait', '🇰🇼'),
  City('manama', 'المنامة', 'Manama', 26.2285, 50.5860, 'kuwait', '🇧🇭'),
  City('doha', 'الدوحة', 'Doha', 25.2854, 51.5310, 'qatar', '🇶🇦'),
  City('dubai', 'دبي', 'Dubai', 25.2048, 55.2708, 'dubai', '🇦🇪'),
  City('abudhabi', 'أبوظبي', 'Abu Dhabi', 24.4539, 54.3773, 'dubai', '🇦🇪'),
  City('sharjah', 'الشارقة', 'Sharjah', 25.3463, 55.4209, 'dubai', '🇦🇪'),
  City('muscat', 'مسقط', 'Muscat', 23.5880, 58.3829, 'makkah', '🇴🇲'),
  // --- Yemen
  City('sanaa', 'صنعاء', 'Sanaa', 15.3694, 44.1910, 'mwl', '🇾🇪'),
  City('aden', 'عدن', 'Aden', 12.7855, 45.0187, 'mwl', '🇾🇪'),
  // --- Turkey / Iran
  City('istanbul', 'إستنبول', 'Istanbul', 41.0082, 28.9784, 'turkey', '🇹🇷'),
  City('ankara', 'أنقرة', 'Ankara', 39.9334, 32.8597, 'turkey', '🇹🇷'),
  City('tehran', 'طهران', 'Tehran', 35.6892, 51.3890, 'tehran', '🇮🇷'),
  // --- South Asia
  City('karachi', 'كراتشي', 'Karachi', 24.8607, 67.0011, 'karachi', '🇵🇰'),
  City('lahore', 'لاهور', 'Lahore', 31.5204, 74.3587, 'karachi', '🇵🇰'),
  City('islamabad', 'إسلام آباد', 'Islamabad', 33.6844, 73.0479, 'karachi', '🇵🇰'),
  City('delhi', 'دلهي', 'Delhi', 28.6139, 77.2090, 'karachi', '🇮🇳'),
  City('dhaka', 'دكا', 'Dhaka', 23.8103, 90.4125, 'karachi', '🇧🇩'),
  // --- South-East Asia
  City('kualalumpur', 'كوالالمبور', 'Kuala Lumpur', 3.1390, 101.6869, 'singapore', '🇲🇾'),
  City('jakarta', 'جاكرتا', 'Jakarta', -6.2088, 106.8456, 'singapore', '🇮🇩'),
  // --- Diaspora / other capitals
  City('london', 'لندن', 'London', 51.5074, -0.1278, 'mwl', '🇬🇧'),
  City('paris', 'باريس', 'Paris', 48.8566, 2.3522, 'mwl', '🇫🇷'),
  City('berlin', 'برلين', 'Berlin', 52.5200, 13.4050, 'mwl', '🇩🇪'),
  City('stockholm', 'ستوكهولم', 'Stockholm', 59.3293, 18.0686, 'mwl', '🇸🇪'),
  City('moscow', 'موسكو', 'Moscow', 55.7558, 37.6173, 'mwl', '🇷🇺'),
  City('newyork', 'نيويورك', 'New York', 40.7128, -74.0060, 'isna', '🇺🇸'),
  City('chicago', 'شيكاغو', 'Chicago', 41.8781, -87.6298, 'isna', '🇺🇸'),
  City('losangeles', 'لوس أنجلوس', 'Los Angeles', 34.0522, -118.2437, 'isna', '🇺🇸'),
  City('toronto', 'تورونتو', 'Toronto', 43.6532, -79.3832, 'isna', '🇨🇦'),
];

City? cityById(String? id) =>
    id == null ? null : kCities.where((c) => c.id == id).firstOrNull;

/// Persisted settings (all keys live under the `K` namespace in prefs).
class PrayerSettings {
  final City? city;
  final String? methodOverride; // null => use the city's default method
  final bool hanafi; // Hanafi asr (later, 2× shadow)
  final bool notify;
  const PrayerSettings({this.city, this.methodOverride, this.hanafi = false, this.notify = true});

  CalcMethod get method {
    final ov = methodOverride;
    if (ov != null && ov.isNotEmpty) return methodById(ov);
    final c = city;
    if (c != null && kCalcMethods.any((m) => m.id == c.methodId)) return methodById(c.methodId);
    return kCalcMethods.first;
  }

  bool get configured => city != null;

  static PrayerSettings load(SharedPreferences p) => PrayerSettings(
        city: cityById(p.getString(K.prayerCity)),
        methodOverride: p.getString(K.prayerMethod),
        hanafi: p.getBool(K.prayerHanafi) ?? false,
        notify: p.getBool(K.prayerNotify) ?? true,
      );
}

/// One computed prayer time.
class PrayerEntry {
  final PrayerId id;
  final DateTime wall; // UTC-zoned DateTime carrying the local clock reading
  const PrayerEntry(this.id, this.wall);
}

/// All six markers for one calendar day.
class DayPrayers {
  final DateTime day; // local calendar date (any zone, only y/m/d are read)
  final List<PrayerEntry> entries;
  const DayPrayers(this.day, this.entries);
}

/// The next marker after [now], possibly tomorrow's fajr.
class NextPrayer {
  final PrayerId id;
  final DateTime wall;
  final bool tomorrow;
  const NextPrayer(this.id, this.wall, {required this.tomorrow});
}

/// Converts a wall-clock DateTime (UTC zone, local reading) to epoch ms.
int wallToInstant(DateTime wall, Duration offset) =>
    wall.subtract(offset).millisecondsSinceEpoch;

/// Local wall-clock "now" in the same convention the computed times use
/// (a UTC-zoned DateTime whose clock reading is local civil time).
DateTime wallNow(Duration offset) => DateTime.now().toUtc().add(offset);

String prayerName(PrayerId id, bool ar) {
  switch (id) {
    case PrayerId.fajr:
      return ar ? 'الفجر' : 'Fajr';
    case PrayerId.sunrise:
      return ar ? 'الشروق' : 'Sunrise';
    case PrayerId.dhuhr:
      return ar ? 'الظهر' : 'Dhuhr';
    case PrayerId.asr:
      return ar ? 'العصر' : 'Asr';
    case PrayerId.maghrib:
      return ar ? 'المغرب' : 'Maghrib';
    case PrayerId.isha:
      return ar ? 'العشاء' : 'Isha';
  }
}

/// 12-hour clock, Arabic ص/م suffix in Arabic, AM/PM in English.
String fmtClock(DateTime wall, bool ar) {
  final h24 = wall.hour;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = wall.minute.toString().padLeft(2, '0');
  final am = h24 < 12;
  if (ar) return '$h:$m ${am ? 'ص' : 'م'}';
  return '$h:$m ${am ? 'AM' : 'PM'}';
}

/// Core calculator - pure and synchronous (the astronomy is microsecond-grade).
DayPrayers computeDay(City city, DateTime localDate, CalcMethod method, bool hanafi,
    {Duration? offset}) {
  final off = offset ?? DateTime.now().timeZoneOffset;
  final p = method.method.getParameters();
  p.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
  // High-latitude safety (London/Stockholm in deep winter): the library
  // itself falls back to angle-based or middle-of-night resolution.
  final pt = PrayerTimes(
    Coordinates(city.lat, city.lng),
    DateComponents(localDate.year, localDate.month, localDate.day),
    p,
    utcOffset: off,
  );
  return DayPrayers(localDate, [
    PrayerEntry(PrayerId.fajr, pt.fajr),
    PrayerEntry(PrayerId.sunrise, pt.sunrise),
    PrayerEntry(PrayerId.dhuhr, pt.dhuhr),
    PrayerEntry(PrayerId.asr, pt.asr),
    PrayerEntry(PrayerId.maghrib, pt.maghrib),
    PrayerEntry(PrayerId.isha, pt.isha),
  ]);
}

/// Next marker strictly after [now] (wall-clock convention).
NextPrayer? nextAfter(List<DayPrayers> days, DateTime now) {
  for (final d in days) {
    for (final e in d.entries) {
      if (e.wall.isAfter(now)) {
        final tomorrow = d.day.day != now.day || d.day.month != now.month;
        return NextPrayer(e.id, e.wall, tomorrow: tomorrow);
      }
    }
  }
  return null;
}

/// Builds the 7-day alarm batch handed to the native scheduler.
///
/// [now] is a real *instant* (any zone; `DateTime.now()` in production).
/// `sunrise` is excluded (not a prayer). IDs are deterministic per
/// (day, prayer) so re-scheduling replaces the same PendingIntent instead of
/// piling up: 5000 + dayIndex*10 + prayerIndex, i.e. the range 5000-5064.
/// Reminder alarms use 100+, the rest timer 9001+, receiver notify ids
/// 2000+/7000+ - no collisions.
List<Map<String, dynamic>> buildNotificationBatch(
    City city, CalcMethod method, bool hanafi, DateTime now,
    {int days = 7, Duration? offset, bool arabic = true}) {
  final off = offset ?? DateTime.now().timeZoneOffset;
  final nowWall = now.toUtc().add(off);
  final todayLocal = DateTime(nowWall.year, nowWall.month, nowWall.day);
  final out = <Map<String, dynamic>>[];
  const prayers = [
    PrayerId.fajr,
    PrayerId.dhuhr,
    PrayerId.asr,
    PrayerId.maghrib,
    PrayerId.isha
  ];
  for (var d = 0; d < days; d++) {
    final date = todayLocal.add(Duration(days: d));
    final day = computeDay(city, date, method, hanafi, offset: off);
    for (var i = 0; i < prayers.length; i++) {
      final e = day.entries.firstWhere((x) => x.id == prayers[i]);
      if (!e.wall.isAfter(nowWall)) continue; // past times are pointless
      out.add({
        'id': 5000 + d * 10 + i,
        'at': wallToInstant(e.wall, off),
        'title': arabic
            ? '🕌 حان وقت صلاة ${prayerName(e.id, true)}'
            : '🕌 It is time for ${prayerName(e.id, false)}',
        'body': arabic
            ? 'تقبّل الله طاعتك — ${city.name(true)}'
            : 'May Allah accept it - ${city.name(false)}',
      });
    }
  }
  out.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
  return out;
}

/// ---------------------------------------------------------------------------
/// Platform glue (mirrors the `Reminders` class for the daily alarms).
/// ---------------------------------------------------------------------------

class Prayers {
  Prayers._();

  static const MethodChannel _ch = MethodChannel('vshape/native');

  static PrayerSettings settingsOf(AppState st) => PrayerSettings.load(st.prefs);

  /// Re-applies prayer notifications after any settings change or app boot.
  /// Returns the number of alarms scheduled (0 when off / not configured).
  static Future<int> apply(AppState st) async {
    if (!Platform.isAndroid) return 0;
    final s = settingsOf(st);
    if (!s.configured || !s.notify) {
      await cancel();
      return 0;
    }
    final batch = buildNotificationBatch(
      s.city!,
      s.method,
      s.hanafi,
      DateTime.now(),
      arabic: st.isArabic,
    );
    try {
      await _ch.invokeMethod<void>('schedulePrayers', {'prayers': batch});
    } catch (_) {
      return 0;
    }
    return batch.length;
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod<void>('cancelPrayers');
    } catch (_) {}
  }

  /// Next prayer info for the home-screen widget; null when not configured.
  static NextPrayer? nextForWidget(PrayerSettings s, {Duration? offset}) {
    final c = s.city;
    if (c == null) return null;
    final off = offset ?? DateTime.now().timeZoneOffset;
    final nowWall = wallNow(off);
    final today = computeDay(
        c, DateTime(nowWall.year, nowWall.month, nowWall.day), s.method, s.hanafi,
        offset: off);
    final tomorrow = computeDay(
        c,
        DateTime(nowWall.year, nowWall.month, nowWall.day)
            .add(const Duration(days: 1)),
        s.method,
        s.hanafi,
        offset: off);
    return nextAfter([today, tomorrow], nowWall);
  }
}
