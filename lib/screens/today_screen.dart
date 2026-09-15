import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../screens/home_shell.dart';
import '../widgets/common.dart';
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

    final today = c.workout.dayForWeekday(now.weekday) ??
        (c.workout.days.isNotEmpty ? c.workout.days.first : null);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(
            title: c.meta.name.t(st.isArabic).isEmpty ? 'V-System' : c.meta.name.t(st.isArabic),
            subtitle: '${l.weekday(now.weekday)} · ${l.monthDay(now)}',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pill('${st.streak()} 🔥', color: C.amber),
                const SizedBox(height: 4),
                Text(l.streak, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),

          // ---------------- hero: three rings ----------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  C.violet.withValues(alpha: 0.20),
                  C.cyan.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: C.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniRing(
                  value: tasks.isEmpty ? 0 : tasksDone / tasks.length,
                  color: C.green,
                  emoji: '✅',
                  top: '$tasksDone/${tasks.length}',
                  bottom: l.tasksDone,
                ),
                _MiniRing(
                  value: waterPct,
                  color: C.cyan,
                  emoji: '💧',
                  top: '${(waterTotal / 1000).toStringAsFixed(1)}${l.liters}',
                  bottom: l.water,
                ),
                _MiniRing(
                  value: proteinPct,
                  color: C.orange,
                  emoji: '🍗',
                  top: '${protein}g',
                  bottom: l.protein,
                ),
              ],
            ),
          ),
          const Gap(16),

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

class _MiniRing extends StatelessWidget {
  const _MiniRing({
    required this.value,
    required this.color,
    required this.emoji,
    required this.top,
    required this.bottom,
  });

  final double value;
  final Color color;
  final String emoji;
  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RingProgress(
          value: value,
          color: color,
          size: 86,
          stroke: 9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              Text(top,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(bottom, style: Theme.of(context).textTheme.labelSmall),
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
              colors: day.isRest
                  ? [C.green.withValues(alpha: 0.16), C.green.withValues(alpha: 0.04)]
                  : [C.violet.withValues(alpha: 0.20), C.violet.withValues(alpha: 0.04)],
            ),
            border: Border.all(color: (day.isRest ? C.green : C.violet).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Text(day.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.todayWorkout, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(day.focus.t(st.isArabic),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 7),
                    BarProgress(
                      value: pct,
                      color: day.isRest ? C.green : C.violet,
                      height: 6,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      day.isRest
                          ? l.restDay
                          : '$done/$total ${l.setsWord}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ],
          ),
        ),
      ),
    );
  }
}
