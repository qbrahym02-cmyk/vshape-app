import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../screens/progress_screen.dart';
import '../screens/rules_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final c = st.content;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(title: l.more, subtitle: c.meta.tagline.t(st.isArabic)),

          _BigTile(
            emoji: '📊',
            title: l.progress,
            subtitle: st.isArabic
                ? 'سجل القوة والقياسات ومؤشرات التقدم'
                : 'Strength log, measurements and KPIs',
            color: C.green,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProgressScreen())),
          ),
          const Gap(10),
          _BigTile(
            emoji: '🛡️',
            title: l.rules,
            subtitle: st.isArabic ? '٥ تحذيرات صارمة + لماذا ستنجح' : '5 hard warnings + why this works',
            color: C.red,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const RulesScreen())),
          ),
          const Gap(10),
          _BigTile(
            emoji: '⚙️',
            title: l.settings,
            subtitle: st.isArabic
                ? 'اللغة، المظهر، التحديث عن بُعد، تحديث التطبيق'
                : 'Language, theme, remote content, app updates',
            color: C.cyan,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            badge: st.pendingUpdate != null,
          ),
          const Gap(20),

          SectionCard(
            emoji: '🧠',
            title: l.philosophy,
            accent: C.violet,
            children: [
              for (final p in c.philosophy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title.t(st.isArabic),
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(p.text.t(st.isArabic),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '🎒',
            title: st.t(c.backpack.title),
            accent: C.amber,
            children: [StepList(steps: st.tl(c.backpack.body), color: C.amber)],
          ),
          const Gap(20),

          Center(
            child: Text(
              '${c.meta.name.t(st.isArabic)} · v${c.version}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge = false,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (badge) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
            ],
          ),
        ),
      ),
    );
  }
}
