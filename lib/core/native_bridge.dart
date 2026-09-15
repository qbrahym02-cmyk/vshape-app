import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_state.dart';
import 'models.dart';

/// All platform-channel traffic with the Kotlin side live here.
class Native {
  static const MethodChannel _ch = MethodChannel('vshape/native');
  static const EventChannel _dl = EventChannel('vshape/download_progress');

  static Stream<Map<String, dynamic>> get downloadEvents => _dl
      .receiveBroadcastStream()
      .map((e) => (e as Map).cast<String, dynamic>());

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
}

/// Builds the reminder set from the (remotely updatable) content file and
/// hands it to the native AlarmManager scheduler.
class Reminders {
  static Future<void> apply(AppState st) async {
    if (!Platform.isAndroid) return;
    final cfg = st.content.reminders;
    final on = st.remindersOn && cfg.enabled;
    if (!on) {
      await Native.cancelAll();
      return;
    }
    await Native.requestNotificationPermission();

    final ar = st.isArabic;
    final alarms = <Map<String, dynamic>>[];
    var id = 100;

    for (final t in cfg.water) {
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

    await Native.scheduleDaily(alarms);
  }

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

/// Tiny helper used by the settings screen to preview the JSON payload.
String prettyJson(Map<String, dynamic> m) {
  const e = JsonEncoder.withIndent('  ');
  final s = e.convert(m);
  return s.length > 4000 ? '${s.substring(0, 4000)}\n…' : s;
}

/// Convenience accessors so screens don't repeat `st.content.water...`.
extension ContentX on AppContent {
  WaterConfig get w => water;
  FoodConfig get f => food;
  WorkoutConfig get wk => workout;
}
