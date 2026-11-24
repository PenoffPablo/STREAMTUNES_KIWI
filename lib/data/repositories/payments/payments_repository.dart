/// Pasarela de pagos (Mercado Pago).
///
/// El Access Token NUNCA vive en la app: la preferencia se crea en la
/// Edge Function `mercadopago-create-preference`, que lo lee de sus secrets.
abstract class PaymentsRepository {
  /// Devuelve el `init_point` (URL de checkout) o `null` si no se pudo crear.
  ///
  /// [donationId] identifica el intento (viaja como `external_reference`,
  /// solo para trazabilidad). El donante, el nombre de la banda y el tope NO
  /// se mandan: la Edge Function los toma del JWT y de la base, así no se
  /// pueden falsificar desde la app.
  Future<String?> createDonationCheckout({
    required String donationId,
    required String bandId,
    required double amount,
    String? message,
    bool isAnonymous = false,
  });
}
