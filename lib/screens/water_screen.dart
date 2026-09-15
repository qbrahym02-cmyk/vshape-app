import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content.water;
    final total = st.waterTotal();
    final pct = c.goalMl == 0 ? 0.0 : total / c.goalMl;
    final glassesTotal = (total / c.glassMl).floor();
    final reached = total >= c.goalMl;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(
            title: '💧 ${l.water}',
            subtitle: st.isArabic
                ? 'الهدف ${c.minMl}–${c.maxMl} مل يوميًا لوزن ٨٠ كغ + تمرين'
                : 'Goal ${c.minMl}-${c.maxMl} ml per day at 80 kg + training',
          ),

          // ---------------- big ring ----------------
          Center(
            child: RingProgress(
              value: pct,
              color: reached ? C.green : C.cyan,
              size: 210,
              stroke: 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (total / 1000).toStringAsFixed(2),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 40,
                          color: reached ? C.green : C.cyan,
                        ),
                  ),
                  Text('${l.liters} / ${(c.goalMl / 1000).toStringAsFixed(2)} ${l.liters}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Pill(
                    '$glassesTotal / ${(c.goalMl / c.glassMl).ceil()} ${l.glasses}',
                    color: reached ? C.green : C.cyan,
                    icon: Icons.local_drink_rounded,
                  ),
                ],
              ),
            ),
          ),
          const Gap(18),

          // ---------------- quick add ----------------
          SectionCard(
            emoji: '⚡',
            title: l.quickAdd,
            accent: C.cyan,
            children: [
              Row(
                children: [
                  for (final ml in [250, c.glassMl, 750, 1000])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            st.addWater(ml);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: C.cyan,
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
                            side: BorderSide(color: C.cyan.withValues(alpha: 0.35)),
                          ),
                          child: Text(ml >= 1000 ? '1 ${l.liters}' : '$ml',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ),
                ],
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => st.addWater(-250),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      label: const Text('250-'),
                      style: OutlinedButton.styleFrom(foregroundColor: C.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await _confirm(context,
                            st.isArabic ? 'تصفير عداد ماء اليوم؟' : 'Reset today\'s water counter?');
                        if (ok == true) {
                          for (final s in c.slots) {
                            await st.setSlot(s.id, 0);
                          }
                          await st.addWater(-total);
                        }
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(l.reset),
                      style: OutlinedButton.styleFrom(foregroundColor: C.amber),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),

          // ---------------- schedule ----------------
          SectionCard(
            emoji: '🗓️',
            title: l.schedule,
            accent: C.blue,
            subtitle: st.isArabic
                ? 'كل خانة = ${c.glassMl} مل. اضغط + لتشرب، و− لو شربت أقل.'
                : 'Each step = ${c.glassMl} ml. Tap + as you drink, - if you drank less.',
            children: [
              for (final s in c.slots) _WaterSlotCard(slotId: s.id),
            ],
          ),
          const Gap(16),

          InfoBanner(c.note.t(st.isArabic), color: C.cyan, icon: Icons.water_drop_rounded),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String msg) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.ok)),
          ],
        ),
      );
}

class _WaterSlotCard extends StatelessWidget {
  const _WaterSlotCard({required this.slotId});
  final String slotId;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final c = st.content.water;
    final slot = c.slots.firstWhere((e) => e.id == slotId);
    final done = st.slotDone(slotId);
    final complete = done >= slot.glasses;
    final t = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: complete ? C.green.withValues(alpha: 0.08) : C.cyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (complete ? C.green : C.cyan).withValues(alpha: complete ? 0.4 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (complete ? C.green : C.cyan).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(slot.time,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: complete ? C.green : C.cyan)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(slot.title.t(st.isArabic),
                    style: t.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
              ),
              if (slot.remind)
                Icon(Icons.notifications_active_outlined,
                    size: 15, color: t.textTheme.bodySmall?.color),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(child: Text(slot.why.t(st.isArabic), style: t.textTheme.bodySmall)),
              const SizedBox(width: 10),
              _StepBtn(
                icon: Icons.remove_rounded,
                color: C.red,
                onTap: done == 0 ? null : () => st.bumpSlot(slotId, slot.glasses, up: false),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$done/${slot.glasses}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              _StepBtn(
                icon: Icons.add_rounded,
                color: C.cyan,
                onTap: () {
                  HapticFeedback.lightImpact();
                  st.bumpSlot(slotId, slot.glasses, up: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: onTap == null ? color.withValues(alpha: 0.06) : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 19, color: color)),
        ),
      );
}
