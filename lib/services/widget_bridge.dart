import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';

/// Payload for the Android home-screen widget.
///
/// Everything the widget shows is pre-formatted here (in the user's language),
/// because a `RemoteViews` layout cannot run Dart and should not know anything
/// about `content.json`.
class WidgetData {
  final int waterMl;
  final int waterGoalMl;
  final int waterGlasses;
  final int proteinG;
  final int proteinGoalG;
  final int kcal;
  final int kcalGoal;
  final int streak;
  final int setsDone;
  final int setsTotal;
  final bool restDay;
  final String workoutTitle;
  final String workoutEmoji;
  final bool arabic;

  const WidgetData({
    required this.waterMl,
    required this.waterGoalMl,
    required this.waterGlasses,
    required this.proteinG,
    required this.proteinGoalG,
    required this.kcal,
    required this.kcalGoal,
    required this.streak,
    required this.setsDone,
    required this.setsTotal,
    required this.restDay,
    required this.workoutTitle,
    required this.workoutEmoji,
    required this.arabic,
  });

  /// Reads the current state - safe to call from tests (pure Dart).
  factory WidgetData.from(AppState st) {
    final ar = st.isArabic;
    final now = DateTime.now();
    final day = st.content.workout.dayForWeekday(now.weekday);
    final water = st.waterTotal();
    final glass = st.content.water.glassMl == 0 ? 500 : st.content.water.glassMl;
    return WidgetData(
      waterMl: water,
      waterGoalMl: st.content.water.goalMl,
      waterGlasses: (water / glass).floor(),
      proteinG: st.proteinEaten(),
      proteinGoalG: st.content.food.proteinTarget,
      kcal: st.kcalEaten(),
      kcalGoal: st.content.food.kcalTarget[1],
      streak: st.streak(),
      setsDone: day == null ? 0 : st.setsDone(day.id),
      setsTotal: day?.totalSets ?? 0,
      restDay: day?.isRest ?? false,
      workoutTitle: day == null
          ? (ar ? 'لا يوجد تمرين' : 'No session')
          : (day.isRest
              ? (ar ? 'يوم راحة 🦴' : 'Rest day 🦴')
              : '${day.title.t(ar)} · ${day.focus.t(ar)}'),
      workoutEmoji: day?.emoji ?? '💪',
      arabic: ar,
    );
  }

  Map<String, dynamic> toJson() {
    final ar = arabic;
    String l(String a, String e) => ar ? a : e;
    return <String, dynamic>{
      'water': (waterMl / 1000).toStringAsFixed(1),
      'waterGoal': (waterGoalMl / 1000).toStringAsFixed(1),
      'waterUnit': l('لتر', 'L'),
      'waterGlasses': waterGlasses,
      'waterPct': waterGoalMl == 0 ? 0 : (waterMl * 100 / waterGoalMl).round().clamp(0, 100),
      'protein': proteinG,
      'proteinGoal': proteinGoalG,
      'kcal': kcal,
      'kcalGoal': kcalGoal,
      'streak': streak,
      'setsDone': setsDone,
      'setsTotal': setsTotal,
      'workout': workoutTitle,
      'emoji': workoutEmoji,
      'lang': ar ? 'ar' : 'en',
      'labelWater': l('الماء', 'Water'),
      'labelProtein': l('بروتين', 'Protein'),
      'labelKcal': l('سعرات', 'kcal'),
      'labelStreak': l('متتالية', 'streak'),
      'labelToday': l('تمرين اليوم', "Today's session"),
      'labelSets': l('مجموعات', 'sets'),
      'restDay': restDay,
    };
  }
}

/// Thin wrapper around the `vshape/native` channel methods that drive the
/// home-screen widget.  Every call is fire-and-forget and swallows errors, so
/// the widget can never break the app (or the widget tests, where the channel
/// has no handler at all).
class WidgetBridge {
  WidgetBridge._();

  static const MethodChannel _ch = MethodChannel('vshape/native');

  static bool _installed = false;
  static bool _probed = false;

  /// True once we know the user actually placed the widget on a home screen.
  static bool get installed => _installed;

  static Future<bool> probe() async {
    if (!Platform.isAndroid || kIsWeb) return false;
    try {
      _installed = await _ch.invokeMethod<bool>('widgetInstalled') ?? false;
    } catch (_) {
      _installed = false;
    }
    _probed = true;
    return _installed;
  }

  /// Pushes the current numbers to every widget instance.
  static Future<void> push(WidgetData data) async {
    if (!Platform.isAndroid || kIsWeb) return;
    if (_probed && !_installed) return; // nothing on the home screen: skip the IPC
    try {
      await _ch.invokeMethod<void>('updateWidget', {'json': jsonEncode(data.toJson())});
      _installed = true;
    } catch (_) {
      // older builds / no widget: ignore
    }
  }

  static Future<void> syncFrom(AppState st) async {
    try {
      await push(WidgetData.from(st));
    } catch (_) {}
  }
}
