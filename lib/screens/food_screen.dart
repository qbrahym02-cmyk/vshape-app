import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content.food;
    final protein = st.proteinEaten();
    final kcal = st.kcalEaten();
    final pPct = c.proteinTarget == 0 ? 0.0 : protein / c.proteinTarget;
    final kPct = c.kcalTarget[1] == 0 ? 0.0 : kcal / c.kcalTarget[1];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(
            title: '🍽️ ${l.food}',
            subtitle: st.isArabic
                ? 'خطة اقتصادية: ${c.kcalTarget[0]}–${c.kcalTarget[1]} سعرة و ${c.proteinTarget} جم بروتين'
                : 'Budget plan: ${c.kcalTarget[0]}-${c.kcalTarget[1]} kcal and ${c.proteinTarget} g protein',
          ),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.proteinToday,
                  value: '$protein',
                  unit: '/ ${c.proteinTarget} g',
                  color: pPct >= 1 ? C.green : C.orange,
                  icon: Icons.egg_alt_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: l.kcalToday,
                  value: '$kcal',
                  unit: '/ ${c.kcalTarget[1]}',
                  color: C.amber,
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
            ],
          ),
          const Gap(14),

          SectionCard(
            accent: C.orange,
            children: [
              Row(
                children: [
                  Text(l.protein, style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  Text('${(pPct * 100).round()}%',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: pPct >= 1 ? C.green : C.orange)),
                ],
              ),
              const Gap(7),
              BarProgress(value: pPct, color: pPct >= 1 ? C.green : C.orange, height: 10),
              const Gap(14),
              Row(
                children: [
                  Text(st.isArabic ? 'سعرات' : 'Calories',
                      style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  Text('${(kPct * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: C.amber)),
                ],
              ),
              const Gap(7),
              BarProgress(value: kPct, color: C.amber, height: 10),
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '🍳',
            title: l.meals,
            accent: C.orange,
            subtitle: st.isArabic
                ? 'علّم كل صنف أكلته — البروتين يتحسب تلقائياً'
                : 'Tick every item you ate - protein is counted for you',
            children: [for (final m in c.meals) _MealCard(meal: m)],
          ),
          const Gap(16),

          SectionCard(
            emoji: '🏆',
            title: l.cheapProtein,
            accent: C.green,
            children: [for (final s in c.sources) _SourceRow(src: s)],
          ),
          const Gap(16),

          InfoBanner(c.budgetRule.t(st.isArabic), color: C.amber, icon: Icons.savings_rounded),
          const Gap(16),

          SectionCard(
            emoji: '🚫',
            title: l.avoidList,
            accent: C.red,
            children: [
              for (final s in c.avoid.t(st.isArabic))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block_rounded, size: 17, color: C.red),
                      const SizedBox(width: 9),
                      Expanded(child: Text(s, style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatefulWidget {
  const _MealCard({required this.meal});
  final Meal meal;

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final m = widget.meal;
    final t = Theme.of(context);
    final doneCount = List.generate(m.items.length, (i) => st.mealItemDone(m.id, i))
        .where((e) => e)
        .length;
    final complete = m.items.isNotEmpty && doneCount == m.items.length;
    final proteinNow =
        m.items.isEmpty ? 0 : (m.proteinG * doneCount / m.items.length).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: complete ? C.green.withValues(alpha: 0.07) : C.orange.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (complete ? C.green : C.orange).withValues(alpha: complete ? 0.35 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CheckDisc(
                done: complete,
                color: C.green,
                size: 30,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  for (var i = 0; i < m.items.length; i++) {
                    if (st.mealItemDone(m.id, i) != !complete) st.toggleMealItem(m.id, i);
                  }
                },
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title.t(st.isArabic),
                        style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
                    if (!m.subtitle.isEmpty)
                      Text(m.subtitle.t(st.isArabic), style: t.textTheme.labelSmall),
                  ],
                ),
              ),
              if (m.time.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.orange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(m.time,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.orange)),
                ),
              IconButton(
                onPressed: () => setState(() => _open = !_open),
                icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            children: [
              Pill('$proteinNow/${m.proteinG} g', color: complete ? C.green : C.orange, icon: Icons.egg_alt_outlined),
              Pill('${m.kcal} kcal', color: C.amber, icon: Icons.local_fire_department_outlined),
              Pill('$doneCount/${m.items.length}', color: C.blue, icon: Icons.checklist_rounded),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: AlignmentDirectional.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < m.items.length; i++)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              st.toggleMealItem(m.id, i);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckDisc(
                                    done: st.mealItemDone(m.id, i),
                                    color: C.orange,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      m.items[i].name.t(st.isArabic),
                                      style: t.textTheme.bodyMedium?.copyWith(
                                        decoration: st.mealItemDone(m.id, i)
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: st.mealItemDone(m.id, i)
                                            ? t.textTheme.bodySmall?.color
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!m.tip.isEmpty) ...[
                          const Gap(8),
                          InfoBanner(m.tip.t(st.isArabic), color: C.amber, icon: Icons.lightbulb_outline_rounded),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.src});
  final ProteinSource src;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.green.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Text('${src.rank}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.green)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(src.name.t(st.isArabic),
                          style: t.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    ),
                    Text(src.protein.t(st.isArabic),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.green)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(src.note.t(st.isArabic), style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
