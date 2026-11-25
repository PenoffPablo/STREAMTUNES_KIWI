import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';

void main() {
  test('PendingFollowService.sync: en paralelo, tolera fallos parciales y escribe una vez', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = PendingFollowService(prefs: prefs);
    await service.queueFollow('ok-1');
    await service.queueFollow('falla');
    await service.queueFollow('ok-2');

    final inFlight = <String>{};
    var maxConcurrent = 0;
    final synced = await service.sync((bandId) async {
      inFlight.add(bandId);
      maxConcurrent = inFlight.length > maxConcurrent ? inFlight.length : maxConcurrent;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight.remove(bandId);
      if (bandId == 'falla') throw Exception('500');
      return true;
    });

    expect(synced, 2);
    expect(maxConcurrent, 3, reason: 'los follows deben correr en paralelo');
    expect(await service.getPendingFollows(), ['falla']);
  });
}
