import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Lee los saldos con la función `band_balances` (calcula en la base: neto
/// verificado por Mercado Pago - liquidado) y registra pagos en `band_payouts`.
/// La RLS asegura que solo un moderador pueda registrar, y el trigger
/// `validate_payout` que no se liquide más que el saldo pendiente.
class SupabasePayoutsRepository implements PayoutsRepository {
  SupabasePayoutsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BandBalance> getBandBalance(String bandId) async {
    final res = await (_client.rpc('band_balances', params: {'p_band': bandId})).withNetworkTimeout();
    final rows = res as List;
    if (rows.isEmpty) return BandBalance.empty(bandId);
    return BandBalance.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<BandBalance>> getAllBalances() async {
    final res = await (_client.rpc('band_balances')).withNetworkTimeout();
    return (res as List).map((row) => BandBalance.fromJson(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<BandPayout>> getPayouts(String bandId) async {
    final res =
        await (_client
                .from('band_payouts')
                .select()
                .eq('band_id', bandId)
                .order('paid_at', ascending: false))
            .withNetworkTimeout();
    return (res as List).map((json) => BandPayout.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<BandPayout> registerPayout({
    required String bandId,
    required double amount,
    String? reference,
    String? note,
  }) async {
    final res =
        await (_client
                .from('band_payouts')
                .insert({
                  'band_id': bandId,
                  'amount': amount,
                  'reference': (reference == null || reference.isEmpty) ? null : reference,
                  'note': (note == null || note.isEmpty) ? null : note,
                })
                .select()
                .single())
            .withNetworkTimeout();
    return BandPayout.fromJson(res);
  }
}
