import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/content_service.dart';
import 'models.dart';
import 'native_bridge.dart';

const String kAssetContent = 'assets/content/content.json';
const String kDefaultContentUrl =
    'https://raw.githubusercontent.com/qbrahym02-cmyk/vshape-app/main/content.json';

/// Keys used in SharedPreferences.
class K {
  static const lang = 'lang'; // 'ar' | 'en'
  static const theme = 'theme'; // 'system' | 'light' | 'dark'
  static const contentJson = 'remote_content_json';
  static const contentUrl = 'content_url';
  static const lastSync = 'last_sync_ms';
  static const lastUpdateCheck = 'last_update_check_ms';
  static const remindersOn = 'reminders_on';
  static const onboarded = 'onboarded_v1';
  static const lastContentVersion = 'last_content_version';

  static String date() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static String water(String d) => 'w_$d';
  static String slot(String d, String id) => 'ws_${d}_$id';
  static String task(String d, String id) => 't_${d}_$id';
  static String mealItem(String d, String mealId, int idx) => 'mi_${d}_${mealId}_$idx';
  static String mealDone(String d, String mealId) => 'md_${d}_${mealId}';
  static String setDone(String d, String exId, int idx) => 'sd_${d}_${exId}_$idx';
  static String dayDone(String d, String dayId) => 'dd_${d}_$dayId';
  static String strength(String id) => 'str_$id';
  static String measure(String id) => 'meas_$id';
}

enum SyncStatus { idle, loading, ok, error }

class AppState extends ChangeNotifier {
  AppState._(this._prefs, this._content, this._isArabic, this._themeMode);

  final SharedPreferences _prefs;
  AppContent _content;
  bool _isArabic;
  ThemeMode _themeMode;

  SyncStatus syncStatus = SyncStatus.idle;

  /// Set by the daily background check when a newer APK is published.
  ReleaseInfo? pendingUpdate;
  String? syncMessage;
  DateTime? lastSyncAt;
  String? contentSource; // 'asset' | 'remote' | 'cache'

  // ---------------------------------------------------------------- boot ----
  static Future<AppState> boot() async {
    final prefs = await SharedPreferences.getInstance();
    AppContent content;
    String source = 'asset';

    final cached = prefs.getString(K.contentJson);
    if (cached != null && cached.isNotEmpty) {
      try {
        content = AppContent.fromMap(jsonDecode(cached) as Map<String, dynamic>);
        source = 'cache';
      } catch (_) {
        content = AppContent.fromMap(jsonDecode(await _readAsset()) as Map<String, dynamic>);
        source = 'asset';
      }
    } else {
      content = AppContent.fromMap(jsonDecode(await _readAsset()) as Map<String, dynamic>);
      source = 'asset';
    }

    final langCode = prefs.getString(K.lang);
    final isArabic = langCode == null
        ? (PlatformDispatcher.instance.locale.languageCode != 'en')
        : langCode == 'ar';
    final theme = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(K.theme),
      orElse: () => ThemeMode.dark,
    );

