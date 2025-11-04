import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';

// Estado de actualización
class UpdateState {
  final UpdateInfo? availableUpdate;
  final bool isChecking;
  final bool isDownloading;
  final double downloadProgress;
  final String? error;

  const UpdateState({
    this.availableUpdate,
    this.isChecking = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.error,
  });

  UpdateState copyWith({
    UpdateInfo? availableUpdate,
    bool? isChecking,
    bool? isDownloading,
    double? downloadProgress,
    String? error,
  }) {
    return UpdateState(
      availableUpdate: availableUpdate ?? this.availableUpdate,
      isChecking: isChecking ?? this.isChecking,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error ?? this.error,
    );
  }

  bool get hasUpdateAvailable => availableUpdate != null;
}

// Notifier para manejar el estado de actualización
class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _updateService;

  UpdateNotifier(this._updateService) : super(const UpdateState()) {
    _init();
  }

  Future<void> _init() async {
    // Cargar última verificación y actualización en caché
    await _updateService.loadLastCheckTime();
    await _updateService.loadCachedUpdate();
    
    if (_updateService.hasUpdateAvailable) {
      state = state.copyWith(
        availableUpdate: _updateService.cachedUpdate,
      );
      
      // Mostrar notificación local si hay actualización
      _updateService.showUpdateNotification(_updateService.cachedUpdate!);
    }
  }

  /// Verifica si hay actualizaciones disponibles
  Future<void> checkForUpdates({bool forceCheck = false}) async {
    if (state.isChecking) return;

    state = state.copyWith(isChecking: true, error: null);

    try {
      final updateInfo = await _updateService.checkForUpdates(
        forceCheck: forceCheck,
      );

      state = state.copyWith(
        availableUpdate: updateInfo,
        isChecking: false,
      );
      
      // Mostrar notificación si hay nueva actualización
      if (updateInfo != null) {
        _updateService.showUpdateNotification(updateInfo);
      }
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
    }
  }

  /// Descarga e instala la actualización
  Future<void> downloadAndInstall() async {
    if (state.availableUpdate == null || state.isDownloading) return;

    state = state.copyWith(
      isDownloading: true,
      downloadProgress: 0.0,
      error: null,
    );

    try {
      await _updateService.downloadAndInstall(
        state.availableUpdate!,
        (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
      );

      // Después de abrir el instalador, resetear el estado
      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 0.0,
        error: 'Error al descargar: ${e.toString()}',
      );
    }
  }

  /// Descarta el error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider del notifier
final updateNotifierProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final updateService = ref.watch(updateServiceProvider);
  return UpdateNotifier(updateService);
});

// Provider simple para saber si hay actualización disponible (para badge)
final hasUpdateAvailableProvider = Provider<bool>((ref) {
  final updateState = ref.watch(updateNotifierProvider);
  return updateState.hasUpdateAvailable;
});
