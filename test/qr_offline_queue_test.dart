import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/repositories/auth_repository.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/services/pending_follow_service.dart';
import 'package:streamtunes/view_models/home_view_model.dart';

void main() {
  group('QR Offline Queue & Sótano Sync Tests', () {
    late FakeAuthRepository authRepo;
    late FakeBandsRepository bandsRepo;
    late FakeSongsRepository songsRepo;
    late PendingFollowService pendingFollowService;
    late HomeViewModel homeViewModel;

    const testBandSlug = 'los-fuzzers';
    const testBandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      authRepo = FakeAuthRepository();
      bandsRepo = FakeBandsRepository();
      songsRepo = FakeSongsRepository();
      pendingFollowService = PendingFollowService(prefs: prefs);

      homeViewModel = HomeViewModel(
        songsRepo: songsRepo,
        bandsRepo: bandsRepo,
        authRepo: authRepo,
        pendingFollowService: pendingFollowService,
      );
    });

    tearDown(() {
      homeViewModel.dispose();
    });

    test('Escaneo de QR sin conexión en sótano guarda en PendingFollowService e informa al usuario', () async {
      // 1. Simular escaneo de QR en un sótano sin conexión a internet
      final result = await homeViewModel.handleQrScan(
        'streamtunes://band/$testBandSlug',
        simulateOffline: true,
      );

      expect(result.isOffline, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.message, contains('Sin señal en el sótano'));
      expect(result.band, isNotNull);
      expect(result.band!.slug, equals(testBandSlug));

      // 2. Verificar que quedó encolado en SharedPreferences
      final pending = await pendingFollowService.getPendingFollows();
      expect(pending, contains(testBandSlug));
    });

    test('Sincronización automática de la cola offline al recuperar red (AppLifecycleState.resumed)', () async {
      // 1. Encolar dos bandas manualmente como si se hubieran escaneado en el recital
      await pendingFollowService.queueFollow(testBandId);
      await pendingFollowService.queueFollow('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

      var pending = await pendingFollowService.getPendingFollows();
      expect(pending.length, equals(2));

      // 2. El usuario inicia sesión
      final user = await authRepo.signInWithEmail('fan@streamtunes.com', 'pass123');

      // 3. Al reanudar la app con conexión, se ejecuta sync()
      final syncedCount = await pendingFollowService.sync((bandId) async {
        return await bandsRepo.followBand(bandId, user.id);
      });

      // 4. Verificaciones
      expect(syncedCount, equals(2));
      pending = await pendingFollowService.getPendingFollows();
      expect(pending.isEmpty, isTrue); // La cola debe haber quedado limpia

      // Verificar que el usuario ahora sigue efectivamente a la banda
      final isFollowing = await bandsRepo.isFollowing(testBandId, user.id);
      expect(isFollowing, isTrue);
    });

    test('Escaneo con conexión autentica anónimamente y sigue de forma instantánea', () async {
      expect(authRepo.currentUser, isNull);

      final result = await homeViewModel.handleQrScan('streamtunes://band/$testBandSlug');

      expect(result.isOffline, isFalse);
      expect(result.isSuccess, isTrue);
      expect(result.message, contains('Ahora sigues a'));
      expect(authRepo.currentUser, isNotNull);
      expect(authRepo.currentUser!.isAnonymous, isTrue);
    });
  });
}

