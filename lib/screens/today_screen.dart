import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../screens/home_shell.dart';
import '../widgets/common.dart';
import '../widgets/daily_cards.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, this.onOpenWorkout});

  final VoidCallback? onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content;
    final now = DateTime.now();

    final tasks = c.routine;
    final tasksDone = tasks.where((r) => st.taskDone(r.id)).length;
    final waterTotal = st.waterTotal();
    final waterPct = c.water.goalMl == 0 ? 0.0 : waterTotal / c.water.goalMl;
    final protein = st.proteinEaten();
    final proteinPct = c.food.proteinTarget == 0 ? 0.0 : protein / c.food.proteinTarget;

    // Only the day that actually matches today's weekday - a 6-day content
    // plan must not present Monday's session as "today's workout".
    final today = c.workout.dayForWeekday(now.weekday);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(
            title: c.meta.name.t(st.isArabic).isEmpty ? 'V-System' : c.meta.name.t(st.isArabic),
            subtitle:
                '${l.greetingFor(now)} · ${l.weekday(now.weekday)} · ${l.monthDay(now)}',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pill('${st.streak()} 🔥', color: C.amber),
                const SizedBox(height: 4),
                Text(l.streak, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),

          // ---------------- hero: daily score + three rings ----------------
          _ScoreHero(
            score: st.dayScoreToday,
            waterPct: waterPct,
            proteinPct: proteinPct,
            tasksPct: tasks.isEmpty ? 0.0 : tasksDone / tasks.length,
            waterLabel: '${(waterTotal / 1000).toStringAsFixed(1)}${l.liters}',
            proteinLabel: '${protein}g',
            tasksLabel: '$tasksDone/${tasks.length}',
          ),
          const Gap(16),

          // ------------- exam mode, deload warning, morning check-in --------
          const ExamModeBanner(),
          const DeloadBanner(),
          if (!c.checkin.isEmpty) ...[
            const CheckInCard(),
            const Gap(16),
          ],

          // ---------------- today's workout ----------------
          if (today != null) ...[
            _TodayWorkoutCard(day: today, onOpen: onOpenWorkout),
            const Gap(16),
          ],

          // ---------------- water slots ----------------
          SectionCard(
            emoji: '💧',
            title: l.schedule,
            accent: C.cyan,
            trailing: TextButton(
              onPressed: () => HomeShell.goTo(context, 1),
              child: Text(l.water),
            ),
            children: [
              for (final s in c.water.slots)
                _SlotRow(slot: s),
            ],
          ),
          const Gap(16),

          // ---------------- meals ----------------
          SectionCard(
            emoji: '🍽️',
            title: l.meals,
            accent: C.orange,
            subtitle: '${protein}g / ${c.food.proteinTarget}g ${l.protein}',
            trailing: TextButton(
              onPressed: () => HomeShell.goTo(context, 2),
              child: Text(l.food),
            ),
            children: [
              BarProgress(
                value: proteinPct,
                color: proteinPct >= 1 ? C.green : C.orange,
                height: 8,
              ),
              const Gap(12),
              for (final m in c.food.meals) _MealRow(meal: m),
            ],
          ),
          const Gap(16),

          // ---------------- routine ----------------
          SectionCard(
            emoji: '⏰',
            title: l.dailyRoutine,
            accent: C.amber,
            subtitle: '${tasksDone}/${tasks.length} ${l.tasksDone}',
            children: [
              BarProgress(
                value: tasks.isEmpty ? 0 : tasksDone / tasks.length,
                color: tasksDone == tasks.length && tasks.isNotEmpty ? C.green : C.amber,
                height: 8,
              ),
              const Gap(8),
              for (final r in tasks) _RoutineRow(item: r),
            ],
          ),
          const Gap(16),

          // ---------------- growth sleep + monthly photo ----------------
          const SleepCard(),
          const Gap(16),
          const QuoteCard(),
          const Gap(16),
          if (!c.progress.photoCheckpoint.isEmpty) ...[
            const PhotoCheckpointCard(),
            const Gap(16),
          ],

          if (tasksDone == tasks.length && tasks.isNotEmpty && waterPct >= 1 && proteinPct >= 1)
            InfoBanner(l.nothingLeft, color: C.green, icon: Icons.emoji_events_rounded)
          else
            InfoBanner(l.keepGoing, color: C.cyan, icon: Icons.bolt_rounded),
          const Gap(10),
          Text(
            c.meta.tagline.t(st.isArabic),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Hero of the Today tab: one big 0..100 score plus the three pillar rings.
///
/// The score is the single number a 16-year-old glances at between classes;
/// the rings keep the detail for when he wants it.
class _ScoreHero extends StatelessWidget {
  const _ScoreHero({
    required this.score,
    required this.waterPct,
    required this.proteinPct,
    required this.tasksPct,
    required this.waterLabel,
    required this.proteinLabel,
    required this.tasksLabel,
  });

  final int score;
  final double waterPct;
  final double proteinPct;
  final double tasksPct;
  final String waterLabel;
  final String proteinLabel;
  final String tasksLabel;

  Color get _accent {
    if (score >= 80) return C.green;
    if (score >= 50) return C.cyan;
    if (score >= 25) return C.amber;
    return C.orange;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            _accent.withValues(alpha: 0.20),
            C.violet.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // The big score.
          RingProgress(
            value: score / 100,
            color: _accent,
            size: 108,
            stroke: 11,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$score',
                    style: t.textTheme.headlineSmall
                        ?.copyWith(fontSize: 34, color: _accent)),
                Text(l.scoreTitle, style: t.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                _PillarRow(
                  emoji: '✅',
                  label: l.tasksDone,
                  value: tasksLabel,
                  pct: tasksPct,
                  color: C.green,
                ),
                const SizedBox(height: 11),
                _PillarRow(
                  emoji: '💧',
                  label: l.water,
                  value: waterLabel,
                  pct: waterPct,
                  color: C.cyan,
                ),
                const SizedBox(height: 11),
                _PillarRow(
                  emoji: '🍗',
                  label: l.protein,
                  value: proteinLabel,
                  pct: proteinPct,
                  color: C.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
  });

  final String emoji;
  final String label;
  final String value;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: t.textTheme.labelMedium),
                  Text(value,
                      style: t.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: color)),
                ],
              ),
              const SizedBox(height: 4),
              BarProgress(value: pct, color: color, height: 6),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rotating message of the day. One deterministic quote per date; tapping
