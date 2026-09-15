import 'package:flutter/material.dart';

import '../core/plan_math.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

/// The weekly adherence report: one honest percentage, its five columns, and
/// the single weakest one to fix next week.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);
    final cfg = st.content.report;
    final r = st.weeklyReport();

    final praiseLines = st.tl(cfg.praise);
    final praise = (praiseLines.isNotEmpty && r.praise < praiseLines.length)
        ? praiseLines[r.praise]
        : l.reportHint;

    final scoreColor = r.score >= 0.9
        ? C.green
        : r.score >= 0.7
            ? C.cyan
            : r.score >= 0.5
                ? C.amber
                : C.red;

    return Scaffold(
      appBar: AppBar(title: Text('📅 ${l.weeklyReport}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          if (!r.hasAnyData) ...[
            const EmptyState('📅', ''),
            InfoBanner(l.reportNoData, color: C.cyan, icon: Icons.info_outline_rounded),
            const Gap(20),
          ],

          // ------------------------------------------------- score hero ----
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  scoreColor.withValues(alpha: 0.18),
                  C.violet.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: C.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                RingProgress(
                  value: r.score,
                  color: scoreColor,
                  size: 104,
                  stroke: 11,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${r.scorePct}%',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor)),
                      Text(l.adherence, style: t.textTheme.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cfg.title.isEmpty ? l.weeklyReport : st.t(cfg.title),
                          style: t.textTheme.titleMedium),
                      const Gap(6),
                      Text(praise, style: t.textTheme.bodySmall?.copyWith(height: 1.6)),
                      const Gap(10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          Pill('${r.sessionsDone}/${r.sessionsTarget}',
                              color: C.violet, icon: Icons.fitness_center_rounded),
                          if (r.records > 0)
                            Pill('${r.records}', color: C.amber, icon: Icons.emoji_events_rounded),
                          if (r.sleepLogged > 0)
                            Pill('${r.sleepOnTime}/${r.days}',
                                color: C.blue, icon: Icons.bedtime_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // ---------------------------------------------------- columns ----
          SectionCard(
            emoji: '📊',
            title: l.adherence,
            accent: C.cyan,
            subtitle: cfg.note.isEmpty ? l.reportHint : st.t(cfg.note),
            children: [
              for (final row in r.rows) ...[
                _RowTile(row: row),
                const Gap(14),
              ],
            ],
          ),
          const Gap(16),

          // ------------------------------------------------- next week -----
          if (r.weakest != null && r.hasAnyData)
            InfoBanner(
              '${l.weakestRow}: ${l.reportRow(r.weakest!.id)} '
              '(${(r.weakest!.value * 100).round()}%)',
              color: C.orange,
              icon: Icons.flag_rounded,
            ),
          const Gap(16),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.sessionsDone,
                  value: '${r.sessionsDone}',
                  unit: '/ ${r.sessionsTarget}',
                  color: C.violet,
                  icon: Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: l.recordsSet,
                  value: '${r.records}',
                  color: C.amber,
                  icon: Icons.emoji_events_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: l.sleepStreak,
                  value: '${st.sleepStreak()}',
                  color: C.blue,
                  icon: Icons.bedtime_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final WeekRow row;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);

    final pct = (row.value * 100).round();
    final prev = (row.previous * 100).round();
    final delta = pct - prev;
    final hasHistory = row.previous > 0 || prev > 0;

    final color = row.target <= 0
        ? C.cyan
        : row.met
            ? C.green
            : row.value >= row.target * 0.6
                ? C.amber
                : C.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l.reportRow(row.id), style: t.textTheme.titleSmall)),
            if (hasHistory)
              Pill(
                '${delta >= 0 ? '+' : ''}$delta%',
                color: delta > 0 ? C.green : (delta < 0 ? C.red : C.border),
                icon: delta > 0
                    ? Icons.trending_up_rounded
                    : delta < 0
                        ? Icons.trending_down_rounded
                        : Icons.remove_rounded,
              ),
            const SizedBox(width: 8),
            Text('$pct%',
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const Gap(7),
        BarProgress(value: row.value, color: color, height: 8),
        const Gap(5),
        Row(
          children: [
            Expanded(
              child: Text(
                hasHistory ? '${l.lastWeek}: $prev%' : (st.isArabic ? 'لا سجل سابق' : 'no history yet'),
                style: t.textTheme.labelSmall,
              ),
            ),
            if (row.target > 0)
              Text('${l.target}: ${(row.target * 100).round()}%', style: t.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
