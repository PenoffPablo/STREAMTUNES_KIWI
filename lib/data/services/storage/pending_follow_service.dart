import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/utils/async_utils.dart';

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
  Future<void> removeFollow(String bandId) => _removeAll({bandId});

  /// Una sola lectura-modificación-escritura para todas las bandas procesadas.
  Future<void> _removeAll(Set<String> bandIds) async {
    if (bandIds.isEmpty) return;
    try {
      final prefs = await _getPrefs();
      final current = prefs.getStringList(_storageKey) ?? [];
      await prefs.setStringList(
        _storageKey,
        current.where((id) => !bandIds.contains(id)).toList(),
      );
    } catch (e) {
      debugPrint('[PendingFollowService] Error al remover de la cola: $e');
    }
  }

  /// Sincroniza la cola al recuperar conexión (llamado al reanudar la app).
  ///
  /// * Todos los follows se intentan EN PARALELO (`Future.wait`).
  /// * Cada uno se reintenta con backoff exponencial ante fallas de red.
  /// * Un fallo individual no cancela al resto (cada Future atrapa su error).
  /// * Al final se hace UNA sola escritura con los que salieron bien.
  ///
  /// Devuelve la cantidad de bandas sincronizadas.
  Future<int> sync(Future<bool> Function(String bandId) followAction) async {
    final pending = await getPendingFollows();
    if (pending.isEmpty) return 0;

    final results = await Future.wait(pending.map((bandId) async {
      try {
        final ok = await retry(() => followAction(bandId));
        return ok ? bandId : null;
      } catch (e) {
        debugPrint('[PendingFollowService] Error sincronizando banda $bandId: $e');
        return null;
      }
    }));

    final synced = results.whereType<String>().toSet();
    await _removeAll(synced);
    debugPrint('[PendingFollowService] Sincronización completada: ${synced.length} bandas');
    return synced.length;
  }
}
