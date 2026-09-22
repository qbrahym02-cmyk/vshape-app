import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/prayer_service.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

/// Prayer-times screen: next prayer + countdown, the six daily markers,
/// city/method/hanafi/notification settings.
///
/// Everything is computed locally (offline astronomy); the only platform
/// interaction is scheduling the notification batch.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  Timer? _ticker;
  int _armedCount = -1; // -1 = unknown yet

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _refreshArmedCount();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshArmedCount() async {
    final st = context.st; // captured before the await
    final n = await Prayers.apply(st);
    if (mounted) setState(() => _armedCount = n);
  }

  Future<void> _changePrefs(Future<void> Function(AppState st) fn) async {
    final st = context.st; // captured before the await
    await fn(st);
    if (!mounted) return;
    st.ping(); // rebuild everything that reads prefs
    await _refreshArmedCount();
    try {
      await st.refreshWidget();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final s = Prayers.settingsOf(st);
    final now = DateTime.now();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        children: [
          ScreenHeader(title: l.prayerTimes, subtitle: s.configured
              ? '${s.city!.flag} ${s.city!.name(st.isArabic)} · ${s.method.name(st.isArabic)}'
              : l.prayerSubtitle),
          const Gap(12),

          if (!s.configured) _PickCityCard(onPick: () => _pickCity()),
          if (s.configured) ...[
            _NextPrayerCard(settings: s, now: now, arabic: st.isArabic, l: l),
            const Gap(12),
            _TimesCard(settings: s, now: now, arabic: st.isArabic, l: l),
            const Gap(12),
            _SettingsCard(
              settings: s,
              armedCount: _armedCount,
              onCity: () => _pickCity(),
              onMethod: () => _pickMethod(s),
              onHanafi: (v) => _changePrefs((st) async =>
                  st.prefs.setBool(K.prayerHanafi, v)),
              onNotify: (v) => _changePrefs((st) async =>
                  st.prefs.setBool(K.prayerNotify, v)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCity() async {
    final city = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CityPickerSheet(),
    );
    if (city == null) return;
    await _changePrefs((st) async {
      await st.prefs.setString(K.prayerCity, city.id);
      // A new city invalidates a manual method override - the city's own
      // default is almost always what the user wants there.
      await st.prefs.setString(K.prayerMethod, '');
    });
  }

  Future<void> _pickMethod(PrayerSettings s) async {
    final st = context.st; // captured before the async gap below
    final picked = await showModalBottomSheet<CalcMethod>(
      context: context,
      builder: (_) => _MethodSheet(current: s.method),
    );
    if (picked == null) return;
    // Picking the city default again == clearing the override.
    final cityDefault = cityById(st.prefs.getString(K.prayerCity))?.methodId;
    await _changePrefs((st) async {
      await st.prefs.setString(
          K.prayerMethod, picked.id == cityDefault ? '' : picked.id);
    });
  }
}

/// Big card: the next marker, its clock time and a live-ish countdown.
class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.settings, required this.now, required this.arabic, required this.l});
  final PrayerSettings settings;
  final DateTime now;
  final bool arabic;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final next = Prayers.nextForWidget(settings);

    if (next == null) return const SizedBox.shrink();

    final left = next.wall.difference(now.toUtc().add(DateTime.now().timeZoneOffset));
    final big = left < const Duration(hours: 10);
    final label = next.id == PrayerId.sunrise
        ? l.sunriseNotPrayer
        : (next.tomorrow ? l.tomorrowFajr : prayerName(next.id, arabic));

    return SectionCard(
      emoji: next.id == PrayerId.sunrise ? '🌄' : '🕋',
      title: l.nextPrayer,
      accent: C.violet,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                label,
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              fmtClock(next.wall, arabic),
              style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: C.violet),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _countdownText(left, arabic),
          style: t.textTheme.titleMedium?.copyWith(color: C.cyan),
        ),
        if (next.id == PrayerId.dhuhr && now.weekday == DateTime.friday) ...[
          const SizedBox(height: 6),
          Text('🕋 ${l.jumuah}', style: t.textTheme.bodySmall),
        ],
        if (big) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: _windowProgress(next, settings, now),
              backgroundColor: C.violet.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(C.violet),
            ),
          ),
        ],
      ],
    );
  }

  /// Fraction of the gap since the previous marker that has already passed -
  /// gives the bar a meaningful slope instead of an arbitrary fill.
  double _windowProgress(NextPrayer next, PrayerSettings s, DateTime now) {
    final off = DateTime.now().timeZoneOffset;
    final nowWall = now.toUtc().add(off);
    DateTime? prev;
    final c = s.city!;
    final today = computeDay(c, now, s.method, s.hanafi, offset: off);
    final yesterday = computeDay(
        c, DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
        s.method, s.hanafi, offset: off);
    for (final e in [...yesterday.entries, ...today.entries]) {
      if (e.wall.isAfter(nowWall)) break;
      prev = e.wall;
    }
    if (prev == null) return 0;
    final total = next.wall.difference(prev).inMilliseconds;
    if (total <= 0) return 0;
    return nowWall.difference(prev).inMilliseconds / total;
  }

  String _countdownText(Duration left, bool ar) {
    if (left.isNegative) return ar ? 'الآن' : 'now';
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h >= 1) {
      return ar ? 'بعد $h ساعة و $m دقيقة' : 'in $h h $m min';
    }
    if (m >= 1) return ar ? 'بعد $m دقيقة' : 'in $m min';
    return ar ? 'بعد ${left.inSeconds} ثانية' : 'in ${left.inSeconds} s';
  }
}

