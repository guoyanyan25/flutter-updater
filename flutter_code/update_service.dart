import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// 版本更新服务
/// 用法：在首页 initState 里调用  UpdateService.checkForUpdate(context);
class UpdateService {
  // TODO: 改成你自己的 version.json 地址
  // 方式一：raw 直链（简单）
  static const String _versionUrl =
      'https://raw.githubusercontent.com/guoyanyan25/flutter-updater/main/version.json';
  // 方式二：GitHub Pages（更稳定，推荐）
  // static const String _versionUrl =
  //     'https://你的用户名.github.io/flutter-updater/version.json';

  /// 启动检测，建议在首页第一帧渲染完后调用
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final resp = await http.get(Uri.parse(_versionUrl)).timeout(
            const Duration(seconds: 10),
          );
      if (resp.statusCode != 200) return;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final latestVersion = json['latest_version'] as String;
      final latestBuild = json['latest_build_number'] as int? ?? 0;
      final minVersion = json['min_required_version'] as String;
      final minBuild = json['min_required_build_number'] as int? ?? 0;
      final force = json['force_update'] == true;
      final notes = json['release_notes'] as String? ?? '';
      final apkUrl = json['apk_url'] as String? ?? '';
      final sha256 = json['apk_sha256'] as String? ?? '';

      // 是否已有更新版本
      final hasUpdate = _isNewer(latestVersion, latestBuild, currentVersion, currentBuild);
      // 是否低于最低要求版本（需要强制更新）
      final isTooOld = !_isNewer(currentVersion, currentBuild, minVersion, minBuild) &&
          currentVersion != minVersion;

      if (hasUpdate) {
        _showUpdateDialog(
          context,
          latest: latestVersion,
          notes: notes,
          force: force || isTooOld,
          apkUrl: apkUrl,
          sha256: sha256,
        );
      }
    } catch (e) {
      // 网络失败/JSON 解析失败一律静默处理，不干扰用户
      debugPrint('检查更新失败: $e');
    }
  }

  /// 语义化版本比较：返回 true 表示 latest 更新
  static bool _isNewer(String latest, int latestBuild, String current, int currentBuild) {
    final a = latest.split('.').map(int.parse).toList();
    final b = current.split('.').map(int.parse).toList();
    for (var i = 0; i < a.length; i++) {
      if (i >= b.length || a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    // 版本号相同则比较 buildNumber
    return latestBuild > currentBuild;
  }

  /// 显示更新弹窗
  static void _showUpdateDialog(
    BuildContext context, {
    required String latest,
    required String notes,
    required bool force,
    required String apkUrl,
    required String sha256,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (_) => AlertDialog(
        title: Text('发现新版本 v$latest'),
        content: Text(notes),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后再说'),
            ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (Platform.isAndroid && apkUrl.isNotEmpty) {
                await _downloadAndInstall(apkUrl, sha256);
              } else {
                // iOS 或其他：跳外部商店
                if (apkUrl.isNotEmpty) {
                  await launchUrl(Uri.parse(apkUrl),
                      mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 下载 APK 并调用系统安装器（仅 Android）
  static Future<void> _downloadAndInstall(String url, String expectedSha256) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';
      final file = File(filePath);

      final req = http.Request('GET', Uri.parse(url));
      final streamedResp = await http.Client().send(req);
      final total = streamedResp.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();
      await for (final chunk in streamedResp.stream) {
        sink.add(chunk);
        received += chunk.length;
      }
      await sink.close();

      // TODO: 可选 - 校验 sha256
      // final bytes = await file.readAsBytes();
      // final digest = sha256.convert(bytes).toString();
      // if (expectedSha256.isNotEmpty && digest != expectedSha256) {
      //   throw Exception('APK 校验失败');
      // }

      await OpenFilex.open(filePath);
    } catch (e) {
      debugPrint('下载安装失败: $e');
    }
  }
}
