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
                // Nombre del donante desde profiles (la tabla no guarda donor_name).
                .select('*, donor:profiles!donations_donor_id_fkey(display_name)')
                .eq('band_id', bandId)
                .eq('status', 'approved')
                .order('created_at', ascending: false))
            .withNetworkTimeout();

    return (res as List).map((json) => Donation.fromJson(json)).toList();
  }

  /// Registra la donación declarada por el fan, de forma IDEMPOTENTE.
  ///
  /// * Siempre `pending`: el cliente no puede aprobarse a sí mismo (lo exige
  ///   también la política RLS). La aprueba el webhook de Mercado Pago con el
  ///   monto real, o la banda desde su panel si fue una transferencia al alias.
  /// * `donor_id` es el usuario autenticado o `null`.
  /// * El `id` lo genera la app y viaja en el pago: ON CONFLICT DO NOTHING.
  /// * Sin `.select()`: una donación pendiente anónima no es visible por RLS,
  ///   y pedirla de vuelta (RETURNING) haría fallar el insert.
  @override
  Future<Donation> createDonation(Donation donation) async {
    final donorId = _client.auth.currentUser?.id;
    final pending = Donation(
      id: donation.id,
      bandId: donation.bandId,
      donorUserId: donorId,
      donorName: donation.donorName,
      amountArs: donation.amountArs,
      message: donation.message,
      isAnonymous: donation.isAnonymous,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await (_client
            .from('donations')
            .upsert(pending.toJson(), onConflict: 'id', ignoreDuplicates: true))
        .withNetworkTimeout();
    return pending;
  }

  @override
  Future<List<Donation>> getPendingDonations(String bandId) async {
    final res =
        await (_client
                .from('donations')
                .select('*, donor:profiles!donations_donor_id_fkey(display_name)')
                .eq('band_id', bandId)
                .eq('status', 'pending')
                .order('created_at', ascending: false))
            .withNetworkTimeout();
    return (res as List).map((json) => Donation.fromJson(json)).toList();
  }

  @override
  Future<void> reviewDonation(String donationId, {required bool approved}) async {
    // `.select('id')` devuelve las filas realmente actualizadas: si otro
    // miembro o el webhook ya la resolvió, no hay filas y se informa, en vez
    // de mostrar "confirmado" sin haber cambiado nada.
    final updated =
        await (_client
                .from('donations')
                .update({'status': approved ? 'approved' : 'refunded'})
                .eq('id', donationId)
                .eq('status', 'pending')
                .select('id'))
            .withNetworkTimeout();
    if ((updated as List).isEmpty) {
      throw const AppException('Este aporte ya fue revisado.');
    }
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    _streamController.close();
  }
}