/// The six markers for today, next one highlighted.
class _TimesCard extends StatelessWidget {
  const _TimesCard({required this.settings, required this.now, required this.arabic, required this.l});
  final PrayerSettings settings;
  final DateTime now;
  final bool arabic;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final day = computeDay(settings.city!, now, settings.method, settings.hanafi);
    final off = DateTime.now().timeZoneOffset;
    final nowWall = now.toUtc().add(off);
    PrayerId? nextId;
    for (final e in day.entries) {
      if (e.wall.isAfter(nowWall)) {
        nextId = e.id;
        break;
      }
    }

    return SectionCard(
      emoji: '🕰️',
      title: arabic ? 'مواقيت اليوم' : 'Today\'s times',
      accent: C.cyan,
      children: [
        for (final e in day.entries)
          _TimeRow(
            name: prayerName(e.id, arabic),
            time: fmtClock(e.wall, arabic),
            isNext: e.id == nextId,
            isSunrise: e.id == PrayerId.sunrise,
          ),
        const SizedBox(height: 4),
        Text(
          '${settings.method.name(arabic)} · ${settings.hanafi ? l.hanafiAsr : 'العصر: الشافعي/الجمهور'}',
          style: t.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.name, required this.time, this.isNext = false, this.isSunrise = false});
  final String name;
  final String time;
  final bool isNext;
  final bool isSunrise;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = isNext ? C.violet : (isSunrise ? t.disabledColor : null);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isNext ? C.violet.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(12),
        border: isNext ? Border.all(color: C.violet.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          Text(isSunrise ? '🌄' : '🕌', style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                color: isSunrise ? t.disabledColor : null,
              ),
            ),
          ),
          if (isNext)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: C.violet.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⏳', style: t.textTheme.labelSmall),
            ),
          Text(
            time,
            style: t.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings: city, method, hanafi asr, notifications.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.settings,
    required this.armedCount,
    required this.onCity,
    required this.onMethod,
    required this.onHanafi,
    required this.onNotify,
  });
  final PrayerSettings settings;
  final int armedCount;
  final VoidCallback onCity;
  final VoidCallback onMethod;
  final ValueChanged<bool> onHanafi;
  final ValueChanged<bool> onNotify;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);
    final st2 = settings;

    return SectionCard(
      emoji: '⚙️',
      title: l.settings,
      accent: C.green,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text(st2.city?.flag ?? '🏙️', style: const TextStyle(fontSize: 22)),
          title: Text(l.city, style: t.textTheme.bodyMedium),
          subtitle: Text(
            st2.city == null ? l.chooseCity : '${st2.city!.name(st.isArabic)} (${st2.city!.lat.toStringAsFixed(1)}, ${st2.city!.lng.toStringAsFixed(1)})',
            style: t.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onCity,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Text('📐', style: TextStyle(fontSize: 20)),
          title: Text(l.calcMethod, style: t.textTheme.bodyMedium),
          subtitle: Text(st2.method.name(st.isArabic), style: t.textTheme.bodySmall),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onMethod,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.hanafiAsr, style: t.textTheme.bodyMedium),
          value: st2.hanafi,
          onChanged: onHanafi,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.prayerNotifications, style: t.textTheme.bodyMedium),
          subtitle: Text(
            armedCount > 0
                ? '${l.notificationsArmed} · $armedCount ${l.prayersScheduled}'
                : l.prayerNotifyHint,
            style: t.textTheme.bodySmall,
          ),
          value: st2.notify,
          onChanged: onNotify,
        ),
      ],
    );
  }
}

/// First-run card pushing the (required) city pick.
class _PickCityCard extends StatelessWidget {
  const _PickCityCard({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      emoji: '🕋',
      title: l.chooseCity,
      accent: C.violet,
      children: [
        Text(l.noCityPicked, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.location_city_rounded),
          label: Text(l.chooseCity),
        ),
      ],
    );
  }
}

/// Searchable bottom sheet with every bundled city.
class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();
  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final h = MediaQuery.of(context).size.height;
    final hits = kCities
        .where((c) =>
            _q.isEmpty ||
            c.ar.contains(_q) ||
            c.en.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return SizedBox(
      height: h * 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text('🕋 ${l.chooseCity}',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l.searchCity,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: hits.length,
              itemBuilder: (_, i) {
                final c = hits[i];
                return ListTile(
                  dense: true,
                  leading: Text(c.flag, style: const TextStyle(fontSize: 20)),
                  title: Text(c.name(st.isArabic)),
                  subtitle: Text(
                      '${c.lat.toStringAsFixed(1)}, ${c.lng.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.labelSmall),
                  trailing: Text(
                    methodById(c.methodId).name(st.isArabic),
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Method picker (with the per-city default marked).
class _MethodSheet extends StatelessWidget {
  const _MethodSheet({required this.current});
  final CalcMethod current;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('📐 ${l.calcMethod}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in kCalcMethods)
                  ListTile(
                    dense: true,
                    title: Text(m.name(st.isArabic)),
                    trailing: m.id == current.id
                        ? const Icon(Icons.check_circle_rounded, color: C.violet)
                        : null,
                    onTap: () => Navigator.pop(context, m),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