    final st = AppState._(prefs, content, isArabic, theme);
    st.contentSource = source;
    final ms = prefs.getInt(K.lastSync);
    if (ms != null) st.lastSyncAt = DateTime.fromMillisecondsSinceEpoch(ms);
    return st;
  }

  static Future<String> _readAsset() async {
    try {
      return await rootBundle.loadString(kAssetContent);
    } catch (_) {
      return '{"version":0}';
    }
  }

  // ------------------------------------------------------------- content ----
  AppContent get content => _content;
  bool get isArabic => _isArabic;
  Locale get locale => Locale(isArabic ? 'ar' : 'en');
  ThemeMode get themeMode => _themeMode;
  String get langCode => isArabic ? 'ar' : 'en';

  String t(Txt txt) => txt.t(_isArabic);
  List<String> tl(BiList l) => l.t(_isArabic);

  String get contentUrl => _prefs.getString(K.contentUrl) ?? kDefaultContentUrl;

  Future<void> setContentUrl(String url) async {
    url = url.trim();
    if (url.isEmpty) {
      await _prefs.remove(K.contentUrl);
    } else {
      await _prefs.setString(K.contentUrl, url);
    }
    notifyListeners();
  }

  /// Pull the content file from the network; fall back to cache/asset.
  Future<bool> syncContent({bool force = false}) async {
    syncStatus = SyncStatus.loading;
    syncMessage = null;
    notifyListeners();
    try {
      final map = await ContentService.fetch(contentUrl);
      final fresh = AppContent.fromMap(map);
      _content = fresh;
      contentSource = 'remote';
      await _prefs.setString(K.contentJson, jsonEncode(map));
      await _prefs.setInt(K.lastSync, DateTime.now().millisecondsSinceEpoch);
      await _prefs.setInt(K.lastContentVersion, fresh.version);
      lastSyncAt = DateTime.now();
      syncStatus = SyncStatus.ok;
      syncMessage = isArabic
          ? 'تم التحديث إلى النسخة ${fresh.version}'
          : 'Updated to content v${fresh.version}';
      notifyListeners();
      unawaited(Reminders.apply(this));
      return true;
    } catch (e) {
      syncStatus = SyncStatus.error;
      syncMessage = (isArabic ? 'فشل التحديث: ' : 'Sync failed: ') + _short(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> resetContentToBundled() async {
    await _prefs.remove(K.contentJson);
    _content = AppContent.fromMap(jsonDecode(await _readAsset()) as Map<String, dynamic>);
    contentSource = 'asset';
    notifyListeners();
  }

  String _short(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    return s.length > 140 ? s.substring(0, 140) : s;
  }

  // -------------------------------------------------------------- settings --
  Future<void> setArabic(bool ar) async {
    _isArabic = ar;
    await _prefs.setString(K.lang, ar ? 'ar' : 'en');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await _prefs.setString(K.theme, m.name);
    notifyListeners();
  }

  /// Lets external helpers trigger a rebuild.
  void ping() => notifyListeners();

  // ---------------------------------------------------------------- state ---
  SharedPreferences get prefs => _prefs;

  // water
  int waterToday() => _prefs.getInt(K.water(K.date())) ?? 0;
  Future<void> addWater(int ml) async {
    final v = (waterToday() + ml).clamp(0, 20000);
    await _prefs.setInt(K.water(K.date()), v);
    notifyListeners();
  }

  Future<void> setSlot(String slotId, int glasses) async {
    await _prefs.setInt(K.slot(K.date(), slotId), glasses.clamp(0, 40));
    await _syncQuickTotal();
    notifyListeners();
  }

  /// Keeps the "quick add" counter in sync with the slot checklist so both
  /// UIs always show the same number.
  Future<void> _syncQuickTotal() async {
    final sum = _content.water.slots.fold<int>(
        0, (s, e) => s + slotDone(e.id) * _content.water.glassMl);
    if (sum > waterToday()) await _prefs.setInt(K.water(K.date()), sum);
  }

  Future<void> bumpSlot(String slotId, int target, {required bool up}) async {
    final cur = slotDone(slotId);
    final next = up ? (cur + 1) : (cur - 1);
    await setSlot(slotId, next.clamp(0, target).toInt());
  }

  int slotDone(String slotId) => _prefs.getInt(K.slot(K.date(), slotId)) ?? 0;

  /// Total for today = max(sum of slots, quick-add counter) so both UIs agree.
  int waterTotal() {
    final slots = _content.water.slots.fold<int>(
        0, (s, e) => s + slotDone(e.id) * _content.water.glassMl);
    final quick = waterToday();
    return slots > quick ? slots : quick;
  }

  Future<void> toggleSlot(String slotId, int target) async {
    final cur = slotDone(slotId);
    final next = cur >= target ? 0 : target;
    await setSlot(slotId, next);
  }

  // tasks
  bool taskDone(String id) => _prefs.getBool(K.task(K.date(), id)) ?? false;
  Future<void> setTask(String id, bool v) async {
    await _prefs.setBool(K.task(K.date(), id), v);
    notifyListeners();
  }

  Future<void> toggleTask(String id) => setTask(id, !taskDone(id));

  // meals
  bool mealItemDone(String mealId, int idx) =>
      _prefs.getBool(K.mealItem(K.date(), mealId, idx)) ?? false;
  Future<void> toggleMealItem(String mealId, int idx) async {
    await _prefs.setBool(K.mealItem(K.date(), mealId, idx), !mealItemDone(mealId, idx));
    notifyListeners();
  }

  bool mealDone(String mealId) {
    final m = _content.food.meals.where((e) => e.id == mealId).toList();
    if (m.isEmpty) return false;
    for (var i = 0; i < m.first.items.length; i++) {
      if (!mealItemDone(mealId, i)) return false;
    }
    return m.first.items.isNotEmpty;
  }

  int proteinEaten() {
    var sum = 0;
    for (final m in _content.food.meals) {
      if (m.items.isEmpty) continue;
      var done = 0;
      for (var i = 0; i < m.items.length; i++) {
        if (mealItemDone(m.id, i)) done++;
      }
      sum += (m.proteinG * done / m.items.length).round();
    }
    return sum;
  }

  int kcalEaten() {
    var sum = 0;
    for (final m in _content.food.meals) {
      if (m.items.isEmpty) continue;
      var done = 0;
      for (var i = 0; i < m.items.length; i++) {
        if (mealItemDone(m.id, i)) done++;
      }
      sum += (m.kcal * done / m.items.length).round();
    }
    return sum;
  }

  // workouts
  bool setDoneToday(String exId, int idx) =>
      _prefs.getBool(K.setDone(K.date(), exId, idx)) ?? false;
  Future<void> toggleSet(String exId, int idx) async {
    await _prefs.setBool(K.setDone(K.date(), exId, idx), !setDoneToday(exId, idx));
    notifyListeners();
  }

  int setsDone(String dayId) {
    final d = _content.workout.days.where((e) => e.id == dayId).toList();
    if (d.isEmpty) return 0;
    var n = 0;
    for (final ex in d.first.exercises) {
      for (var i = 0; i < ex.sets; i++) {
        if (setDoneToday(ex.id, i)) n++;
      }
    }
    return n;
  }

  bool dayDoneToday(String dayId) =>
      _prefs.getBool(K.dayDone(K.date(), dayId)) ?? false;
  Future<void> toggleDayDone(String dayId) async {
    await _prefs.setBool(K.dayDone(K.date(), dayId), !dayDoneToday(dayId));
    notifyListeners();
  }

  // progress logs  (json arrays of {"d": "2026-09-15", "v": 12})
  List<Map<String, dynamic>> logFor(String id) {
    final s = _prefs.getString(id);
    if (s == null || s.isEmpty) return const [];
    try {
      final l = jsonDecode(s) as List;
      return [for (final e in l) (e as Map).cast<String, dynamic>()];
    } catch (_) {
      return const [];
    }
  }

  Future<void> appendLog(String id, num value) async {
    final list = logFor(id);
    final entry = <String, dynamic>{'d': K.date(), 'v': value};
    final filtered = list.where((e) => e['d'] != entry['d']).toList();
    filtered.add(entry);
    filtered.sort((a, b) => '${a['d']}'.compareTo('${b['d']}'));
    if (filtered.length > 240) filtered.removeRange(0, filtered.length - 240);
    await _prefs.setString(id, jsonEncode(filtered));
    notifyListeners();
  }

  Future<void> removeLogEntry(String id, String date) async {
    final list = logFor(id).where((e) => e['d'] != date).toList();
    await _prefs.setString(id, jsonEncode(list));
    notifyListeners();
  }

  num? lastLogValue(String id) {
    final l = logFor(id);
    if (l.isEmpty) return null;
    final v = l.last['v'];
    return v is num ? v : num.tryParse('$v');
  }

  // reminders
  bool get remindersOn => _prefs.getBool(K.remindersOn) ?? true;
  Future<void> setReminders(bool on) async {
    await _prefs.setBool(K.remindersOn, on);
    notifyListeners();
    await Reminders.apply(this);
  }

  // streak
  int streak() {
    var n = 0;
    for (var i = 0; i < 400; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final ok = (_prefs.getInt(K.water(key)) ?? 0) >= _content.water.goalMl * 0.6 ||
          _content.routine.any((r) => _prefs.getBool(K.task(key, r.id)) ?? false);
      if (ok) {
        n++;
      } else if (i > 0) {
        break;
      } else {
        // today not finished yet: don't break the streak
        continue;
      }
    }
    return n;
  }

  Future<void> wipeAllData() async {
    final keys = _prefs.getKeys().where((k) => k != K.lang && k != K.theme).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }
}
