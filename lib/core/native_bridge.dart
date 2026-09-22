import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_state.dart';
import 'models.dart';

/// All platform-channel traffic with the Kotlin side live here.
class Native {
  static const MethodChannel _ch = MethodChannel('vshape/native');

  static Future<Map<String, dynamic>> packageInfo() async {
    try {
      final r = await _ch.invokeMethod<dynamic>('packageInfo');
      if (r is Map) return r.cast<String, dynamic>();
    } catch (_) {}
    return {'versionName': '1.0.0', 'versionCode': 1};
  }

  /// versionCode / versionName of the installed build.
  static Future<int> versionCode() async {
    final p = await packageInfo();
    final v = p['versionCode'];
    return v is num ? v.toInt() : int.tryParse('$v') ?? 1;
  }

  /// Primary supported ABI of this device, e.g. "arm64-v8a".
  static Future<String> deviceAbi() async {
    try {
      final r = await _ch.invokeMethod<String>('deviceAbi');
      return r ?? '';
    } catch (_) {
      return '';
    }
  }

  /// "universal" when the installed APK ships every ABI (its versionCode
  /// carries no per-ABI offset), otherwise the single ABI it was built for
  /// (e.g. "arm64-v8a"). '' when the answer is unavailable - the updater then
  /// falls back to a plain code heuristic.
  ///
  /// This is what makes versionCode comparison unambiguous: the Kotlin side
  /// opens the installed APK and counts its `lib/<abi>/` folders.
  static Future<String> buildFlavor() async {
    try {
      return await _ch.invokeMethod<String>('buildFlavor') ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> canRequestUnknownSources() async {
    try {
      return await _ch.invokeMethod<bool>('canRequestUnknownSources') ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openUnknownSourcesSettings() =>
      _ch.invokeMethod<void>('openUnknownSourcesSettings').catchError((_) {});

  /// Ask Android to install an already-downloaded APK file.
  static Future<bool> installApk(String path) async {
    try {
      return await _ch.invokeMethod<bool>('installApk', {'path': path}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestNotificationPermission') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> scheduleDaily(List<Map<String, dynamic>> alarms) =>
      _ch.invokeMethod<void>('scheduleDaily', {'alarms': alarms}).catchError((_) {});

  static Future<void> cancelAll() => _ch.invokeMethod<void>('cancelAll').catchError((_) {});

  static Future<List<dynamic>> scheduled() async {
    try {
      return await _ch.invokeMethod<List<dynamic>>('scheduled') ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> keepScreenOnDuringWorkout(bool on) =>
      _ch.invokeMethod<void>('keepScreenOn', {'on': on}).catchError((_) {});

  /// Fire a one-off local notification (used by the rest timer).
  static Future<void> notify({
    required String title,
    required String body,
    int id = 9001,
  }) =>
      _ch
          .invokeMethod<void>('notify', {'id': id, 'title': title, 'body': body})
          .catchError((_) {});

  /// Short vibration, so the timer can be felt with the phone on the floor.
  static Future<void> vibrate(int ms) =>
      _ch.invokeMethod<void>('vibrate', {'ms': ms}).catchError((_) {});
}

/// Builds the reminder set from the (remotely updatable) content file and hands
/// it to the native AlarmManager scheduler.
class Reminders {
  /// Pure builder (no platform calls) so it can be unit-tested.
  ///
  /// Water reminders come from `water.slots`: a slot with `"remind": false` in
  /// the content file is skipped, so editing content.json on GitHub really does
  /// change what the phone reminds you about. `reminders.water` acts as an
  /// extra list for times that have no slot of their own - a time that already
  /// matches a reminding slot is ignored instead of being scheduled twice.
  static List<Map<String, dynamic>> buildAlarms(AppContent c, bool ar) {
    final cfg = c.reminders;
    final alarms = <Map<String, dynamic>>[];
    var id = 100;

    final slotTimes = <String>{};
    for (final s in c.water.slots) {
      if (!s.remind) continue;
      final t = s.time.trim();
      if (!_timeRe.hasMatch(t)) continue;
      slotTimes.add(_norm(t));
      alarms.add({
        'id': id++,
        'hour': _h(t),
        'minute': _m(t),
        'title': Water.title(t, ar),
        'body': Water.body(t, ar),
        'slot': s.id,
      });
    }

    for (final t in cfg.water) {
      if (slotTimes.contains(_norm(t))) continue;
      alarms.add({
        'id': id++,
        'hour': _h(t),
        'minute': _m(t),
        'title': Water.title(t, ar),
        'body': Water.body(t, ar),
      });
    }

    alarms.add({
      'id': id++,
      'hour': _h(cfg.workout),
      'minute': _m(cfg.workout),
      'title': ar ? 'وقت التمرين 🏋️' : 'Workout time 🏋️',
      'body': ar
          ? 'أفضل ساعة في اليوم: حرارة جسمك وقوتك في الذروة. جهّز الحقيبة.'
          : 'The best hour of your day: body temperature and strength peak now. Prep the bag.',
    });
    alarms.add({
      'id': id++,
      'hour': _h(cfg.sleep),
      'minute': _m(cfg.sleep),
      'title': ar ? 'أغلق الشاشات 📵' : 'Screens off 📵',
      'body': ar
          ? 'هرمون النمو يُفرز ٨٠٪ بين ١١ م و٢ ص. نام قبل ١١.'
          : '80% of growth hormone is released between 11 PM and 2 AM. Be asleep before 11.',
    });

    return alarms;
  }

  static Future<void> apply(AppState st) async {
    if (!Platform.isAndroid) return;
    final cfg = st.content.reminders;
    if (!(st.remindersOn && cfg.enabled)) {
      await Native.cancelAll();
      return;
    }
    // Best-effort permission ask, deliberately *not* awaited: if the system
    // dialog gets dismissed without an answer, a pending future here would
    // silently block the content sync and the update check that run right
    // after boot. Alarms are scheduled regardless - Android 13+ simply
    // suppresses the notifications while the permission is denied.
    unawaited(Native.requestNotificationPermission()
        .timeout(const Duration(seconds: 8), onTimeout: () => false)
        .catchError((_) => false));
    await Native.scheduleDaily(buildAlarms(st.content, st.isArabic));
  }

  static final RegExp _timeRe = RegExp(r'^\d{1,2}:\d{2}$');

  /// "06:30" -> "6:30" so 06:30 and 6:30 are recognised as the same time.
  static String _norm(String t) => '${_h(t)}:${_m(t)}';

  static int _h(String t) {
    final p = t.split(':');
    return (int.tryParse(p[0]) ?? 8) % 24;
  }

  static int _m(String t) {
    final p = t.split(':');
    final i = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return i % 60;
  }
}

/// Reminder copy for water (kept next to the content model so it can evolve).
class Water {
  static String title(String time, bool ar) =>
      ar ? '💧 وقت الماء ($time)' : '💧 Water time ($time)';

  static String body(String time, bool ar) =>
      ar ? 'اشرب زجاجة الآن — عضلاتك ٧٥٪ ماء.' : 'Drink a glass now - your muscles are 75% water.';
}
