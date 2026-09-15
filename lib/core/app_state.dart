import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/content_service.dart';
import '../services/widget_bridge.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'plan_math.dart';

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

  /// How many times an "extra" (off-plan) food was added on a given day.
  static String extra(String d, String id) => 'ex_${d}_$id';

  // ---- v1.1 settings and daily logs -------------------------------------
  /// "Study first" mode: only the three V-shape sessions stay in the week.
  static const examMode = 'exam_mode_on';

  /// Currency symbol the protein price tool shows (user typed, e.g. "ج.م").
  static const currency = 'currency_symbol';

  /// Bedtime logged for a given morning, as `HH:MM`.
  static String sleep(String d) => 'sl_$d';

  /// Morning readiness / DOMS rating, 1..5.
  static String checkin(String d) => 'ci_$d';

  /// Local price of one unit of a protein source.
  static String price(String id) => 'pr_$id';

  /// A once-a-month check (photo, clothes test...) for `yyyy-MM`.
  static String monthly(String id, String ym) => 'mo_${ym}_$id';

  /// A safety briefing the user has acknowledged.
  static String gate(String id) => 'gate_$id';

  /// `yyyy-MM` for [d] - the granularity of the monthly checks.
  static String ymOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
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

  @visibleForTesting
  static Future<String> debugReadAsset() => _readAsset();

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

  // ------------------------------------------------------- home widget -----
  bool _widgetSyncQueued = false;

  /// Pushes the numbers to the home-screen widget.
  ///
  /// Uses a microtask (not a Timer) so widget tests never end up with a pending
  /// timer, and collapses bursts of taps into a single platform-channel call.
  void scheduleWidgetSync() {
    if (_widgetSyncQueued) return;
    _widgetSyncQueued = true;
    Future.microtask(() async {
      _widgetSyncQueued = false;
      try {
        await WidgetBridge.syncFrom(this);
      } catch (_) {}
    });
  }

  /// Full refresh: re-probe whether the widget is on a home screen, then push.
  Future<void> refreshWidget() async {
    try {
      await WidgetBridge.probe();
      await WidgetBridge.push(WidgetData.from(this));
    } catch (_) {}
  }

  // ---------------------------------------------------------------- state ---
  SharedPreferences get prefs => _prefs;

  // water
  int waterToday() => _prefs.getInt(K.water(K.date())) ?? 0;
  Future<void> addWater(int ml) async {
    final v = (waterToday() + ml).clamp(0, 20000);
    await _prefs.setInt(K.water(K.date()), v);
    notifyListeners();
    scheduleWidgetSync();
  }

  Future<void> setSlot(String slotId, int glasses) async {
    await _prefs.setInt(K.slot(K.date(), slotId), glasses.clamp(0, 40));
    await _syncQuickTotal();
    notifyListeners();
    scheduleWidgetSync();
  }

  /// Keeps the "quick add" counter in sync with the slot checklist so both
  /// UIs always show the same number.
  Future<void> _syncQuickTotal() async {
    final sum = waterFromSlots();
    if (sum > waterToday()) await _prefs.setInt(K.water(K.date()), sum);
  }

  Future<void> bumpSlot(String slotId, int target, {required bool up}) async {
    final cur = slotDone(slotId);
    final next = up ? (cur + 1) : (cur - 1);
    await setSlot(slotId, next.clamp(0, target).toInt());
  }

  int slotDone(String slotId) => _prefs.getInt(K.slot(K.date(), slotId)) ?? 0;

  /// Millilitres recorded through the slot checklist.
  int waterFromSlots() => _content.water.slots.fold<int>(
      0, (s, e) => s + slotDone(e.id) * _content.water.glassMl);

  /// Total for today = max(sum of slots, quick-add counter) so both UIs agree.
  int waterTotal() {
    final slots = waterFromSlots();
    final quick = waterToday();
    return slots > quick ? slots : quick;
  }

  /// Same rule as [waterTotal] but for an arbitrary day (used by [streak]).
  int waterTotalOn(String dateKey) {
    final slots = _content.water.slots.fold<int>(
        0, (s, e) => s + (_prefs.getInt(K.slot(dateKey, e.id)) ?? 0) * _content.water.glassMl);
    final quick = _prefs.getInt(K.water(dateKey)) ?? 0;
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
    scheduleWidgetSync();
  }

  Future<void> toggleTask(String id) => setTask(id, !taskDone(id));

  // meals
  bool mealItemDone(String mealId, int idx) =>
      _prefs.getBool(K.mealItem(K.date(), mealId, idx)) ?? false;
  Future<void> toggleMealItem(String mealId, int idx) async {
    await _prefs.setBool(K.mealItem(K.date(), mealId, idx), !mealItemDone(mealId, idx));
    notifyListeners();
    scheduleWidgetSync();
  }

  bool mealDone(String mealId) {
    final m = _content.food.meals.where((e) => e.id == mealId).toList();
    if (m.isEmpty) return false;
    for (var i = 0; i < m.first.items.length; i++) {
      if (!mealItemDone(mealId, i)) return false;
    }
    return m.first.items.isNotEmpty;
  }

  /// Protein eaten today, in grams (planned meals + extras).
  int proteinEaten() => proteinOn(keyFor(DateTime.now()));

  /// Kcal eaten today (planned meals + extras).
  int kcalEaten() => kcalOn(keyFor(DateTime.now()));

  bool _mealItemDoneOn(String date, String mealId, int idx) =>
      _prefs.getBool(K.mealItem(date, mealId, idx)) ?? false;

  /// Protein for an arbitrary day - used by the 7-day chart.
  int proteinOn(String date) => _mealMacros(date).$1 + _extrasMacros(date).$1;

  /// Kcal for an arbitrary day.
  int kcalOn(String date) => _mealMacros(date).$2 + _extrasMacros(date).$2;

  /// (protein, kcal) coming from the ticked items of the planned meals.
  ///
  /// When the content file carries per-item macros the count is exact; when it
  /// does not (older content) the meal total is split evenly between its items,
  /// which is what the app always did.
  (int, int) _mealMacros(String date) {
    var protein = 0;
    var kcal = 0;
    for (final m in _content.food.meals) {
      if (m.items.isEmpty) continue;
      var done = 0;
      var itemP = 0;
      var itemK = 0;
      var hasMacros = true;
      for (var i = 0; i < m.items.length; i++) {
        if (!_mealItemDoneOn(date, m.id, i)) continue;
        done++;
        final it = m.items[i];
        if (it.proteinG == null || it.kcal == null) {
          hasMacros = false;
        } else {
          itemP += it.proteinG!;
          itemK += it.kcal!;
        }
      }
      if (done == 0) continue;
      if (hasMacros) {
        protein += itemP;
        kcal += itemK;
      } else {
        protein += (m.proteinG * done / m.items.length).round();
        kcal += (m.kcal * done / m.items.length).round();
      }
    }
    return (protein, kcal);
  }

  // ------------------------------------------------------------- extras ----
  /// How many times an off-plan food was added today.
  int extraCount(String id) => extraCountOn(keyFor(DateTime.now()), id);

  int extraCountOn(String date, String id) => _prefs.getInt(K.extra(date, id)) ?? 0;

  Future<void> bumpExtra(String id, {required bool up}) async {
    final cur = extraCount(id);
    final next = up ? cur + 1 : cur - 1;
    await _prefs.setInt(K.extra(keyFor(DateTime.now()), id), next.clamp(0, 40));
    notifyListeners();
    scheduleWidgetSync();
  }

  /// (protein, kcal) contributed by the extras of a given day.
  (int, int) _extrasMacros(String date) {
    var protein = 0;
    var kcal = 0;
    for (final x in _content.food.extras.items) {
      final n = extraCountOn(date, x.id);
      if (n == 0) continue;
      protein += x.proteinG * n;
      kcal += x.kcal * n;
    }
    return (protein, kcal);
  }

  /// Last [days] days of (protein, kcal), oldest first - for the week chart.
  List<({String date, int protein, int kcal})> weekMacros({int days = 7}) {
    final out = <({String date, int protein, int kcal})>[];
    for (var i = days - 1; i >= 0; i--) {
      final key = keyFor(DateTime.now().subtract(Duration(days: i)));
      out.add((date: key, protein: proteinOn(key), kcal: kcalOn(key)));
    }
    return out;
  }

  // workouts
  bool setDoneToday(String exId, int idx) =>
      _prefs.getBool(K.setDone(K.date(), exId, idx)) ?? false;
  Future<void> toggleSet(String exId, int idx) async {
    await _prefs.setBool(K.setDone(K.date(), exId, idx), !setDoneToday(exId, idx));
    notifyListeners();
    scheduleWidgetSync();
  }

  int setsDone(String dayId) => setsDoneOn(K.date(), dayId);

  /// Ticked sets of [dayId] on an arbitrary day - what the weekly report needs.
  int setsDoneOn(String date, String dayId) {
    final d = _content.workout.days.where((e) => e.id == dayId).toList();
    if (d.isEmpty) return 0;
    var n = 0;
    for (final ex in d.first.exercises) {
      for (var i = 0; i < ex.sets; i++) {
        if (_prefs.getBool(K.setDone(date, ex.id, i)) ?? false) n++;
      }
    }
    return n;
  }

  bool dayDoneToday(String dayId) =>
      _prefs.getBool(K.dayDone(K.date(), dayId)) ?? false;
  Future<void> toggleDayDone(String dayId) async {
    await _prefs.setBool(K.dayDone(K.date(), dayId), !dayDoneToday(dayId));
    notifyListeners();
    scheduleWidgetSync();
  }

  // ---------------------------------------------------------- exam mode ----
  /// "Study first": keeps only the three sessions that build the V.
  bool get examModeOn => _prefs.getBool(K.examMode) ?? false;

  /// False when the loaded content predates exam mode (v4 and older).
  bool get examModeAvailable => !_content.examMode.isEmpty;

  Future<void> setExamMode(bool on) async {
    await _prefs.setBool(K.examMode, on);
    notifyListeners();
    scheduleWidgetSync();
  }

  /// Rest days always stay; exam mode only drops training days it does not keep.
  bool dayIsActive(WorkoutDay d) =>
      !examModeOn || d.isRest || _content.examMode.keeps(d.id);

  /// Training sessions that count towards this week's target.
  List<WorkoutDay> get activeTrainingDays =>
      _content.workout.days.where((d) => !d.isRest && dayIsActive(d)).toList();

  int get weeklySessionTarget => activeTrainingDays.length;

  // -------------------------------------------------------- growth sleep ----
  /// Bedtime logged for [date] as `HH:MM`, or null when nothing was entered.
  String? sleepTimeOn(String date) => _prefs.getString(K.sleep(date));

  String? get sleepTimeToday => sleepTimeOn(K.date());

  /// Records last night's bedtime; anything that is not `HH:MM` is ignored.
  Future<void> setSleepTime(String hhmm) async {
    final s = hhmm.trim();
    if (minutesOfDay(s) == null) return;
    await _prefs.setString(K.sleep(K.date()), s);
    notifyListeners();
    scheduleWidgetSync();
  }

  Future<void> clearSleepTime() async {
    await _prefs.remove(K.sleep(K.date()));
    notifyListeners();
    scheduleWidgetSync();
  }

  /// True when the logged bedtime is at or before the growth-hormone cutoff.
  bool sleepOnTimeOn(String date) {
    final t = sleepTimeOn(date);
    if (t == null) return false;
    return bedtimeOnTime(bedtime: t, target: _content.sleep.target);
  }

  bool get sleepOnTimeToday => sleepOnTimeOn(K.date());

  /// Nights in a row inside the window, ending with the most recent logged one.
  ///
  /// Today with nothing logged yet does not break the streak; a late night does.
  int sleepStreak() {
    final flags = <bool>[];
    for (var i = 0; i < 400; i++) {
      final key = keyFor(DateTime.now().subtract(Duration(days: i)));
      final t = sleepTimeOn(key);
      if (t == null) {
        if (i == 0) continue; // this morning not filled in yet
        break;
      }
      flags.add(bedtimeOnTime(bedtime: t, target: _content.sleep.target));
    }
    return leadingStreak(flags);
  }

  // ------------------------------------------------------------ check-in ----
  int? checkinOn(String date) => _prefs.getInt(K.checkin(date));

  int? get checkinToday => checkinOn(K.date());

  Future<void> setCheckin(int level) async {
    await _prefs.setInt(K.checkin(K.date()), level.clamp(1, 5));
    notifyListeners();
    scheduleWidgetSync();
  }

  CheckInLevel? get checkinLevelToday => _content.checkin.levelFor(checkinToday);

  /// Sets to drop from every exercise today, from the morning rating.
  /// 99 means "do not train at all" (ill or wiped out).
  int get setsToDropToday {
    if (_content.checkin.isEmpty) return 0;
    final v = checkinToday;
    if (v == null) return 0;
    if (v <= 1) return 99;
    return _content.checkin.isLow(v) ? 1 : 0;
  }

  /// Several low days in a row -> suggest a deload week instead of pushing.
  bool get deloadSuggested {
    final cfg = _content.checkin;
    if (cfg.isEmpty || cfg.deloadAfterDays <= 0) return false;
    for (var i = 0; i < cfg.deloadAfterDays; i++) {
      if (!cfg.isLow(checkinOn(keyFor(DateTime.now().subtract(Duration(days: i)))))) return false;
    }
    return true;
  }

  // -------------------------------------------------- protein price tool ----
  /// Currency symbol: what the user typed, else the content default.
  String get currency {
    final saved = _prefs.getString(K.currency)?.trim() ?? '';
    if (saved.isNotEmpty) return saved;
    final d = _content.food.priceTool.currencyDefault.t(_isArabic);
    return d.isEmpty ? (_isArabic ? 'ج.م' : 'EGP') : d;
  }

  Future<void> setCurrency(String s) async {
    final v = s.trim();
    if (v.isEmpty) {
      await _prefs.remove(K.currency);
    } else {
      await _prefs.setString(K.currency, v.length > 8 ? v.substring(0, 8) : v);
    }
    notifyListeners();
  }

  /// Reads a double defensively: SharedPreferences hands back an int when a
  /// whole number was stored on some platforms.
  double? priceOf(String id) {
    final v = _prefs.get(K.price(id));
    return v is num ? v.toDouble() : null;
  }

  Future<void> setPrice(String id, double? value) async {
    if (value == null || value <= 0 || !value.isFinite) {
      await _prefs.remove(K.price(id));
    } else {
      await _prefs.setDouble(K.price(id), value.clamp(0.01, 1000000));
    }
    notifyListeners();
  }

  /// Every priceable source together with the local price the user typed.
  List<SourcePrice> get pricedSources => [
        for (final s in _content.food.priceableSources)
          SourcePrice(
            id: s.id,
            proteinPerUnitG: s.proteinPerUnitG,
            maxUnits: s.maxUnits > 0 ? s.maxUnits : double.infinity,
            price: priceOf(s.id),
          )
      ];

  /// Priced sources, cheapest protein first.
  List<SourcePrice> get rankedSources => [...pricedSources.where((s) => s.priced)]
    ..sort((a, b) => a.costPerGram!.compareTo(b.costPerGram!));

  /// Cheapest basket that reaches today's protein target.
  Basket get proteinBasket =>
      cheapestBasket(sources: pricedSources, targetG: _content.food.proteinTarget.toDouble());

  // ------------------------------------------------------- backpack load ----
  /// Bodyweight for the loading window: the last logged weight wins, otherwise
  /// the middle of the profile range in the content file.
  double get bodyKg {
    final logged = lastLogValue(K.measure('weight'));
    if (logged != null && logged >= 25 && logged <= 300) return logged.toDouble();
    final r = _content.meta.weightKg;
    if (r.length == 2 && r[0] > 0) return (r[0] + r[1]) / 2.0;
    return 80;
  }

  double backpackLoadKg({required int bottles, required double sandFraction}) {
    final cfg = _content.backpackLoad;
    return backpackKg(
      bottles: bottles,
      bottleMl: cfg.bottleMl.toDouble(),
      sandFraction: sandFraction,
      waterKgPerL: cfg.waterKgPerL,
      sandKgPerL: cfg.sandKgPerL,
      bagKg: cfg.bagKg,
    );
  }

  ({double min, double max}) get safeLoadKg =>
      loadRangeKg(bodyKg: bodyKg, bodyPct: _content.backpackLoad.bodyPct);

  // ------------------------------------------------- monthly checkpoints ----
  String get monthKey => K.ymOf(DateTime.now());

  bool monthlyDone(String id, [String? ym]) =>
      _prefs.getBool(K.monthly(id, ym ?? monthKey)) ?? false;

  Future<void> toggleMonthly(String id, [String? ym]) async {
    final key = K.monthly(id, ym ?? monthKey);
    await _prefs.setBool(key, !(_prefs.getBool(key) ?? false));
    notifyListeners();
  }

  /// True from the checkpoint day (the 15th) until the photo is ticked off.
  bool get photoDue =>
      _content.progress.photoCheckpoint.isDueOn(DateTime.now()) && !monthlyDone('photo');

  // --------------------------------------------------------- safety gates ----
  bool gateAcked(String id) => _prefs.getBool(K.gate(id)) ?? false;

  Future<void> ackGate(String id) async {
    await _prefs.setBool(K.gate(id), true);
    notifyListeners();
  }

  /// The briefing that still has to be acknowledged before training [day].
  SafetyGate? pendingGateFor(WorkoutDay day) {
    final g = _content.workout.gateForDay(day);
    if (g == null || g.id.isEmpty || gateAcked(g.id)) return null;
    return g;
  }

  // -------------------------------------------------------- weekly report ----
  /// Adherence over the last [days] days, compared with the [days] before.
  WeekReport weeklyReport({int days = 7}) {
    final cfg = _content.report;
    String key(int i) => keyFor(DateTime.now().subtract(Duration(days: i)));

    double meanOf(int from, int to, double Function(String date) f) {
      var sum = 0.0;
      for (var i = from; i < to; i++) {
        sum += f(key(i));
      }
      final n = to - from;
      return n <= 0 ? 0 : sum / n;
    }

    double waterOn(String d) => share(waterTotalOn(d), _content.water.goalMl);
    double proteinOnDay(String d) => share(proteinOn(d), _content.food.proteinTarget);
    double routineOn(String d) {
      final tasks = _content.routine;
      if (tasks.isEmpty) return 0;
      return share(
          tasks.where((r) => _prefs.getBool(K.task(d, r.id)) ?? false).length, tasks.length);
    }

    // Training is counted in sets, and only over days that count: rest days
    // and days dropped by exam mode are never held against you.
    ({double done, double total}) trainingIn(int from, int to) {
      var done = 0.0;
      var total = 0.0;
      for (var i = from; i < to; i++) {
        final d = key(i);
        final parsed = DateTime.tryParse(d);
        if (parsed == null) continue;
        final day = _content.workout.dayForWeekday(parsed.weekday);
        if (day == null || day.isRest || !dayIsActive(day)) continue;
        total += day.totalSets;
        done += setsDoneOn(d, day.id);
      }
      return (done: done, total: total);
    }

    ({int logged, int onTime}) sleepIn(int from, int to) {
      var logged = 0;
      var onTime = 0;
      for (var i = from; i < to; i++) {
        final t = sleepTimeOn(key(i));
        if (t == null) continue;
        logged++;
        if (bedtimeOnTime(bedtime: t, target: _content.sleep.target)) onTime++;
      }
      return (logged: logged, onTime: onTime);
    }

    final tNow = trainingIn(0, days);
    final tPrev = trainingIn(days, days * 2);
    final sNow = sleepIn(0, days);
    final sPrev = sleepIn(days, days * 2);

    final rows = <WeekRow>[
      WeekRow(
        id: 'water',
        value: meanOf(0, days, waterOn),
        previous: meanOf(days, days * 2, waterOn),
        target: _content.water.goalMl > 0 ? cfg.waterTarget : 0,
      ),
      WeekRow(
        id: 'protein',
        value: meanOf(0, days, proteinOnDay),
        previous: meanOf(days, days * 2, proteinOnDay),
        target: _content.food.proteinTarget > 0 ? cfg.proteinTarget : 0,
      ),
      WeekRow(
        id: 'routine',
        value: meanOf(0, days, routineOn),
        previous: meanOf(days, days * 2, routineOn),
        target: _content.routine.isEmpty ? 0 : cfg.routineTarget,
      ),
      WeekRow(
        id: 'training',
        value: share(tNow.done, tNow.total),
        previous: share(tPrev.done, tPrev.total),
        // No training days at all in either window -> nothing to score.
        target: (tNow.total > 0 || tPrev.total > 0) ? cfg.trainingTarget : 0,
      ),
      WeekRow(
        id: 'sleep',
        value: sNow.logged == 0 ? 0 : share(sNow.onTime, days),
        previous: sPrev.logged == 0 ? 0 : share(sPrev.onTime, days),
        target: (sNow.logged == 0 && sPrev.logged == 0) ? 0 : cfg.sleepTarget,
      ),
    ];

    var sessionsDone = 0;
    for (var i = 0; i < days; i++) {
      final d = key(i);
      final parsed = DateTime.tryParse(d);
      if (parsed == null) continue;
      final day = _content.workout.dayForWeekday(parsed.weekday);
      if (day == null || day.isRest || !dayIsActive(day)) continue;
      if (day.totalSets > 0 && setsDoneOn(d, day.id) >= day.totalSets) sessionsDone++;
    }

    return WeekReport(
      days: days,
      rows: rows,
      records: recordsIn(days),
      sessionsDone: sessionsDone,
      sessionsTarget: weeklySessionTarget,
      sleepLogged: sNow.logged,
      sleepOnTime: sNow.onTime,
    );
  }

  /// Personal records set inside the last [days] days, across the strength log.
  int recordsIn(int days) {
    var n = 0;
    for (final e in _content.progress.strengthExercises) {
      num? best;
      for (final entry in logFor(K.strength(e.id))) {
        final v = entry['v'];
        if (v is! num) continue;
        final isRecord = best == null || v > best;
        if (isRecord) best = v;
        if (!isRecord) continue;
        final ago = daysAgo('${entry['d']}');
        if (ago >= 0 && ago < days) n++;
      }
    }
    return n;
  }

  /// Whole days between [dateKey] and today (negative for a future date).
  int daysAgo(String dateKey) {
    final d = DateTime.tryParse(dateKey);
    if (d == null) return -1;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
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

  /// True when a day "counts": 60% of the water goal **or** any routine task.
  ///
  /// Uses [waterTotalOn] (not the raw quick-add counter) so a day filled in
  /// through the slot checklist counts exactly like one filled through the
  /// quick-add buttons - otherwise a perfectly good day breaks the streak.
  bool dayCounts(String dateKey) {
    if (waterTotalOn(dateKey) >= _content.water.goalMl * 0.6) return true;
    return _content.routine.any((r) => _prefs.getBool(K.task(dateKey, r.id)) ?? false);
  }

  String keyFor(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Consecutive "counted" days ending today (today is allowed to be empty).
  int streak() {
    var n = 0;
    for (var i = 0; i < 400; i++) {
      final ok = dayCounts(keyFor(DateTime.now().subtract(Duration(days: i))));
      if (ok) {
        n++;
      } else if (i > 0) {
        break;
      }
      // i == 0 and not done yet: keep looking, today must not break the streak.
    }
    return n;
  }

  Future<void> wipeAllData() async {
    // Language, theme and the currency symbol are settings, not training data.
    final keys = _prefs
        .getKeys()
        .where((k) => k != K.lang && k != K.theme && k != K.currency)
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }
}
