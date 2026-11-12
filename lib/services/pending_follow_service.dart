import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingFollowService {
  static const String _storageKey = 'streamtunes_pending_qr_follows';
  final SharedPreferences? prefs;

  PendingFollowService({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Añade una banda a la cola de seguimiento offline del sótano
  Future<void> queueFollow(String bandId) async {
    try {
      final prefs = await _getPrefs();
      final currentList = prefs.getStringList(_storageKey) ?? [];
      if (!currentList.contains(bandId)) {
        currentList.add(bandId);
        await prefs.setStringList(_storageKey, currentList);
        debugPrint('[PendingFollowService] Banda $bandId encolada para seguimiento offline');
      }
    } catch (e) {
      debugPrint('[PendingFollowService] Error al encolar seguimiento offline: $e');
    }
  }

  /// Obtiene las bandas pendientes en la cola
  Future<List<String>> getPendingFollows() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getStringList(_storageKey) ?? [];
    } catch (e) {
      debugPrint('[PendingFollowService] Error al leer cola: $e');
      return [];
    }
  }

  /// Remueve una banda procesada con éxito
  Future<void> removeFollow(String bandId) async {
    try {
      final prefs = await _getPrefs();
      final currentList = prefs.getStringList(_storageKey) ?? [];
      currentList.remove(bandId);
      await prefs.setStringList(_storageKey, currentList);
    } catch (e) {
      debugPrint('[PendingFollowService] Error al remover de la cola: $e');
    }
  }

  /// Sincroniza la cola al recuperar conexión (llamado al reanudar la app)
  /// Retorna la cantidad de bandas sincronizadas exitosamente.
  Future<int> sync(Future<bool> Function(String bandId) followAction) async {
    final pending = await getPendingFollows();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    final toRemove = <String>[];

    for (final bandId in pending) {
      try {
        final success = await followAction(bandId);
        if (success) {
          toRemove.add(bandId);
          syncedCount++;
        }
      } catch (e) {
        debugPrint('[PendingFollowService] Error sincronizando banda $bandId: $e');
      }
    }

    for (final bandId in toRemove) {
      await removeFollow(bandId);
    }

    debugPrint('[PendingFollowService] Sincronización completada: $syncedCount bandas procesadas');
    return syncedCount;
  }
}
