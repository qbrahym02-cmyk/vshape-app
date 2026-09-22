import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Network helpers: remote content file + GitHub-release based app updates.
class ContentService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
    headers: {'Accept': 'application/json', 'User-Agent': 'VSystemApp/1.0'},
  ));

  /// Fetch + parse the remote content JSON. Works with raw.githubusercontent,
  /// GitHub Pages, Drive "uc?export=download" links or any static JSON host.
  static Future<Map<String, dynamic>> fetch(String url) async {
    if (url.trim().isEmpty) throw Exception('empty url');
    var u = url.trim();
    // Google Drive sharing link -> direct download
    final drive = RegExp(r'drive\.google\.com/file/d/([\w-]+)').firstMatch(u);
    if (drive != null) {
      u = 'https://drive.google.com/uc?export=download&id=${drive.group(1)}';
    }
    final res = await _dio.get<String>(u, options: Options(responseType: ResponseType.plain));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = (res.data ?? '').trim();
    if (body.isEmpty) throw Exception('empty response');
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw Exception('not a JSON object');
    return decoded.cast<String, dynamic>();
  }
}

class ReleaseInfo {
  final String tagName;
  final String name;
  final int versionCode;
  final String versionName;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final String abi;

  /// True when [versionCode] is already free of the per-ABI offset.
  final bool codeIsNormalized;

  /// The release *asset* file name behind [apkUrl] ('' when unknown).
  /// Needed to find its line inside checksums.sha256.
  final String apkAssetName;

  /// The release's web page. What the UI should open when the release
  /// published no APK at all (in that case [apkUrl] stays empty).
  final String releaseUrl;

  /// URL of the checksums.sha256 asset published next to the APKs
  /// ('' when the release has none).
  final String checksumsUrl;

  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    this.abi = 'universal',
    this.codeIsNormalized = false,
    this.apkAssetName = '',
    this.releaseUrl = '',
    this.checksumsUrl = '',
  });

  /// True when [apkUrl] points at a real APK asset. It is '' for a release
  /// that published no APKs, and the download button must stay hidden -
  /// downloading the release *web page* and saving it as "update.apk" would
  /// only produce a cryptic installer failure.
  bool get hasDownloadableApk => apkUrl.toLowerCase().endsWith('.apk');

  /// The versionCode to compare against the installed build.
  ///
  /// `flutter build apk --split-per-abi` adds an ABI offset to the code baked
  /// into the APK (armeabi-v7a +1000, arm64-v8a +2000, x86_64 +3000), so a code
  /// read off a device has to be stripped. A code that comes from `version.json`
  /// - or from the `+N` part of a tag - is *already* the base code, and
  /// subtracting the offset again would make it negative and hide every future
  /// update. [codeIsNormalized] tells the two cases apart.
  int get normalizedCode => codeIsNormalized ? versionCode : versionCode - abiOffsetFor(abi);

  static int abiOffsetFor(String abi) {
    final a = abi.toLowerCase();
    if (a.contains('armeabi')) return 1000;
    if (a.contains('arm64')) return 2000;
    if (a.contains('x86_64')) return 3000;
    if (a.contains('x86')) return 4000;
    return 0;
  }

  /// Turns the versionCode reported by the OS into the base code that can be
  /// compared against a release.
  ///
  /// The number alone is ambiguous: a `--split-per-abi` APK carries
  /// `base + offset` while the *universal* APK keeps the plain base, and once
  /// base codes grow past 1000 the two ranges overlap. [flavor] settles it:
  /// the Kotlin side reads the `lib/<abi>/` folders of the installed APK and
  /// reports either "universal" (all ABIs shipped) or the single ABI it was
  /// built for.
  ///
  /// Legacy installs (<= 1.1.0) have no such channel; there the fallback only
  /// strips the offset when the result stays plausible, which was always true
  /// because their base codes were <= 7.
  static int normalizeInstalledCode({
    required int code,
    String flavor = '',
    String deviceAbi = '',
  }) {
    if (code <= 0) return code;
    final f = flavor.toLowerCase().trim();
    if (f == 'universal') return code;
    if (f.isNotEmpty) {
      final stripped = code - abiOffsetFor(f);
      return stripped >= 1 ? stripped : code;
    }
    final off = abiOffsetFor(deviceAbi);
    return code > off ? code - off : code;
  }
}

