import 'package:flutter/material.dart';

/// Rounded card with an optional header. The workhorse of every screen.
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? emoji;
  final Color? accent;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;
  final bool dense;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.emoji,
    this.accent,
    this.trailing,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = accent ?? t.colorScheme.primary;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (emoji != null) ...[
                    Text(emoji!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: t.textTheme.titleMedium),
                        if (subtitle != null)
                          Text(subtitle!, style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              SizedBox(height: dense ? 8 : 12),
              Container(
                height: 3,
                width: 46,
                decoration: BoxDecoration(
                  color: a,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              SizedBox(height: dense ? 8 : 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;
  const Pill(this.text, {super.key, this.color, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 8, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: filled ? 1 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.white : c),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big tappable check disc used by routine / meal / water rows.
class CheckDisc extends StatelessWidget {
  final bool done;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  const CheckDisc({super.key, required this.done, required this.color, this.size = 30, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : Colors.transparent,
          border: Border.all(color: done ? color : color.withValues(alpha: 0.5), width: 2),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: size * 0.62, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Small square set-checkbox used in workout cards.
class SetBox extends StatelessWidget {
  final bool done;
  final int index;
  final Color color;
  final VoidCallback onTap;
  const SetBox({super.key, required this.done, required this.index, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: done ? color : color.withValues(alpha: 0.45), width: 1.6),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 19, color: Colors.white)
            : Text(
                '$index',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
              ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.unit,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (icon != null) Icon(icon, size: 15, color: color),
                  if (icon != null) const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.labelMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (unit != null) ...[
                    const SizedBox(width: 3),
                    Text(unit!, style: t.textTheme.bodySmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const InfoBanner(this.text, {super.key, required this.color, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
          ),
        ],
      ),
    );
  }
}

/// Numbered bullet list (used for exercise steps).
class StepList extends StatelessWidget {
  final List<String> steps;
  final Color color;
  const StepList({super.key, required this.steps, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: t.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Empty state with an emoji.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String text;
  const EmptyState(this.emoji, this.text, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

/// Header used at the top of each tab.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.textTheme.headlineSmall?.copyWith(fontSize: 25)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(subtitle!, style: t.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small helper to space stacked widgets consistently.
class Gap extends StatelessWidget {
  final double h;
  const Gap(this.h, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

extension ColorX on Color {
  Color soften(double a) => withValues(alpha: a);
}

/// Shared gradient used on hero cards.
LinearGradient heroGradient(Color a, Color b) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [a, b],
    );

const kCardRadius = 20.0;
