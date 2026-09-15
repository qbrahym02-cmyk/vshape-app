// Basic smoke tests for the content model + parsing of the bundled JSON.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vshape_app/core/models.dart';

void main() {
  test('bundled content.json parses into a full AppContent', () {
    final file = File('assets/content/content.json');
    expect(file.existsSync(), isTrue, reason: 'assets/content/content.json must exist');

    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final c = AppContent.fromMap(map);

    expect(c.version, greaterThan(0));
    expect(c.water.goalMl, greaterThan(2000));
    expect(c.water.slots, isNotEmpty);
    expect(c.food.meals, isNotEmpty);
    expect(c.food.plannedProtein, greaterThanOrEqualTo(120));
    expect(c.workout.days.length, 7);
    expect(c.routine.length, greaterThan(5));
    expect(c.rules, isNotEmpty);

    final sunday = c.workout.dayForWeekday(7);
    expect(sunday, isNotNull);
    expect(sunday!.exercises, isNotEmpty);

    // bilingual resolution
    expect(c.water.note.t(true), isNotEmpty);
    expect(c.water.note.t(false), isNotEmpty);
  });

  test('models tolerate missing / broken fields', () {
    final c = AppContent.fromMap(<String, dynamic>{});
    expect(c.version, 1);
    expect(c.water.glassMl, 500);
    expect(c.workout.days, isEmpty);
    expect(Txt.from('plain').t(true), 'plain');
    expect(BiList.from(['a', 'b']).ar, ['a', 'b']);
  });
}
