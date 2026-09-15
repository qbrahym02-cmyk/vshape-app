import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/native_bridge.dart';
import '../core/theme.dart';
import '../services/content_service.dart';
import '../services/update_controller.dart';
import '../services/widget_bridge.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';
import '../widgets/scope.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final UpdateController _upd = UpdateController(context.st)..loadCurrent();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _upd.check(silent: true);
    });
  }

  @override
  void dispose() {
    _upd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text('⚙️ ${l.settings}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          // ---------------------------------------------------- appearance --
          SectionCard(
            emoji: '🎨',
            title: l.appearance,
            accent: C.cyan,
            children: [
              Text(l.language, style: Theme.of(context).textTheme.labelMedium),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: _Choice(
                      label: '🇸🇦 ${l.arabic}',
                      selected: st.isArabic,
                      color: C.cyan,
                      onTap: () => st.setArabic(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Choice(
                      label: '🇬🇧 ${l.english}',
                      selected: !st.isArabic,
                      color: C.cyan,
                      onTap: () => st.setArabic(false),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Row(
                children: [
                  for (final m in ThemeMode.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _Choice(
                          label: m == ThemeMode.system
                              ? l.themeSystem
                              : (m == ThemeMode.light ? l.themeLight : l.themeDark),
                          selected: st.themeMode == m,
                          color: C.violet,
                          onTap: () => st.setThemeMode(m),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Gap(16),

          // ------------------------------------------------- remote content --
          SectionCard(
            emoji: '🛰️',
            title: l.remoteContent,
            accent: C.green,
            subtitle: st.isArabic
                ? 'عدّل ملف content.json على GitHub والتطبيق يتغير بدون إعادة تثبيت'
                : 'Edit content.json on GitHub and the app changes without reinstalling',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${l.contentVersion}: v${st.content.version}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          '${l.source}: ${st.contentSource == 'remote' ? l.sourceRemote : (st.contentSource == 'cache' ? l.sourceCache : l.sourceAsset)}'
                          ' · ${l.lastSynced}: ${st.lastSyncAt == null ? l.never : _fmt(st.lastSyncAt!)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SyncButton(state: st),
                ],
              ),
              if (st.syncMessage != null) ...[
                const Gap(10),
                InfoBanner(
                  st.syncMessage!,
                  color: st.syncStatus == SyncStatus.error ? C.red : C.green,
                  icon: st.syncStatus == SyncStatus.error
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                ),
              ],
              const Gap(12),
              OutlinedButton.icon(
                onPressed: () => _editUrl(context, st),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(l.contentUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Gap(6),
              Text(st.contentUrl,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10.5)),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showHelp(context),
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: Text(l.howRemoteWorks, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await _confirm(context,
                          st.isArabic ? 'إرجاع المحتوى المدمج في التطبيق؟' : 'Restore the bundled content?');
                      if (ok == true) await st.resetContentToBundled();
                    },
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                    label: Text(l.restoreBundled, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),

          // ----------------------------------------------------- app update --
          _UpdateCard(controller: _upd),
          const Gap(16),

          // ------------------------------------------------------ reminders --
          SectionCard(
            emoji: '🔔',
            title: l.reminders,
            accent: C.amber,
            children: [
              SwitchListTile(
                value: st.remindersOn,
                onChanged: (v) async {
                  await st.setReminders(v);
                  if (v) await Native.requestNotificationPermission();
                },
                contentPadding: EdgeInsets.zero,
                title: Text(l.remindersOn, style: Theme.of(context).textTheme.bodyMedium),
                subtitle: Text(
                  '${_waterTimes(st).join(' · ')}  |  🏋️ ${st.content.reminders.workout}'
                  '  |  😴 ${st.content.reminders.sleep}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                activeThumbColor: C.amber,
              ),
              const Gap(6),
              InfoBanner(
                st.isArabic
                    ? 'الأوقات تُقرأ من ملف المحتوى — تقدر تغيّرها من GitHub بدون تحديث التطبيق.'
                    : 'These times come from the content file - change them on GitHub without updating the app.',
                color: C.amber,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const Gap(16),

          // -------------------------------------------------- home widget --
          _WidgetCard(onHow: () => _showWidgetHelp(context)),
          const Gap(16),

          // ---------------------------------------------------------- data --
          SectionCard(
            emoji: '🗑️',
            title: l.dataSection,
            accent: C.red,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await _confirm(context, l.wipeConfirm);
                  if (ok == true) {
                    await st.wipeAllData();
                    if (context.mounted) snack(context, st.isArabic ? 'تم الحذف' : 'Erased', color: C.red);
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 18, color: C.red),
                label: Text(l.wipeData, style: const TextStyle(color: C.red)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: C.red.withValues(alpha: 0.4))),
              ),
            ],
          ),
          const Gap(20),
          Center(
            child: Text(
              '${st.content.meta.name.t(st.isArabic)} · content v${st.content.version}'
              ' · ${st.content.updatedAt}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  /// The times that will actually ring: water alarms come from the schedule
  /// slots (skipping `remind: false`) plus any extra times in `reminders.water`.
  /// Reading `reminders.water` alone would show times that never fire.
  static List<String> _waterTimes(AppState st) {
    final alarms = Reminders.buildAlarms(st.content, st.isArabic);
    final water = alarms.where((a) => a['slot'] != null || a['title'].toString().contains('💧'));
    final out = water
        .map((a) => '${a['hour']}:${'${a['minute']}'.padLeft(2, '0')}')
        .toList()
      ..sort();
    return out.isEmpty ? st.content.reminders.water : out;
  }

  void _showWidgetHelp(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AppScope(
        state: st,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🧩 ${l.widgetTitle}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Gap(12),
                StepList(
                  steps: st.isArabic
                      ? const [
                          'اضغط مطولاً على مكان فاضي في الشاشة الرئيسية.',
                          'اختر «ودجت» أو «Widgets».',
                          'ابحث عن V-System واضغط عليه.',
                          'اسحبه إلى المكان الذي تريده (يحتاج عرض ٤ خانات).',
                          'ارجع للتطبيق واضغط «تحديث الودجت الآن» — أو استخدم التطبيق بشكل عادي وسيتحدث وحده.',
                        ]
                      : const [
                          'Long-press an empty spot on your home screen.',
                          'Tap "Widgets".',
                          'Find V-System and tap it.',
                          'Drag it where you want it (needs 4 columns of width).',
                          'Back in the app press "Refresh widget now" - or just use the app and it updates by itself.',
                        ],
                  color: C.cyan,
                ),
                const Gap(12),
                InfoBanner(
                  st.isArabic
                      ? 'لو ما ظهر V-System في قائمة الودجت: افتح التطبيق مرة واحدة بعد التثبيت ثم أعد المحاولة.'
                      : 'If V-System is missing from the widget list: open the app once after installing, then try again.',
                  color: C.amber,
                  icon: Icons.lightbulb_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _editUrl(BuildContext context, AppState st) async {
    final ctrl = TextEditingController(text: st.contentUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.contentUrl, style: const TextStyle(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'https://raw.githubusercontent.com/…/content.json'),
            ),
            const Gap(8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.st.isArabic
                    ? 'يقبل: GitHub raw / GitHub Pages / Gist / Google Drive / أي رابط JSON'
                    : 'Accepts: GitHub raw / Pages / Gist / Google Drive / any JSON URL',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.save)),
        ],
      ),
    );
    if (ok == true) {
      await st.setContentUrl(ctrl.text);
      await st.syncContent();
    }
  }

  void _showHelp(BuildContext context) {
    final st = context.st;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AppScope(
        state: st,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🛰️ ${context.l10n.howRemoteWorks}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Gap(14),
                StepList(
                  color: C.green,
                  steps: st.isArabic
                      ? [
                          'افتح المستودع qbrahym02-cmyk/vshape-app على GitHub.',
                          'اضغط على ملف content.json ثم أيقونة القلم (Edit).',
                          'عدّل أي شيء: الوجبات، التمارين، أهداف الماء، أوقات التنبيهات، النصوص.',
                          'ارفع رقم "version" في أول الملف (مثلاً من 3 إلى 4).',
                          'اضغط Commit changes.',
                          'في التطبيق: الإعدادات ← مزامنة الآن. خلاص، تغيّر كل شيء بدون تثبيت جديد.',
                        ]
                      : [
                          'Open the repo qbrahym02-cmyk/vshape-app on GitHub.',
                          'Tap content.json, then the pencil (Edit) icon.',
                          'Change anything: meals, exercises, water targets, reminder times, wording.',
                          'Bump the "version" number at the top (e.g. 3 -> 4).',
                          'Press Commit changes.',
                          'In the app: Settings -> Sync now. Everything updates with no reinstall.',
                        ],
                ),
                const Gap(16),
                InfoBanner(
                  st.isArabic
                      ? 'نصيحة: لا تحذف الأقواس أو الفواصل — الملف JSON. لو صار خطأ، التطبيق يكمل على آخر نسخة محفوظة ولا ينهار.'
                      : 'Tip: don\'t remove brackets or commas - it is JSON. If it breaks, the app keeps running on the last saved copy.',
                  color: C.amber,
                ),
                const Gap(14),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                      Uri.parse('https://github.com/qbrahym02-cmyk/vshape-app/edit/main/content.json'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(st.isArabic ? 'افتح الملف على GitHub' : 'Open the file on GitHub'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String msg) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.ok)),
          ],
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.color, required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? color : Theme.of(context).dividerColor, width: selected ? 1.6 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) Icon(Icons.check_circle_rounded, size: 16, color: color),
                if (selected) const SizedBox(width: 5),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? color : null)),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final loading = state.syncStatus == SyncStatus.loading;
    return FilledButton.icon(
      onPressed: loading ? null : () => state.syncContent(),
      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white),
      icon: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.sync_rounded, size: 19),
      label: Text(context.l10n.syncNow),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.controller});
  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = controller;

    return AnimatedBuilder(
      animation: u,
      builder: (context, _) {
        return SectionCard(
          emoji: '📦',
          title: l.appUpdate,
          accent: C.blue,
          subtitle:
              '${l.currentVersion}: ${u.currentName} (code ${u.currentCode})',
          children: [
            if (u.error != null) ...[
              InfoBanner(u.error!, color: C.red, icon: Icons.error_outline_rounded),
              const Gap(10),
            ],
            if (u.hasUpdate)
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: C.green.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.newVersion}: ${u.latest!.versionName} (${u.latest!.versionCode})',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: C.green),
                          ),
                        ),
                        if (u.latest!.apkSize > 0)
                          Text(
                            '${(u.latest!.apkSize / 1048576).toStringAsFixed(1)} MB · ${u.latest!.abi}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                    if (u.latest!.notes.trim().isNotEmpty) ...[
                      const Gap(6),
                      Text(u.latest!.notes.trim().split('\n').take(6).join('\n'),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const Gap(12),
                    if (u.downloading)
                      Column(
                        children: [
                          BarProgress(value: u.progress, color: C.green, height: 8),
                          const Gap(8),
                          Row(
                            children: [
                              Text('${l.downloading} ${(u.progress * 100).round()}%',
                                  style: Theme.of(context).textTheme.labelSmall),
                              const Spacer(),
                              TextButton(
                                  onPressed: u.cancelDownload, child: Text(l.cancel)),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: u.downloaded == null
                                ? FilledButton.icon(
                                    onPressed: u.busy ? null : () => u.download(),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: C.green, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.download_rounded, size: 19),
                                    label: Text(l.downloadInstall),
                                  )
                                : FilledButton.icon(
                                    onPressed: () async {
                                      final ok = await u.install();
                                      if (!ok && u.needsUnknownSources && context.mounted) {
                                        snack(context, l.allowUnknown, color: C.amber);
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                        backgroundColor: C.green, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.install_mobile_rounded, size: 19),
                                    label: Text(l.installNow),
                                  ),
                          ),
                        ],
                      ),
                    if (u.needsUnknownSources) ...[
                      const Gap(10),
                      InfoBanner(l.allowUnknown, color: C.amber, icon: Icons.shield_outlined),
                      const Gap(6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => Native.openUnknownSourcesSettings(),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(l.openSettings),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (u.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else
              InfoBanner(l.upToDate, color: C.green, icon: Icons.verified_rounded),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: u.busy ? null : () => u.check(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.checkUpdate),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://github.com/${UpdateService.repo}/releases'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('GitHub'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Home-screen widget: a live preview of what Android will render, plus a
/// manual refresh (the widget also updates on every tap inside the app).
class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.onHow});

  final VoidCallback onHow;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);
    final d = WidgetData.from(st);
    final waterPct = d.waterGoalMl == 0 ? 0.0 : d.waterMl / d.waterGoalMl;
    final setsPct = d.setsTotal == 0
        ? (d.restDay ? 1.0 : 0.0)
        : d.setsDone / d.setsTotal;

    return SectionCard(
      emoji: '🧩',
      title: l.widgetTitle,
      accent: C.cyan,
      subtitle: l.widgetHint,
      children: [
        // ---- preview (mirrors res/layout/widget_vsystem.xml) ----
        Directionality(
          textDirection: st.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1020),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('V',
                        style: TextStyle(
                            color: C.cyan, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(width: 6),
                    Text('V-System',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    const Spacer(),
                    Text('${d.streak} 🔥',
                        style: const TextStyle(color: C.amber, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
                const Gap(9),
                Text(
                  '${(d.waterMl / 1000).toStringAsFixed(1)}'
                  ' / ${(d.waterGoalMl / 1000).toStringAsFixed(1)} '
                  '${st.isArabic ? 'لتر' : 'L'}  ·  ${d.waterGlasses} ${st.isArabic ? 'كوب' : 'glasses'}',
                  style: const TextStyle(color: C.cyan, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const Gap(4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: waterPct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(C.cyan),
                  ),
                ),
                const Gap(9),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🍗 ${d.proteinG}/${d.proteinGoalG}g',
                        style: const TextStyle(color: C.orange, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '🔥 ${d.kcal}/${d.kcalGoal}',
                        style: const TextStyle(color: C.amber, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Gap(7),
                Text(
                  '${d.workoutEmoji} ${d.workoutTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                ),
                const Gap(4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value: setsPct.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(C.violet),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      d.restDay
                          ? (st.isArabic ? 'راحة' : 'rest')
                          : '${d.setsDone}/${d.setsTotal}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await st.refreshWidget();
                  if (context.mounted) {
                    snack(context, l.widgetUpdated, color: C.cyan);
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.widgetRefresh,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onHow,
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: Text(l.widgetHow, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const Gap(8),
        Text(
          st.isArabic
              ? 'الودجت يشتغل حتى والتطبيق مغلق، ويتحدّث تلقائياً مع كل ضغطة + مرة كل ساعة تقريباً.'
              : 'The widget keeps working with the app closed, and refreshes on every tap plus roughly once an hour.',
          style: t.textTheme.labelSmall,
        ),
      ],
    );
  }
}
