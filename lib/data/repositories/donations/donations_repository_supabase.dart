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

  void _unsubscribeRealtime() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _client.removeChannel(channel);
  }

  void _subscribeRealtime() {
    if (_channel != null) return;
    try {
      _channel = _client
          .channel('public:donations')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'donations',
            callback: (payload) {
              try {
                final newRecord = payload.newRecord;
                final donation = Donation.fromJson(newRecord);
                if (donation.isApproved) {
                  _streamController.add(donation);
                }
              } catch (e) {
                debugPrint(
                  '[SupabaseDonationsRepository] Error parseando donación realtime: $e',
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint(
        '[SupabaseDonationsRepository] Error suscribiendo a realtime: $e',
      );
    }
  }

  @override
  Stream<Donation> get donationCreatedStream => _streamController.stream;

  @override
  Future<List<Donation>> getDonationsByBand(String bandId) async {
    final res =
        await (_client
                .from('donations')
                // Nombre del donante desde profiles (la tabla no guarda donor_name).
                .select('*, donor:profiles!donations_donor_id_fkey(display_name)')
                .eq('band_id', bandId)
                .eq('status', 'approved')
                .order('created_at', ascending: false))
            .withNetworkTimeout();

    return (res as List).map((json) => Donation.fromJson(json)).toList();
  }

  @override
  /// Registra la donación de forma IDEMPOTENTE.
  ///
  /// * `donor_id` es el usuario autenticado o `null` (la columna admite nulos).
  ///   Antes, sin sesión, se asignaba la donación al primer perfil de la tabla:
  ///   es decir, a OTRA persona.
  /// * El `id` lo genera la app y viaja también en el `external_reference` de
  ///   Mercado Pago. Si el webhook ya registró este pago, el insert se ignora
  ///   (ON CONFLICT DO NOTHING) y se devuelve la fila existente: no hay duplicados.
  @override
  Future<Donation> createDonation(Donation donation) async {
    final payload = donation
        .copyWith(status: 'approved')
        .toJson()
      ..['donor_id'] = _client.auth.currentUser?.id;

    final inserted =
        await (_client
                .from('donations')
                .upsert(payload, onConflict: 'id', ignoreDuplicates: true)
                .select())
            .withNetworkTimeout();

    final rows = inserted as List;
    final created = rows.isNotEmpty
        ? Donation.fromJson(rows.first as Map<String, dynamic>)
        : Donation.fromJson(
            await (_client.from('donations').select().eq('id', donation.id).single())
                .withNetworkTimeout(),
          );
    if (rows.isNotEmpty && _streamController.hasListener) _streamController.add(created);
    return created;
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    _streamController.close();
  }
}
