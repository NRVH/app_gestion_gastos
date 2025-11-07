/// Plataforma Web - sin soporte para descargas de APK
class PlatformFileHandler {
  static Future<void> downloadAndSaveApk({
    required String url,
    required String version,
    required Function(double) onProgress,
    required Future<void> Function(String path) saveBytes,
  }) async {
    throw UnsupportedError('La descarga de APK no está soportada en Web');
  }

  static Future<void> writeApkFile(String path, List<int> bytes) async {
    throw UnsupportedError('Escritura de archivos no soportada en Web');
  }

  static Future<bool> fileExists(String path) async {
    return false;
  }

  static Future<int> getFileSize(String path) async {
    return 0;
  }

  static Future<void> openInstaller(String path) async {
    throw UnsupportedError('El instalador no está disponible en Web');
  }

  static Future<dynamic> getTempDirectory() async {
    throw UnsupportedError('Directorio temporal no disponible en Web');
  }
}
