/// Pure maths behind the v1.1 tools (prices, backpack load, sleep, reports).
///
/// Deliberately free of Flutter imports: everything here is deterministic and
/// covered by `test/plan_math_test.dart`, which keeps the UI code thin and the
/// rules reviewable in one place.
library;

// ---------------------------------------------------------------------------
// Time: is a bedtime inside the growth-hormone window?
// ---------------------------------------------------------------------------

/// `"23:30"` -> 1410 minutes after midnight. Null when the text is not `HH:MM`.
int? minutesOfDay(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Puts a clock time on the "night" axis, where anything before noon is really
/// after midnight: `00:30` becomes `24:30`. That is what lets `23:00` be a
/// sensible cutoff without special-casing midnight.
int _nightAxis(int minutes) => minutes < 12 * 60 ? minutes + 24 * 60 : minutes;

/// True when [bedtime] is at or before [target] on the same night.
///
/// `22:30` vs `23:00` -> on time. `00:30` vs `23:00` -> late (90 minutes).
bool bedtimeOnTime({required String bedtime, required String target}) {
  final b = minutesOfDay(bedtime);
  final t = minutesOfDay(target);
  if (b == null || t == null) return false;
  return _nightAxis(b) <= _nightAxis(t);
}

/// Minutes past [target] (0 when on time, or when either value is unusable).
int minutesLate({required String bedtime, required String target}) {
  final b = minutesOfDay(bedtime);
  final t = minutesOfDay(target);
  if (b == null || t == null) return 0;
  final d = _nightAxis(b) - _nightAxis(t);
  return d > 0 ? d : 0;
}

// ---------------------------------------------------------------------------
// Protein economics: price per 20 g, ranking, cheapest basket
// ---------------------------------------------------------------------------

/// One protein source with what the user pays for a unit of it.
class SourcePrice {
  const SourcePrice({
    required this.id,
    required this.proteinPerUnitG,
    this.maxUnits = double.infinity,
    this.price,
  });

  final String id;

  /// Grams of protein in one unit (one egg, one litre of milk, 100 g cooked...).
  final double proteinPerUnitG;

  /// Realistic daily ceiling, so the "cheapest basket" stays edible.
  final double maxUnits;

  /// Local price of one unit. `null` until the user types it in.
  final double? price;

  bool get priced => price != null && price! > 0 && proteinPerUnitG > 0;

  /// Price of one gram of protein - the only number that lets you compare an
  /// egg with a litre of milk.
  double? get costPerGram => priced ? price! / proteinPerUnitG : null;

  /// Price of [perGrams] grams of protein (20 g by default).
  double? costPer(double perGrams) {
    final c = costPerGram;
    return c == null ? null : c * perGrams;
  }

  /// Grams of protein this source can supply in a day, cap included.
  double get cappedGrams => proteinPerUnitG * maxUnits;
}

/// One line of the cheapest basket: how much of a source to buy/eat.
class BasketLine {
  const BasketLine({
    required this.id,
    required this.units,
    required this.grams,
    required this.cost,
  });

  final String id;
  final double units;
  final double grams;
  final double cost;
}

class Basket {
  const Basket({required this.lines, required this.grams, required this.cost, required this.reached});

  final List<BasketLine> lines;
  final double grams;
  final double cost;

  /// False when even every capped source together cannot reach the target.
  final bool reached;

  bool get isEmpty => lines.isEmpty;
}

/// Greedy cheapest-first basket that respects each source's daily cap.
///
/// Greedy is exactly right here: cost per gram is a linear price, so filling
/// from the cheapest capped source first is optimal.
Basket cheapestBasket({required List<SourcePrice> sources, required double targetG}) {
  final priced = sources.where((s) => s.priced).toList()
    ..sort((a, b) => a.costPerGram!.compareTo(b.costPerGram!));

  final lines = <BasketLine>[];
  var grams = 0.0;
  var cost = 0.0;

  for (final s in priced) {
    if (grams >= targetG) break;
    var units = (targetG - grams) / s.proteinPerUnitG;
    if (units > s.maxUnits) units = s.maxUnits;
    if (units <= 0) continue;
    units = roundTo(units, 2);
    final g = units * s.proteinPerUnitG;
    final c = units * s.price!;
    lines.add(BasketLine(id: s.id, units: units, grams: g, cost: c));
    grams += g;
    cost += c;
  }

  return Basket(
    lines: lines,
    grams: roundTo(grams, 1),
    cost: roundTo(cost, 2),
    reached: grams >= targetG - 0.5,
  );
}

/// How much of today's target the priced sources could cover at most.
double maxReachableGrams(List<SourcePrice> sources) =>
    sources.where((s) => s.priced).fold<double>(0, (sum, s) => sum + s.cappedGrams);

// ---------------------------------------------------------------------------
// Backpack load (sand + water bottles)
// ---------------------------------------------------------------------------

enum LoadVerdict { light, good, heavy }

/// Total mass of the loaded bag in kilograms.
///
/// [sandFraction] is the share of each bottle taken up by sand (0 = water only,
/// 1 = packed sand); the rest is water. Sand is ~1.6 kg/L, water 1.0 kg/L.
double backpackKg({
  required int bottles,
  required double bottleMl,
  required double sandFraction,
  required double waterKgPerL,
  required double sandKgPerL,
  required double bagKg,
}) {
  final bag = bagKg < 0 ? 0.0 : bagKg;
  if (bottles <= 0 || bottleMl <= 0) return roundTo(bag, 2);
  final litres = bottles * bottleMl / 1000.0;
  final sand = litres * sandFraction.clamp(0.0, 1.0);
  final water = litres - sand;
  return roundTo(bag + sand * sandKgPerL + water * waterKgPerL, 2);
}

/// The safe loading window for this bodyweight, from the content's percentages.
({double min, double max}) loadRangeKg({required double bodyKg, required List<int> bodyPct}) {
  final lo = bodyPct.isNotEmpty ? bodyPct.first : 10;
  final hi = bodyPct.length > 1 ? bodyPct[1] : 20;
  final kg = bodyKg <= 0 ? 80.0 : bodyKg;
  return (min: roundTo(kg * lo / 100.0, 1), max: roundTo(kg * hi / 100.0, 1));
}

LoadVerdict loadVerdict({required double kg, required double bodyKg, required List<int> bodyPct}) {
  final r = loadRangeKg(bodyKg: bodyKg, bodyPct: bodyPct);
  if (kg < r.min) return LoadVerdict.light;
  if (kg > r.max) return LoadVerdict.heavy;
  return LoadVerdict.good;
}

// ---------------------------------------------------------------------------
// Adherence / weekly report
// ---------------------------------------------------------------------------

/// Share of [total] that [done] covers, clamped to 0..1 and null-safe.
double share(num done, num total) {
  if (total <= 0) return 0;
  final v = done / total;
  if (v <= 0) return 0;
  return v >= 1 ? 1 : v.toDouble();
}

/// One row of the weekly report: this week, last week, and the bar to clear.
class WeekRow {
  const WeekRow({required this.id, required this.value, required this.previous, required this.target});

  final String id;

  /// 0..1 adherence this week.
  final double value;

  /// 0..1 adherence the week before.
  final double previous;

  /// 0..1 bar from the content file (0 = no bar).
  final double target;

  double get delta => value - previous;
  bool get met => target <= 0 ? true : value >= target;
  bool get improving => delta > 0.0001;
}

/// Mean adherence across rows, ignoring rows that have no data at all.
double overallScore(List<WeekRow> rows) {
  final usable = rows.where((r) => r.target > 0 || r.value > 0 || r.previous > 0).toList();
  if (usable.isEmpty) return 0;
  return roundTo(usable.fold<double>(0, (s, r) => s + r.value) / usable.length, 3);
}

/// Index into the four praise lines of the content file.
int praiseIndex(double score) {
  if (score >= 0.9) return 0;
  if (score >= 0.7) return 1;
  if (score >= 0.5) return 2;
  return 3;
}

/// Everything the weekly report screen needs, computed in one pass by
/// `AppState.weeklyReport`.
class WeekReport {
  const WeekReport({
    required this.days,
    required this.rows,
    required this.records,
    required this.sessionsDone,
    required this.sessionsTarget,
    required this.sleepLogged,
    required this.sleepOnTime,
  });

  final int days;
  final List<WeekRow> rows;

  /// Personal records set inside the window.
  final int records;

  /// Sessions whose every set was ticked, versus the sessions that counted.
  final int sessionsDone;
  final int sessionsTarget;

  /// Nights with a logged bedtime, and how many of those were on time.
  final int sleepLogged;
  final int sleepOnTime;

  /// Mean adherence, 0..1.
  double get score => overallScore(rows);

  /// Which of the four content praise lines fits this score.
  int get praise => praiseIndex(score);

  int get scorePct => (score * 100).round();

  WeekRow? rowById(String id) {
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Weakest scored row - "fix this one thing next week".
  WeekRow? get weakest {
    WeekRow? w;
    for (final r in rows) {
      if (r.target <= 0) continue;
      if (w == null || r.value < w.value) w = r;
    }
    return w;
  }

  bool get hasAnyData => rows.any((r) => r.value > 0 || r.previous > 0);
}

// ---------------------------------------------------------------------------
// Streaks and personal records
// ---------------------------------------------------------------------------

/// Consecutive `true` flags from the start of [flags] (index 0 = most recent).
int leadingStreak(List<bool> flags) {
  var n = 0;
  for (final f in flags) {
    if (!f) break;
    n++;
  }
  return n;
}

/// True when [candidate] is strictly better than everything in [previous]
/// (an empty history counts as a record - the first lift always is one).
bool beatsBest(Iterable<num> previous, num candidate) {
  num? best;
  for (final v in previous) {
    if (best == null || v > best) best = v;
  }
  return best == null || candidate > best;
}

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

double roundTo(double v, int decimals) {
  if (!v.isFinite) return 0;
  final f = _pow10(decimals);
  return (v * f).roundToDouble() / f;
}

double _pow10(int n) {
  var f = 1.0;
  for (var i = 0; i < n; i++) {
    f *= 10;
  }
  return f;
}

/// Compact number text: `12` stays `12`, `12.5` stays `12.5`, `12.0` -> `12`.
String compact(num v) {
  final d = v.toDouble();
  if (d == d.roundToDouble()) return d.round().toString();
  return roundTo(d, 1).toString();
}
