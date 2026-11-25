import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/services/device/deep_link_service.dart';

void main() {
  test('DeepLinkService extrae el slug de banda de distintos formatos', () {
    expect(DeepLinkService.extractBandSlug(Uri.parse('streamtunes://band/los-fuzzers')), 'los-fuzzers');
    expect(DeepLinkService.extractBandSlug(Uri.parse('https://streamtunes.app/band/abc/?x=1')), 'abc');
    expect(DeepLinkService.extractBandSlug(Uri.parse('https://streamtunes.app/otra')), isNull);
  });
}
