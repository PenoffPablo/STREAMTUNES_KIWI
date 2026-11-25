import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/domain/models/donation.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

void main() {
  test('un aporte anónimo nunca muestra el nombre del donante', () {
    final d = Donation.fromJson({
      'id': 'd1',
      'band_id': _bandId,
      'amount': 1000,
      'is_public': false,
      'donor_name': null,
      'status': 'approved',
      'created_at': '2026-11-24T10:00:00Z',
    });
    expect(d.donorName, 'Fan anónimo');
    expect(d.donorUserId, isNull, reason: 'la base ya no expone donor_id al público');

    final pub = Donation.fromJson({
      'id': 'd2',
      'band_id': _bandId,
      'amount': 1000,
      'is_public': true,
      'donor_name': 'Juan Rock',
      'created_at': '2026-11-24T10:00:00Z',
    });
    expect(pub.donorName, 'Juan Rock');
  });
}
