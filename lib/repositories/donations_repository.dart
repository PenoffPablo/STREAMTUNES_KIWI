import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DonationsRepository {
  Stream<Donation> get donationCreatedStream;
  Future<List<Donation>> getDonationsByBand(String bandId);
  Future<Donation> createDonation(Donation donation);
  void dispose();
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeDonationsRepository implements DonationsRepository {
  final List<Donation> _donations = [
    Donation(
      id: 'don-1',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      donorUserId: '33333333-3333-3333-3333-333333333333',
      donorName: 'Valeria Indie',
      amountArs: 2500.00,
      message: '¡Aguante el sonido crudo! Nos vemos el sábado.',
      isAnonymous: false,
      status: 'approved',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Donation(
      id: 'don-2',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      donorUserId: '44444444-4444-4444-4444-444444444444',
      donorName: 'Fan anónimo',
      amountArs: 1000.00,
      message: 'Para las cuerdas de la viola.',
      isAnonymous: true,
      status: 'approved',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  final _streamController = StreamController<Donation>.broadcast();

  @override
  Stream<Donation> get donationCreatedStream => _streamController.stream;

  @override
  Future<List<Donation>> getDonationsByBand(String bandId) async {
    return _donations
        .where((d) => d.bandId == bandId && d.isApproved)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Donation> createDonation(Donation donation) async {
    if (donation.amountArs > 5000.0) {
      throw Exception('El monto supera el tope de \$5.000 ARS permitido por el colectivo.');
    }

    final newDonation = donation.copyWith(
      id: donation.id.isNotEmpty ? donation.id : 'don-${DateTime.now().millisecondsSinceEpoch}',
      status: 'approved',
      createdAt: DateTime.now(),
    );

    _donations.insert(0, newDonation);
    _streamController.add(newDonation);
    return newDonation;
  }

  @override
  void dispose() {
    _streamController.close();
  }
}

//// Implementación real conectada a Supabase en tiempo real
class SupabaseDonationsRepository implements DonationsRepository {
  final SupabaseClient _client;
  final _streamController = StreamController<Donation>.broadcast();
  RealtimeChannel? _channel;

  SupabaseDonationsRepository(this._client) {
    _initRealtime();
  }

  void _initRealtime() {
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
                debugPrint('[SupabaseDonationsRepository] Error parseando donación realtime: $e');
              }
            },
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
    final res = await _client
        .from('donations')
        .select()
        .eq('band_id', bandId)
        .eq('status', 'approved')
        .order('created_at', ascending: false);

    return (res as List).map((json) => Donation.fromJson(json)).toList();
  }

  @override
  Future<Donation> createDonation(Donation donation) async {
    // 1. Obtener o asegurar un donor_id válido en profiles para cumplir NOT NULL y FK
    String? donorId = donation.donorUserId;
    if (donorId == null || donorId.isEmpty) {
      final currentAuthUser = _client.auth.currentUser;
      if (currentAuthUser != null) {
        donorId = currentAuthUser.id;
      } else {
        try {
          final anonAuth = await _client.auth.signInAnonymously();
          donorId = anonAuth.user?.id;
        } catch (_) {}
      }
    }

    if (donorId == null || donorId.isEmpty) {
      try {
        final existingProfile = await _client.from('profiles').select('id').limit(1).maybeSingle();
        donorId = existingProfile?['id'] as String?;
      } catch (_) {}
    }

    final Map<String, dynamic> payload = {
      'band_id': donation.bandId,
      'donor_id': donorId,
      'amount': donation.amountArs,
      'currency': 'ARS',
      'message': donation.message ?? '',
      'is_public': !donation.isAnonymous,
      'status': 'approved',
      'created_at': DateTime.now().toIso8601String(),
    };

    final res = await _client.from('donations').insert(payload).select().single();
    final created = Donation.fromJson(res);
    _streamController.add(created);
    return created;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _streamController.close();
  }
}

