import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/native_bridge.dart';
import 'content_service.dart';

/// Owns the "is there a newer APK?" logic + the download/install flow.
class UpdateController extends ChangeNotifier {
  UpdateController(this._state);

  final AppState _state;

  bool _disposed = false;

  bool busy = false;
  bool downloading = false;
  double progress = 0;
  String? error;
  ReleaseInfo? latest;
  int currentCode = 1;
  String currentName = '1.0.0';
  File? downloaded;
  bool needsUnknownSources = false;
  CancelToken? _cancel;

  String _installedAbi = '';
  String _buildFlavor = '';

  /// ChangeNotifier throws in debug builds when a listener is notified after
  /// dispose; every notify in this class happens after an await, so a user
  /// leaving Settings mid-check would otherwise trip it.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Installed versionCode with the per-ABI offset removed - see
  /// [ReleaseInfo.normalizeInstalledCode] for why the build *flavour*
  /// (universal vs split) decides whether to subtract at all.
  int get normalizedCurrent => ReleaseInfo.normalizeInstalledCode(
        code: currentCode,
        flavor: _buildFlavor,
        deviceAbi: _installedAbi,
      );

  bool get hasUpdate =>
      latest != null &&
      latest!.hasDownloadableApk &&
      latest!.normalizedCode > normalizedCurrent;

  Future<void> loadCurrent() async {
    final p = await Native.packageInfo();
    currentCode = (p['versionCode'] as num?)?.toInt() ?? 1;
    currentName = (p['versionName'] ?? '1.0.0').toString();
    _installedAbi = await Native.deviceAbi();
    _buildFlavor = await Native.buildFlavor();
    _notify();
  }

  /// Pure decision (kept separate so it is testable): a file downloaded for a
  /// previous release must not be installed as if it were the new one.
  static bool isStaleDownload(ReleaseInfo? was, ReleaseInfo? now) =>
      was != null && now != null && was.tagName != now.tagName;

  Future<void> check({bool silent = false}) async {
    busy = true;
    error = null;
    _notify();
    try {
      await loadCurrent();
      final fresh = await UpdateService.latest(abi: await Native.deviceAbi());
      if (isStaleDownload(latest, fresh)) {
        // The user downloaded 1.1.0 but never installed it, and 1.2.0 is out:
        // drop the old file so "Install now" can never install the wrong APK.
        downloaded = null;
        progress = 0;
      }
      latest = fresh;
      if (latest == null && !silent) {
        error = _state.isArabic
            ? 'ما لقيت نسخة منشورة على GitHub (أو ما فيه إنترنت).'
            : 'No published release found on GitHub (or no internet).';
      }
    } catch (e) {
      if (!silent) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> download() async {
    final info = latest;
    if (info == null || !info.hasDownloadableApk) return false;
    downloading = true;
    progress = 0;
    error = null;
    _notify();
    _cancel = CancelToken();
    try {
      final f = await UpdateService.download(
        info,
        cancel: _cancel,
        onProgress: (p) {
          progress = p;
          _notify();
        },
      );
      downloaded = f;
      downloading = false;
      _notify();
      return true;
    } catch (e) {
      downloading = false;
      error = e.toString().replaceFirst('Exception: ', '');
      _notify();
      return false;
    }
  }

  void cancelDownload() {
    _cancel?.cancel('user');
    downloading = false;
    _notify();
  }

  Future<bool> install() async {
    final f = downloaded;
    if (f == null) return false;
    needsUnknownSources = !(await Native.canRequestUnknownSources());
    if (needsUnknownSources) {
      await Native.openUnknownSourcesSettings();
      _notify();
      return false;
    }
    final ok = await Native.installApk(f.path);
    _notify();
    return ok;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Small helper used by [main] to do a silent update check once per day.
class UpdateChecker {
  /// One GitHub call per [minInterval] while an update is already known.
  /// When nothing is pending we re-check after [freshInterval] instead, so a
  /// release published in the afternoon is offered the same day.
  static const minInterval = Duration(hours: 20);
  static const freshInterval = Duration(hours: 6);

  /// Pure decision logic (kept separate so it is testable without a device):
  /// both codes must already have the per-ABI offset stripped.
  static bool isNewer({required int latestCode, required int installedCode}) =>
      latestCode > installedCode;

  static Future<void> maybeNotify(AppState st) async {
    final prefs = st.prefs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(K.lastUpdateCheck) ?? 0;

    ReleaseInfo? info = st.pendingUpdate;
    final threshold =
        info == null ? freshInterval.inMilliseconds : minInterval.inMilliseconds;
    if (now - last >= threshold) {
      try {
        info = await UpdateService.latest(abi: await Native.deviceAbi());
      } catch (_) {
        info = st.pendingUpdate; // keep the previous result on a network error
      }
      await prefs.setInt(K.lastUpdateCheck, now);
    }
    if (info == null) return;

    final cur = await Native.versionCode();
    final installed = ReleaseInfo.normalizeInstalledCode(
      code: cur,
      flavor: await Native.buildFlavor(),
      deviceAbi: await Native.deviceAbi(),
    );

    if (info.hasDownloadableApk &&
        isNewer(latestCode: info.normalizedCode, installedCode: installed)) {
      // Deliberately *not* remembered as "seen": the green strip has to come
      // back on the next launch, otherwise an update silently never arrives.
      st.pendingUpdate = info;
      st.ping();
    } else if (st.pendingUpdate != null) {
      st.pendingUpdate = null;
      st.ping();
    }
  }
}
