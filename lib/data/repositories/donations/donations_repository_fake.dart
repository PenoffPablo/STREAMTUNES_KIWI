import 'dart:async';

import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';

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
  Future<List<Donation>> getRecentVerified({int limit = 20}) async {
    final verified = _donations.where((d) => d.isApproved && d.isVerified).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return verified.take(limit).toList();
  }

  /// Simula lo que hace el webhook de Mercado Pago al aprobar un pago
  /// (en la app real no hay inserción desde el cliente). Para tests y demo.
  void addApproved(Donation donation) {
    final approved = donation.copyWith(status: 'approved');
    _donations.insert(0, approved);
    _streamController.add(approved);
  }

  @override
  void dispose() {
    _streamController.close();
  }
}
