import 'package:streamtunes/data/repositories/payments/payments_repository.dart';

/// Implementación offline: no hay pasarela, la UI cae al fallback (abrir la app de MP).
class FakePaymentsRepository implements PaymentsRepository {
  @override
  Future<String?> createDonationCheckout({
    required String donationId,
    required String bandId,
    required String bandName,
    required double amount,
    String? donorUserId,
    String? donorName,
    String? message,
    bool isAnonymous = false,
  }) async => null;
}
