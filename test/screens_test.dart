// Smoke tests.
//
// Two layers:
//   1. every screen must build (Arabic + English) without throwing or
//      overflowing badly - checked by pumping the screen and asserting that no
//      exception escaped;
//   2. the counting logic behind the UI (water, protein, sets, streak, logs).
//
// SharedPreferences performs real async platform work which the fake-async
// zone inside testWidgets blocks, so every async call runs in tester.runAsync.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vshape_app/core/app_state.dart';
import 'package:vshape_app/core/models.dart';
import 'package:vshape_app/screens/food_screen.dart';
import 'package:vshape_app/screens/more_screen.dart';
import 'package:vshape_app/screens/progress_screen.dart';
import 'package:vshape_app/screens/rules_screen.dart';
import 'package:vshape_app/screens/settings_screen.dart';
import 'package:vshape_app/screens/today_screen.dart';
import 'package:vshape_app/screens/training_screen.dart';
import 'package:vshape_app/screens/water_screen.dart';
import 'package:vshape_app/services/widget_bridge.dart';
import 'package:vshape_app/widgets/exercise_art.dart';
import 'package:vshape_app/widgets/painters.dart';
import 'package:vshape_app/widgets/scope.dart';

Future<AppState> _boot({bool arabic = true}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  // Answer every platform-channel call with null instead of hanging forever:
  // the native helpers all treat a null reply as "feature unavailable".
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('vshape/native'), (call) async => null);
  final st = await AppState.boot();
  await st.setArabic(arabic);
  return st;
}

