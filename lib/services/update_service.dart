import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 自动更新服务：从固定地址读取 version.json 比对版本，
/// 若有更新则下载 apk 并调起安装（覆盖安装，数据保留）。
///
/// 部署约定（GitHub 仓库 main 分支的 update/ 目录，raw 直链，URL 永久固定）：
///   version.json  -> {"versionCode": 12, "versionName": "1.0.0+12", "apk": "app-release.apk", "note": "更新说明"}
///   app-release.apk -> 最新安装包（与本机出包同名，覆盖推送即可）
class UpdateService {
  // GitHub raw 固定地址（仓库 update/ 目录）。改包只需覆盖这两个文件，URL 不变。
  static const String baseUrl =
      'https://raw.githubusercontent.com/deckardcnk-Sea/schedule_time_app/main/update/';

  /// 检查更新。返回 null 表示无更新或检查失败。
  static Future<UpdateInfo?> checkUpdate() async {
    try {
      final res = await http
          .get(Uri.parse('${baseUrl}version.json'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final info = UpdateInfo.fromJson(res.body);
      final pkg = await PackageInfo.fromPlatform();
      final current = int.tryParse(pkg.buildNumber) ?? 0;
      if (info.versionCode > current) return info;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 下载并安装最新 apk（覆盖安装）。返回是否成功调起安装器。
  static Future<bool> downloadAndInstall(UpdateInfo info) async {
    try {
      final url = '$baseUrl${info.apk}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 5));
      if (res.statusCode != 200) return false;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update_${info.versionCode}.apk');
      await file.writeAsBytes(res.bodyBytes);
      final result = await OpenFile.open(file.path,
          type: 'application/vnd.android.package-archive');
      // done / fileNotFound 之外，android 上 type=noAppToOpen 也表示已拉起系统安装器
      return result.type == ResultType.done ||
          result.type == ResultType.fileNotFound ||
          result.type == ResultType.noAppToOpen;
    } catch (_) {
      return false;
    }
  }
}

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apk;
  final String? note;
  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apk,
    this.note,
  });
  factory UpdateInfo.fromJson(String jsonStr) {
    final m = jsonDecode(jsonStr) as Map<String, dynamic>;
    return UpdateInfo(
      versionCode: m['versionCode'] as int,
      versionName: m['versionName'] as String,
      apk: m['apk'] as String,
      note: m['note'] as String?,
    );
  }
}
