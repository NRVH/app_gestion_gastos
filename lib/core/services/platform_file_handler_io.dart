import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Plataforma móvil - descarga e instala APKs
class PlatformFileHandler {
  static Future<void> downloadAndSaveApk({
    required String url,
    required String version,
    required Function(double) onProgress,
    required Future<void> Function(String path) saveBytes,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'app-update-$version.apk';
    final file = File('${tempDir.path}/$fileName');

    // Si ya existe, eliminar
    if (await file.exists()) {
      await file.delete();
    }

    return;
  }

  static Future<void> writeApkFile(String path, List<int> bytes) async {
    final file = File(path);
    await file.writeAsBytes(bytes);
  }

  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  static Future<int> getFileSize(String path) async {
    return await File(path).length();
  }

  static Future<void> openInstaller(String path) async {
    await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
  }

  static Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }
}
