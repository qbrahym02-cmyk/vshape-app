import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';
import '../widgets/workout_day_view.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final days = st.content.workout.days;
    if (days.isEmpty) {
      return const Scaffold(body: EmptyState('🏋️', 'No workout plan loaded'));
    }
    final selectedId = _selected ??
        (days.firstWhere((d) => d.day == DateTime.now().weekday,
                orElse: () => days.first))
            .id;
    final day = days.firstWhere((d) => d.id == selectedId, orElse: () => days.first);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(
            title: l.training,
            subtitle: st.content.meta.goal.t(st.isArabic),
            trailing: IconButton.filledTonal(
              onPressed: () => _showEquipment(context),
              icon: const Icon(Icons.backpack_outlined),
              tooltip: l.backpackTitle,
            ),
          ),
          DayStrip(
            selectedId: day.id,
            onSelect: (id) => setState(() => _selected = id),
          ),
          const Gap(14),
          Row(
            children: [
              Text(day.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${day.title.t(st.isArabic)} · ${day.focus.t(st.isArabic)}',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (!day.isRest)
                      Text(
                        '${day.exercises.length} ${l.exercises} · ${day.totalSets} ${l.setsWord}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (day.day == DateTime.now().weekday)
                Pill(l.todayLabel, color: C.amber, filled: true),
            ],
          ),
          const Gap(14),
          WorkoutDayView(day: day, showRules: true),
          const Gap(18),
          _RulesCard(),
        ],
      ),
    );
  }

  void _showEquipment(BuildContext context) {
    final st = context.st;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AppScope(
        state: st,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎒 ${st.t(st.content.backpack.title)}',
                  style: Theme.of(context).textTheme.titleLarge),
              const Gap(10),
              InfoBanner(st.t(st.content.workout.equipmentNote),
                  color: C.violet, icon: Icons.fitness_center_rounded),
              const Gap(14),
              Flexible(
                child: SingleChildScrollView(
                  child: StepList(
                    steps: st.tl(st.content.backpack.body),
                    color: C.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    return SectionCard(
      emoji: '🛡️',
      title: l.rules,
      accent: C.red,
      children: [
        for (final r in st.content.rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title.t(st.isArabic),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: r.severity == 'high' ? C.red : C.amber)),
                      const SizedBox(height: 2),
                      Text(r.text.t(st.isArabic), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
