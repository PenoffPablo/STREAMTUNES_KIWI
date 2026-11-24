import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository_fake.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository_fake.dart';
import 'package:streamtunes/data/services/audio/audio_analyzer_service.dart';
import 'package:streamtunes/data/services/device/deep_link_service.dart';
import 'package:streamtunes/data/services/device/external_launcher_service.dart';
import 'package:streamtunes/data/services/reports/band_report_service.dart';
import 'package:streamtunes/data/services/storage/pending_follow_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/band_public/view_models/donation_view_model.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/ui/home/view_models/home_view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/utils/stream_transformers.dart';

/// Repositorio de canciones con latencia controlable, para probar carreras.
class _SlowSongsRepository extends FakeSongsRepository {
  /// Compuertas por GÉNERO: permiten demorar una petición y dejar pasar otra.
  final Map<String?, Completer<void>> gates = {};
  final List<String?> queries = [];

  @override
  Future<List<Song>> getLatestSongs({int limit = 20, String? genre, String? query}) async {
    queries.add(query);
    final gate = gates[genre];
    if (gate != null) await gate.future;
    return super.getLatestSongs(limit: limit, genre: genre, query: query);
  }
}

class _FakeLauncher extends ExternalLauncherService {
  _FakeLauncher({this.canOpen = true});
  final bool canOpen;
  final List<String> opened = [];

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);
    return canOpen;
  }
}

/// Pasarela que devuelve un checkout y registra qué se le pidió.
class _FakeCheckout implements PaymentsRepository {
  final List<({String donationId, String bandId, double amount, bool anonymous})> requests = [];

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
    requests.add((donationId: donationId, bandId: bandId, amount: amount, anonymous: isAnonymous));
    return 'https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=test';
  }
}

class _CounterViewModel extends ViewModel {
  Future<void> slowIncrement(Future<void> gate) async {
    await gate;
    notifyListeners(); // llega DESPUÉS del dispose
  }
}

