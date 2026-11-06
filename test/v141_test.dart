// v1.4.1: 90-day adherence levels, best streak, remote exercise photos and the
// numeric fields the widget buttons need.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vshape_app/core/app_state.dart';
import 'package:vshape_app/core/models.dart';
import 'package:vshape_app/screens/diagnostics_screen.dart';
import 'package:vshape_app/services/widget_bridge.dart';
import 'package:vshape_app/widgets/adherence_calendar.dart';
import 'package:vshape_app/widgets/exercise_media.dart';
import 'package:vshape_app/widgets/scope.dart';

Future<AppState> _boot() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('vshape/native'), (call) async => null);
  final st = await AppState.boot();
  await st.setArabic(true);
  return st;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState st;
  setUp(() async => st = await _boot());
  String day(int ago) => st.keyFor(DateTime.now().subtract(Duration(days: ago)));

  group('adherence levels', () {
    test('nothing logged is level 0', () {
      expect(st.dayLevel(day(1)), 0);
    });

    test('some water is level 1, above the 60% rule is level 2', () async {
      await st.prefs.setInt(K.water(day(1)), 400);
      expect(st.dayLevel(day(1)), 1);

      await st.prefs.setInt(K.water(day(2)), (st.content.water.goalMl * 0.65).round());
      expect(st.dayLevel(day(2)), 2);
    });

    test('the full water goal is level 3, water + a session is level 4', () async {
      await st.prefs.setInt(K.water(day(1)), st.content.water.goalMl);
      expect(st.dayLevel(day(1)), 3);

      final monday = st.content.workout.dayForWeekday(1)!;
      for (final ex in monday.exercises) {
        for (var i = 0; i < ex.sets; i++) {
          await st.prefs.setBool(K.setDone(day(1), ex.id, i), true);
        }
      }
      expect(st.sessionsOn(day(1)), greaterThanOrEqualTo(1));
      expect(st.dayLevel(day(1)), 4);
    });

    test('a routine task alone makes the day count', () async {
      await st.prefs.setBool(K.task(day(3), st.content.routine.first.id), true);
      expect(st.dayCounts(day(3)), isTrue);
      expect(st.dayLevel(day(3)), 2);
    });

    test('adherence list is oldest-first, ends today and stays in range', () {
      final a = st.adherence(days: 91);
      expect(a.length, 91);
      expect(a.last.date, K.date());
      for (final e in a) {
        expect(e.level, inInclusiveRange(0, 4));
      }
    });

    test('best streak survives a missed day and is persisted', () async {
      for (var i = 1; i <= 4; i++) {
        await st.prefs.setInt(K.water(day(i)), st.content.water.goalMl);
      }
      expect(st.bestStreak(), greaterThanOrEqualTo(4));
      await st.noteBestStreak();
      expect(st.prefs.getInt(K.bestStreak), isNotNull);
      expect(st.prefs.getInt(K.bestStreak)!, greaterThanOrEqualTo(4));
    });
  });

  group('exercise photos', () {
    test('content v7 gives every exercise an https image', () {
      final map = jsonDecode(File('assets/content/content.json').readAsStringSync())
          as Map<String, dynamic>;
      final c = AppContent.fromMap(map);
      var n = 0;
      for (final d in c.workout.days) {
        for (final e in d.exercises) {
          expect(e.image, startsWith('https://'), reason: e.id);
          expect(e.image, endsWith('.jpg'), reason: e.id);
          n++;
        }
      }
      expect(n, 20);
    });

    test('the bundled content always matches the published one', () {
      expect(File('content.json').readAsStringSync(),
          File('assets/content/content.json').readAsStringSync());
    });

    test('photo preference defaults on and can be turned off', () async {
      expect(st.photosOn, isTrue);
      await st.setPhotos(false);
      expect(st.photosOn, isFalse);
      expect(st.exerciseImageUrls.length, 20);
    });

    testWidgets('ExerciseMedia falls back to the vector drawing offline', (tester) async {
      late AppState s;
      await tester.runAsync(() async => s = await _boot());
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppScope(
            state: s,
            child: const Scaffold(
              body: Row(children: [
                ExerciseMedia(exerciseId: 'goblet_squat', size: 60),
                ExerciseMedia(
                    exerciseId: 'plank',
                    imageUrl: 'https://example.invalid/none.jpg',
                    size: 60),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('widget payload', () {
    test('carries the numbers the Kotlin water buttons need', () {
      final d = WidgetData.from(st).toJson();
      expect(d['waterMl'], isA<int>());
      expect(d['waterGoalMl'], st.content.water.goalMl);
      expect(d['glassMl'], st.content.water.glassMl);
      expect(d['waterPct'], inInclusiveRange(0, 100));
    });
  });

  group('adherence calendar widget', () {
    testWidgets('renders 91 squares without overflowing', (tester) async {
      late AppState s;
      await tester.runAsync(() async => s = await _boot());
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: AppScope(
            state: s,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(children: [
                  AdherenceCalendar(days: s.adherence(days: 91)),
                  const AdherenceLegend(),
                ]),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('diagnostics screen', () {
    testWidgets('builds without network or platform plugins', (tester) async {
      late AppState s;
      await tester.runAsync(() async => s = await _boot());
      await tester.pumpWidget(MaterialApp(
        locale: s.locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppScope(state: s, child: const DiagnosticsScreen()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
