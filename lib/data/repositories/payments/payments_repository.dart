/// Pasarela de pagos (Mercado Pago).
///
/// El Access Token NUNCA vive en la app: la preferencia se crea en la
/// Edge Function `mercadopago-create-preference`, que lo lee de sus secrets.
abstract class PaymentsRepository {
  /// Devuelve el `init_point` (URL de checkout) o `null` si no se pudo crear.
  ///
  /// [donationId] identifica el intento de donación: el webhook lo usa como
  /// `id` de la fila, así un mismo pago nunca se registra dos veces.
  Future<String?> createDonationCheckout({
    required String donationId,
    required String bandId,
    required String bandName,
    required double amount,
    String? donorUserId,
    String? donorName,
    String? message,
    bool isAnonymous = false,
  });
}
