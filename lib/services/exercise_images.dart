import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads and caches the exercise photos advertised by `content.json`.
///
/// Why download instead of bundling?
///   * 20 photos would add ~10-20 MB to an APK that is currently 22 MB.
///   * The photos then follow the remote content file: a better picture can be
///     published on GitHub without shipping a new APK at all.
///   * The vector poses stay as the instant placeholder, so the UI is never
///     empty - not while downloading and not offline on a fresh install.
class ExerciseImages {
  ExerciseImages._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
    headers: {'User-Agent': 'VSystemApp/1.0'},
  ));

  /// Bumped after every successful download so widgets can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Directory? _dir;
  static final Set<String> _inFlight = <String>{};
  static final Set<String> _failed = <String>{};

  static Future<Directory?> _cacheDir() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/eximg');
      if (!d.existsSync()) d.createSync(recursive: true);
      _dir = d;
      return d;
    } catch (_) {
      return null;
    }
  }

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  /// The cached file for [id], when it was downloaded for [url].
  ///
  /// The URL is stored next to the image (`<id>.url`) so that replacing a photo
  /// on GitHub (same path, new bytes) is picked up after a re-download.
  static Future<File?> cached(String id, {String url = ''}) async {
    final dir = await _cacheDir();
    if (dir == null) return null;
    final f = File('${dir.path}/${_safe(id)}.img');
    if (!f.existsSync()) return null;
    if (url.isNotEmpty) {
      final meta = File('${dir.path}/${_safe(id)}.url');
      if (meta.existsSync() && meta.readAsStringSync() != url) return null;
    }
    return f;
  }

  /// Synchronous best-effort check - used inside build() to avoid a flash.
  static File? cachedSync(String id, {String url = ''}) {
    final dir = _dir;
    if (dir == null) return null;
    final f = File('${dir.path}/${_safe(id)}.img');
    if (!f.existsSync()) return null;
    if (url.isNotEmpty) {
      final meta = File('${dir.path}/${_safe(id)}.url');
      if (meta.existsSync() && meta.readAsStringSync() != url) return null;
    }
    return f;
  }

  /// Warms the directory cache so [cachedSync] works on the very first frame.
  static Future<void> prime() async => _cacheDir();

  /// Downloads [url] for [id] once; returns true when a usable file exists.
  static Future<bool> ensure(String id, String url) async {
    if (url.isEmpty) return false;
    final have = await cached(id, url: url);
    if (have != null) return true;
    if (_inFlight.contains(id)) return false;
    _inFlight.add(id);
    try {
      final dir = await _cacheDir();
      if (dir == null) return false;
      final tmp = File('${dir.path}/${_safe(id)}.download');
      final out = File('${dir.path}/${_safe(id)}.img');
      await _dio.download(url, tmp.path);
      if (tmp.lengthSync() < 1024) {
        // an HTML error page, not an image
        await tmp.delete();
        _failed.add(id);
        return false;
      }
      if (out.existsSync()) await out.delete();
      await tmp.rename(out.path);
      await File('${dir.path}/${_safe(id)}.url').writeAsString(url);
      _failed.remove(id);
      revision.value++;
      return true;
    } catch (_) {
      _failed.add(id);
      return false;
    } finally {
      _inFlight.remove(id);
    }
  }

  static bool failed(String id) => _failed.contains(id);
  static bool downloading(String id) => _inFlight.contains(id);

  /// Downloads every missing photo (used by "download all" in Settings).
  static Future<int> ensureAll(Map<String, String> idToUrl,
      {void Function(int done, int total)? onProgress}) async {
    var done = 0;
    final entries = idToUrl.entries.toList();
    for (final e in entries) {
      if (e.value.isEmpty) {
        done++;
        continue;
      }
      await ensure(e.key, e.value);
      done++;
      onProgress?.call(done, entries.length);
    }
    revision.value++;
    return done;
  }

  /// Cached bytes on disk (for the diagnostics screen).
  static Future<int> cacheSize() async {
    final dir = await _cacheDir();
    if (dir == null) return 0;
    var total = 0;
    for (final f in dir.listSync()) {
      if (f is File && f.path.endsWith('.img')) total += f.lengthSync();
    }
    return total;
  }

  static Future<int> cachedCount() async {
    final dir = await _cacheDir();
    if (dir == null) return 0;
    return dir.listSync().whereType<File>().where((f) => f.path.endsWith('.img')).length;
  }

  static Future<void> clear() async {
    final dir = await _cacheDir();
    if (dir == null) return;
    for (final f in dir.listSync()) {
      try {
        f.deleteSync(recursive: true);
      } catch (_) {}
    }
    revision.value++;
  }
}