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

  bool get hasUpdate =>
      latest != null && latest!.versionCode > currentCode && (latest!.apkUrl.isNotEmpty);

  Future<void> loadCurrent() async {
    final p = await Native.packageInfo();
    currentCode = (p['versionCode'] as num?)?.toInt() ?? 1;
    currentName = (p['versionName'] ?? '1.0.0').toString();
    notifyListeners();
  }

  Future<void> check({bool silent = false}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await loadCurrent();
      latest = await UpdateService.latest();
      if (latest == null && !silent) {
        error = _state.isArabic
            ? 'ما لقيت نسخة منشورة على GitHub (أو ما فيه إنترنت).'
            : 'No published release found on GitHub (or no internet).';
      }
    } catch (e) {
      if (!silent) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> download() async {
    final info = latest;
    if (info == null || info.apkUrl.isEmpty) return false;
    downloading = true;
    progress = 0;
    error = null;
    notifyListeners();
    _cancel = CancelToken();
    try {
      final f = await UpdateService.download(
        info,
        cancel: _cancel,
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      downloaded = f;
      downloading = false;
      notifyListeners();
      return true;
    } catch (e) {
      downloading = false;
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void cancelDownload() {
    _cancel?.cancel('user');
    downloading = false;
    notifyListeners();
  }

  Future<bool> install() async {
    final f = downloaded;
    if (f == null) return false;
    needsUnknownSources = !(await Native.canRequestUnknownSources());
    if (needsUnknownSources) {
      await Native.openUnknownSourcesSettings();
      notifyListeners();
      return false;
    }
    final ok = await Native.installApk(f.path);
    notifyListeners();
    return ok;
  }
}

/// Small helper used by [main] to do a silent update check once per day.
class UpdateChecker {
  static const _key = 'update_seen_code';

  static Future<void> maybeNotify(AppState st) async {
    final prefs = st.prefs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(K.lastUpdateCheck) ?? 0;
    if (now - last < const Duration(hours: 20).inMilliseconds) return;

    final info = await UpdateService.latest();
    await prefs.setInt(K.lastUpdateCheck, now);
    if (info == null) return;

    final cur = await Native.versionCode();
    if (info.versionCode > cur && (prefs.getInt(_key) ?? 0) < info.versionCode) {
      await prefs.setInt(_key, info.versionCode);
      st.pendingUpdate = info;
      st.ping();
    }
  }
}