class UpdateService {
  /// GitHub repo used to publish new APK releases.
  static const String repo = 'qbrahym02-cmyk/vshape-app';
  static const String apiLatest = 'https://api.github.com/repos/$repo/releases/latest';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'VSystemApp/1.0'},
  ));

  static final _tagRe = RegExp(r'(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?');

  /// Returns null when there is no published release yet (or the network fails).
  ///
  /// When [abi] is given (e.g. "arm64-v8a") and the release publishes a
  /// per-ABI APK, that smaller file is preferred over the universal one.
  static Future<ReleaseInfo?> latest({String abi = ''}) async {
    final res = await _dio.get<dynamic>(apiLatest);
    if (res.statusCode != 200 || res.data == null) return null;
    final j = (res.data as Map).cast<String, dynamic>();

    // Preferred source of truth for the version: the version.json asset that CI
    // publishes next to the APKs.
    Map<String, dynamic>? versionJson;
    final vUrl = versionJsonUrlOf(j);
    if (vUrl.isNotEmpty) {
      try {
        final r = await _dio.get<dynamic>(vUrl);
        if (r.data is Map) versionJson = (r.data as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    return parseRelease(j, abi: abi, versionJson: versionJson);
  }

  /// URL of the `version.json` asset inside a release payload ('' when absent).
  static String versionJsonUrlOf(Map<String, dynamic> j) {
    for (final a in _list(j['assets'])) {
      if (a is! Map) continue;
      final am = a.cast<String, dynamic>();
      if ((am['name'] ?? '').toString().toLowerCase() == 'version.json') {
        return (am['browser_download_url'] ?? '').toString();
      }
    }
    return '';
  }

  /// Pure part of [latest]: turns a GitHub release payload into a [ReleaseInfo].
  ///
  /// Version resolution, in order:
  ///   1. the `version.json` asset published next to the APKs - CI writes the
  ///      *base* versionCode there, so it is already normalised;
  ///   2. the `+N` of the tag (`v1.0.4+5` -> 5), also a base code;
  ///   3. `MAJOR*10000 + MINOR*100 + PATCH` of the tag.
  /// In every case [ReleaseInfo.codeIsNormalized] is set, because nothing here
  /// ever carries a per-ABI offset.
  static ReleaseInfo parseRelease(
    Map<String, dynamic> j, {
    String abi = '',
    Map<String, dynamic>? versionJson,
  }) {
    final tag = (j['tag_name'] ?? '').toString();
    final releaseUrl = (j['html_url'] ?? '').toString();
    final assets = _list(j['assets']);

    // Asset names look like "V-System-arm64-v8a.apk": the ABI must match as a
    // whole segment so an x86 device never grabs the x86_64 file.
    final wanted = abi.toLowerCase().trim();
    bool matchesAbi(String lowerName) =>
        wanted.isNotEmpty && lowerName.endsWith('-$wanted.apk');

    const abiMarkers = [
      'arm64-v8a', 'armeabi-v7a', 'x86_64', 'armeabi', 'x86', 'universal'
    ];

    String universalUrl = '';
    int universalSize = 0;
    String universalName = '';
    String abiUrl = '';
    int abiSize = 0;
    String abiName = '';
    String checksumsUrl = '';

    for (final a in assets) {
      if (a is! Map) continue;
      final am = a.cast<String, dynamic>();
      final name = (am['name'] ?? '').toString();
      final lower = name.toLowerCase();
      final url = (am['browser_download_url'] ?? '').toString();
      final assetSize = (am['size'] as num?)?.toInt() ?? 0;
      if (lower == 'checksums.sha256' && url.isNotEmpty) {
        checksumsUrl = url;
      } else if (lower.endsWith('.apk') && url.isNotEmpty) {
        if (matchesAbi(lower)) {
          abiUrl = url;
          abiSize = assetSize;
          abiName = name;
        } else if (lower.contains('universal') || lower == 'app-release.apk') {
          universalUrl = url;
          universalSize = assetSize;
          universalName = name;
        } else if (universalUrl.isEmpty &&
            !abiMarkers.any((m) => lower.contains(m))) {
          // A name with no ABI marker at all ("app-release.apk",
          // "V-System.apk") is a plain universal build. A name that carries
          // some *other* ABI belongs to a different device: skip it.
          universalUrl = url;
          universalSize = assetSize;
          universalName = name;
        }
      }
    }

    String apkUrl;
    int size;
    String chosenAbi;
    String assetName;
    if (abiUrl.isNotEmpty) {
      apkUrl = abiUrl;
      size = abiSize;
      chosenAbi = abi;
      assetName = abiName;
    } else if (universalUrl.isNotEmpty) {
      apkUrl = universalUrl;
      size = universalSize;
      chosenAbi = 'universal';
      assetName = universalName;
    } else {
      // No APK in this release: keep the page URL separately so the UI can
      // still open it, but never pretend the page itself is downloadable.
      apkUrl = '';
      size = 0;
      chosenAbi = 'universal';
      assetName = '';
    }

    int versionCode = 0;
    String versionName = tag.replaceFirst(RegExp('^v'), '');
    final v = versionJson;
    if (v != null && v.isNotEmpty) {
      versionCode = (v['versionCode'] as num?)?.toInt() ?? 0;
      versionName = (v['versionName'] ?? versionName).toString();
    }
    if (versionCode == 0) {
      final m = _tagRe.firstMatch(tag);
      if (m != null) {
        versionName = '${m.group(1)}.${m.group(2)}.${m.group(3)}';
        versionCode = m.group(4) != null
            ? int.parse(m.group(4)!)
            : int.parse(m.group(1)!) * 10000 +
                int.parse(m.group(2)!) * 100 +
                int.parse(m.group(3)!);
      }
    }

    return ReleaseInfo(
      tagName: tag,
      name: (j['name'] ?? tag).toString(),
      versionCode: versionCode,
      versionName: versionName,
      notes: (j['body'] ?? '').toString(),
      apkUrl: apkUrl,
      apkSize: size,
      abi: chosenAbi,
      codeIsNormalized: true,
      apkAssetName: assetName,
      releaseUrl: releaseUrl,
      checksumsUrl: checksumsUrl,
    );
  }

  static List<dynamic> _list(dynamic v) => v is List ? v : const <dynamic>[];

  /// Downloads the APK into app-private external storage and returns the file.
  ///
  /// After the bytes land, [verifyDownload] checks them against the
  /// checksums.sha256 asset CI publishes next to the APKs - a truncated or
  /// corrupted file is deleted instead of being handed to the installer.
  static Future<File> download(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final out = File('${dir.path}/update-${info.tagName}.apk');
    if (out.existsSync()) await out.delete();
    await _dio.download(
      info.apkUrl,
      out.path,
      cancelToken: cancel,
      onReceiveProgress: (r, t) {
        if (onProgress != null && t > 0) onProgress(r / t);
      },
    );
    await verifyDownload(info, out);
    return out;
  }

  /// Pure: picks the hash line for [assetName] out of a `sha256sum` listing.
  static String expectedSha256(String checksums, String assetName) {
    if (assetName.isEmpty) return '';
    for (final line in checksums.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 &&
          parts[1] == assetName &&
          RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(parts[0])) {
        return parts[0].toLowerCase();
      }
    }
    return '';
  }

  /// sha256 of a byte list - kept separate so tests can exercise it cheaply.
  static String sha256OfBytes(List<int> bytes) => sha256.convert(bytes).toString();

  /// Compares the downloaded [f] with the published checksum and deletes it on
  /// a mismatch (then throws, so the UI shows the failure instead of the
  /// installer doing it later, cryptically). Skipped silently when the release
  /// ships no checksums asset - older releases never did.
  static Future<void> verifyDownload(ReleaseInfo info, File f) async {
    final url = info.checksumsUrl;
    if (url.isEmpty || !info.hasDownloadableApk) return;
    String sums;
    try {
      final r = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (r.statusCode != 200) return;
      sums = (r.data ?? '').trim();
    } catch (_) {
      return; // a checksum we cannot read must not block a good download
    }
    final expected = expectedSha256(sums, info.apkAssetName);
    if (expected.isEmpty) return;
    final digest = await sha256.bind(f.openRead()).first;
    if (digest.toString() != expected) {
      try {
        await f.delete();
      } catch (_) {}
      throw Exception(
          'checksum mismatch for ${info.apkAssetName} - download again');
    }
  }
}
