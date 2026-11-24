import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase en tiempo real
class SupabaseDonationsRepository implements DonationsRepository {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  /// El canal realtime sigue el ciclo de vida de los OYENTES del stream:
  /// se abre con el primer `listen` y se cierra cuando el último cancela.
  /// (Antes se abría en el constructor, al iniciar la app, aunque nadie
  /// estuviera mirando un perfil de banda, y quedaba abierto para siempre.)
  late final StreamController<Donation> _streamController =
      StreamController<Donation>.broadcast(
        onListen: _subscribeRealtime,
        onCancel: _unsubscribeRealtime,
      );

  SupabaseDonationsRepository(this._client);

  /// Columnas que el público puede leer de `donations`.
  static const _publicColumns = 'id, band_id, amount, currency, message, is_public, donor_name, status, created_at';

  void _unsubscribeRealtime() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _client.removeChannel(channel);
  }

  void _subscribeRealtime() {
    if (_channel != null) return;

    // Una donación entra al muro cuando queda APROBADA: puede ser un INSERT
    // (pago ya aprobado) o un UPDATE (el webhook o la banda la confirman).
    // El muro descarta repetidos por id.
    void onChange(PostgresChangePayload payload) {
      try {
        final donation = Donation.fromJson(payload.newRecord);
        if (donation.isApproved && !_streamController.isClosed) {
          _streamController.add(donation);
        }
      } catch (e) {
        debugPrint('[SupabaseDonationsRepository] Error parseando donación realtime: $e');
      }
    }

    try {
      _channel = _client
          .channel('public:donations')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'donations',
            callback: onChange,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'donations',
            callback: onChange,
          )
          .subscribe();
    } catch (e) {
      debugPrint('[SupabaseDonationsRepository] Error suscribiendo a realtime: $e');
    }
  }

  @override
  Stream<Donation> get donationCreatedStream => _streamController.stream;

  @override
  Future<List<Donation>> getDonationsByBand(String bandId) async {
    final res =
        await (_client
                .from('donations')
                // Solo columnas públicas: el donante real, el neto y el id del
                // pago no se exponen (ver migración 20261124030000).
                .select(_publicColumns)
                .eq('band_id', bandId)
                .eq('status', 'approved')
                .order('created_at', ascending: false))
            .withNetworkTimeout();

    return (res as List).map((json) => Donation.fromJson(json)).toList();
  }

  @override
  Future<List<Donation>> getRecentVerified({int limit = 20}) async {
    // RPC solo para moderadores: incluye neto, id de MP y nombre de la banda.
    final res = await _client.rpc('admin_recent_payments', params: {'p_limit': limit}).withNetworkTimeout();
    return (res as List).map((json) => Donation.fromJson(json)).toList();
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    _streamController.close();
  }
}
