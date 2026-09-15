// The 90-second rest countdown: controller logic + the widgets that use it.
//
// The controller reads the wall clock, so the timing assertions run in
// runAsync/real time instead of the fake-async widget zone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vshape_app/core/app_state.dart';
import 'package:vshape_app/widgets/rest_timer.dart';
import 'package:vshape_app/widgets/scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Answer every platform-channel call with null: the native helpers treat a
  // null reply as "feature unavailable" (so no vibration/notification in tests).
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('vshape/native'), (call) async => null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);

  Future<AppState> boot({bool arabic = true}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = await AppState.boot();
    await st.setArabic(arabic);
    return st;
  }

  group('RestTimerController', () {
    test('counts down from the requested seconds', () async {
      final c = RestTimerController();
      addTearDown(c.dispose);
      c.start(60, label: 'Table rows');

      expect(c.running, isTrue);
      expect(c.left, 60);
      expect(c.total, 60);
      expect(c.label, 'Table rows');
      expect(c.progress, 0);

      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(c.left, lessThan(60));
      expect(c.left, greaterThanOrEqualTo(58));
      expect(c.progress, greaterThan(0));
      expect(c.progress, lessThan(1));
    });

    test('pause freezes the countdown, resume continues it', () async {
      final c = RestTimerController();
      addTearDown(c.dispose);
      c.start(60);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      c.togglePause();
      final frozen = c.left;
      expect(c.paused, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(c.left, frozen, reason: 'a paused rest must not keep running');

      c.togglePause();
      expect(c.paused, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(c.left, lessThan(frozen));
    });

    test('+30 extends both the total and what is left', () async {
      final c = RestTimerController();
      addTearDown(c.dispose);
      c.start(90);
      final before = c.left;
      c.add(30);
      expect(c.total, 120);
      expect(c.left, before + 30);
      expect(c.progress, lessThan(1));
    });

    test('stop clears the timer so the bar disappears', () async {
      final c = RestTimerController();
      addTearDown(c.dispose);
      c.start(90);
      c.stop();
      expect(c.running, isFalse);
      expect(c.left, 0);
      expect(c.label, isNull);
    });

    test('silly durations are clamped', () {
      final c = RestTimerController();
      addTearDown(c.dispose);
      c.start(0);
      expect(c.total, 5);
      c.start(999999);
      expect(c.total, 3600);
    });

    test('finishing on its own stops the timer', () async {
      final c = RestTimerController();
      addTearDown(c.dispose);
      c.start(5); // the minimum
      expect(c.running, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 6200));
      expect(c.running, isFalse, reason: 'the countdown must clean itself up');
      expect(c.left, 0);
    });
  });

  group('rest timer widgets', () {
    Future<void> pumpScoped(WidgetTester tester, {bool arabic = true}) async {
      late AppState st;
      await tester.runAsync(() async => st = await boot(arabic: arabic));
      await tester.pumpWidget(
        MaterialApp(
          locale: st.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: st.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: AppScope(
              state: st,
              child: RestTimerScope(child: child ?? const SizedBox.shrink()),
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const RestPill(seconds: 90, label: 'Wide push-ups'),
                  RestTimerBar(controller: RestTimerScope.of(context)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('bar is hidden until a rest starts, then shows the seconds (Arabic)',
        (tester) async {
      await pumpScoped(tester);
      expect(find.text('راحة بين المجموعات'), findsNothing);

      await tester.tap(find.byType(RestPill));
      await tester.pump();

      expect(find.text('راحة بين المجموعات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bar renders in English and the skip button clears it', (tester) async {
      await pumpScoped(tester, arabic: false);

      await tester.tap(find.byType(RestPill));
      await tester.pump();
      expect(find.text('Rest between sets'), findsOneWidget);
      expect(find.text('Wide push-ups'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.text('Rest between sets'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('+30 and pause buttons are wired', (tester) async {
      await pumpScoped(tester);

      await tester.tap(find.byType(RestPill));
      await tester.pump();

      await tester.tap(find.text('+30'));
      await tester.pump();
      expect(find.text('90'), findsNothing, reason: '90 s became 120 s');

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
