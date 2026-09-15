import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
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
    if (res != null) {
      await st.appendLog(id, res);
      if (context.mounted) snack(context, st.isArabic ? 'تم الحفظ ✓' : 'Saved ✓', color: color);
    }
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
