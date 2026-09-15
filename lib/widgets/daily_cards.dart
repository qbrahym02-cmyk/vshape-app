import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/plan_math.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

/// Morning readiness / DOMS rating. One tap, and the app tells you how much to
/// do today - including "drop a set" and "rest completely".
class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key});

  /// Green when ready, red when ill: the colour language of the whole app.
  static Color colorFor(int value) {
    if (value >= 4) return C.green;
    if (value == 3) return C.amber;
    if (value == 2) return C.orange;
    return C.red;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final cfg = st.content.checkin;
    if (cfg.isEmpty) return const SizedBox.shrink();

    final ordered = cfg.ordered;
    final level = st.checkinLevelToday;
    final accent = level == null ? C.violet : colorFor(level.value);

    return SectionCard(
      emoji: '🌡️',
      title: cfg.title.isEmpty ? l.checkinTitle : st.t(cfg.title),
      accent: accent,
      subtitle: level == null ? l.checkinAsk : '${level.emoji} ${st.t(level.label)}',
      children: [
        Row(
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              Expanded(
                child: _LevelButton(
                  level: ordered[i],
                  selected: ordered[i].value == level?.value,
                ),
              ),
              if (i != ordered.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        if (level != null) ...[
          const Gap(12),
          InfoBanner(st.t(level.advice), color: accent, icon: Icons.bolt_rounded),
        ] else if (!cfg.note.isEmpty) ...[
          const Gap(10),
          Text(st.t(cfg.note), style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({required this.level, required this.selected});

  final CheckInLevel level;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final color = CheckInCard.colorFor(level.value);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        st.setCheckin(level.value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.20) : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.25),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(level.emoji, style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 3),
            Text(
              st.t(level.label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.25,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? color : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Last night's bedtime against the 23:00 growth-hormone cutoff.
class SleepCard extends StatelessWidget {
  const SleepCard({super.key});

  /// Quick chips: two on time, one on the dot, and the two classic late ones.
  static const List<String> quickTimes = ['22:15', '22:45', '23:00', '23:30', '00:30'];

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final cfg = st.content.sleep;
    final logged = st.sleepTimeToday;
    final onTime = st.sleepOnTimeToday;
    final accent = logged == null ? C.blue : (onTime ? C.green : C.red);

    return SectionCard(
      emoji: '😴',
      title: cfg.title.isEmpty ? l.sleepTitle : st.t(cfg.title),
      accent: accent,
      subtitle: '${st.sleepStreak()} 🔥 ${l.sleepStreak} · ${l.sleepTarget} ${cfg.target}',
      children: [
        if (logged == null) ...[
          InfoBanner(
            cfg.note.isEmpty ? l.sleepNotLogged : st.t(cfg.note),
            color: C.blue,
            icon: Icons.bedtime_rounded,
          ),
          const Gap(10),
        ] else ...[
          Row(
            children: [
              Text(
                logged,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  onTime
                      ? l.sleepOnTime
                      : l.sleepLate(minutesLate(bedtime: logged, target: cfg.target)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => st.clearSleepTime(),
                child: Text(l.clearEntry),
              ),
            ],
          ),
          const Gap(6),
        ],
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final t in quickTimes)
              ActionChip(
                label: Text(t),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  st.setSleepTime(t);
                },
                side: BorderSide(
                  color: logged == t
                      ? C.green
                      : bedtimeOnTime(bedtime: t, target: cfg.target)
                          ? C.blue.withValues(alpha: 0.4)
                          : C.red.withValues(alpha: 0.35),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.schedule_rounded, size: 15),
              label: Text(st.isArabic ? 'وقت آخر' : 'Other time'),
              onPressed: () => _pickTime(context, st),
            ),
          ],
        ),
        if (!cfg.tip.isEmpty) ...[
          const Gap(10),
          Text(st.t(cfg.tip), style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }

  Future<void> _pickTime(BuildContext context, AppState st) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 0),
      helpText: context.l10n.logBedtime,
      builder: (context, child) => Directionality(
        textDirection: st.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    await st.setSleepTime('$hh:$mm');
  }
}

/// "Two low days in a row" -> suggest a deload instead of pushing through.
class DeloadBanner extends StatelessWidget {
  const DeloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    if (!st.deloadSuggested) return const SizedBox.shrink();
    final note = st.content.checkin.deloadNote;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoBanner(
        note.isEmpty ? l.deloadTitle : '${l.deloadTitle} — ${st.t(note)}',
        color: C.orange,
        icon: Icons.self_improvement_rounded,
      ),
    );
  }
}

/// Compact reminder that exam mode is trimming the week.
class ExamModeBanner extends StatelessWidget {
  const ExamModeBanner({super.key, this.onManage});

  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final cfg = st.content.examMode;
    if (cfg.isEmpty || !st.examModeOn) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: C.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.amber.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Text('🎓', style: TextStyle(fontSize: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${st.t(cfg.title)} · ${l.examSessions(cfg.sessionsPerWeek)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: C.amber),
                ),
                Text(st.t(cfg.subtitle), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          if (onManage != null)
            TextButton(onPressed: onManage, child: Text(st.isArabic ? 'إدارة' : 'Manage')),
        ],
      ),
    );
  }
}

/// The switch plus the exam-week rules; lives in Settings.
class ExamModeCard extends StatelessWidget {
  const ExamModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final cfg = st.content.examMode;
    if (cfg.isEmpty) return const SizedBox.shrink();

    final days = st.content.workout.days;
    final kept = <WorkoutDay>[
      for (final id in cfg.keepDays)
        for (final d in days)
          if (d.id == id) d,
    ];

    return SectionCard(
      emoji: '🎓',
      title: st.t(cfg.title),
      accent: C.amber,
      subtitle: st.t(cfg.subtitle),
      trailing: Switch(
        value: st.examModeOn,
        activeThumbColor: C.amber,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          st.setExamMode(v);
        },
      ),
      children: [
        Text(st.t(cfg.note), style: Theme.of(context).textTheme.bodyMedium),
        const Gap(10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final d in kept)
              Pill('${d.emoji} ${l.weekday(d.day)}', color: C.violet, icon: Icons.fitness_center_rounded),
          ],
        ),
        const Gap(12),
        StepList(steps: st.tl(cfg.rules), color: C.amber),
        const Gap(10),
        Text(
          st.examModeOn ? l.examModeOn : l.examModeOff,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Shown from the 15th until the monthly comparison photo is ticked off.
class PhotoCheckpointCard extends StatelessWidget {
  const PhotoCheckpointCard({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final cp = st.content.progress.photoCheckpoint;
    if (cp.isEmpty) return const SizedBox.shrink();

    final done = st.monthlyDone('photo');
    final due = cp.isDueOn(DateTime.now());
    if (!due && !done) return const SizedBox.shrink();

    return SectionCard(
      emoji: '📸',
      title: st.t(cp.title),
      accent: done ? C.green : C.violet,
      subtitle: '${l.monthDay(DateTime.now())} · ${l.thisMonth}',
      trailing: CheckDisc(
        done: done,
        color: C.green,
        size: 30,
        onTap: () {
          HapticFeedback.mediumImpact();
          st.toggleMonthly('photo');
        },
      ),
      children: [
        InfoBanner(
          done ? l.photoDone : (due ? l.photoDue : st.t(cp.note)),
          color: done ? C.green : C.violet,
          icon: done ? Icons.check_circle_rounded : Icons.photo_camera_rounded,
        ),
        const Gap(10),
        StepList(steps: st.tl(cp.checklist), color: C.violet),
      ],
    );
  }
}
