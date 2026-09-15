// Pure-maths tests for the v1.1 tools: no Flutter binding, no SharedPreferences.
// These are the rules the UI merely displays, so they are pinned down here.
import 'package:flutter_test/flutter_test.dart';
import 'package:vshape_app/core/plan_math.dart';

void main() {
  group('bedtime vs the growth-hormone cutoff', () {
    test('HH:MM parses, anything else does not', () {
      expect(minutesOfDay('23:00'), 23 * 60);
      expect(minutesOfDay('0:30'), 30);
      expect(minutesOfDay(' 22:15 '), 22 * 60 + 15);
      expect(minutesOfDay('24:00'), isNull);
      expect(minutesOfDay('23:60'), isNull);
      expect(minutesOfDay('aa:bb'), isNull);
      expect(minutesOfDay(''), isNull);
      expect(minutesOfDay('23'), isNull);
    });

    test('on time means at or before the target', () {
      expect(bedtimeOnTime(bedtime: '21:00', target: '23:00'), isTrue);
      expect(bedtimeOnTime(bedtime: '22:30', target: '23:00'), isTrue);
      expect(bedtimeOnTime(bedtime: '23:00', target: '23:00'), isTrue);
      expect(bedtimeOnTime(bedtime: '23:01', target: '23:00'), isFalse);
      expect(bedtimeOnTime(bedtime: '23:30', target: '23:00'), isFalse);
    });

    test('after midnight counts as the same, late, night', () {
      expect(bedtimeOnTime(bedtime: '00:30', target: '23:00'), isFalse);
      expect(bedtimeOnTime(bedtime: '02:00', target: '23:00'), isFalse);
      expect(minutesLate(bedtime: '00:30', target: '23:00'), 90);
      expect(minutesLate(bedtime: '23:30', target: '23:00'), 30);
      expect(minutesLate(bedtime: '22:00', target: '23:00'), 0);
      expect(minutesLate(bedtime: 'nope', target: '23:00'), 0);
    });
  });

  group('protein economics', () {
    // Prices are made up; the ratios are what the maths has to get right.
    const eggs = SourcePrice(id: 'eggs', proteinPerUnitG: 6.5, maxUnits: 6, price: 6);
    const milk = SourcePrice(id: 'milk', proteinPerUnitG: 32, maxUnits: 4, price: 30);
    const cottage = SourcePrice(id: 'cottage', proteinPerUnitG: 11.5, maxUnits: 3, price: 25);
    const soy = SourcePrice(id: 'soy', proteinPerUnitG: 36, maxUnits: 1, price: 90);
    const unpriced = SourcePrice(id: 'chicken', proteinPerUnitG: 22, maxUnits: 4);

    test('cost per gram is what makes an egg comparable to a litre of milk', () {
      expect(eggs.costPerGram, closeTo(6 / 6.5, 1e-9));
      expect(milk.costPerGram, closeTo(30 / 32, 1e-9));
      expect(eggs.costPer(20), closeTo(6 / 6.5 * 20, 1e-9));
      expect(unpriced.priced, isFalse);
      expect(unpriced.costPer(20), isNull);
      expect(unpriced.costPerGram, isNull);
    });

    test('the basket fills cheapest-first and respects the daily caps', () {
      final b = cheapestBasket(sources: const [cottage, milk, eggs], targetG: 150);

      // eggs (0.92/g) then milk (0.94/g); cottage (2.17/g) never gets a turn.
      expect(b.lines.map((l) => l.id), ['eggs', 'milk']);
      expect(b.lines[0].units, 6, reason: 'the 6-egg cap binds before the target');
      expect(b.lines[0].grams, closeTo(39, 1e-9));
      expect(b.lines[1].units, closeTo(111 / 32, 0.01));
      expect(b.grams, closeTo(150, 0.05));
      expect(b.reached, isTrue);
      expect(b.cost, closeTo(6 * 6 + (111 / 32) * 30, 0.2));
    });

    test('quantities are rounded to something you can actually measure', () {
      final b = cheapestBasket(sources: const [milk], targetG: 100);
      expect(b.lines.single.units, closeTo(3.13, 0.01), reason: '100/32, two decimals');
      expect(b.grams, closeTo(100, 0.5));
    });

    test('a basket that cannot reach the target says so', () {
      final b = cheapestBasket(sources: const [soy], targetG: 150);
      expect(b.lines.length, 1);
      expect(b.lines.single.units, 1, reason: 'capped at 100 g dry');
      expect(b.grams, closeTo(36, 1e-9));
      expect(b.reached, isFalse);
      expect(maxReachableGrams(const [soy, milk]), closeTo(36 + 128, 1e-9));
      expect(maxReachableGrams(const [unpriced]), 0, reason: 'no price, no plan');
    });

    test('nothing priced means an empty basket, not a crash', () {
      final b = cheapestBasket(sources: const [unpriced], targetG: 150);
      expect(b.isEmpty, isTrue);
      expect(b.cost, 0);
      expect(b.reached, isFalse);
    });
  });

  group('backpack loading', () {
    const bottleMl = 1500.0;
    const bagKg = 1.0;

    double kg(int bottles, double sand) => backpackKg(
          bottles: bottles,
          bottleMl: bottleMl,
          sandFraction: sand,
          waterKgPerL: 1.0,
          sandKgPerL: 1.6,
          bagKg: bagKg,
        );

    test('sand is heavier than water in the same bottle', () {
      expect(kg(3, 0), closeTo(5.5, 1e-9));
      expect(kg(3, 0.5), closeTo(6.85, 1e-9));
      expect(kg(3, 1), closeTo(8.2, 1e-9));
      expect(kg(4, 1), closeTo(10.6, 1e-9));
    });

    test('an empty bag is just the bag, and nonsense is clamped', () {
      expect(kg(0, 1), closeTo(bagKg, 1e-9));
      expect(kg(-3, 1), closeTo(bagKg, 1e-9));
      expect(kg(3, 5), kg(3, 1), reason: 'sand fraction is clamped to 1');
      expect(kg(3, -1), kg(3, 0), reason: 'and to 0');
    });

    test('the safe window is a percentage of bodyweight', () {
      final r = loadRangeKg(bodyKg: 82.5, bodyPct: [10, 20]);
      expect(r.min, closeTo(8.3, 0.05));
      expect(r.max, closeTo(16.5, 0.05));
      expect(loadVerdict(kg: 1, bodyKg: 82.5, bodyPct: [10, 20]), LoadVerdict.light);
      expect(loadVerdict(kg: 10, bodyKg: 82.5, bodyPct: [10, 20]), LoadVerdict.good);
      expect(loadVerdict(kg: r.max, bodyKg: 82.5, bodyPct: [10, 20]), LoadVerdict.good);
      expect(loadVerdict(kg: 25, bodyKg: 82.5, bodyPct: [10, 20]), LoadVerdict.heavy);
    });
  });

  group('adherence maths', () {
    test('share is clamped and null-safe', () {
      expect(share(5, 10), 0.5);
      expect(share(15, 10), 1);
      expect(share(0, 10), 0);
      expect(share(-5, 10), 0);
      expect(share(5, 0), 0);
    });

    test('the overall score ignores columns with no data at all', () {
      const rows = [
        WeekRow(id: 'water', value: 1, previous: 0, target: 0.9),
        WeekRow(id: 'sleep', value: 0, previous: 0, target: 0),
      ];
      expect(overallScore(rows), 1.0);
      expect(overallScore(const [WeekRow(id: 'x', value: 0, previous: 0, target: 0)]), 0);
    });

    test('rows know whether they met their bar and how they moved', () {
      const up = WeekRow(id: 'water', value: 0.95, previous: 0.8, target: 0.9);
      const down = WeekRow(id: 'protein', value: 0.4, previous: 0.7, target: 0.85);
      expect(up.met, isTrue);
      expect(up.improving, isTrue);
      expect(down.met, isFalse);
      expect(down.improving, isFalse);
      expect(down.delta, closeTo(-0.3, 1e-9));
    });

    test('praise is bucketed into the four content lines', () {
      expect(praiseIndex(0.95), 0);
      expect(praiseIndex(0.9), 0);
      expect(praiseIndex(0.75), 1);
      expect(praiseIndex(0.55), 2);
      expect(praiseIndex(0.2), 3);
    });

    test('the report picks the weakest scored column', () {
      const r = WeekReport(
        days: 7,
        rows: [
          WeekRow(id: 'water', value: 0.95, previous: 0.9, target: 0.9),
          WeekRow(id: 'protein', value: 0.30, previous: 0.4, target: 0.85),
          WeekRow(id: 'sleep', value: 0.10, previous: 0, target: 0),
        ],
        records: 1,
        sessionsDone: 2,
        sessionsTarget: 5,
        sleepLogged: 3,
        sleepOnTime: 2,
      );
      expect(r.weakest?.id, 'protein', reason: 'sleep has no bar, so it is not scored');
      expect(r.rowById('water')?.value, 0.95);
      expect(r.rowById('nope'), isNull);
      expect(r.scorePct, greaterThan(0));
      expect(r.hasAnyData, isTrue);
    });
  });

  group('streaks and records', () {
    test('a streak stops at the first miss', () {
      expect(leadingStreak(const [true, true, false, true]), 2);
      expect(leadingStreak(const [false, true, true]), 0);
      expect(leadingStreak(const []), 0);
      expect(leadingStreak(const [true, true]), 2);
    });

    test('only a strictly better lift is a record', () {
      expect(beatsBest(const [], 5), isTrue, reason: 'the first lift is always a record');
      expect(beatsBest(const [8], 9), isTrue);
      expect(beatsBest(const [8], 8), isFalse, reason: 'matching is not beating');
      expect(beatsBest(const [8, 12], 10), isFalse);
    });
  });

  group('number text', () {
    test('compact drops pointless zeros', () {
      expect(compact(12), '12');
      expect(compact(12.0), '12');
      expect(compact(12.5), '12.5');
      expect(compact(0.59), '0.6');
    });

    test('roundTo is finite-safe', () {
      expect(roundTo(1.2345, 2), 1.23);
      expect(roundTo(double.infinity, 2), 0);
      expect(roundTo(8.25, 1), 8.3);
    });
  });
}
