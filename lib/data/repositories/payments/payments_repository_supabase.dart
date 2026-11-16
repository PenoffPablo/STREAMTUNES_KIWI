import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

class SupabasePaymentsRepository implements PaymentsRepository {
  final SupabaseClient _client;

  SupabasePaymentsRepository(this._client);

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
  }) async {
    final res = await (_client.functions.invoke(
      'mercadopago-create-preference',
      body: {
        'donation_id': donationId,
        'band_id': bandId,
        'band_name': bandName,
        'amount': amount,
        'donor_user_id': donorUserId,
        'donor_name': donorName,
        'message': message,
        'is_anonymous': isAnonymous,
      },
    )).withNetworkTimeout();
    final data = res.data;
    if (data is Map && data['init_point'] is String) {
      return data['init_point'] as String;
    }
    return null;
  }
}
