import 'dart:async';

import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
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
    return _donations.where((d) => d.bandId == bandId && d.isApproved).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Donation> createDonation(Donation donation) async {
    if (donation.amountArs > 5000.0) {
      throw Exception(
        'El monto supera el tope de \$5.000 ARS permitido por el colectivo.',
      );
    }

    // Idempotente por id (igual que Supabase con ON CONFLICT DO NOTHING).
    final existing = _donations.where((d) => d.id == donation.id && d.id.isNotEmpty);
    if (existing.isNotEmpty) return existing.first;

    // Igual que la base: lo que declara el fan queda pendiente.
    final newDonation = donation.copyWith(
      id: donation.id.isNotEmpty
          ? donation.id
          : 'don-${DateTime.now().millisecondsSinceEpoch}',
      status: 'pending',
      createdAt: DateTime.now(),
    );

    _donations.insert(0, newDonation);
    return newDonation;
  }

  /// Solo para tests y datos de demo: simula un pago ya aprobado (webhook).
  void addApproved(Donation donation) {
    final approved = donation.copyWith(status: 'approved');
    _donations.insert(0, approved);
    _streamController.add(approved);
  }

  @override
  Future<List<Donation>> getPendingDonations(String bandId) async {
    return _donations.where((d) => d.bandId == bandId && d.status == 'pending').toList();
  }

  @override
  Future<void> reviewDonation(String donationId, {required bool approved}) async {
    final idx = _donations.indexWhere((d) => d.id == donationId && d.status == 'pending');
    if (idx == -1) throw const AppException('Este aporte ya fue revisado.');
    final updated = _donations[idx].copyWith(status: approved ? 'approved' : 'refunded');
    _donations[idx] = updated;
    if (approved) _streamController.add(updated); // aparece en el muro en vivo
  }

  @override
  void dispose() {
    _streamController.close();
  }
}
