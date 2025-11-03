import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';
import 'package:open_filex/open_filex.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String changelog;
  final String publishedAt;
  final int? assetSize;
  final String tagName;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.publishedAt,
    this.assetSize,
    required this.tagName,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    // Buscar el asset APK
    String? apkUrl;
    int? apkSize;
    
    if (json['assets'] != null && json['assets'] is List) {
      for (var asset in json['assets']) {
        if (asset['name'] != null && 
            asset['name'].toString().toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'];
          apkSize = asset['size'];
          break;
        }
      }
    }

    return UpdateInfo(
      version: json['tag_name']?.toString().replaceFirst('v', '') ?? '0.0.0',
      downloadUrl: apkUrl ?? '',
      changelog: json['body'] ?? 'Sin descripción',
      publishedAt: json['published_at'] ?? '',
      assetSize: apkSize,
      tagName: json['tag_name'] ?? '',
    );
  }

  String get formattedSize {
    if (assetSize == null) return 'Desconocido';
    final mb = assetSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(publishedAt);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }
}

class UpdateService {
  static const String _githubOwner = 'NRVH';
  static const String _githubRepo = 'app_gestion_gastos';
  static const String _lastCheckKey = 'last_update_check';
  static const String _cachedUpdateKey = 'cached_update_info';
  
  // Cache de actualización disponible
  UpdateInfo? _cachedUpdate;
  DateTime? _lastCheck;

  /// Verifica si hay una nueva versión disponible
  Future<UpdateInfo?> checkForUpdates({bool forceCheck = false}) async {
    try {
      // Si ya tenemos una actualización en caché y no es forzado, retornarla
      if (!forceCheck && _cachedUpdate != null) {
        print('📦 [Update] Usando actualización en caché: ${_cachedUpdate!.version}');
        return _cachedUpdate;
      }

      // Verificar si debemos hacer check (cada 24h)
      if (!forceCheck && !_shouldCheckForUpdates()) {
        print('⏰ [Update] Check muy reciente, saltando verificación');
        return _cachedUpdate;
      }

      print('🔍 [Update] Verificando actualizaciones en GitHub...');
      
      // Obtener info de la app actual
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);
      print('📱 [Update] Versión actual: $currentVersion');

      // Consultar GitHub API para obtener el último release
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(json);
        
        print('🆕 [Update] Última versión en GitHub: ${updateInfo.version}');
        
        // Comparar versiones
        final latestVersion = Version.parse(updateInfo.version);
        if (latestVersion > currentVersion) {
          print('✨ [Update] ¡Nueva versión disponible!');
          _cachedUpdate = updateInfo;
          await _saveCachedUpdate(updateInfo);
          await _saveLastCheckTime();
          return updateInfo;
        } else {
          print('✅ [Update] App está actualizada');
          _cachedUpdate = null;
          await _clearCachedUpdate();
          await _saveLastCheckTime();
          return null;
        }
      } else {
        print('❌ [Update] Error en API de GitHub: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [Update] Error al verificar actualizaciones: $e');
      return null;
    }
  }

  /// Descarga e instala la actualización
  Future<void> downloadAndInstall(
    UpdateInfo updateInfo, 
    void Function(double progress) onProgress,
  ) async {
    try {
      if (updateInfo.downloadUrl.isEmpty) {
        throw Exception('URL de descarga no disponible');
      }

      print('⬇️ [Update] Descargando APK desde: ${updateInfo.downloadUrl}');
      
      // Obtener directorio temporal
      final tempDir = await getTemporaryDirectory();
      final fileName = 'app-update-${updateInfo.version}.apk';
      final file = File('${tempDir.path}/$fileName');

      // Descargar con progreso
      final request = await http.Client().send(
        http.Request('GET', Uri.parse(updateInfo.downloadUrl)),
      );

      if (request.statusCode != 200) {
        throw Exception('Error al descargar: ${request.statusCode}');
      }

      final contentLength = request.contentLength ?? 0;
      var receivedBytes = 0;
      final bytes = <int>[];

      await for (var chunk in request.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        
        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          onProgress(progress);
          print('⬇️ [Update] Progreso: ${(progress * 100).toStringAsFixed(1)}%');
        }
      }

      // Guardar archivo
      await file.writeAsBytes(bytes);
      print('✅ [Update] APK descargado: ${file.path}');

      // Instalar APK
      print('📦 [Update] Abriendo instalador...');
      final result = await OpenFilex.open(file.path);
      
      if (result.type != ResultType.done) {
        print('⚠️ [Update] Resultado de instalación: ${result.type} - ${result.message}');
      } else {
        print('✅ [Update] Instalador abierto exitosamente');
      }
      
    } catch (e) {
      print('❌ [Update] Error al descargar/instalar: $e');
      rethrow;
    }
  }

  /// Verifica si debe hacer check de actualizaciones (cada 24h)
  bool _shouldCheckForUpdates() {
    if (_lastCheck == null) return true;
    final now = DateTime.now();
    final difference = now.difference(_lastCheck!);
    return difference.inHours >= 24;
  }

  /// Guarda el tiempo del último check
  Future<void> _saveLastCheckTime() async {
    _lastCheck = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, _lastCheck!.toIso8601String());
  }

  /// Carga el tiempo del último check
  Future<void> loadLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString(_lastCheckKey);
    if (lastCheckStr != null) {
      _lastCheck = DateTime.parse(lastCheckStr);
    }
  }

  /// Guarda la actualización en caché
  Future<void> _saveCachedUpdate(UpdateInfo updateInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUpdateKey, jsonEncode({
      'version': updateInfo.version,
      'downloadUrl': updateInfo.downloadUrl,
      'changelog': updateInfo.changelog,
      'publishedAt': updateInfo.publishedAt,
      'assetSize': updateInfo.assetSize,
      'tagName': updateInfo.tagName,
    }));
  }

  /// Carga la actualización desde caché
  Future<void> loadCachedUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString(_cachedUpdateKey);
    if (cachedStr != null) {
      final json = jsonDecode(cachedStr);
      _cachedUpdate = UpdateInfo(
        version: json['version'],
        downloadUrl: json['downloadUrl'],
        changelog: json['changelog'],
        publishedAt: json['publishedAt'],
        assetSize: json['assetSize'],
        tagName: json['tagName'],
      );
      print('📦 [Update] Actualización cargada desde caché: ${_cachedUpdate!.version}');
    }
  }

  /// Limpia la actualización en caché
  Future<void> _clearCachedUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUpdateKey);
  }

  /// Obtiene la actualización en caché
  UpdateInfo? get cachedUpdate => _cachedUpdate;

  /// Verifica si hay actualización disponible en caché
  bool get hasUpdateAvailable => _cachedUpdate != null;
}
