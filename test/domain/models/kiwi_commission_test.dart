import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

/// Comisión de KIWI: 20% del neto (después de Mercado Pago) para sostener la
/// app. Ejemplo: aporte $1000, MP $60, neto $940, KIWI $188, banda $752.
void main() {
  test('el saldo de la banda lee la comisión de KIWI de band_balances', () {
    final b = BandBalance.fromJson({
      'band_id': _bandId,
      'band_name': 'Los Fuzzers',
      'collected': 1000,
      'net_collected': 940,
      'kiwi_fee': 188,
      'paid': 500,
      'pending': 252,
    });
    expect(b.mercadoPagoFees, 60);
    expect(b.kiwiFee, 188);
    expect(b.bandShare, 752, reason: 'neto menos la comisión de KIWI');
    expect(b.pending, 252);
  });

  test('un pago del panel de moderación muestra cuánto es para la banda', () {
    final d = Donation.fromJson({
      'id': 'd1',
      'band_id': _bandId,
      'amount': 1000,
      'net_amount': 940,
      'kiwi_fee': 188,
      'mp_payment_id': 'mp-1',
      'is_public': true,
      'donor_name': 'Juan',
      'status': 'approved',
      'created_at': '2026-11-25T10:00:00Z',
    });
    expect(d.kiwiFee, 188);
    expect(d.bandShare, 752);
  });

  test('sin datos de comisión (vista pública) no se descuenta nada', () {
    final d = Donation(id: 'd2', bandId: _bandId, donorName: 'Fan', amountArs: 500, createdAt: DateTime(2026));
    expect(d.bandShare, 500);
  });

  test('el porcentaje se lee de app_config y por defecto es 20', () {
    expect(const AppConfig().kiwiCommissionPct, 20);
    expect(AppConfig.fromMap({'kiwi_commission_pct': '15'}).kiwiCommissionPct, 15);
    expect(AppConfig.fromMap({}).kiwiCommissionPct, kDefaultKiwiCommissionPct);
  });
}
