import 'dart:async';

import 'package:streamtunes/domain/models/donation.dart';

abstract class DonationsRepository {
  Stream<Donation> get donationCreatedStream;
  /// Muro público: solo donaciones aprobadas.
  Future<List<Donation>> getDonationsByBand(String bandId);

  /// Registra una donación declarada por el fan ("Ya transferí").
  /// Siempre queda `pending`: la aprueba el webhook de Mercado Pago o la banda.
  /// Es idempotente por `id`.
  Future<Donation> createDonation(Donation donation);

  /// Donaciones por confirmar de una banda (transferencias al alias).
  Future<List<Donation>> getPendingDonations(String bandId);

  /// La banda confirma (`approved`) o rechaza (`refunded`) una pendiente.
  Future<void> reviewDonation(String donationId, {required bool approved});
  void dispose();
}
