import 'dart:convert';
import 'dart:io';

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

  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    this.abi = 'universal',
  });
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
    final tag = (j['tag_name'] ?? '').toString();
    final assets = (j['assets'] as List? ?? const []);
    String apkUrl = '';
    String versionJsonUrl = '';
    int size = 0;
    String chosenAbi = 'universal';
    String universalUrl = '';
    int universalSize = 0;
    String abiUrl = '';
    int abiSize = 0;

    for (final a in assets) {
      final am = (a as Map).cast<String, dynamic>();
      final name = (am['name'] ?? '').toString().toLowerCase();
      final url = (am['browser_download_url'] ?? '').toString();
      if (name.endsWith('.apk') && url.isNotEmpty) {
        final assetSize = (am['size'] as num?)?.toInt() ?? 0;
        if (abi.isNotEmpty && name.contains(abi.toLowerCase())) {
          abiUrl = url;
          abiSize = assetSize;
        } else if (name.contains('universal') || name == 'app-release.apk') {
          universalUrl = url;
          universalSize = assetSize;
        } else if (universalUrl.isEmpty) {
          universalUrl = url;
          universalSize = assetSize;
        }
      } else if (name == 'version.json') {
        versionJsonUrl = url;
      }
    }
    if (abiUrl.isNotEmpty) {
      apkUrl = abiUrl;
      size = abiSize;
      chosenAbi = abi;
    } else if (universalUrl.isNotEmpty) {
      apkUrl = universalUrl;
      size = universalSize;
      chosenAbi = 'universal';
    }
    if (apkUrl.isEmpty) {
      // fall back to the release web page
      apkUrl = (j['html_url'] ?? '').toString();
    }

    // Preferred: an explicit version.json asset published next to the APK.
    int versionCode = 0;
    String versionName = tag.replaceFirst('v', '');
    if (versionJsonUrl.isNotEmpty) {
      try {
        final r = await _dio.get<dynamic>(versionJsonUrl);
        final v = (r.data as Map).cast<String, dynamic>();
        versionCode = (v['versionCode'] as num?)?.toInt() ?? 0;
        versionName = (v['versionName'] ?? versionName).toString();
      } catch (_) {}
    }
    // Fallback: parse the tag  vMAJOR.MINOR.PATCH+CODE
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
    );
  }

  /// Downloads the APK into app-private external storage and returns the file.
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
    return out;
  }
}
