import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/plan_math.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content.progress;

    return Scaffold(
      appBar: AppBar(title: Text('📊 ${l.progress}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          InfoBanner(c.title.t(st.isArabic), color: C.green, icon: Icons.insights_rounded),
          const Gap(16),

          for (final k in c.kpis) ...[
            _KpiCard(kpi: k),
            const Gap(10),
          ],

          const Gap(10),
          SectionCard(
            emoji: '🏋️',
            title: c.strengthTitle.t(st.isArabic),
            accent: C.violet,
            subtitle: st.isArabic
                ? 'سجّل أقصى تكرارات كل أسبوع — هذا دليلك الحقيقي على البناء العضلي'
                : 'Log your max reps weekly - this is your real proof of muscle growth',
            children: [
              for (final e in c.strengthExercises) ...[
                _LogRow(
                  id: K.strength(e.id),
                  name: e.name.t(st.isArabic),
                  color: C.violet,
                  unit: st.isArabic ? 'تكرار' : 'reps',
                ),
                const Gap(6),
              ],
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '📏',
            title: l.measurements,
            accent: C.cyan,
            subtitle: st.isArabic
                ? 'اختياري: سجّلها مرة كل أسبوعين بنفس الظروف (صباحاً، قبل الأكل)'
                : 'Optional: log every two weeks under the same conditions (morning, fasted)',
            children: [
              for (final e in c.measurements) ...[
                _LogRow(
                  id: K.measure(e.id),
                  name: e.name.t(st.isArabic),
                  color: C.cyan,
                  unit: e.id == 'weight' ? 'kg' : 'cm',
                ),
                const Gap(6),
              ],
            ],
          ),
          const Gap(16),

          const _MonthlyCard(),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    return SectionCard(
      emoji: kpi.emoji,
      title: kpi.title.t(st.isArabic),
      accent: C.green,
      dense: true,
      children: [
        Text(kpi.detail.t(st.isArabic), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.id, required this.name, required this.color, required this.unit});

  final String id;
  final String name;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final log = st.logFor(id);
    final values = <double>[
      for (final e in log)
        if (e['v'] is num) (e['v'] as num).toDouble()
    ];
    final last = st.lastLogValue(id);
    final first = values.isEmpty ? null : values.first;
    final delta = (last != null && first != null) ? last - first : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: Theme.of(context).textTheme.titleSmall)),
              if (delta != null && delta != 0)
                Pill(
                  '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 1)}',
                  color: delta > 0 ? C.green : C.red,
                  icon: delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                ),
              const SizedBox(width: 6),
              Text(
                last == null ? '—' : '${last.toStringAsFixed(last.truncateToDouble() == last ? 0 : 1)} $unit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
              ),
            ],
          ),
          if (values.length >= 2) ...[
            const Gap(8),
            SparkLine(values: values, color: color, height: 46),
          ],
          const Gap(8),
          Row(
            children: [
              Text(
                log.isEmpty
                    ? (st.isArabic ? 'لا يوجد سجل بعد' : 'No entries yet')
                    : '${log.length} ${st.isArabic ? 'سجل' : 'entries'} · ${log.last['d']}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              if (log.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showHistory(context, st),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(st.isArabic ? 'السجل' : 'History'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              TextButton.icon(
                onPressed: () => _add(context, st),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.addEntry),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, AppState st) async {
    final ctrl = TextEditingController();
    final res = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name, style: const TextStyle(fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(hintText: context.l10n.value, suffixText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              final v = num.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (res == null) return;
    // Read the history first: appendLog replaces an entry from the same day.
    final before = <num>[
      for (final e in st.logFor(id))
        if (e['v'] is num) e['v'] as num
    ];
    await st.appendLog(id, res);
    if (!context.mounted) return;
    if (beatsBest(before, res)) {
      _celebrate(context, res);
    } else {
      snack(context, st.isArabic ? 'تم الحفظ ✓' : 'Saved ✓', color: color);
    }
  }

  /// A personal record is the one piece of proof that needs no scale and no
  /// tape measure, so it gets a proper moment instead of a quiet snackbar.
  void _celebrate(BuildContext context, num value) {
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Text('🏆', style: TextStyle(fontSize: 40)),
        title: Text(l.newRecord, textAlign: TextAlign.center),
        content: Text(
          l.newRecordBody(compact(value), unit),
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: Colors.black),
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, AppState st) {
    final log = st.logFor(id).reversed.toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => AppScope(
        state: st,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const Gap(12),
              for (final e in log)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${e['d']}', style: const TextStyle(fontSize: 12)),
                  title: Text('${e['v']} $unit',
                      style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: C.red),
                    onPressed: () {
                      st.removeLogEntry(id, '${e['d']}');
                      Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The once-a-month checks: comparison photo, clothes test, measurements and
/// the max-rep test. Ticks are stored per `yyyy-MM`, so every month starts clean
/// and last month's evidence stays on the record.
class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard();

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final checks = st.content.progress.monthlyChecks;
    if (checks.isEmpty) return const SizedBox.shrink();

    final cp = st.content.progress.photoCheckpoint;
    final done = checks.where((m) => st.monthlyDone(m.id)).length;

    return SectionCard(
      emoji: '🗓️',
      title: l.monthlyChecks,
      accent: C.violet,
      subtitle: '$done/${checks.length} · ${l.thisMonth} (${st.monthKey})',
      children: [
        BarProgress(
          value: checks.isEmpty ? 0 : done / checks.length,
          color: done == checks.length ? C.green : C.violet,
          height: 7,
        ),
        const Gap(10),
        for (final m in checks) _MonthlyRow(check: m),
        if (!cp.isEmpty) ...[
          const Gap(12),
          InfoBanner(st.t(cp.note), color: C.violet, icon: Icons.photo_camera_rounded),
        ],
      ],
    );
  }
}

class _MonthlyRow extends StatelessWidget {
  const _MonthlyRow({required this.check});

  final MonthlyCheck check;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final done = st.monthlyDone(check.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        st.toggleMonthly(check.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CheckDisc(done: done, color: C.violet, size: 26),
            const SizedBox(width: 11),
            Text(check.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                st.t(check.title),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Theme.of(context).textTheme.bodySmall?.color : null,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
