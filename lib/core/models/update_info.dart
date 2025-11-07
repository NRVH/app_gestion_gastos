/// Información sobre una actualización disponible
class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final DateTime releaseDate;
  final bool isPreRelease;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseDate,
    required this.isPreRelease,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    // Buscar el asset APK
    String apkUrl = '';
    if (json['assets'] != null && json['assets'] is List) {
      for (var asset in json['assets']) {
        final assetName = asset['name'] as String?;
        if (assetName != null && assetName.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] ?? '';
          break;
        }
      }
    }

    return UpdateInfo(
      version: (json['tag_name'] as String).replaceFirst('v', ''),
      releaseNotes: json['body'] ?? '',
      downloadUrl: apkUrl,
      releaseDate: DateTime.parse(json['published_at']),
      isPreRelease: json['prerelease'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'releaseNotes': releaseNotes,
      'downloadUrl': downloadUrl,
      'releaseDate': releaseDate.toIso8601String(),
      'isPreRelease': isPreRelease,
    };
  }
}
