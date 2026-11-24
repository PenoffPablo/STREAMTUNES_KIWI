import 'dart:async';

import 'package:streamtunes/domain/models/donation.dart';

/// Donaciones (solo lectura desde la app).
///
/// Todas las donaciones se cobran con el checkout de Mercado Pago en la
/// cuenta de KIWI. Las registra únicamente el webhook (con service role),
/// después de verificar el pago contra la API de Mercado Pago: la app nunca
/// inserta ni aprueba donaciones.
abstract class DonationsRepository {
  /// Donaciones aprobadas en vivo (muro de la banda).
  Stream<Donation> get donationCreatedStream;

  /// Muro público: solo donaciones aprobadas.
  Future<List<Donation>> getDonationsByBand(String bandId);

  void dispose();
}
