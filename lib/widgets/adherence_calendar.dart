import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'scope.dart';

/// 13 weeks x 7 days of coloured squares (oldest first, today last).
///
/// Level 0..4 comes from `AppState.dayLevel`: nothing / some activity / the day
/// counts (streak rule) / water goal reached / water goal **and** a session.
class AdherenceCalendar extends StatelessWidget {
  const AdherenceCalendar({super.key, required this.days});

  final List<({String date, int level})> days;

  static const _labelsAr = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
  static const _labelsEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Color _color(int level, BuildContext context) {
    switch (level) {
      case 4:
        return C.green;
      case 3:
        return C.green.withValues(alpha: 0.72);
      case 2:
        return C.green.withValues(alpha: 0.45);
      case 1:
        return C.green.withValues(alpha: 0.20);
      default:
        return Theme.of(context).dividerColor.withValues(alpha: 0.55);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final ar = context.st.isArabic;

    final firstWeekday = DateTime.parse(days.first.date).weekday; // 1..7
    final pad = firstWeekday - 1;
    final cells = <({String date, int level})?>[
      for (var i = 0; i < pad; i++) null,
      ...days,
    ];
    final weeks = <List<({String date, int level})?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, (i + 7 <= cells.length) ? i + 7 : cells.length));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 2),
            for (final l in (ar ? _labelsAr : _labelsEn))
              SizedBox(
                height: 16,
                width: 14,
                child: Text(l,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8.5)),
              ),
          ],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final w in weeks)
                Column(
                  children: [
                    for (var r = 0; r < 7; r++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: _Square(
                          entry: r < w.length ? w[r] : null,
                          color: _color(
                              (r < w.length && w[r] != null) ? w[r]!.level : 0, context),
                          ar: ar,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.entry, required this.color, required this.ar});

  final ({String date, int level})? entry;
  final Color color;
  final bool ar;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final box = Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
    if (e == null) return Opacity(opacity: 0, child: box);
    return Tooltip(
      message: e.date,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final meaning = ar
              ? ['ما فيه تسجيل', 'نشاط بسيط', 'يوم محسوب', 'هدف الماء كامل', 'ماء + تمرين 💪'][e.level]
              : ['nothing logged', 'some activity', 'day counted', 'water goal met',
                  'water + session 💪'][e.level];
          snack(context, '${e.date} · $meaning', color: C.green);
        },
        child: box,
      ),
    );
  }
}

/// "Less -> More" legend for the calendar.
class AdherenceLegend extends StatelessWidget {
  const AdherenceLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = context.st.isArabic;
    return Row(
      children: [
        Text(ar ? 'أقل' : 'Less', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 6),
        for (final a in [0.20, 0.45, 0.72, 1.0])
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: C.green.withValues(alpha: a),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(ar ? 'أكثر' : 'More', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
