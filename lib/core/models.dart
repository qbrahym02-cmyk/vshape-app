/// Data models for the remotely-updatable content file (assets/content/content.json).
library;

class Txt {
  final String ar;
  final String en;
  const Txt(this.ar, this.en);

  factory Txt.from(dynamic v) {
    if (v is String) return Txt(v, v);
    if (v is Map) {
      return Txt(
        (v['ar'] ?? v['en'] ?? '').toString(),
        (v['en'] ?? v['ar'] ?? '').toString(),
      );
    }
    return const Txt('', '');
  }

  /// Resolve for the given "is Arabic" flag.
  String t(bool isAr) => isAr ? ar : en;

  bool get isEmpty => ar.isEmpty && en.isEmpty;
}

Txt _txt(dynamic v) => Txt.from(v);
String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? d;

List<dynamic> _list(dynamic v) => v is List ? v : const <dynamic>[];

/// Coerces a JSON list of strings (or of {"ar":..,"en":..} objects) into
/// a plain list of strings for the requested language.
List<String> _biStrings(dynamic v, bool wantArabic) {
  if (v is! List) return const <String>[];
  final out = <String>[];
  for (final e in v) {
    if (e is Map) {
      final pick = wantArabic ? (e['ar'] ?? e['en']) : (e['en'] ?? e['ar']);
      out.add('$pick');
    } else if (e != null) {
      out.add('$e');
    }
  }
  return out;
}

/// Bilingual list of sentences (steps / bullets).
class BiList {
  final List<String> ar;
  final List<String> en;
  const BiList(this.ar, this.en);

  /// Accepts three shapes:
  ///   {"ar": ["..",".."], "en": ["..",".."]}   <- used by exercise steps
  ///   [{"ar":"..","en":".."}, ...]             <- used by the "avoid" list
  ///   ["..", ".."]                             <- plain strings (both langs)
  factory BiList.from(dynamic v) {
    if (v is Map) {
      final ar = _biStrings(v['ar'], true);
      final en = _biStrings(v['en'], false);
      if (ar.isEmpty && en.isEmpty) {
        final flat = _biStrings(v, true);
        return BiList(flat, flat);
      }
      return BiList(ar.isEmpty ? en : ar, en.isEmpty ? ar : en);
    }
    if (v is List) {
      return BiList(_biStrings(v, true), _biStrings(v, false));
    }
    return const BiList(<String>[], <String>[]);
  }

  List<String> t(bool isAr) => isAr ? ar : en;
  bool get isEmpty => ar.isEmpty && en.isEmpty;
}

// ---------------------------------------------------------------------------
// App meta
// ---------------------------------------------------------------------------

class AppMeta {
  final Txt name;
  final Txt tagline;
  final Txt goal;
  final int age;
  final List<int> heightCm;
  final List<int> weightKg;

