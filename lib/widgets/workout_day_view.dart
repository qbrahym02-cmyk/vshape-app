import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/exercise_art.dart';
import '../widgets/rest_timer.dart';
import '../widgets/scope.dart';

/// Reusable body of a training day: exercise cards with tappable set boxes.
class WorkoutDayView extends StatelessWidget {
  const WorkoutDayView({super.key, required this.day, this.showRules = true});

  final WorkoutDay day;
  final bool showRules;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content.workout;

    if (day.isRest) {
      return Column(
        children: [
          SectionCard(
            emoji: day.emoji,
            title: st.t(day.title),
            subtitle: st.t(day.focus),
            accent: C.green,
            children: [
              InfoBanner(
                st.isArabic
                    ? 'يوم راحة — العضلات تكبر هنا، لا في يوم التمرين.'
                    : 'Rest day - your muscles grow here, not on training days.',
                color: C.green,
                icon: Icons.self_improvement_rounded,
              ),
              const Gap(12),
              for (final s in st.tl(day.restPlan))
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 18, color: C.green),
                      const SizedBox(width: 9),
                      Expanded(child: Text(s, style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    }

    final doneSets = st.setsDone(day.id);
    final totalSets = day.totalSets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRules) ...[
          SectionCard(
            accent: C.violet,
            emoji: '⏱️',
            title: l.tempo,
            children: [
              Text(st.t(c.tempoRule), style: Theme.of(context).textTheme.bodyMedium),
              const Gap(8),
              Text(st.t(c.restRule),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: C.amber)),
            ],
          ),
          const Gap(12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                '${l.exercises} · $doneSets/$totalSets ${l.setsWord}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Pill(
              '${(totalSets == 0 ? 0 : doneSets / totalSets * 100).round()}%',
              color: doneSets >= totalSets && totalSets > 0 ? C.green : C.violet,
              icon: Icons.fitness_center_rounded,
            ),
          ],
        ),
        const Gap(10),
        for (final ex in day.exercises) ...[
          ExerciseCard(exercise: ex),
          const Gap(12),
        ],
        Gap(totalSets > 0 ? 4 : 0),
        if (totalSets > 0)
          FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              st.toggleDayDone(day.id);
              snack(
                context,
                st.dayDoneToday(day.id)
                    ? (st.isArabic ? 'تم تسجيل إنجاز اليوم 💪' : 'Session marked complete 💪')
                    : (st.isArabic ? 'ألغيت علامة الإنجاز' : 'Completion unmarked'),
                color: C.violet,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: st.dayDoneToday(day.id) ? C.green : C.violet,
              foregroundColor: Colors.white,
            ),
            icon: Icon(st.dayDoneToday(day.id) ? Icons.verified_rounded : Icons.flag_rounded),
            label: Text(st.dayDoneToday(day.id) ? (st.isArabic ? 'أنهيت التمرين ✓' : 'Completed ✓') : l.markDayDone),
          ),
      ],
    );
  }
}

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final ex = widget.exercise;
    final t = Theme.of(context);

    final doneCount = List.generate(ex.sets, (i) => st.setDoneToday(ex.id, i))
        .where((e) => e)
        .length;
    final complete = doneCount >= ex.sets && ex.sets > 0;

    return SectionCard(
      padding: EdgeInsets.fromLTRB(16, 14, 16, _open ? 16 : 14),
      accent: complete ? C.green : C.violet,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExerciseArt(
              exerciseId: ex.id,
              size: 58,
              color: complete ? C.green : C.violet,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name.t(st.isArabic),
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(ex.target.t(st.isArabic), style: t.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 6),
            CheckDisc(
              done: complete,
              color: C.green,
              size: 30,
              onTap: () {
                // toggle every set at once
                final target = !complete;
                for (var i = 0; i < ex.sets; i++) {
                  if (st.setDoneToday(ex.id, i) != target) st.toggleSet(ex.id, i);
                }
                HapticFeedback.mediumImpact();
              },
            ),
          ],
        ),
        const Gap(12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pill('${ex.sets} × ${ex.reps.t(st.isArabic)}', color: C.violet, icon: Icons.repeat_rounded),
            // tap it -> the 90 s rest countdown starts (see widgets/rest_timer.dart)
            RestPill(seconds: ex.restS, label: ex.name.t(st.isArabic)),
            Pill('${l.tempo}: ${ex.tempo}', color: C.amber, icon: Icons.speed_rounded),
          ],
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < ex.sets; i++)
                    SetBox(
                      index: i + 1,
                      done: st.setDoneToday(ex.id, i),
                      color: C.violet,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        st.toggleSet(ex.id, i);
                      },
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20),
              label: Text(_open ? l.close : l.howTo),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          alignment: AlignmentDirectional.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: C.violet.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.violet.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExerciseArt(
                              exerciseId: ex.id,
                              size: 92,
                              color: C.violet,
                              showFrame: false,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: StepList(steps: st.tl(ex.steps), color: C.violet)),
                          ],
                        ),
                      ),
                      if (!ex.note.isEmpty) ...[
                        const Gap(10),
                        InfoBanner(ex.note.t(st.isArabic), color: C.amber, icon: Icons.lightbulb_outline_rounded),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Horizontal 7-day selector.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final days = st.content.workout.days;
    final todayWeekday = DateTime.now().weekday;

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final sel = d.id == selectedId;
          final isToday = d.day == todayWeekday;
          final done = st.dayDoneToday(d.id);
          return GestureDetector(
            onTap: () => onSelect(d.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 66,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: sel ? C.violet.withValues(alpha: 0.16) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sel ? C.violet : (isToday ? C.amber.withValues(alpha: 0.6) : Theme.of(context).dividerColor),
                  width: sel ? 1.8 : 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 17)),
                  const SizedBox(height: 3),
                  Text(
                    l.weekdayShort(d.day),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: sel ? C.violet : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? C.green : (isToday ? C.amber : Colors.transparent),
                      border: Border.all(
                        color: done || isToday ? Colors.transparent : Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
