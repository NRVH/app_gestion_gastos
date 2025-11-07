import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';

// Imports condicionales para evitar errores en Web
// dart:io no está disponible en Web
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'
    if (dart.library.html) 'package:open_filex/open_filex.dart';

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
    // En Web, no tiene sentido verificar actualizaciones de APK
    // Las apps web se actualizan automáticamente al refrescar
    if (kIsWeb) {
      print('🌐 [Update] En Web no se verifica actualizaciones - Se actualiza automáticamente');
      return null;
    }
    
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
      print('📱 [Update] PackageInfo - version: ${packageInfo.version}, buildNumber: ${packageInfo.buildNumber}');
      final currentVersion = Version.parse(packageInfo.version);
      print('📱 [Update] Versión actual parseada: $currentVersion');

      // Consultar GitHub API para obtener el último release
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout al consultar GitHub API. Verifica tu conexión a internet.');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(json);
        
        print('🆕 [Update] Última versión en GitHub: ${updateInfo.version}');
        
        // Verificar que el APK esté disponible
        if (updateInfo.downloadUrl.isEmpty) {
          print('⚠️ [Update] No hay APK disponible en el release');
          // Limpiar caché de error previo
          _cachedUpdate = null;
          await _clearCachedUpdate();
          throw Exception('No se encontró APK en el release de GitHub');
        }
        
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
      } else if (response.statusCode == 404) {
        print('❌ [Update] No se encontró ningún release en GitHub');
        // Limpiar caché de actualización previa que ya no es válida
        _cachedUpdate = null;
        await _clearCachedUpdate();
        throw Exception('No hay releases publicados en GitHub');
      } else if (response.statusCode == 403) {
        print('❌ [Update] Límite de rate limit de GitHub API excedido');
        // No limpiar caché aquí, puede ser temporal
        throw Exception('Demasiadas solicitudes. Intenta más tarde.');
      } else {
        print('❌ [Update] Error en API de GitHub: ${response.statusCode}');
        // Limpiar caché en caso de errores persistentes del servidor
        _cachedUpdate = null;
        await _clearCachedUpdate();
        throw Exception('Error del servidor de GitHub (${response.statusCode})');
      }
    } on TimeoutException catch (e) {
      print('❌ [Update] Timeout: $e');
      // Limpiar caché en caso de timeouts persistentes
      _cachedUpdate = null;
      await _clearCachedUpdate();
      throw Exception('Tiempo de espera agotado. Intenta de nuevo.');
    } on FormatException catch (e) {
      print('❌ [Update] Error parseando respuesta: $e');
      // Limpiar caché si la respuesta es inválida
      _cachedUpdate = null;
      await _clearCachedUpdate();
      throw Exception('Error procesando la respuesta de GitHub');
    } catch (e) {
      print('❌ [Update] Error inesperado: $e');
      // Limpiar caché en caso de errores inesperados
      _cachedUpdate = null;
      await _clearCachedUpdate();
      rethrow;
    }
  }

  /// Descarga e instala la actualización
  /// Solo funciona en Android/iOS, no disponible en Web
  Future<void> downloadAndInstall(
    UpdateInfo updateInfo, 
    void Function(double progress) onProgress,
  ) async {
    // En Web, esta función no hace nada (las apps web se actualizan automáticamente)
    if (kIsWeb) {
      print('🌐 [Update] Descarga no disponible en Web');
      throw Exception('La descarga de actualizaciones no está disponible en Web');
    }
    
    try {
      if (updateInfo.downloadUrl.isEmpty) {
        throw Exception('URL de descarga no disponible');
      }

      print('⬇️ [Update] Descargando APK desde: ${updateInfo.downloadUrl}');
      
      // Importar dart:io solo cuando no es Web
      // ignore: depend_on_referenced_packages
      final io = await import('dart:io');
      
      // Obtener directorio temporal
      final tempDir = await getTemporaryDirectory();
      final fileName = 'app-update-${updateInfo.version}.apk';
      final filePath = '${tempDir.path}/$fileName';
      
      // Crear archivo usando reflexión para evitar import directo de dart:io
      final file = io.File(filePath);

      // Si ya existe el archivo, eliminarlo primero
      if (await file.exists()) {
        await file.delete();
        print('🗑️ [Update] APK anterior eliminado');
      }

      // Descargar con progreso
      final client = http.Client();
      final request = await client.send(
        http.Request('GET', Uri.parse(updateInfo.downloadUrl)),
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          client.close();
          throw Exception('Tiempo de descarga agotado. Verifica tu conexión.');
        },
      );

      if (request.statusCode != 200) {
        client.close();
        throw Exception('Error al descargar APK (código ${request.statusCode})');
      }

      final contentLength = request.contentLength ?? 0;
      if (contentLength == 0) {
        print('⚠️ [Update] Tamaño del archivo desconocido');
      }
      
      var receivedBytes = 0;
      final bytes = <int>[];

      try {
        await for (var chunk in request.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;
          
          if (contentLength > 0) {
            final progress = receivedBytes / contentLength;
            onProgress(progress);
            if (receivedBytes % (1024 * 1024) == 0 || progress == 1.0) { // Log cada MB
              print('⬇️ [Update] Progreso: ${(progress * 100).toStringAsFixed(1)}% (${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB)');
            }
          }
        }
      } catch (e) {
        client.close();
        throw Exception('Error durante la descarga: $e');
      }

      client.close();

      // Verificar que se descargó algo
      if (bytes.isEmpty) {
        throw Exception('El archivo descargado está vacío');
      }

      // Guardar archivo
      await file.writeAsBytes(bytes);
      final fileSize = await file.length();
      print('✅ [Update] APK descargado: ${file.path} (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');

      // Verificar que el archivo existe y tiene contenido
      if (!await file.exists()) {
        throw Exception('Error al guardar el archivo APK');
      }

      // Instalar APK
      print('📦 [Update] Abriendo instalador...');
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      
      if (result.type == ResultType.done) {
        print('✅ [Update] Instalador abierto exitosamente');
      } else if (result.type == ResultType.noAppToOpen) {
        throw Exception('No se puede abrir el instalador. Verifica los permisos.');
      } else if (result.type == ResultType.fileNotFound) {
        throw Exception('Archivo APK no encontrado después de la descarga');
      } else {
        print('⚠️ [Update] Resultado: ${result.type} - ${result.message}');
        throw Exception(result.message ?? 'Error desconocido al abrir el instalador');
      }
      
    } on TimeoutException catch (e) {
      print('❌ [Update] Timeout durante descarga: $e');
      throw Exception('Descarga muy lenta o conexión inestable');
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

  /// Limpia la actualización en caché (método interno)
  Future<void> _clearCachedUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUpdateKey);
  }

  /// Limpia la actualización en caché (método público)
  Future<void> clearCachedUpdate() async {
    _cachedUpdate = null;
    await _clearCachedUpdate();
  }

  /// Obtiene la actualización en caché
  UpdateInfo? get cachedUpdate => _cachedUpdate;

  /// Verifica si hay actualización disponible en caché
  bool get hasUpdateAvailable => _cachedUpdate != null;

  /// Muestra una notificación local cuando hay actualización disponible
  void showUpdateNotification(UpdateInfo updateInfo) {
    // Por ahora solo log, se puede implementar notificación local más adelante
    print('🔔 [Update] Notificación: Nueva versión ${updateInfo.version} disponible');
    // TODO: Implementar notificación local usando flutter_local_notifications
    // si se desea una notificación más prominente
  }
}
