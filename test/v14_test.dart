// v1.4 tests: daily score, achievements, motivation quotes, and the new
// screens building in both languages.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vshape_app/core/achievements.dart';
import 'package:vshape_app/core/app_state.dart';
import 'package:vshape_app/core/plan_math.dart';
import 'package:vshape_app/screens/achievements_screen.dart';
import 'package:vshape_app/screens/more_screen.dart';
import 'package:vshape_app/screens/today_screen.dart';
import 'package:vshape_app/widgets/painters.dart';
import 'package:vshape_app/widgets/scope.dart';

Future<AppState> _boot({bool arabic = true}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('vshape/native'), (call) async => null);
  final st = await AppState.boot();
  await st.setArabic(arabic);
  return st;
}

Future<AppState> _pumpScreen(WidgetTester tester, Widget screen, {bool arabic = true}) async {
  late AppState st;
  // Real platform work (SharedPreferences, the asset bundle) must run inside
  // runAsync - the fake-async zone of testWidgets otherwise blocks forever.
  await tester.runAsync(() async {
    st = await _boot(arabic: arabic);
    await st.addWater(st.content.water.goalMl ~/ 2);
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
        textDirection: st.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AppScope(state: st, child: screen),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  return st;
}

/// The quote card sits below the fold inside the scroll view; scrolls
/// until the quote of the day is built and asserts it is there.
Future<void> _assertQuoteReachable(WidgetTester tester, AppState st) async {
  final wanted = st.t(st.content.motivation.quoteFor(DateTime.now()));
  var found = find.text(wanted).evaluate().isNotEmpty;
  for (var i = 0; i < 12 && !found; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    found = find.text(wanted).evaluate().isNotEmpty;
  }
  expect(found, isTrue, reason: 'quote of the day must be reachable: "$wanted"');
}

void main() {
  // ------------------------------------------------------------ dayScore --
  group('dayScore', () {
    test('an empty day scores 0, a perfect day 100', () {
      expect(
        dayScore(water: 0, protein: 0, tasks: 0, workout: 0),
        0,
      );
      expect(
        dayScore(water: 1, protein: 1, tasks: 1, workout: 1),
        100,
      );
    });

    test('water and protein weigh 30 each, tasks and workout 20', () {
      // Only water done: 30 points.
      expect(dayScore(water: 1, protein: 0, tasks: 0, workout: 0), 30);
      // Water + protein: 60.
      expect(dayScore(water: 1, protein: 1, tasks: 0, workout: 0), 60);
      // Everything but training: 80.
      expect(dayScore(water: 1, protein: 1, tasks: 1, workout: 0), 80);
    });

    test('values above 100% are clamped, not punished', () {
      expect(dayScore(water: 1.4, protein: 2.0, tasks: 1, workout: 1), 100);
      // Half-way values round, they do not truncate.
      expect(dayScore(water: 0.5, protein: 0.5, tasks: 0.5, workout: 0.5), 50);
    });
  });

  // ------------------------------------------------------- achievements --
  group('achievements', () {
    test('a fresh install unlocks nothing but the progress renders', () {
      const c = AchievementCounts(
        loggedDays: 0,
        streak: 0,
        waterGoalDays: 0,
        proteinGoalDays: 0,
        workoutsDone: 0,
        sleepOnTime: 0,
        records: 0,
        photosDone: 0,
      );
      final badges = evaluateAchievements(c);
      expect(badges, isNotEmpty);
      expect(badges.where((b) => b.unlocked), isEmpty);
      // Every locked badge still knows how far along it is.
      for (final b in badges) {
        expect(b.progress, inInclusiveRange(0, 1));
        expect(b.goal, greaterThan(0));
      }
    });

    test('streak badges unlock at 3, 7, 14 and 30', () {
      AchievementCounts at(int streak) => AchievementCounts(
            loggedDays: streak,
            streak: streak,
            waterGoalDays: 0,
            proteinGoalDays: 0,
            workoutsDone: 0,
            sleepOnTime: 0,
            records: 0,
            photosDone: 0,
          );
      bool has(List<Achievement> l, String id) => l.any((b) => b.id == id && b.unlocked);

      final d2 = evaluateAchievements(at(2));
      expect(has(d2, 'streak_3'), isFalse);
      expect(has(d2, 'first_day'), isTrue);

      final d3 = evaluateAchievements(at(3));
      expect(has(d3, 'streak_3'), isTrue);
      expect(has(d3, 'streak_7'), isFalse);

      final d7 = evaluateAchievements(at(7));
      expect(has(d7, 'streak_7'), isTrue);
      expect(has(d7, 'streak_14'), isFalse);

      final d30 = evaluateAchievements(at(30));
      expect(has(d30, 'streak_14'), isTrue);
      expect(has(d30, 'streak_30'), isTrue);
    });

    test('every badge id is unique and texts exist in both languages', () {
      final badges = evaluateAchievements(const AchievementCounts(
        loggedDays: 1,
        streak: 1,
        waterGoalDays: 1,
        proteinGoalDays: 1,
        workoutsDone: 1,
        sleepOnTime: 1,
        records: 1,
        photosDone: 1,
      ));
      final ids = badges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'badge ids must be unique');
      for (final b in badges) {
        expect(b.arTitle, isNotEmpty, reason: b.id);
        expect(b.enTitle, isNotEmpty, reason: b.id);
        expect(b.arDesc, isNotEmpty, reason: b.id);
        expect(b.enDesc, isNotEmpty, reason: b.id);
      }
    });

    testWidgets('the achievements screen builds in both languages', (tester) async {
      for (final ar in [true, false]) {
        await _pumpScreen(tester, const AchievementsScreen(), arabic: ar);
        expect(tester.takeException(), isNull);
      }
    });
  });

  // ------------------------------------------------------ AppState glue --
  group('AppState v1.4', () {
    late AppState st;

    setUp(() async {
      st = await _boot();
    });

    test('dayScoreToday starts at its baseline and rises with real logs', () async {
      // A rest day counts the training share (20 points) as met on purpose, so
      // the expected starting point depends on which weekday the suite runs on -
      // it used to assume a training day and failed every Friday.
      final today = st.content.workout.dayForWeekday(DateTime.now().weekday);
      final restToday = today == null || today.isRest || today.totalSets == 0;
      final baseline = restToday ? 20 : 0;
      expect(st.dayScoreToday, baseline);

      // Water to 100% of goal: +30.
      await st.addWater(st.content.water.goalMl);
      expect(st.dayScoreToday, baseline + 30);

      // All routine tasks: +20.
      for (final r in st.content.routine) {
        await st.setTask(r.id, true);
      }
      expect(st.dayScoreToday, baseline + 50);
    });

    test('achievementCounts sees logged water and unlocks hydration badges', () async {
      // Hit the water goal (report target ~90%) every day for 10 days.
      final bar = (st.content.water.goalMl * st.content.report.waterTarget).round();
      for (var i = 0; i < 10; i++) {
        final key = st.keyFor(DateTime.now().subtract(Duration(days: i)));
        await st.prefs.setInt(K.water(key), bar);
      }
      final c = st.achievementCounts();
      expect(c.waterGoalDays, greaterThanOrEqualTo(10));
      final badges = evaluateAchievements(c);
      expect(badges.any((b) => b.id == 'water_10' && b.unlocked), isTrue);
    });

    test('motivation: content v6 ships quotes and the daily rotation moves', () {
      final cfg = st.content.motivation;
      expect(cfg.isEmpty, isFalse, reason: 'bundled content v6 must carry quotes');
      expect(cfg.quotes.length, greaterThanOrEqualTo(10));

      final today = DateTime.now();
      final a = cfg.quoteFor(today);
      final b = cfg.quoteFor(today.add(const Duration(days: 1)));
      // Different days rotate; a 14-quote cycle cannot repeat next day.
      expect(a.t(true), isNot(b.t(true)));

      // The offset cycles within the list, never out of range.
      for (var o = 0; o < cfg.quotes.length * 2; o++) {
        expect(cfg.quoteFor(today, offset: o).isEmpty, isFalse);
      }
    });

    test('content v6: profile age is 16 (the user grew a year)', () {
      expect(st.content.meta.age, 16);
      expect(st.content.version, greaterThanOrEqualTo(6));
    });

    testWidgets('Today screen shows the score hero and quote card (Arabic)', (tester) async {
      final st = await _pumpScreen(tester, const TodayScreen(), arabic: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(RingProgress), findsWidgets);
      expect(find.text('نقاط اليوم'), findsOneWidget);
      await _assertQuoteReachable(tester, st);
    });

    testWidgets('Today screen shows the score hero and quote card (English)', (tester) async {
      final st = await _pumpScreen(tester, const TodayScreen(), arabic: false);
      expect(tester.takeException(), isNull);
      expect(find.byType(RingProgress), findsWidgets);
      expect(find.text("Today's score"), findsOneWidget);
      await _assertQuoteReachable(tester, st);
    });

    testWidgets('More screen lists the achievements tile with a live count', (tester) async {
      await _pumpScreen(tester, const MoreScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('الإنجازات'), findsOneWidget);
    });
  });

  // ------------------------------------------------------- content v6 ----
  group('content v6', () {
    test('the published file and the bundled asset stay identical', () {
      final a = File('content.json').readAsStringSync();
      final b = File('assets/content/content.json').readAsStringSync();
      expect(a, b);
    });

    test('every motivation quote is bilingual and non-empty', () {
      final map = jsonDecode(File('content.json').readAsStringSync())
          as Map<String, dynamic>;
      final quotes = (map['motivation'] as Map)['quotes'] as List;
      expect(quotes, isNotEmpty);
      for (final q in quotes) {
        final m = q as Map;
        expect('$m'.contains('ar'), isTrue);
        expect((m['ar'] ?? '').toString(), isNotEmpty);
        expect((m['en'] ?? '').toString(), isNotEmpty);
      }
    });

    test('no stale age-15 copy remains in the narrative sections', () {
      final map = jsonDecode(File('content.json').readAsStringSync())
          as Map<String, dynamic>;
      final narrative = jsonEncode({
        'app': map['app'],
        'philosophy': map['philosophy'],
        'rules': map['rules'],
        'avoid': map['food']['avoid'],
      }, toEncodable: (o) => o);
      expect(narrative.contains('سن ١٥'), isFalse);
      expect(narrative.contains('At 15'), isFalse);
      expect(narrative.contains('at 15'), isFalse);
    });
  });
}
