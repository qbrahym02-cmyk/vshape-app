// Tests for the v1.1 features:
//   - content v5 (exam mode, growth sleep, check-in, price tool, backpack load,
//     safety gates, monthly photo, weekly report copy),
//   - the AppState logic behind them,
//   - a build smoke test for the new report screen.
//
// SharedPreferences does real async platform work that the fake-async zone
// inside testWidgets blocks, so every state call runs in tester.runAsync.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vshape_app/core/app_state.dart';
import 'package:vshape_app/core/models.dart';
import 'package:vshape_app/screens/report_screen.dart';
import 'package:vshape_app/widgets/scope.dart';

AppContent _bundled() => AppContent.fromMap(
    jsonDecode(File('assets/content/content.json').readAsStringSync()) as Map<String, dynamic>);

Future<AppState> _boot([Map<String, Object>? initial]) async {
  SharedPreferences.setMockInitialValues(initial ?? <String, Object>{});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('vshape/native'), (call) async => null);
  return AppState.boot();
}

/// Copies everything out of the live prefs so a second boot sees the same data.
Map<String, Object> _snapshot(AppState st) {
  final out = <String, Object>{};
  for (final k in st.prefs.getKeys()) {
    final v = st.prefs.get(k);
    if (v is bool) {
      out[k] = v;
    } else if (v is int) {
      out[k] = v;
    } else if (v is double) {
      out[k] = v;
    } else if (v is String) {
      out[k] = v;
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  group('content v5', () {
    test('the new sections parse', () {
      final c = _bundled();
      expect(c.version, greaterThanOrEqualTo(5));

      expect(c.examMode.isEmpty, isFalse);
      expect(c.examMode.keepDays, isNotEmpty);
      expect(c.examMode.rules.t(true), isNotEmpty);
      expect(c.examMode.rules.t(true).length, c.examMode.rules.t(false).length);

      expect(c.sleep.target, '23:00');
      expect(c.sleep.hoursMin, greaterThanOrEqualTo(7));

      expect(c.checkin.levels.length, 5);
      expect(c.checkin.soreThreshold, greaterThan(0));
      expect(c.checkin.deloadAfterDays, greaterThan(0));
      expect(c.checkin.levelFor(5)?.emoji, isNotEmpty);
      expect(c.checkin.levelFor(99), isNull);
      expect(c.checkin.ordered.first.value, 5);

      expect(c.food.priceTool.perGrams, 20);
      expect(c.food.priceableSources, isNotEmpty);
      for (final s in c.food.priceableSources) {
        expect(s.proteinPerUnitG, greaterThan(0), reason: s.id);
        expect(s.maxUnits, greaterThan(0), reason: '${s.id} needs a daily cap');
        expect(s.unit.t(true), isNotEmpty, reason: s.id);
        expect(s.unit.t(false), isNotEmpty, reason: s.id);
      }
      final ids = c.food.priceableSources.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'price keys must be unique');

      expect(c.backpackLoad.isEmpty, isFalse);
      expect(c.backpackLoad.bottleMl, 1500);
      expect(c.backpackLoad.sandKgPerL, greaterThan(c.backpackLoad.waterKgPerL));
      expect(c.backpackLoad.bodyPct, [10, 20]);
      expect(c.backpackLoad.steps.t(true).length, c.backpackLoad.steps.t(false).length);

      expect(c.progress.photoCheckpoint.dayOfMonth, 15);
      expect(c.progress.photoCheckpoint.checklist.t(true), isNotEmpty);
      expect(c.progress.monthlyChecks, isNotEmpty);

      expect(c.report.praise.t(true).length, 4);
      expect(c.report.praise.t(true).length, c.report.praise.t(false).length);
      expect(c.report.waterTarget, greaterThan(0));
    });

    test('safety gates point at exercises that really exist', () {
      final c = _bundled();
      expect(c.workout.safetyGates, isNotEmpty);
      final exerciseIds = {
        for (final d in c.workout.days)
          for (final e in d.exercises) e.id
      };
      for (final g in c.workout.safetyGates) {
        expect(g.id, isNotEmpty);
        expect(g.checklist.t(true).length, greaterThanOrEqualTo(5), reason: g.id);
        expect(g.checklist.t(true).length, g.checklist.t(false).length, reason: g.id);
        expect(g.confirm.t(true), isNotEmpty, reason: g.id);
        for (final id in g.exerciseIds) {
          expect(exerciseIds, contains(id), reason: 'gate ${g.id} -> unknown exercise $id');
        }
        expect(
          c.workout.days.any((d) => c.workout.gateForDay(d)?.id == g.id),
          isTrue,
          reason: 'gate ${g.id} is never reachable from a training day',
        );
      }
    });

    test('exam mode keeps real training days only', () {
      final c = _bundled();
      for (final id in c.examMode.keepDays) {
        final day = c.workout.days.where((d) => d.id == id).toList();
        expect(day, isNotEmpty, reason: 'exam mode keeps an unknown day: $id');
        expect(day.single.isRest, isFalse, reason: id);
        expect(day.single.exercises, isNotEmpty, reason: id);
      }
      expect(c.examMode.sessionsPerWeek, c.examMode.keepDays.length);
    });

    test('old (v4) content still parses and simply hides the new features', () {
      final c = AppContent.fromMap(<String, dynamic>{});
      expect(c.version, 1);
      expect(c.examMode.isEmpty, isTrue);
      expect(c.checkin.isEmpty, isTrue);
      expect(c.food.priceTool.isEmpty, isTrue);
      expect(c.food.priceableSources, isEmpty);
      expect(c.backpackLoad.isEmpty, isTrue);
      expect(c.workout.safetyGates, isEmpty);
      expect(c.progress.photoCheckpoint.isEmpty, isTrue);
      expect(c.progress.monthlyChecks, isEmpty);
      // the sleep log stays usable because its cutoff has a default
      expect(c.sleep.target, '23:00');
      expect(c.report.waterTarget, greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  group('exam mode', () {
    testWidgets('drops the days it does not keep, rest days stay', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      final days = st.content.workout.days;
      final fullWeek = days.where((d) => !d.isRest).length;
      expect(st.examModeOn, isFalse);
      expect(st.examModeAvailable, isTrue);
      expect(st.weeklySessionTarget, fullWeek);
      expect(days.every(st.dayIsActive), isTrue);

      await tester.runAsync(() => st.setExamMode(true));
      expect(st.examModeOn, isTrue);
      expect(st.weeklySessionTarget, st.content.examMode.sessionsPerWeek);
      expect(st.weeklySessionTarget, lessThan(fullWeek));
      for (final d in days) {
        final keep = d.isRest || st.content.examMode.keeps(d.id);
        expect(st.dayIsActive(d), keep, reason: d.id);
      }

      await tester.runAsync(() => st.setExamMode(false));
      expect(st.weeklySessionTarget, fullWeek);
    });

    testWidgets('a phone still on v4 content sees no exam mode at all', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot(<String, Object>{
        K.contentJson: jsonEncode(<String, dynamic>{
          'version': 4,
          'workout': {
            'days': [
              {'id': 'sat', 'day': 6, 'exercises': []}
            ]
          }
        }),
      }));
      expect(st.content.version, 4);
      expect(st.examModeAvailable, isFalse);
      expect(st.examModeOn, isFalse);
      // with no exercises anywhere, nothing is expected of the week
      expect(st.weeklyReport().rowById('training')!.target, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('growth sleep log', () {
    testWidgets('bedtimes are judged against the 23:00 cutoff', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      expect(st.sleepTimeToday, isNull);
      expect(st.sleepStreak(), 0);

      await tester.runAsync(() => st.setSleepTime('22:40'));
      expect(st.sleepOnTimeToday, isTrue);
      expect(st.sleepStreak(), 1);

      await tester.runAsync(() => st.setSleepTime('00:20'));
      expect(st.sleepOnTimeToday, isFalse, reason: 'after midnight is a late night');
      expect(st.sleepStreak(), 0, reason: 'a late night breaks the streak');

      await tester.runAsync(() => st.setSleepTime('nonsense'));
      expect(st.sleepTimeToday, '00:20', reason: 'invalid input must be ignored');

      await tester.runAsync(() => st.clearSleepTime());
      expect(st.sleepTimeToday, isNull);
    });

    testWidgets('a streak survives this morning being unfilled', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());
      await tester.runAsync(() async {
        for (var i = 1; i <= 3; i++) {
          final key = K.sleep(st.keyFor(DateTime.now().subtract(Duration(days: i))));
          await st.prefs.setString(key, '22:45');
        }
        st.ping();
      });
      expect(st.sleepStreak(), 3, reason: 'today is not logged yet, so it must not break it');

      await tester.runAsync(() => st.setSleepTime('23:30'));
      expect(st.sleepStreak(), 0, reason: 'but a late night logged today does');
    });
  });

  // -------------------------------------------------------------------------
  group('daily check-in', () {
    testWidgets('trims the day and suggests a deload after two low days', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      expect(st.checkinToday, isNull);
      expect(st.setsToDropToday, 0);
      expect(st.deloadSuggested, isFalse);

      await tester.runAsync(() => st.setCheckin(5));
      expect(st.setsToDropToday, 0);
      expect(st.checkinLevelToday?.value, 5);

      await tester.runAsync(() => st.setCheckin(2));
      expect(st.setsToDropToday, 1, reason: 'sore -> one set less per exercise');
      expect(st.deloadSuggested, isFalse, reason: 'one low day is not enough');

      await tester.runAsync(() async {
        final y = st.keyFor(DateTime.now().subtract(const Duration(days: 1)));
        await st.prefs.setInt(K.checkin(y), 2);
        st.ping();
      });
      expect(st.deloadSuggested, isTrue);

      await tester.runAsync(() => st.setCheckin(1));
      expect(st.setsToDropToday, 99, reason: 'ill -> full rest');

      await tester.runAsync(() => st.setCheckin(40));
      expect(st.checkinToday, 5, reason: 'ratings are clamped');
    });
  });

  // -------------------------------------------------------------------------
  group('protein price tool', () {
    testWidgets('ranks the cheapest protein and builds a basket', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      expect(st.rankedSources, isEmpty);
      expect(st.proteinBasket.isEmpty, isTrue);

      await tester.runAsync(() async {
        await st.setPrice('eggs', 6); // 6.5 g per egg  -> 0.92 per gram
        await st.setPrice('milk', 30); // 32 g per litre -> 0.94 per gram
        await st.setPrice('soy', 90); // 36 g per 100 g -> 2.50 per gram
        st.ping();
      });

      final ranked = st.rankedSources;
      expect(ranked.map((s) => s.id), ['eggs', 'milk', 'soy']);
      expect(ranked.first.costPer(20), lessThan(ranked.last.costPer(20)!));

      final basket = st.proteinBasket;
      expect(basket.lines.first.id, 'eggs');
      expect(basket.grams, greaterThan(0));
      expect(basket.cost, greaterThan(0));
      // eggs (6 x 6.5 = 39 g) + milk (2 L x 32 = 64 g) + soy (1 x 36 g) = 139 g,
      // under the 150 g target: the app must say so rather than pretend.
      expect(basket.reached, isFalse);

      await tester.runAsync(() => st.setPrice('eggs', null));
      expect(st.rankedSources.any((s) => s.id == 'eggs'), isFalse);
      expect(st.priceOf('eggs'), isNull);
    });

    testWidgets('prices survive a restart, whole numbers included', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());
      await tester.runAsync(() => st.setPrice('milk', 30));
      expect(st.priceOf('milk'), 30.0);

      final saved = _snapshot(st);
      await tester.runAsync(() async => st = await _boot(saved));
      expect(st.priceOf('milk'), 30.0, reason: 'a whole number must come back as a double');
      expect(st.rankedSources.map((s) => s.id), contains('milk'));
    });

    testWidgets('the currency symbol is user-editable', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());
      expect(st.currency, isNotEmpty);
      await tester.runAsync(() => st.setCurrency('  USD  '));
      expect(st.currency, 'USD');
      await tester.runAsync(() => st.setCurrency('   '));
      expect(st.currency, isNotEmpty, reason: 'falls back to the content default');
    });
  });

  // -------------------------------------------------------------------------
  group('backpack load', () {
    testWidgets('follows the sand fraction and this bodyweight', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      // The profile range is 80-85 kg, so its midpoint drives the safe window.
      expect(st.bodyKg, closeTo(82.5, 0.01));
      expect(st.backpackLoadKg(bottles: 3, sandFraction: 0), closeTo(5.5, 0.01));
      expect(st.backpackLoadKg(bottles: 3, sandFraction: 1), closeTo(8.2, 0.01));
      expect(st.safeLoadKg.min, lessThan(st.safeLoadKg.max));

      // A logged weight overrides the profile range.
      await tester.runAsync(() => st.appendLog(K.measure('weight'), 74));
      expect(st.bodyKg, closeTo(74, 0.01));
      expect(st.safeLoadKg.max, closeTo(14.8, 0.05));
    });
  });

  // -------------------------------------------------------------------------
  group('monthly checks and photo checkpoint', () {
    testWidgets('ticks are stored per month', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      expect(st.monthlyDone('photo'), isFalse);
      await tester.runAsync(() => st.toggleMonthly('photo'));
      expect(st.monthlyDone('photo'), isTrue);
      expect(st.photoDue, isFalse);

      final now = DateTime.now();
      final prev =
          now.month == 1 ? DateTime(now.year - 1, 12) : DateTime(now.year, now.month - 1);
      expect(st.monthlyDone('photo', K.ymOf(prev)), isFalse, reason: 'last month starts clean');

      await tester.runAsync(() => st.toggleMonthly('photo'));
      expect(st.monthlyDone('photo'), isFalse);
    });

    test('the checkpoint is due from the 15th onwards', () {
      final cp = _bundled().progress.photoCheckpoint;
      expect(cp.isEmpty, isFalse);
      expect(cp.isDueOn(DateTime(2026, 9, 14)), isFalse);
      expect(cp.isDueOn(DateTime(2026, 9, 15)), isTrue);
      expect(cp.isDueOn(DateTime(2026, 9, 30)), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('safety gates', () {
    testWidgets('the table gate is pending until acknowledged, once', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      final sunday = st.content.workout.dayForWeekday(7)!; // pull day: table rows
      final gate = st.content.workout.gateForDay(sunday);
      expect(gate, isNotNull);
      expect(st.pendingGateFor(sunday)?.id, gate!.id);
      expect(st.gateAcked(gate.id), isFalse);

      await tester.runAsync(() => st.ackGate(gate.id));
      expect(st.pendingGateFor(sunday), isNull);
      expect(st.gateAcked(gate.id), isTrue);

      final monday = st.content.workout.dayForWeekday(1)!; // legs: no gate
      expect(st.content.workout.gateForDay(monday), isNull);
      expect(st.pendingGateFor(monday), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('weekly report', () {
    testWidgets('scores what was actually logged and nothing more', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      var r = st.weeklyReport();
      expect(r.rows.length, 5);
      expect(r.hasAnyData, isFalse);
      expect(r.score, 0);

      await tester.runAsync(() async {
        for (final s in st.content.water.slots) {
          await st.setSlot(s.id, s.glasses);
        }
        for (final m in st.content.food.meals) {
          for (var i = 0; i < m.items.length; i++) {
            if (!st.mealItemDone(m.id, i)) await st.toggleMealItem(m.id, i);
          }
        }
        for (final task in st.content.routine) {
          await st.setTask(task.id, true);
        }
        await st.setSleepTime('22:30');
      });

      r = st.weeklyReport();
      expect(r.hasAnyData, isTrue);
      // One perfect day out of seven.
      expect(r.rowById('water')!.value, closeTo(1 / 7, 0.01));
      expect(r.rowById('protein')!.value, closeTo(1 / 7, 0.01));
      expect(r.rowById('routine')!.value, closeTo(1 / 7, 0.01));
      expect(r.rowById('sleep')!.value, closeTo(1 / 7, 0.01));
      expect(r.sleepLogged, 1);
      expect(r.sleepOnTime, 1);
      expect(r.score, greaterThan(0));
      expect(r.praise, inInclusiveRange(0, 3));
      expect(r.weakest, isNotNull);
    });

    testWidgets('a longer window spreads the same day thinner', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());
      await tester.runAsync(() => st.setSleepTime('22:30'));
      final short = st.weeklyReport(days: 7);
      final long = st.weeklyReport(days: 30);
      expect(long.days, 30);
      expect(long.rowById('sleep')!.value, lessThan(short.rowById('sleep')!.value));
    });

    testWidgets('records are counted only inside the window', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());

      await tester.runAsync(() async {
        await st.prefs.setString(
          K.strength('table_row'),
          jsonEncode([
            {'d': st.keyFor(DateTime.now().subtract(const Duration(days: 30))), 'v': 8},
            {'d': st.keyFor(DateTime.now().subtract(const Duration(days: 3))), 'v': 12},
            {'d': st.keyFor(DateTime.now()), 'v': 10},
          ]),
        );
        st.ping();
      });

      expect(st.recordsIn(7), 1, reason: 'only the 12-rep day is both a record and in range');
      expect(st.recordsIn(40), 2, reason: 'the first 8 was a record too');
      expect(st.weeklyReport().records, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('report screen', () {
    Future<void> pumpReport(WidgetTester tester, {bool arabic = true}) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());
      await tester.runAsync(() => st.setArabic(arabic));
      await tester.runAsync(() async {
        await st.setSleepTime('22:30');
        await st.setCheckin(4);
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: st.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Directionality(
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            child: AppScope(state: st, child: const ReportScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    testWidgets('builds in Arabic with data logged', (tester) => pumpReport(tester));
    testWidgets('builds in English with data logged', (tester) => pumpReport(tester, arabic: false));

    testWidgets('explains itself before anything is logged', (tester) async {
      late AppState st;
      await tester.runAsync(() async => st = await _boot());
      await tester.runAsync(() => st.setArabic(true));
      await tester.pumpWidget(
        MaterialApp(
          locale: st.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AppScope(state: st, child: const ReportScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('لا يوجد ما يكفي'), findsOneWidget);
    });
  });
}