  AppMeta({
    required this.name,
    required this.tagline,
    required this.goal,
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  factory AppMeta.from(Map<String, dynamic> j) {
    final app = (j['app'] as Map?)?.cast<String, dynamic>() ?? const {};
    final profile = (app['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<int> range(dynamic v, int a, int b) {
      if (v is List && v.length >= 2) return [_i(v[0], a), _i(v[1], b)];
      if (v is num) return [v.toInt(), v.toInt()];
      return [a, b];
    }

    return AppMeta(
      name: _txt(app['name']),
      tagline: _txt(app['tagline']),
      goal: _txt(profile['goal']),
      age: _i(profile['age'], 15),
      heightCm: range(profile['height_cm'], 185, 190),
      weightKg: range(profile['weight_kg'], 80, 85),
    );
  }
}

// ---------------------------------------------------------------------------
// Water
// ---------------------------------------------------------------------------

class WaterSlot {
  final String id;
  final String time;
  final int glasses;
  final Txt title;
  final Txt why;
  final bool remind;

  WaterSlot({
    required this.id,
    required this.time,
    required this.glasses,
    required this.title,
    required this.why,
    required this.remind,
  });

  factory WaterSlot.from(Map<String, dynamic> j) => WaterSlot(
        id: _s(j['id']),
        time: _s(j['time'], '08:00'),
        glasses: _i(j['glasses'], 1),
        title: _txt(j['title']),
        why: _txt(j['why']),
        remind: j['remind'] != false,
      );
}

class WaterConfig {
  final int goalMl;
  final int glassMl;
  final int minMl;
  final int maxMl;
  final Txt note;
  final List<WaterSlot> slots;

  WaterConfig({
    required this.goalMl,
    required this.glassMl,
    required this.minMl,
    required this.maxMl,
    required this.note,
    required this.slots,
  });

  int get slotTotalMl =>
      slots.fold(0, (s, e) => s + e.glasses * glassMl);

  factory WaterConfig.from(Map<String, dynamic> j) {
    final glass = _i(j['glass_ml'], 500).clamp(100, 2000);
    return WaterConfig(
      goalMl: _i(j['goal_ml'], 3750),
      glassMl: glass,
      minMl: _i(j['min_ml'], 3500),
      maxMl: _i(j['max_ml'], 4000),
      note: _txt(j['note']),
      slots: [for (final e in _list(j['slots'])) WaterSlot.from((e as Map).cast<String, dynamic>())],
    );
  }
}

// ---------------------------------------------------------------------------
// Food
// ---------------------------------------------------------------------------

class MealItem {
  final Txt name;
  final String qty;

  /// Exact macros for this single item. `null` when the content file only
  /// gives meal totals (older content versions) - the counter then falls back
  /// to splitting the meal evenly, exactly like before.
  final int? proteinG;
  final int? kcal;

  MealItem({required this.name, required this.qty, this.proteinG, this.kcal});

  factory MealItem.from(Map<String, dynamic> j) => MealItem(
        name: _txt(j['name']),
        qty: _s(j['qty'], '1'),
        proteinG: j['protein_g'] is num ? (j['protein_g'] as num).toInt() : null,
        kcal: j['kcal'] is num ? (j['kcal'] as num).toInt() : null,
      );
}

/// One "off-plan" food the user can tap to add to today's totals.
class FoodExtra {
  final String id;
  final String emoji;
  final Txt name;
  final int proteinG;
  final int kcal;

  FoodExtra({
    required this.id,
    required this.emoji,
    required this.name,
    required this.proteinG,
    required this.kcal,
  });

  factory FoodExtra.from(Map<String, dynamic> j) => FoodExtra(
        id: _s(j['id']),
        emoji: _s(j['emoji'], '🍽️'),
        name: _txt(j['name']),
        proteinG: _i(j['protein_g']),
        kcal: _i(j['kcal']),
      );
}

class ExtrasConfig {
  final Txt note;
  final List<FoodExtra> items;

  ExtrasConfig({required this.note, required this.items});

  const ExtrasConfig._empty()
      : note = const Txt('', ''),
        items = const <FoodExtra>[];

  bool get isEmpty => items.isEmpty;

  factory ExtrasConfig.from(Map<String, dynamic> j) => ExtrasConfig(
        note: _txt(j['note']),
        items: [
          for (final e in _list(j['items']))
            FoodExtra.from((e as Map).cast<String, dynamic>())
        ],
      );
}

class Meal {
  final String id;
  final String time;
  final Txt title;
  final Txt subtitle;
  final int proteinG;
  final int kcal;
  final List<MealItem> items;
  final Txt tip;

  Meal({
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.proteinG,
    required this.kcal,
    required this.items,
    required this.tip,
  });

  factory Meal.from(Map<String, dynamic> j) => Meal(
        id: _s(j['id']),
        time: _s(j['time'], ''),
        title: _txt(j['title']),
        subtitle: _txt(j['subtitle']),
        proteinG: _i(j['protein_g']),
        kcal: _i(j['kcal']),
        items: [
          for (final e in _list(j['items']))
            MealItem.from((e as Map).cast<String, dynamic>())
        ],
        tip: _txt(j['tip']),
      );
}

class ProteinSource {
  final Txt name;
  final Txt protein;
  final int rank;
  final Txt note;
  ProteinSource({required this.name, required this.protein, required this.rank, required this.note});
  factory ProteinSource.from(Map<String, dynamic> j) => ProteinSource(
        name: _txt(j['name']),
        protein: _txt(j['protein']),
        rank: _i(j['rank'], 99),
        note: _txt(j['note']),
      );
}

class FoodConfig {
  final List<int> kcalTarget;
  final int proteinTarget;
  final Txt budgetRule;
  final List<Meal> meals;
  final List<ProteinSource> sources;
  final BiList avoid;

  /// Tap-to-add foods for anything eaten outside the plan (v4 of the content
  /// file).  Empty on older content, and the UI simply hides the section.
  final ExtrasConfig extras;

  FoodConfig({
    required this.kcalTarget,
    required this.proteinTarget,
    required this.budgetRule,
    required this.meals,
    required this.sources,
    required this.avoid,
    this.extras = const ExtrasConfig._empty(),
  });

  int get plannedProtein => meals.fold(0, (s, m) => s + m.proteinG);
  int get plannedKcal => meals.fold(0, (s, m) => s + m.kcal);

  factory FoodConfig.from(Map<String, dynamic> j) {
    final kt = j['kcal_target'];
    return FoodConfig(
      kcalTarget: (kt is List && kt.length >= 2) ? [_i(kt[0], 2800), _i(kt[1], 3000)] : [2800, 3000],
      proteinTarget: _i(j['protein_g_target'], 150),
      budgetRule: _txt(j['budget_rule']),
      meals: [for (final e in _list(j['meals'])) Meal.from((e as Map).cast<String, dynamic>())],
      sources: [
        for (final e in _list(j['protein_sources']))
          ProteinSource.from((e as Map).cast<String, dynamic>())
      ]..sort((a, b) => a.rank.compareTo(b.rank)),
      avoid: BiList.from(j['avoid']),
      extras: ExtrasConfig.from(
          (j['extras'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout
// ---------------------------------------------------------------------------

class Exercise {
  final String id;
  final Txt name;
  final Txt target;
  final int sets;
  final Txt reps;
  final int restS;
  final String tempo;
  final BiList steps;
  final Txt note;

  Exercise({
    required this.id,
    required this.name,
    required this.target,
    required this.sets,
    required this.reps,
    required this.restS,
    required this.tempo,
    required this.steps,
    required this.note,
  });

  factory Exercise.from(Map<String, dynamic> j) => Exercise(
        id: _s(j['id']),
        name: _txt(j['name']),
        target: _txt(j['target']),
        sets: _i(j['sets'], 3),
        reps: _txt(j['reps']),
        restS: _i(j['rest_s'], 90),
        tempo: _s(j['tempo'], '3-1-1'),
        steps: BiList.from(j['steps']),
        note: _txt(j['note']),
      );
}

class WorkoutDay {
  final String id;

  /// 0 = Monday ... 6 = Sunday (Dart DateTime.weekday).
  final int day;
  final String emoji;
  final Txt title;
  final Txt focus;
  final bool isRest;
  final List<Exercise> exercises;
  final BiList restPlan;

  WorkoutDay({
    required this.id,
    required this.day,
    required this.emoji,
    required this.title,
    required this.focus,
    required this.isRest,
    required this.exercises,
    required this.restPlan,
  });

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets);

  factory WorkoutDay.from(Map<String, dynamic> j) => WorkoutDay(
        id: _s(j['id']),
        day: _i(j['day'], 1),
        emoji: _s(j['emoji'], '💪'),
        title: _txt(j['title']),
        focus: _txt(j['focus']),
        isRest: j['is_rest'] == true,
        exercises: [
          for (final e in _list(j['exercises']))
            Exercise.from((e as Map).cast<String, dynamic>())
        ],
        restPlan: BiList.from(j['rest_plan']),
      );
}

class WorkoutConfig {
  final Txt tempoRule;
  final Txt restRule;
  final Txt equipmentNote;
  final List<WorkoutDay> days;

  WorkoutConfig({
    required this.tempoRule,
    required this.restRule,
    required this.equipmentNote,
    required this.days,
  });

  WorkoutDay? dayForWeekday(int weekday) {
    for (final d in days) {
      if (d.day == weekday) return d;
    }
    return null;
  }

  factory WorkoutConfig.from(Map<String, dynamic> j) => WorkoutConfig(
        tempoRule: _txt(j['tempo_rule']),
        restRule: _txt(j['rest_rule']),
        equipmentNote: _txt(j['equipment_note']),
        days: [
          for (final e in _list(j['days']))
            WorkoutDay.from((e as Map).cast<String, dynamic>())
        ]..sort((a, b) => a.day.compareTo(b.day)),
      );
}

// ---------------------------------------------------------------------------
// Routine / rules / progress
// ---------------------------------------------------------------------------

class RoutineItem {
  final String id;
  final String time;
  final String emoji;
  final Txt title;
  final Txt detail;
  final String category;
  RoutineItem({
    required this.id,
    required this.time,
    required this.emoji,
    required this.title,
    required this.detail,
    required this.category,
  });
  factory RoutineItem.from(Map<String, dynamic> j) => RoutineItem(
        id: _s(j['id']),
        time: _s(j['time'], ''),
        emoji: _s(j['emoji'], '•'),
        title: _txt(j['title']),
        detail: _txt(j['detail']),
        category: _s(j['category'], 'general'),
      );
}

class Rule {
  final String id;
  final String emoji;
  final String severity;
  final Txt title;
  final Txt text;
  Rule({required this.id, required this.emoji, required this.severity, required this.title, required this.text});
  factory Rule.from(Map<String, dynamic> j) => Rule(
        id: _s(j['id']),
        emoji: _s(j['emoji'], '⚠️'),
        severity: _s(j['severity'], 'mid'),
        title: _txt(j['title']),
        text: _txt(j['text']),
      );
}

class Kpi {
  final String id;
  final String emoji;
  final Txt title;
  final Txt detail;
  final String logType;
  Kpi({required this.id, required this.emoji, required this.title, required this.detail, required this.logType});
  factory Kpi.from(Map<String, dynamic> j) => Kpi(
        id: _s(j['id']),
        emoji: _s(j['emoji'], '📊'),
        title: _txt(j['title']),
        detail: _txt(j['detail']),
        logType: _s(j['log'], 'note'),
      );
}

class LoggableItem {
  final String id;
  final Txt name;
  LoggableItem({required this.id, required this.name});
  factory LoggableItem.from(Map<String, dynamic> j) =>
      LoggableItem(id: _s(j['id']), name: _txt(j['name']));
}

class ProgressConfig {
  final Txt title;
  final List<Kpi> kpis;
  final Txt strengthTitle;
  final List<LoggableItem> strengthExercises;
  final List<LoggableItem> measurements;
  ProgressConfig({
    required this.title,
    required this.kpis,
    required this.strengthTitle,
    required this.strengthExercises,
    required this.measurements,
  });
  factory ProgressConfig.from(Map<String, dynamic> j) {
    final sl = (j['strength_log'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProgressConfig(
      title: _txt(j['title']),
      kpis: [for (final e in _list(j['kpis'])) Kpi.from((e as Map).cast<String, dynamic>())],
      strengthTitle: _txt(sl['title']),
      strengthExercises: [
        for (final e in _list(sl['exercises']))
          LoggableItem.from((e as Map).cast<String, dynamic>())
      ],
      measurements: [
        for (final e in _list(j['measurements']))
          LoggableItem.from((e as Map).cast<String, dynamic>())
      ],
    );
  }
}

class Section {
  final Txt title;
  final BiList body;
  final String emoji;
  Section({required this.title, required this.body, required this.emoji});
  factory Section.from(Map<String, dynamic> j) => Section(
        title: _txt(j['title']),
        body: BiList.from(j['body'] ?? j['rules'] ?? j['text']),
        emoji: _s(j['emoji'], '🎒'),
      );
}

class Philosophy {
  final String emoji;
  final Txt title;
  final Txt text;
  Philosophy({required this.emoji, required this.title, required this.text});
  factory Philosophy.from(Map<String, dynamic> j) => Philosophy(
        emoji: _s(j['emoji'], '🧠'),
        title: _txt(j['title']),
        text: _txt(j['text']),
      );
}

class ReminderConfig {
  final List<String> water;
  final String workout;
  final String sleep;
  final bool enabled;
  ReminderConfig({required this.water, required this.workout, required this.sleep, required this.enabled});
  factory ReminderConfig.from(Map<String, dynamic> j) {
    List<String> times(dynamic v) => [
          for (final e in _list(v))
            if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch('$e')) '$e'
        ];
    return ReminderConfig(
      water: times(j['water']),
      workout: RegExp(r'^\d{1,2}:\d{2}$').hasMatch('${j['workout']}') ? '${j['workout']}' : '17:25',
      sleep: RegExp(r'^\d{1,2}:\d{2}$').hasMatch('${j['sleep']}') ? '${j['sleep']}' : '22:30',
      enabled: j['enabled'] != false,
    );
  }
}

// ---------------------------------------------------------------------------
// Root
// ---------------------------------------------------------------------------

class AppContent {
  final int version;
  final String updatedAt;
  final AppMeta meta;
  final WaterConfig water;
  final FoodConfig food;
  final WorkoutConfig workout;
  final List<RoutineItem> routine;
  final Section backpack;
  final ProgressConfig progress;
  final List<Rule> rules;
  final List<Philosophy> philosophy;
  final ReminderConfig reminders;
  final Map<String, dynamic> raw;

  AppContent({
    required this.version,
    required this.updatedAt,
    required this.meta,
    required this.water,
    required this.food,
    required this.workout,
    required this.routine,
    required this.backpack,
    required this.progress,
    required this.rules,
    required this.philosophy,
    required this.reminders,
    required this.raw,
  });

  factory AppContent.fromMap(Map<String, dynamic> j) {
    Map<String, dynamic> m(String k) => (j[k] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return AppContent(
      version: _i(j['version'], 1),
      updatedAt: _s(j['updated_at'], ''),
      meta: AppMeta.from(j),
      water: WaterConfig.from(m('water')),
      food: FoodConfig.from(m('food')),
      workout: WorkoutConfig.from(m('workout')),
      routine: [
        for (final e in _list(j['routine'])) RoutineItem.from((e as Map).cast<String, dynamic>())
      ]..sort((a, b) => a.time.compareTo(b.time)),
      backpack: Section.from(m('backpack')),
      progress: ProgressConfig.from(m('progress')),
      rules: [for (final e in _list(j['rules'])) Rule.from((e as Map).cast<String, dynamic>())],
      philosophy: [
        for (final e in _list(j['philosophy'])) Philosophy.from((e as Map).cast<String, dynamic>())
      ],
      reminders: ReminderConfig.from(m('reminders')),
      raw: j,
    );
  }
}
