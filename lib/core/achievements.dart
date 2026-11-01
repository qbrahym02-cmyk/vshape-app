/// Achievement badges (v1.4).
///
/// Pure Dart on purpose: the counting rules stay next to their tests in
/// `test/v14_test.dart`, and the screen only renders what this file computes.
/// Nothing is stored - every value is re-derived from the same dated keys the
/// streaks and reports already read, so an achievement can never get stuck.
library;

/// The raw counters an [Achievement] is judged against.
class AchievementCounts {
  const AchievementCounts({
    required this.loggedDays,
    required this.streak,
    required this.waterGoalDays,
    required this.proteinGoalDays,
    required this.workoutsDone,
    required this.sleepOnTime,
    required this.records,
    required this.photosDone,
  });

  /// Days with any evidence at all (water, meal, task, set or bedtime).
  final int loggedDays;

  /// Current "day counts" streak.
  final int streak;

  /// Days the water goal was reached (report target, ~90%).
  final int waterGoalDays;

  /// Days the protein goal was reached (report target, ~85%).
  final int proteinGoalDays;

  /// Training sessions whose every set was ticked.
  final int workoutsDone;

  /// Nights logged inside the growth-hormone window.
  final int sleepOnTime;

  /// Personal records set over the whole log history.
  final int records;

  /// Monthly comparison photos ticked off.
  final int photosDone;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.emoji,
    required this.arTitle,
    required this.enTitle,
    required this.arDesc,
    required this.enDesc,
    required this.goal,
    required this.value,
  });

  final String id;
  final String emoji;
  final String arTitle;
  final String enTitle;
  final String arDesc;
  final String enDesc;

  /// The value that unlocks the badge.
  final int goal;

  /// Where the user stands right now.
  final int value;

  bool get unlocked => goal > 0 && value >= goal;
  double get progress => goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0).toDouble();
}

/// The full badge list, in display order: consistency first, then the four
/// pillars (water / protein / training / sleep), then records and photos.
List<Achievement> evaluateAchievements(AchievementCounts c) {
  Achievement a(
    String id,
    String emoji,
    String arTitle,
    String enTitle,
    String arDesc,
    String enDesc,
    int goal,
    int value,
  ) =>
      Achievement(
        id: id,
        emoji: emoji,
        arTitle: arTitle,
        enTitle: enTitle,
        arDesc: arDesc,
        enDesc: enDesc,
        goal: goal,
        value: value,
      );

  return [
    a('first_day', '🌅', 'الخطوة الأولى', 'The first step',
        'سجّل أول يوم لك في النظام. كل بطل بدأ بيوم واحد.',
        'Log your first day in the system. Every champion started with one.', 1, c.loggedDays),
    a('streak_3', '🔥', '٣ أيام متتالية', '3-day streak',
        'سجّل ٣ أيام متتالية — العادة بدأت تنغرس.',
        'Log 3 days in a row - the habit is starting to stick.', 3, c.streak),
    a('streak_7', '🗓️', 'أسبوع كامل', 'A full week',
        'أسبوع كامل بلا انقطاع. هذا ليس حماساً، هذا انضباط.',
        'A whole week without a miss. That is not motivation, that is discipline.', 7, c.streak),
    a('streak_14', '⚡', 'أسبوعان متتاليان', 'Two weeks strong',
        '١٤ يوماً متتالياً — مرحلة "الطبيعي الجديد".',
        '14 days in a row - welcome to your new normal.', 14, c.streak),
    a('streak_30', '👑', 'شهر كامل', 'A whole month',
        '٣٠ يوماً متتالياً. من يفعلها مرة يقدر يفعلها دائماً.',
        '30 days in a row. Do it once and you can do it forever.', 30, c.streak),
    a('water_10', '💧', 'مرطّب المحترف', 'Hydration pro',
        'حقق هدف الماء في ١٠ أيام.',
        'Hit the water goal on 10 days.', 10, c.waterGoalDays),
    a('water_30', '🌊', 'تمشي بنهر', 'Walking river',
        'هدف الماء في ٣٠ يوماً — خلاياك تشكرك.',
        'The water goal on 30 days - your cells thank you.', 30, c.waterGoalDays),
    a('protein_10', '🍗', 'وقود البناء', 'Building fuel',
        'وصلت هدف البروتين في ١٠ أيام — الطوب وصل لموقع البناء.',
        'Hit the protein target on 10 days - the bricks arrived on site.', 10, c.proteinGoalDays),
    a('protein_30', '🧱', 'بنّاء حقيقي', 'True builder',
        'هدف البروتين في ٣٠ يوماً. العضل الآن لديه مواد دائمة.',
        'The protein target on 30 days. Muscle now has a steady supply.', 30, c.proteinGoalDays),
    a('workout_1', '🏋️', 'أول جلسة كاملة', 'First full session',
        'أكملت جلسة كاملة بكل مجموعاتها.',
        'Finished a full session, every set ticked.', 1, c.workoutsDone),
    a('workout_10', '🔥', '١٠ جلسات كاملة', '10 full sessions',
        '١٠ جلسات كاملة — الجسم بدأ يفهم الرسالة.',
        '10 full sessions - the body is getting the message.', 10, c.workoutsDone),
    a('workout_50', '🏆', '٥٠ جلسة كاملة', '50 full sessions',
        '٥٠ جلسة كاملة. أنت لم تعد "مبتدئاً".',
        '50 full sessions. You are no longer a beginner.', 50, c.workoutsDone),
    a('sleep_7', '😴', 'حرّاس النافذة', 'Window guard',
        '٧ ليالٍ نمت فيها داخل نافذة هرمون النمو.',
        '7 nights asleep inside the growth-hormone window.', 7, c.sleepOnTime),
    a('record_1', '🥇', 'أول رقم قياسي', 'First personal record',
        'سجّلت رقماً قياسياً جديداً — دليل ملموس على النمو.',
        'Set a new personal record - tangible proof of growth.', 1, c.records),
    a('record_10', '📈', '١٠ أرقام قياسية', '10 personal records',
        '١٠ أرقام قياسية. المنحنى يصعد وأنت معه.',
        '10 personal records. The curve is climbing and so are you.', 10, c.records),
    a('photo_1', '📸', 'شاهد التغيير', 'Witness the change',
        'أخذت صورة المقارنة الشهرية الأولى.',
        'Took your first monthly comparison photo.', 1, c.photosDone),
  ];
}