void main() {
  group('Future / async-await', () {
    test('retry reintenta con backoff y finalmente devuelve el valor', () async {
      var calls = 0;
      final value = await retry(() async {
        calls++;
        if (calls < 3) throw Exception('falla de red');
        return 'ok';
      }, delay: const Duration(milliseconds: 1));
      expect(value, 'ok');
      expect(calls, 3);
    });

    test('retry relanza el error después del último intento', () async {
      var calls = 0;
      await expectLater(
        retry(() async {
          calls++;
          throw Exception('siempre falla');
        }, attempts: 2, delay: const Duration(milliseconds: 1)),
        throwsException,
      );
      expect(calls, 2);
    });

    test('withNetworkTimeout convierte el timeout en NetworkTimeoutException', () async {
      final never = Completer<int>().future;
      await expectLater(
        never.withNetworkTimeout(const Duration(milliseconds: 10)),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });

    test('describeError desarma el ParallelWaitError de (f1, f2).wait', () async {
      try {
        await (Future.value(1), Future<int>.error(Exception('sin señal'))).wait;
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<ParallelWaitError>());
        expect(describeError(e), 'sin señal');
      }
    });

    test('ViewModel ignora notifyListeners después de dispose (ciclo de vida)', () async {
      final vm = _CounterViewModel();
      final gate = Completer<void>();
      final pending = vm.slowIncrement(gate.future);
      vm.dispose(); // la View se cerró mientras la operación seguía en curso
      gate.complete();
      await expectLater(pending, completes); // sin "used after being disposed"
      expect(vm.isDisposed, isTrue);
    });

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
  });

  group('Streams', () {
    test('debounce emite solo el último valor de una ráfaga', () async {
      final controller = StreamController<String>();
      final out = <String>[];
      final sub = controller.stream
          .transform(debounce(const Duration(milliseconds: 30)))
          .listen(out.add);
      for (final q in ['r', 'ro', 'roc', 'rock']) {
        controller.add(q);
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(out, ['rock']);
      await sub.cancel();
      await controller.close();
    });

    test('HomeViewModel: búsqueda con debounce hace UNA consulta por ráfaga', () async {
      final songs = _SlowSongsRepository();
      final vm = HomeViewModel(
        songsRepo: songs,
        bandsRepo: FakeBandsRepository(),
        authRepo: FakeAuthRepository(),
        pendingFollowService: PendingFollowService(),
        searchDebounce: const Duration(milliseconds: 20),
      );
      await vm.init();
      songs.queries.clear();

      for (final q in ['n', 'no', 'noc', 'noches']) {
        vm.search(q);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(songs.queries, ['noches']);
      vm.dispose();
    });

    test('HomeViewModel: "la última petición gana" descarta respuestas viejas', () async {
      final songs = _SlowSongsRepository();
      final vm = HomeViewModel(
        songsRepo: songs,
        bandsRepo: FakeBandsRepository(),
        authRepo: FakeAuthRepository(),
        pendingFollowService: PendingFollowService(),
        searchDebounce: Duration.zero,
      );
      await vm.init();

      final allSongs = vm.latestSongs; // resultado de "Todos"
      final slowGate = songs.gates[null] = Completer<void>(); // "Todos" va a tardar
      final oldRequest = vm.loadFeed(); // petición vieja (Todos), queda colgada
      vm.setGenre('Jazz'); // petición nueva, responde enseguida
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final jazzResult = vm.latestSongs;
      expect(jazzResult.length, isNot(allSongs.length), reason: 'los dos resultados deben diferir');

      slowGate.complete(); // ahora responde la vieja...
      await oldRequest;
      expect(vm.latestSongs, jazzResult, reason: '...pero NO pisa el resultado nuevo');
      expect(vm.selectedGenre, 'Jazz');
      vm.dispose();
    });

    test('DeepLinkService extrae el slug de banda de distintos formatos', () {
      expect(DeepLinkService.extractBandSlug(Uri.parse('streamtunes://band/los-fuzzers')), 'los-fuzzers');
      expect(DeepLinkService.extractBandSlug(Uri.parse('https://streamtunes.app/band/abc/?x=1')), 'abc');
      expect(DeepLinkService.extractBandSlug(Uri.parse('https://streamtunes.app/otra')), isNull);
    });
  });

  group('Isolates', () {
    test('BandReportService genera el CSV y la firma en otro isolate', () async {
      const service = BandReportService();
      final report = await service.generate(
        bandId: 'b1',
        bandName: 'Los "Fuzzers"',
        songs: [
          (title: 'A', durationSeconds: 120, playCount: 10),
          (title: 'B', durationSeconds: 60, playCount: 30),
        ],
      );
      expect(report.totalPlays, 40);
      expect(report.totalMinutes, (10 * 120 + 30 * 60) ~/ 60);
      expect(report.topSongTitle, 'B');
      expect(report.csv, contains('"Los ""Fuzzers"""')); // escape CSV
      expect(report.sha256Signature, hasLength(64));
      // Determinismo: mismo input -> misma firma (calculado sin isolate).
      final again = BandReportService.buildReport(bandId: 'b1', bandName: 'Los "Fuzzers"', songs: [
        (title: 'A', durationSeconds: 120, playCount: 10),
        (title: 'B', durationSeconds: 60, playCount: 30),
      ]);
      expect(again.sha256Signature, report.sha256Signature);
    });

    test('Worker de audio: emite progreso creciente y termina con el resultado', () async {
      final analyzer = AudioAnalyzerService();
      addTearDown(analyzer.dispose);
      // ~1 MB con cabecera ID3 -> varios bloques de 256 KB -> varios eventos de progreso.
      final bytes = Uint8List(1024 * 1024)..setAll(0, [0x49, 0x44, 0x33]);
      for (var i = 3; i < bytes.length; i++) {
        bytes[i] = (i * 31) % 256;
      }

      final events = await analyzer.analyzeWithProgress(rawBytes: bytes).toList();
      final progress = events.whereType<AnalysisProgress>().map((e) => e.fraction).toList();
      expect(progress.length, greaterThan(3));
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      expect(events.last, isA<AnalysisDone>());
      expect((events.last as AnalysisDone).result.format, 'mp3');
    });

    test('Worker de audio: se reutiliza para pedidos concurrentes (ids emparejados)', () async {
      final analyzer = AudioAnalyzerService();
      addTearDown(analyzer.dispose);
      Uint8List mp3(int seed) =>
          Uint8List.fromList([0x49, 0x44, 0x33, for (var i = 0; i < 4000; i++) (i * seed) % 256]);

      final results = await Future.wait([
        analyzer.analyzeAudio(rawBytes: mp3(7)),
        analyzer.analyzeAudio(rawBytes: mp3(13)),
      ]);
      expect(results[0].sha256, isNot(results[1].sha256));
    });
  });

  group('DonationViewModel (KIWI cobra con el checkout de Mercado Pago)', () {
    final band = Band(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      name: 'Los Fuzzers',
      slug: 'los-fuzzers',
      genre: 'Rock',
      createdAt: DateTime(2026),
    );

    test('calcula la comisión estimada y el neto para la banda', () {
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: _FakeCheckout(),
        launcher: _FakeLauncher(),
      );
      vm.setAmountText('2000');
      expect(vm.estimatedFee, 120);
      expect(vm.netBandAmount, 1880);
      vm.dispose();
    });

    test('abre el checkout de KIWI con el id del intento (para que el webhook no duplique)', () async {
      final checkout = _FakeCheckout();
      final launcher = _FakeLauncher();
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: checkout,
        launcher: launcher,
      );
      vm.setAmountText('1500');
      vm.setAnonymous(true);

      await vm.startCheckout();

      expect(checkout.requests.single.donationId, vm.donationId);
      expect(checkout.requests.single.amount, 1500);
      expect(checkout.requests.single.anonymous, isTrue);
      expect(launcher.opened.single, contains('mercadopago'));
      expect(vm.checkoutOpened, isTrue);
      expect(vm.errorMessage, isNull);
      expect(vm.isOpeningCheckout, isFalse);
      vm.dispose();
    });

    test('sin pasarela disponible informa el error (no hay caminos alternativos)', () async {
      final launcher = _FakeLauncher();
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: FakePaymentsRepository(), // devuelve null (sin init_point)
        launcher: launcher,
      );
      await vm.startCheckout();
      expect(launcher.opened, isEmpty);
      expect(vm.checkoutOpened, isFalse);
      expect(vm.errorMessage, contains('no están disponibles'));
      vm.dispose();
    });

    test('si no se puede abrir Mercado Pago en el dispositivo, lo informa', () async {
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: _FakeCheckout(),
        launcher: _FakeLauncher(canOpen: false),
      );
      await vm.startCheckout();
      expect(vm.checkoutOpened, isFalse);
      expect(vm.errorMessage, contains('No se pudo abrir'));
      vm.dispose();
    });

    test('respeta el tope de app_config: no ofrece ni cobra montos mayores', () async {
      final checkout = _FakeCheckout();
      final vm = DonationViewModel(
        band: band,
        currentUser: null,
        paymentsRepo: checkout,
        launcher: _FakeLauncher(),
        maxAmount: 5000,
      );
      expect(vm.presets, isNot(contains(10000)));

      vm.setAmountText('6000');
      expect(vm.exceedsMax, isTrue);
      expect(vm.canPay, isFalse);
      await vm.startCheckout();
      expect(checkout.requests, isEmpty);
      vm.dispose();
    });
  });

  test('Donation.toJson usa las columnas reales de public.donations', () {
    final json = Donation(
      id: 'abc',
      bandId: 'b1',
      donorUserId: null,
      donorName: 'Fan',
      amountArs: 1500,
      isAnonymous: true,
      createdAt: DateTime(2026),
    ).toJson();
    expect(json.keys, containsAll(['id', 'band_id', 'donor_id', 'amount', 'currency', 'is_public', 'status']));
    expect(json.keys, isNot(contains('amount_ars')));
    expect(json.keys, isNot(contains('donor_name')));
    expect(json['is_public'], isFalse);
  });
}
