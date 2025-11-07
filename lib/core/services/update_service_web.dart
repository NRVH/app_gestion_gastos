import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_info.dart';

/// Servicio de actualizaciones para Web (funcionalidad limitada)
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
      print('🌐 [Update Web] Versión actual: $currentVersion');

      // Obtener la última release de GitHub
      final url = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
      print('🔍 [Update Web] Consultando: $url');
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceFirst('v', '');
        print('🔄 [Update Web] Última versión en GitHub: $latestVersion');

        // Comparar versiones
        if (_isNewerVersion(latestVersion, currentVersion)) {
          print('✨ [Update Web] ¡Nueva versión disponible!');
          
          return UpdateInfo(
            version: latestVersion,
            releaseNotes: data['body'] ?? '',
            downloadUrl: '', // No hay descarga en Web
            releaseDate: DateTime.parse(data['published_at']),
            isPreRelease: data['prerelease'] ?? false,
          );
        } else {
          print('✅ [Update Web] La app está actualizada');
          return null;
        }
      } else {
        print('❌ [Update Web] Error al consultar GitHub: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [Update Web] Error al verificar actualizaciones: $e');
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
    print('⏭️ [Update Web] Versión $version marcada como ignorada');
  }

  /// Limpia la versión ignorada
  Future<void> clearIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ignoredVersionKey);
    print('🔄 [Update Web] Versión ignorada limpiada');
  }

  /// En Web, no se puede descargar e instalar APKs
  /// Las aplicaciones web se actualizan automáticamente al refrescar
  Future<void> downloadAndInstall(
    UpdateInfo updateInfo, 
    void Function(double progress) onProgress,
  ) async {
    print('🌐 [Update Web] Descarga no disponible en Web');
    throw Exception('La descarga de actualizaciones no está disponible en Web. La aplicación web se actualiza automáticamente al refrescar la página.');
  }

  /// Muestra un diálogo para notificar al usuario sobre la actualización en Web
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
              const SizedBox(height: 16),
              const Text(
                'Para actualizar la aplicación web, simplemente recarga la página.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.blue,
                ),
              ),
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
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              // En Web, simplemente recargar la página
              // ignore: avoid_web_libraries_in_flutter
              // dart.html.window.location.reload();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recarga la página (F5) para actualizar'),
                  duration: Duration(seconds: 5),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Entendido'),
          ),
        ],
      ),
    );
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
