import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

/// Shows a safety briefing the first time a risky exercise is opened.
///
/// Returns true when the gate is satisfied - either acknowledged just now or
/// on an earlier day. The acknowledgement is stored once per gate id, so the
/// table only has to be secured in the user's head a single time.
Future<bool> ensureSafetyGate(BuildContext context, SafetyGate? gate) async {
  if (gate == null) return true;
  final st = AppScope.of(context);
  if (st.gateAcked(gate.id)) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AppScope(state: st, child: SafetyGateSheet(gate: gate)),
  );
  return ok == true;
}

class SafetyGateSheet extends StatefulWidget {
  const SafetyGateSheet({super.key, required this.gate});

  final SafetyGate gate;

  @override
  State<SafetyGateSheet> createState() => _SafetyGateSheetState();
}

class _SafetyGateSheetState extends State<SafetyGateSheet> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final g = widget.gate;
    final t = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(g.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${st.t(g.title)} · ${l.safetyBriefing}',
                      style: t.textTheme.titleLarge),
                ),
              ],
            ),
            const Gap(10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoBanner(st.t(g.why), color: C.red, icon: Icons.warning_amber_rounded),
                    const Gap(14),
                    StepList(steps: st.tl(g.checklist), color: C.amber),
                    const Gap(14),
                    InfoBanner(st.t(g.danger), color: C.orange, icon: Icons.report_gmailerrorred_rounded),
                    const Gap(14),
                    CheckboxListTile(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: C.green,
                      title: Text(st.t(g.confirm), style: t.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.close),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: !_confirmed
                        ? null
                        : () async {
                            await st.ackGate(g.id);
                            if (context.mounted) Navigator.pop(context, true);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: C.green.withValues(alpha: 0.25),
                    ),
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: Text(l.safetyDone),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small card on the training screen: green once the briefing is done, red
/// until it is - with a button to open (or re-read) it.
class SafetyGateCard extends StatelessWidget {
  const SafetyGateCard({super.key, required this.gate});

  final SafetyGate gate;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final acked = st.gateAcked(gate.id);
    final color = acked ? C.green : C.red;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => AppScope(state: st, child: SafetyGateSheet(gate: gate)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(gate.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(st.t(gate.title),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
                    Text(
                      acked ? l.safetyDone : l.safetyAcked,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(
                acked ? Icons.verified_user_rounded : Icons.error_outline_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
