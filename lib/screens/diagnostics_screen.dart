import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native_bridge.dart';
import '../core/theme.dart';
import '../services/content_service.dart';
import '../services/exercise_images.dart';
import '../services/widget_bridge.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

/// "Why is there no update?" - every number the updater looks at, shown as
/// plain values plus the verdict, so a version bug is visible without guessing.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _busy = true;
  String? _error;

  Map<String, dynamic>? _pkg;
  String _abi = '';
  int _normalizedCurrent = 0;
  ReleaseInfo? _latest;
  int _photos = 0;
  int _photoBytes = 0;
  bool _widgetOn = false;
  int _alarms = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final st = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pkg = await Native.packageInfo();
      final abi = await Native.deviceAbi();
      final code = (pkg['versionCode'] as num?)?.toInt() ?? 1;
      ReleaseInfo? latest;
      try {
        latest = await UpdateService.latest(abi: abi);
      } catch (e) {
        latest = null;
      }
      final alarms = await Native.scheduled();
      final widgetOn = await WidgetBridge.probe();
      final photos = await ExerciseImages.cachedCount();
      final bytes = await ExerciseImages.cacheSize();
      if (!mounted) return;
      setState(() {
        _pkg = pkg;
        _abi = abi;
        _normalizedCurrent = code - ReleaseInfo.abiOffsetFor(abi);
        _latest = latest;
        _alarms = alarms.length;
        _widgetOn = widgetOn;
        _photos = photos;
        _photoBytes = bytes;
        _busy = false;
      });
      st.noteBestStreak();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final ar = st.isArabic;
    final t = Theme.of(context);
    final latest = _latest;
    final installedCode = (_pkg?['versionCode'] as num?)?.toInt() ?? 0;
    final latestNorm = latest?.normalizedCode ?? 0;
    final hasUpdate = latest != null && latestNorm > _normalizedCurrent;
    final latestName = latest?.versionName ?? '';

    final lines = <String>[
      'V-System diagnostics / تشخيص',
      'package: ${_pkg?['packageName'] ?? 'com.qbrahym.vsystem'}',
      'versionName: ${_pkg?['versionName'] ?? '?'}',
      'versionCode (installed, as reported by Android): $installedCode',
      'device ABI: $_abi',
      'abi offset applied: ${ReleaseInfo.abiOffsetFor(_abi)}',
      'normalized installed code: $_normalizedCurrent',
      'latest release tag: ${latest?.tagName ?? 'none'}',
      'latest versionName: ${latest?.versionName ?? '-'}',
      'latest code from version.json: ${latest?.versionCode ?? 0} (normalized: $latestNorm)',
      'update offered: $hasUpdate',
      'content version: ${st.content.version}',
      'content url: ${st.contentUrl}',
      'content source: ${st.contentSource}',
      'last sync: ${st.lastSyncAt ?? 'never'}',
      'scheduled alarms: $_alarms',
      'widget installed: $_widgetOn',
      'exercise photos cached: $_photos (${(_photoBytes / 1048576).toStringAsFixed(1)} MB)',
      'streak: ${st.streak()} (best ${st.bestStreak()})',
    ].join('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? '🩺 تشخيص التحديث' : '🩺 Update diagnostics'),
        actions: [
          IconButton(
            tooltip: ar ? 'نسخ التقرير' : 'Copy report',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lines));
              if (context.mounted) {
                snack(context, ar ? 'انسخ التقرير ✅' : 'Report copied ✅', color: C.cyan);
              }
            },
          ),
          IconButton(
            tooltip: ar ? 'تحديث' : 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          if (_busy) const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          if (_error != null) InfoBanner(_error!, color: C.red),

          // ------------------------------------------------ the verdict ----
          SectionCard(
            emoji: hasUpdate ? '🟢' : '✅',
            title: ar ? 'نتيجة فحص التحديث' : 'Update check result',
            accent: hasUpdate ? C.green : C.blue,
            children: [
              Text(
                _busy
                    ? (ar ? 'جاري الفحص…' : 'Checking…')
                    : hasUpdate
                        ? (ar
                            ? 'فيه نسخة أحدث ($latestName) — لازم يظهر الشريط الأخضر.'
                            : 'A newer version exists ($latestName) - the green strip should appear.')
                        : (ar
                            ? 'أنت على آخر نسخة منشورة 🎉'
                            : 'You are on the latest published version 🎉'),
                style: t.textTheme.titleSmall,
              ),
              const Gap(12),
              _Row(
                label: ar ? 'رقم النسخة المثبتة' : 'Installed code',
                value: '$installedCode',
                hint: ar ? 'كما يقرأه أندرويد' : 'as Android reports it',
              ),
              _Row(
                label: ar ? 'إزاحة المعالج' : 'ABI offset',
                value: '-${ReleaseInfo.abiOffsetFor(_abi)}',
                hint: _abi.isEmpty ? 'unknown ABI' : _abi,
              ),
              _Row(
                label: ar ? 'المثبت بعد التطبيع' : 'Installed (normalized)',
                value: '$_normalizedCurrent',
                hint: ar ? 'هذا اللي يُقارن' : 'this is what is compared',
                bold: true,
              ),
              _Row(
                label: ar ? 'أحدث إصدار منشور' : 'Latest published',
                value: '$latestNorm',
                hint: latest == null
                    ? (ar ? 'ما قدر يجيب GitHub' : 'could not reach GitHub')
                    : '${latest.tagName} · ${latest.versionName}',
                bold: true,
              ),
              const Gap(10),
              InfoBanner(
                ar
                    ? 'المقارنة الصحيحة: $latestNorm > $_normalizedCurrent ؟ ${hasUpdate ? 'نعم' : 'لا'}. لو الرقم المنشور سالب أو غريب → الخلل في حساب رقم النسخة.'
                    : 'Correct comparison: $latestNorm > $_normalizedCurrent ? ${hasUpdate ? 'yes' : 'no'}. A negative or odd published number means the version maths is broken.',
                color: hasUpdate ? C.green : C.blue,
                icon: Icons.calculate_rounded,
              ),
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '🛰️',
            title: ar ? 'المحتوى عن بُعد' : 'Remote content',
            accent: C.cyan,
            children: [
              _Row(label: ar ? 'نسخة المحتوى' : 'Content version', value: 'v${st.content.version}'),
              _Row(
                label: ar ? 'المصدر' : 'Source',
                value: st.contentSource ?? '-',
                hint: st.contentSource == 'asset' ? (ar ? 'المدمج (ما زامن بعد)' : 'bundled') : '',
              ),
              _Row(
                label: ar ? 'آخر مزامنة' : 'Last sync',
                value: st.lastSyncAt == null
                    ? (ar ? 'أبداً' : 'never')
                    : '${st.lastSyncAt!.year}-${st.lastSyncAt!.month.toString().padLeft(2, '0')}-${st.lastSyncAt!.day.toString().padLeft(2, '0')}',
              ),
              const Gap(6),
              SelectableText(st.contentUrl,
                  style: t.textTheme.labelSmall?.copyWith(fontSize: 10.5)),
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '📱',
            title: ar ? 'الجهاز والودجت' : 'Device & widget',
            accent: C.violet,
            children: [
              _Row(label: ar ? 'المعالج' : 'Device ABI', value: _abi.isEmpty ? '—' : _abi),
              _Row(label: ar ? 'تنبيهات مجدولة' : 'Scheduled alarms', value: '$_alarms'),
              _Row(
                label: ar ? 'الودجت على الشاشة' : 'Widget installed',
                value: _widgetOn ? (ar ? 'نعم' : 'yes') : (ar ? 'لا' : 'no'),
              ),
              _Row(
                label: ar ? 'صور تمارين محفوظة' : 'Exercise photos cached',
                value: '$_photos',
                hint: '${(_photoBytes / 1048576).toStringAsFixed(1)} MB',
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await st.refreshWidget();
                        if (context.mounted) {
                          snack(context,
                              ar ? 'تم تحديث الودجت ✅' : 'Widget refreshed ✅',
                              color: C.cyan);
                        }
                      },
                      icon: const Icon(Icons.widgets_outlined, size: 18),
                      label: Text(ar ? 'تحديث الودجت' : 'Refresh widget',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ExerciseImages.clear();
                        await _load();
                        if (context.mounted) {
                          snack(context,
                              ar ? 'حُذفت الصور المحفوظة' : 'Cached photos cleared',
                              color: C.amber);
                        }
                      },
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: Text(ar ? 'حذف الصور' : 'Clear photos',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),

          SectionCard(
            emoji: '📋',
            title: ar ? 'تقرير جاهز للنسخ' : 'Copy-ready report',
            accent: C.amber,
            subtitle: ar
                ? 'انسخه وأرسله لو صار أي خلل — فيه كل الأرقام'
                : 'Copy this if anything looks wrong - it has every number',
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  lines,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, height: 1.5),
                ),
              ),
              const Gap(10),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: lines));
                  if (context.mounted) {
                    snack(context, ar ? 'انسخ التقرير ✅' : 'Report copied ✅', color: C.amber);
                  }
                },
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: Text(ar ? 'نسخ التقرير' : 'Copy report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.hint,
    this.bold = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: t.textTheme.bodySmall)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: bold ? C.cyan : null,
                ),
              ),
              if (hint != null && hint!.isNotEmpty)
                Text(hint!, style: t.textTheme.labelSmall?.copyWith(fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}