Future<AppState> _pumpScreen(WidgetTester tester, Widget screen, {bool arabic = true}) async {
  late AppState st;
  await tester.runAsync(() async => st = await _boot(arabic: arabic));
  await tester.pumpWidget(
    MaterialApp(
      locale: st.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: st.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AppScope(state: st, child: screen),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  return st;
}

void main() {
  // ---------------------------------------------------------------- screens --
  group('screens build', () {
    final cases = <String, Widget Function()>{
      'Today': () => const TodayScreen(),
      'Water': () => const WaterScreen(),
      'Food': () => const FoodScreen(),
      'Training': () => const TrainingScreen(),
      'More': () => const MoreScreen(),
      'Progress': () => const ProgressScreen(),
      'Rules': () => const RulesScreen(),
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} (Arabic)', (tester) async {
        await _pumpScreen(tester, entry.value());
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} (English)', (tester) async {
        await _pumpScreen(tester, entry.value(), arabic: false);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Settings builds', (tester) async {
      // SettingsScreen talks to the platform channel lazily, so it is pumped
      // the same way; missing plugin replies are swallowed by design.
      await _pumpScreen(tester, const SettingsScreen());
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------------ state --
  group('AppState logic', () {
    late AppState st;

    setUp(() async {
      st = await _boot();
    });

    test('content is loaded from the bundled asset', () {
      expect(st.content.version, greaterThan(0));
      expect(st.content.workout.days.length, 7);
      expect(st.content.food.meals.length, 5);
      expect(st.content.routine, isNotEmpty);
      expect(st.isArabic, isTrue);
    });

    test('water: quick add and slot counters never disagree', () async {
      expect(st.waterTotal(), 0);

      await st.addWater(500);
      expect(st.waterTotal(), 500);

      await st.bumpSlot('wake', 2, up: true);
      await st.bumpSlot('wake', 2, up: true);
      // two 500 ml glasses == the 500 ml already counted, so the total is 1000
      expect(st.slotDone('wake'), 2);
      expect(st.waterTotal(), 1000);

      await st.toggleSlot('wake', 2); // full -> cleared
      expect(st.slotDone('wake'), 0);

      await st.addWater(-10000);
      expect(st.waterToday(), 0);
    });

    test('water goal is inside the 3.5-4 L protocol', () {
      final w = st.content.water;
      expect(w.goalMl, inInclusiveRange(3500, 4000));
      expect(w.slots.fold<int>(0, (s, e) => s + e.glasses), greaterThanOrEqualTo(7));
    });

    test('food: protein is proportional to the ticked items', () async {
      expect(st.proteinEaten(), 0);
      final breakfast = st.content.food.meals.firstWhere((m) => m.id == 'breakfast');

      await st.toggleMealItem('breakfast', 0);
      final one = st.proteinEaten();
      expect(one, greaterThan(0));
      expect(one, lessThan(breakfast.proteinG));

      for (var i = 1; i < breakfast.items.length; i++) {
        await st.toggleMealItem('breakfast', i);
      }
      expect(st.mealDone('breakfast'), isTrue);
      expect(st.proteinEaten(), greaterThanOrEqualTo(breakfast.proteinG));
      expect(st.kcalEaten(), greaterThan(0));
    });

    test('planned protein covers the 150 g target', () {
      expect(st.content.food.proteinTarget, 150);
      expect(st.content.food.plannedProtein, greaterThanOrEqualTo(150));
    });

    test('workout: sets are tracked per day', () async {
      final monday = st.content.workout.dayForWeekday(1)!;
      expect(monday.exercises, isNotEmpty);
      expect(st.setsDone(monday.id), 0);

      await st.toggleSet(monday.exercises.first.id, 0);
      expect(st.setsDone(monday.id), 1);
      await st.toggleSet(monday.exercises.first.id, 0);
      expect(st.setsDone(monday.id), 0);

      await st.toggleDayDone(monday.id);
      expect(st.dayDoneToday(monday.id), isTrue);
    });

    test('every weekday maps to exactly one session', () {
      for (var d = 1; d <= 7; d++) {
        expect(st.content.workout.dayForWeekday(d), isNotNull, reason: 'weekday $d');
      }
      // training days have exercises, rest days have a plan
      final training = st.content.workout.days.where((d) => !d.isRest).toList();
      expect(training.length, 5);
      for (final d in training) {
        expect(d.exercises, isNotEmpty);
        expect(d.totalSets, greaterThan(0));
        for (final e in d.exercises) {
          expect(e.steps.ar, isNotEmpty, reason: e.id);
          expect(e.steps.en, isNotEmpty, reason: e.id);
          expect(e.sets, greaterThan(0));
        }
      }
    });

    test('routine: all items have unique ids and a time', () {
      final ids = st.content.routine.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final r in st.content.routine) {
        expect(RegExp(r'^\d{1,2}:\d{2}$').hasMatch(r.time), isTrue, reason: r.id);
      }
    });

    test('logs keep one entry per day and expose the latest value', () async {
      await st.appendLog('str_table_row', 8);
      expect(st.logFor('str_table_row').length, 1);
      await st.appendLog('str_table_row', 14); // same day -> replaces
      expect(st.logFor('str_table_row').length, 1);
      expect(st.lastLogValue('str_table_row'), 14);

      await st.removeLogEntry('str_table_row', K.date());
      expect(st.logFor('str_table_row'), isEmpty);
      expect(st.lastLogValue('str_table_row'), isNull);
    });

    test('streak: water from the schedule stations counts (regression)', () async {
      // Filling the stations only (no quick-add) used to leave the raw
      // w_<date> counter at 0, so a fully-drunk day broke the streak.
      final glass = st.content.water.glassMl;
      final y = st.keyFor(DateTime.now().subtract(const Duration(days: 1)));
      for (final slot in st.content.water.slots) {
        await st.prefs.setInt(K.slot(y, slot.id), slot.glasses);
      }
      expect(st.prefs.getInt(K.water(y)) ?? 0, 0, reason: 'precondition: quick-add untouched');
      expect(st.waterTotalOn(y), greaterThanOrEqualTo(st.content.water.goalMl));
      expect(st.dayCounts(y), isTrue);
      expect(st.streak(), 1, reason: 'yesterday counted, today is still empty');
      expect(glass, greaterThan(0));
    });

    test('streak: an empty day breaks the run', () async {
      final y = st.keyFor(DateTime.now().subtract(const Duration(days: 1)));
      final d2 = st.keyFor(DateTime.now().subtract(const Duration(days: 2)));
      await st.prefs.setInt(K.water(d2), st.content.water.goalMl);
      await st.addWater(st.content.water.goalMl); // today
      expect(st.dayCounts(y), isFalse);
      expect(st.streak(), 1, reason: 'today counts, yesterday was empty -> run stops');
    });

    test('streak: one routine task is enough for the day', () async {
      final y = st.keyFor(DateTime.now().subtract(const Duration(days: 1)));
      final taskId = st.content.routine.first.id;
      await st.prefs.setBool(K.task(y, taskId), true);
      expect(st.dayCounts(y), isTrue);
      expect(st.streak(), 1);
    });

    test('streak: counts a long unbroken run', () async {
      for (var i = 1; i <= 5; i++) {
        final d = st.keyFor(DateTime.now().subtract(Duration(days: i)));
        await st.prefs.setInt(K.water(d), st.content.water.goalMl);
      }
      expect(st.streak(), 5);
      await st.addWater(st.content.water.goalMl);
      expect(st.streak(), 6);
    });

    test('bilingual text resolves both ways', () {
      final note = st.content.water.note;
      expect(note.t(true), isNot(note.t(false)));
      expect(note.t(true), contains('ماء'));
      expect(note.t(false), contains('water'));
    });
  });

  // ---------------------------------------------------- v1.0.3: food extras --
  group('exact macros + quick extras', () {
    late AppState st;

    setUp(() async {
      st = await _boot();
    });

    test('extras add protein and kcal on top of the planned meals', () async {
      expect(st.proteinEaten(), 0);
      expect(st.kcalEaten(), 0);

      await st.bumpExtra('egg', up: true);
      await st.bumpExtra('egg', up: true);
      expect(st.extraCount('egg'), 2);
      expect(st.proteinEaten(), 12);
      expect(st.kcalEaten(), 156);

      await st.bumpExtra('egg', up: false);
      expect(st.extraCount('egg'), 1);
      expect(st.proteinEaten(), 6);

      await st.bumpExtra('egg', up: false);
      await st.bumpExtra('egg', up: false); // never goes below zero
      expect(st.extraCount('egg'), 0);
      expect(st.proteinEaten(), 0);
    });

    test('meal items are counted with their exact macros', () async {
      final breakfast = st.content.food.meals.firstWhere((m) => m.id == 'breakfast');
      expect(breakfast.items.first.proteinG, isNotNull);

      await st.toggleMealItem('breakfast', 0);
      expect(st.proteinEaten(), breakfast.items.first.proteinG);
      expect(st.kcalEaten(), breakfast.items.first.kcal);

      for (var i = 1; i < breakfast.items.length; i++) {
        await st.toggleMealItem('breakfast', i);
      }
      expect(st.proteinEaten(), breakfast.proteinG);
      expect(st.kcalEaten(), breakfast.kcal);
    });

    test('weekMacros returns 7 days ending today', () async {
      final w = st.weekMacros();
      expect(w.length, 7);
      expect(w.last.date, K.date());
      await st.bumpExtra('tuna', up: true);
      final w2 = st.weekMacros();
      expect(w2.last.protein, 22);
      expect(w2.first.protein, 0);
    });

    test('WidgetData payload is complete and localised', () {
      final d = WidgetData.from(st).toJson();
      for (final k in [
        'water', 'waterGoal', 'waterPct', 'protein', 'proteinGoal',
        'kcal', 'kcalGoal', 'streak', 'setsDone', 'setsTotal',
        'workout', 'emoji', 'lang', 'labelWater', 'labelProtein', 'labelSets',
      ]) {
        expect(d.containsKey(k), isTrue, reason: 'widget payload is missing "$k"');
      }
      expect(d['lang'], 'ar');
      expect(d['proteinGoal'], st.content.food.proteinTarget);
      expect(d['waterGoal'], isNotEmpty);
    });
  });

  // --------------------------------------------------- v1.0.3: exercise art --
  group('exercise illustrations', () {
    test('every exercise in the plan has a drawing', () {
      final map = jsonDecode(File('assets/content/content.json').readAsStringSync())
          as Map<String, dynamic>;
      final c = AppContent.fromMap(map);
      for (final day in c.workout.days) {
        for (final e in day.exercises) {
          expect(hasExerciseArt(e.id), isTrue, reason: 'no art for ${e.id}');
        }
      }
      expect(exerciseArtIds.length, greaterThanOrEqualTo(18));
    });

    testWidgets('ExerciseArt paints without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Wrap(children: [
            ExerciseArt(exerciseId: 'goblet_squat'),
            ExerciseArt(exerciseId: 'table_row', size: 120),
            ExerciseArt(exerciseId: 'unknown_id_falls_back'),
          ]),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('WeekBars paints with and without data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            WeekBars(values: const [0, 40, 90, 150, 60, 0, 120], color: Colors.orange, goal: 150),
            WeekBars(values: const [0, 0, 0, 0, 0, 0, 0], color: Colors.amber),
          ]),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
