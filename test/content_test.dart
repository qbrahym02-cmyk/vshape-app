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

  _v4Checks();
}

// --------------------------------------------------------------------------
// v4 content: exact per-item macros + quick extras
// --------------------------------------------------------------------------
void _v4Checks() {
  test('content v4: every meal item carries exact macros that add up', () {
    final map = jsonDecode(File('assets/content/content.json').readAsStringSync())
        as Map<String, dynamic>;
    final c = AppContent.fromMap(map);

    expect(c.version, greaterThanOrEqualTo(4));
    for (final m in c.food.meals) {
      expect(m.items, isNotEmpty, reason: m.id);
      var p = 0;
      var k = 0;
      for (final it in m.items) {
        expect(it.proteinG, isNotNull, reason: '${m.id} item missing protein_g');
        expect(it.kcal, isNotNull, reason: '${m.id} item missing kcal');
        p += it.proteinG!;
        k += it.kcal!;
      }
      expect(p, m.proteinG, reason: '${m.id} protein must match the meal total');
      expect(k, m.kcal, reason: '${m.id} kcal must match the meal total');
    }
  });

  test('content v4: quick extras exist and are sane', () {
    final map = jsonDecode(File('assets/content/content.json').readAsStringSync())
        as Map<String, dynamic>;
    final c = AppContent.fromMap(map);
    final extras = c.food.extras.items;

    expect(extras.length, greaterThanOrEqualTo(8));
    final ids = extras.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'extra ids must be unique');
    for (final e in extras) {
      expect(e.proteinG, greaterThanOrEqualTo(0), reason: e.id);
      expect(e.kcal, greaterThan(0), reason: e.id);
      expect(e.name.ar, isNotEmpty, reason: e.id);
      expect(e.name.en, isNotEmpty, reason: e.id);
    }
  });

  test('the bundled asset and the published root file are identical', () {
    final a = File('assets/content/content.json').readAsStringSync();
    final b = File('content.json').readAsStringSync();
    expect(a, b, reason: 'the app ships the same content the remote URL serves');
  });

  test('models still tolerate content without extras or macros', () {
    final c = AppContent.fromMap(<String, dynamic>{
      'food': {
        'meals': [
          {
            'id': 'm1',
            'protein_g': 40,
            'kcal': 600,
            'items': [
              {'name': 'a'},
              {'name': 'b'},
            ]
          }
        ]
      }
    });
    expect(c.food.extras.isEmpty, isTrue);
    expect(c.food.meals.first.items.first.proteinG, isNull);
    expect(c.food.plannedProtein, 40);
  });
}
