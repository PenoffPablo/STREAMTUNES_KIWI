import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/home/view_models/home_view_model.dart';
import 'package:streamtunes/utils/ids.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _bandSlug = 'los-fuzzers';

/// Bandas con "señal" controlable: sin red, las consultas lanzan error
/// (como el repositorio Supabase real, que ya no traga los errores de red).
class _FlakyBandsRepository extends FakeBandsRepository {
  bool offline = false;
  bool followFails = false;
  bool statsFail = false;

  void _check() {
    if (offline) throw Exception('SocketException: sin señal');
  }

  @override
  Future<Band?> getBandById(String id) async {
    _check();
    return super.getBandById(id);
  }

  @override
  Future<Band?> getBandBySlug(String slug) async {
    _check();
    return super.getBandBySlug(slug);
  }

  @override
  Future<bool> followBand(String bandId, String userId) async {
    _check();
    if (followFails) throw Exception('SocketException: se cortó la señal');
    // Igual que la base: band_follows.band_id es uuid.
    if (!isUuid(bandId)) throw Exception('invalid input syntax for type uuid: "$bandId"');
    return super.followBand(bandId, userId);
  }

  @override
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId) async {
    if (statsFail) throw Exception('timeout');
    return super.getBandAggregatedStats(bandId);
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('QR en el sótano (cola offline)', () {
    test('sin señal encola el SLUG del QR y al volver la red lo resuelve a id y sigue', () async {
      final bands = _FlakyBandsRepository()..offline = true;
      final auth = FakeAuthRepository();
      final queue = PendingFollowService(prefs: prefs);
      final home = HomeViewModel(
        songsRepo: FakeSongsRepository(),
        bandsRepo: bands,
        authRepo: auth,
        pendingFollowService: queue,
      );
      addTearDown(home.dispose);

      // 1. Escaneo SIN señal (camino real: no simulateOffline).
      final result = await home.handleQrScan('https://streamtunes.app/band/$_bandSlug');
      expect(result.isOffline, isTrue);
      expect(await queue.getPendingFollows(), [_bandSlug]);

      // 2. Vuelve la señal y el usuario tiene sesión: AppLifecycleState.resumed.
      bands.offline = false;
      final session = SessionViewModel(
        authRepo: auth,
        bandsRepo: bands,
        configRepo: FakeConfigRepository(),
        pendingFollowService: queue,
      );
      addTearDown(session.dispose);
      await session.signInWithEmail('fan@streamtunes.com', 'pass123');

      expect(await session.syncPendingFollows(), 1);
      expect(await queue.getPendingFollows(), isEmpty);
      expect(await bands.isFollowing(_bandId, session.currentUser!.id), isTrue);
    });

    test('un slug que ya no existe se descarta de la cola (no reintenta para siempre)', () async {
      final bands = _FlakyBandsRepository();
      final auth = FakeAuthRepository();
      final queue = PendingFollowService(prefs: prefs);
      await queue.queueFollow('banda-que-no-existe');
      final session = SessionViewModel(
        authRepo: auth,
        bandsRepo: bands,
        configRepo: FakeConfigRepository(),
        pendingFollowService: queue,
      );
      addTearDown(session.dispose);
      await session.signInWithEmail('fan@streamtunes.com', 'pass123');

      await session.syncPendingFollows();
      expect(await queue.getPendingFollows(), isEmpty);
    });

    test('si el follow falla por red, el mensaje NO dice "Ahora sigues"', () async {
      final bands = _FlakyBandsRepository();
      final auth = FakeAuthRepository();
      final queue = PendingFollowService(prefs: prefs);
      final home = HomeViewModel(
        songsRepo: FakeSongsRepository(),
        bandsRepo: bands,
        authRepo: auth,
        pendingFollowService: queue,
      );
      addTearDown(home.dispose);
      await auth.signInWithEmail('fan@streamtunes.com', 'pass123');

      // La banda se encuentra, pero la red se cae justo al seguirla.
      bands.followFails = true;

      final result = await home.handleQrScan('streamtunes://band/$_bandSlug');
      expect(result.isOffline, isTrue);
      expect(result.message, isNot(contains('Ahora sigues')));
      // Se encola el ID (ya se conocía la banda), no el slug.
      expect(await queue.getPendingFollows(), [_bandId]);
    });
  });
}
