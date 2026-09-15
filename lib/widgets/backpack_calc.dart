import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/plan_math.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

/// Opens the sand-and-bottles loading calculator.
Future<void> showBackpackCalc(BuildContext context) async {
  final st = AppScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AppScope(state: st, child: const BackpackCalcSheet()),
  );
}

/// How heavy is the bag, and is it inside the safe window for this bodyweight?
///
/// Sand is ~1.6 kg per litre against water's 1.0, which is why the plan says
/// "fill with sand, top up with water": the same bottle carries 60% more load.
class BackpackCalcSheet extends StatefulWidget {
  const BackpackCalcSheet({super.key});

  @override
  State<BackpackCalcSheet> createState() => _BackpackCalcSheetState();
}

class _BackpackCalcSheetState extends State<BackpackCalcSheet> {
  int _bottles = 3;
  double _sand = 0.5;

  static const int _maxBottles = 8;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);
    final cfg = st.content.backpackLoad;
    if (cfg.isEmpty) return const SizedBox.shrink();

    final kg = st.backpackLoadKg(bottles: _bottles, sandFraction: _sand);
    final perBottle = _bottles == 0 ? 0.0 : (kg - cfg.bagKg) / _bottles;
    final range = st.safeLoadKg;
    final verdict = loadVerdict(kg: kg, bodyKg: st.bodyKg, bodyPct: cfg.bodyPct);
    final color = switch (verdict) {
      LoadVerdict.light => C.cyan,
      LoadVerdict.good => C.green,
      LoadVerdict.heavy => C.red,
    };
    final verdictText = switch (verdict) {
      LoadVerdict.light => l.loadLight,
      LoadVerdict.good => l.loadGood,
      LoadVerdict.heavy => l.loadHeavy,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎒', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(st.t(cfg.title), style: t.textTheme.titleLarge)),
                ],
              ),
              const Gap(10),
              InfoBanner(st.t(cfg.note), color: C.amber, icon: Icons.science_outlined),
              const Gap(16),

              // ---- bottles ----
              Row(
                children: [
                  Expanded(child: Text(l.bottles, style: t.textTheme.titleSmall)),
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onTap: _bottles <= 1
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() => _bottles--);
                          },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('$_bottles',
                        style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onTap: _bottles >= _maxBottles
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() => _bottles++);
                          },
                  ),
                ],
              ),
              const Gap(6),
              Text(
                st.isArabic
                    ? '${compact(cfg.bottleMl / 1000.0)} لتر لكل قارورة · الحقيبة نفسها ${compact(cfg.bagKg)} كجم'
                    : '${compact(cfg.bottleMl / 1000.0)} L per bottle · the bag itself is ${compact(cfg.bagKg)} kg',
                style: t.textTheme.labelSmall,
              ),
              const Gap(16),

              // ---- fill ----
              Text(l.fill, style: t.textTheme.titleSmall),
              const Gap(8),
              SegmentedButton<double>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l.fillWater)),
                  ButtonSegment(value: 0.5, label: Text(l.fillHalf)),
                  ButtonSegment(value: 1, label: Text(l.fillSand)),
                ],
                selected: {_sand},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _sand = s.first),
              ),
              const Gap(18),

              // ---- result ----
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.totalLoad, style: t.textTheme.labelSmall),
                              Text(
                                '${compact(kg)} kg',
                                style: t.textTheme.displaySmall?.copyWith(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pill(verdictText, color: color, filled: true),
                      ],
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.safeRange}: ${compact(range.min)}–${compact(range.max)} kg',
                            style: t.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          st.isArabic
                              ? '${compact(perBottle)} كجم/قارورة'
                              : '${compact(perBottle)} kg per bottle',
                          style: t.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const Gap(8),
                    BarProgress(
                      value: range.max <= 0 ? 0 : share(kg, range.max * 1.4),
                      color: color,
                      height: 8,
                    ),
                  ],
                ),
              ),
              const Gap(16),
              StepList(steps: st.tl(cfg.steps), color: C.amber),
              const Gap(12),
              InfoBanner(st.t(cfg.warning), color: C.red, icon: Icons.warning_amber_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: C.violet.withValues(alpha: enabled ? 0.16 : 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: enabled ? C.violet : C.border, size: 22),
        ),
      ),
    );
  }
}