/// cycles to the next one so re-reading the card never gets stale.
class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final cfg = st.content.motivation;
    if (cfg.isEmpty) return const SizedBox.shrink();

    final quote = cfg.quoteFor(DateTime.now(), offset: _offset);
    if (quote.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      emoji: '💬',
      title: cfg.title.isEmpty ? l.quoteTitle : st.t(cfg.title),
      accent: C.violet,
      trailing: const Icon(Icons.touch_app_rounded, size: 17, color: C.violet),
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _offset++);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.t(quote),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 14.5, height: 1.7),
                ),
                const Gap(6),
                Text(
                  '${_offset + 1}/${cfg.quotes.length} · ${l.quoteNext}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot});
  final WaterSlot slot;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final done = st.slotDone(slot.id);
    final all = done >= slot.glasses;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        st.toggleSlot(slot.id, slot.glasses);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            CheckDisc(done: all, color: C.cyan, size: 26),
            const SizedBox(width: 11),
            SizedBox(
              width: 46,
              child: Text(slot.time,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.cyan)),
            ),
            Expanded(
              child: Text(
                slot.title.t(st.isArabic),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: all ? TextDecoration.lineThrough : null,
                      color: all ? Theme.of(context).textTheme.bodySmall?.color : null,
                    ),
              ),
            ),
            Text('${slot.glasses}×', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final done = st.mealDone(meal.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CheckDisc(done: done, color: C.orange, size: 26),
          const SizedBox(width: 11),
          SizedBox(
            width: 46,
            child: Text(meal.time,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.orange)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.title.t(st.isArabic), style: Theme.of(context).textTheme.bodyMedium),
                Text('${meal.proteinG}g ${st.isArabic ? 'بروتين' : 'protein'} · ${meal.kcal} kcal',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.item});
  final RoutineItem item;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final done = st.taskDone(item.id);
    final color = Accents.forCategory(item.category);
    final now = DateTime.now();
    final hh = int.tryParse(item.time.split(':').first) ?? 0;
    final mm = item.time.split(':').length > 1 ? int.tryParse(item.time.split(':')[1]) ?? 0 : 0;
    final isNow = now.hour == hh && (now.minute - mm).abs() <= 45;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        st.toggleTask(item.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isNow && !done ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNow && !done ? color.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckDisc(done: done, color: color, size: 26),
            const SizedBox(width: 11),
            SizedBox(
              width: 46,
              child: Text(item.time,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ),
            const SizedBox(width: 2),
            Text(item.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.t(st.isArabic),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  if (!item.detail.isEmpty)
                    Text(item.detail.t(st.isArabic), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.day, this.onOpen});
  final WorkoutDay day;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final done = st.setsDone(day.id);
    final total = day.totalSets;
    final pct = total == 0 ? (day.isRest ? 1.0 : 0.0) : done / total;

    // Exam mode can drop this day; the morning rating can trim it.
    final paused = !st.dayIsActive(day);
    final drop = paused ? 0 : st.setsToDropToday;
    final accent = day.isRest ? C.green : (paused ? C.amber : C.violet);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen ?? () => HomeShell.goTo(context, 3),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [accent.withValues(alpha: 0.20), accent.withValues(alpha: 0.04)],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Text(day.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paused ? l.examDropped : l.todayWorkout,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: paused ? C.amber : null),
                    ),
                    const SizedBox(height: 2),
                    Text(day.focus.t(st.isArabic),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 7),
                    BarProgress(
                      value: pct,
                      color: accent,
                      height: 6,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      day.isRest
                          ? l.restDay
                          : '$done/$total ${l.setsWord}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (drop >= 99) ...[
                      const SizedBox(height: 5),
                      Text(
                        st.isArabic ? '🤒 اليوم راحة كاملة — لا تتدرّب' : '🤒 Full rest today - do not train',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: C.red),
                      ),
                    ] else if (drop > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        st.isArabic
                            ? '🌡️ احذف $drop مجموعة من كل تمرين اليوم'
                            : '🌡️ Drop $drop set from every exercise today',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: C.orange),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Forward chevron for the reading direction (Arabic is RTL).
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
