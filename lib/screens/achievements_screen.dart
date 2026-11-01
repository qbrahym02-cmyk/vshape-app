import 'package:flutter/material.dart';

import '../core/achievements.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

/// Trophy wall: every badge with its live progress, unlocked or locked.
///
/// The counters are re-derived on every visit (nothing is stored), so a badge
/// unlocked today can never refuse to show tomorrow - and a wipe-all-data
/// resets the wall with everything else.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;

    final badges = evaluateAchievements(st.achievementCounts());
    final unlocked = badges.where((b) => b.unlocked).length;

    return Scaffold(
      appBar: AppBar(title: Text('🏅 ${l.achievements}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          _SummaryCard(unlocked: unlocked, total: badges.length),
          const Gap(16),
          for (final b in badges) ...[
            _BadgeCard(badge: b),
            const Gap(10),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final pct = total == 0 ? 0.0 : unlocked / total;
    final accent = pct >= 1 ? C.green : C.violet;

    return SectionCard(
      emoji: '🏅',
      title: l.unlockedOf(unlocked, total),
      accent: accent,
      subtitle: l.achievementsHint,
      children: [
        Row(
          children: [
            RingProgress(
              value: pct,
              color: accent,
              size: 74,
              stroke: 8,
              child: Text('$unlocked',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: accent)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                st.isArabic
                    ? 'كل وسام يحكي قصة التزام حقيقية: أيام متتالية، أهداف محققة، أرقام قياسية. استمر والباقي يفتح وحده.'
                    : 'Every badge tells a story of real consistency: streaks, goals hit, records set. Keep going and the rest unlock on their own.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final t = Theme.of(context);
    final accent = badge.unlocked ? C.amber : t.dividerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: badge.unlocked
            ? C.amber.withValues(alpha: 0.08)
            : t.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badge.unlocked ? C.amber.withValues(alpha: 0.4) : t.dividerColor,
          width: badge.unlocked ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          // The medal itself: full colour when unlocked, greyed when locked.
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: badge.unlocked ? C.brandGradient : null,
              color: badge.unlocked ? null : C.surface2,
              border: Border.all(color: accent, width: 1.2),
            ),
            child: Text(
              badge.emoji,
              style: TextStyle(
                fontSize: 23,
                color: badge.unlocked ? Colors.white : t.textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        st.isArabic ? badge.arTitle : badge.enTitle,
                        style: t.textTheme.titleSmall?.copyWith(
                          color: badge.unlocked ? C.amber : t.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                    if (badge.unlocked) ...[
                      const SizedBox(width: 7),
                      const Icon(Icons.verified_rounded, size: 15, color: C.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  st.isArabic ? badge.arDesc : badge.enDesc,
                  style: t.textTheme.bodySmall,
                ),
                if (!badge.unlocked) ...[
                  const Gap(7),
                  Row(
                    children: [
                      Expanded(
                        child: BarProgress(
                          value: badge.progress,
                          color: C.violet,
                          height: 5,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        '${badge.value}/${badge.goal}',
                        style: t.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
