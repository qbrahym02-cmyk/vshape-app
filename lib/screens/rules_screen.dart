import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content;

    return Scaffold(
      appBar: AppBar(title: Text('🛡️ ${l.rules}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          SectionCard(
            emoji: '🚨',
            title: st.isArabic ? 'تحذيرات صارمة (لأنك في الـ١٥)' : 'Hard warnings (because you are 15)',
            accent: C.red,
            children: [
              for (final r in c.rules) ...[
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: (r.severity == 'high' ? C.red : C.amber).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (r.severity == 'high' ? C.red : C.amber).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(r.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              r.title.t(st.isArabic),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: r.severity == 'high' ? C.red : C.amber,
                                  ),
                            ),
                          ),
                          if (r.severity == 'high')
                            Pill(st.isArabic ? 'حرج' : 'critical', color: C.red, filled: true),
                        ],
                      ),
                      const Gap(8),
                      Text(r.text.t(st.isArabic), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Gap(10),
              ],
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '🧠',
            title: l.philosophy,
            accent: C.violet,
            children: [
              for (final p in c.philosophy) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 19)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title.t(st.isArabic), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 3),
                          Text(p.text.t(st.isArabic), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(14),
              ],
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '🎒',
            title: st.t(c.backpack.title),
            accent: C.amber,
            children: [StepList(steps: st.tl(c.backpack.body), color: C.amber)],
          ),
          const Gap(16),

          SectionCard(
            emoji: '⏱️',
            title: st.isArabic ? 'قواعد التنفيذ' : 'Execution rules',
            accent: C.blue,
            children: [
              Text(c.workout.tempoRule.t(st.isArabic), style: Theme.of(context).textTheme.bodyMedium),
              const Gap(8),
              Text(c.workout.restRule.t(st.isArabic), style: Theme.of(context).textTheme.bodyMedium),
              const Gap(8),
              Text(c.workout.equipmentNote.t(st.isArabic),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
