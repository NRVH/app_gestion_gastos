// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

import '../models/update_info.dart';

/// Servicio de actualizaciones para Android/iOS
class UpdateService {
  final String repoOwner;
  final String repoName;
  static const String _lastCheckKey = 'last_update_check';
  static const String _ignoredVersionKey = 'ignored_version';

  UpdateService({
    required this.repoOwner,
    required this.repoName,
  });

  /// Verifica si hay una nueva versión disponible desde GitHub Releases
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      // Obtener la versión actual de la app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('📱 [Update] Versión actual: $currentVersion');

      // Obtener la última release de GitHub
      final url = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
      print('🔍 [Update] Consultando: $url');
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceFirst('v', '');
        print('🔄 [Update] Última versión en GitHub: $latestVersion');

        // Comparar versiones
        if (_isNewerVersion(latestVersion, currentVersion)) {
          print('✨ [Update] ¡Nueva versión disponible!');
          
          // Buscar el asset del APK
          final assets = data['assets'] as List;
          String? apkUrl;
          
          for (var asset in assets) {
            final assetName = asset['name'] as String;
            if (assetName.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          return UpdateInfo(
            version: latestVersion,
            releaseNotes: data['body'] ?? '',
            downloadUrl: apkUrl ?? '',
            releaseDate: DateTime.parse(data['published_at']),
            isPreRelease: data['prerelease'] ?? false,
          );
        } else {
          print('✅ [Update] La app está actualizada');
          return null;
        }
      } else {
        print('❌ [Update] Error al consultar GitHub: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [Update] Error al verificar actualizaciones: $e');
      return null;
    }
  }

  /// Compara dos versiones (formato: X.Y.Z)
  bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts = newVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < newParts.length && i < currentParts.length; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    return newParts.length > currentParts.length;
  }

  /// Verifica si se debe mostrar el diálogo de actualización
  Future<bool> shouldCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey);
    
    if (lastCheck == null) return true;
    
    final lastCheckDate = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    final now = DateTime.now();
    final difference = now.difference(lastCheckDate);
    
    // Verificar cada 24 horas
    return difference.inHours >= 24;
  }

  /// Registra que se realizó una verificación
  Future<void> markCheckCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Verifica si una versión fue ignorada por el usuario
  Future<bool> isVersionIgnored(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final ignoredVersion = prefs.getString(_ignoredVersionKey);
    return ignoredVersion == version;
  }

  /// Marca una versión como ignorada
  Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, version);
    print('⏭️ [Update] Versión $version marcada como ignorada');
  }

  /// Limpia la versión ignorada
  Future<void> clearIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ignoredVersionKey);
    print('🔄 [Update] Versión ignorada limpiada');
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

      // Si ya existe el archivo, eliminarlo primero
      if (await file.exists()) {
        await file.delete();
        print('🗑️ [Update] APK anterior eliminado');
      }

      // Descargar el archivo
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Error al descargar: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final fileStream = file.openWrite();

      await for (var chunk in response.stream) {
        fileStream.add(chunk);
        downloadedBytes += chunk.length;
        
        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress(progress);
          print('📥 [Update] Progreso: ${(progress * 100).toStringAsFixed(1)}%');
        }
      }

      await fileStream.close();
      print('✅ [Update] Descarga completada: ${file.path}');

      // Verificar que el archivo se descargó correctamente
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('El archivo descargado está vacío');
      }

      print('📦 [Update] Tamaño del archivo: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Instalar el APK (esto abrirá el instalador del sistema)
      print('🚀 [Update] Abriendo instalador...');
      await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
    } catch (e) {
      print('❌ [Update] Error en descarga/instalación: $e');
      rethrow;
    }
  }

  /// Muestra un diálogo para notificar al usuario sobre la actualización
  static void showUpdateDialog(
    BuildContext context,
    UpdateInfo updateInfo,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('Actualización disponible'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versión ${updateInfo.version}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Publicado: ${_formatDate(updateInfo.releaseDate)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Novedades:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(updateInfo.releaseNotes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final service = ref.read(updateServiceProvider);
              service.ignoreVersion(updateInfo.version);
              Navigator.of(context).pop();
            },
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDownloadDialog(context, updateInfo, ref);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  /// Muestra el diálogo de progreso de descarga
  static void _showDownloadDialog(
    BuildContext context,
    UpdateInfo updateInfo,
    WidgetRef ref,
  ) {
    double progress = 0.0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Descargando actualización'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text('${(progress * 100).toInt()}%'),
            ],
          ),
        ),
      ),
    );

    // Iniciar descarga
    final service = ref.read(updateServiceProvider);
    service.downloadAndInstall(
      updateInfo,
      (newProgress) {
        progress = newProgress;
        // Actualizar el diálogo (necesitaría un StatefulBuilder)
      },
    ).then((_) {
      Navigator.of(context).pop();
    }).catchError((error) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $error')),
      );
    });
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Provider del servicio de actualizaciones
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    repoOwner: 'Marcelo-Do-Carmo-Ferraz',
    repoName: 'app_gestion_gastos',
  );
});
