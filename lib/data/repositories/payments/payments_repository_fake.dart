import 'package:streamtunes/data/repositories/payments/payments_repository.dart';

/// Implementación offline: no hay pasarela; la UI informa que los pagos no
/// están disponibles.
class FakePaymentsRepository implements PaymentsRepository {
  @override
  Future<String?> createDonationCheckout({
    required String donationId,
    required String bandId,
    required double amount,
    String? message,
    bool isAnonymous = false,
  }) async => null;
}
