import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/models/album.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/config_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/services/audio_analyzer_service.dart';
import 'package:streamtunes/services/device_capabilities_service.dart';
import 'package:streamtunes/view_models/upload_view_model.dart';

void main() {
  group('UploadViewModel - Validaciones de Negocio y Cupos (Criterios D1, D2, D3)', () {
    late FakeSongsRepository songsRepo;
    late FakeConfigRepository configRepo;
    late DeviceCapabilitiesService deviceService;
    late UploadViewModel viewModel;

    const testBandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const testBandName = 'Los Fuzzers';

    setUp(() {
      songsRepo = FakeSongsRepository();
      configRepo = FakeConfigRepository();
      deviceService = DeviceCapabilitiesService();

      viewModel = UploadViewModel(
        songsRepo: songsRepo,
        configRepo: configRepo,
        deviceService: deviceService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Rechaza archivo mayor a 50 MB con mensaje explicativo para el músico', () async {
      // Simulamos la selección de un WAV crudo de 52 MB (54.525.952 bytes)
      const oversizedBytes = 52 * 1024 * 1024;
      final mockSelection = AudioFileSelection(
        path: '/tmp/grabacion_cruda.wav',
        name: 'grabacion_cruda.wav',
        sizeInBytes: oversizedBytes,
      );

      final customDeviceService = _MockOversizedDeviceService(mockSelection);
      final vm = UploadViewModel(
        songsRepo: songsRepo,
        configRepo: configRepo,
        deviceService: customDeviceService,
      );

      await vm.pickAndAnalyzeAudio();

      expect(vm.analysisResult, isNull);
      expect(vm.selectedAudio, isNull);
      expect(vm.errorMessage, contains('supera los 50 MB'));
      expect(vm.errorMessage, contains('WAV crudo'));

      vm.dispose();
    });

    test('Rechaza publicación si la duración es menor a 60 segundos', () async {
      await viewModel.loadBandQuota(testBandId);

      final vmWithAudio = _createViewModelWithValidAudio(
        songsRepo: songsRepo,
        configRepo: configRepo,
        deviceService: deviceService,
      );

      final success = await vmWithAudio.publishSong(
        bandId: testBandId,
        bandName: testBandName,
        title: 'Intro Demasiado Corta',
        genre: 'Rock',
        durationSeconds: 45, // Menor a 60s
      );

      expect(success, isFalse);
      expect(vmWithAudio.errorMessage, contains('al menos 60 segundos'));

      vmWithAudio.dispose();
    });

    test('Bloquea la publicación cuando la banda alcanza el cupo máximo de 20 temas', () async {
      for (int i = 0; i < 20; i++) {
        await songsRepo.uploadSong(Song(
          id: 'test-song-$i',
          bandId: 'full-band-id',
          title: 'Tema $i',
          audioPath: 'https://stream.org/$i.mp3',
          durationSeconds: 120,
          audioSha256: 'sha-unique-$i',
          createdAt: DateTime.now(),
        ));
      }

      await viewModel.loadBandQuota('full-band-id');
      expect(viewModel.hasReachedSongLimit, isTrue);
      expect(viewModel.songCount, equals(20));

      final vmWithAudio = _createViewModelWithValidAudio(
        songsRepo: songsRepo,
        configRepo: configRepo,
        deviceService: deviceService,
      );
      await vmWithAudio.loadBandQuota('full-band-id');

      final success = await vmWithAudio.publishSong(
        bandId: 'full-band-id',
        bandName: 'Banda Llena',
        title: 'Tema 21 (Excedente)',
        genre: 'Indie',
        durationSeconds: 150,
      );

      expect(success, isFalse);
      expect(vmWithAudio.errorMessage, contains('Cupo alcanzado'));

      vmWithAudio.dispose();
    });

    test('Verifica tope de 2 álbumes por banda a nivel repositorio', () async {
      await songsRepo.createAlbum(Album(
        id: 'alb-1',
        bandId: 'album-band-id',
        title: 'Álbum Uno',
        createdAt: DateTime.now(),
      ));
      await songsRepo.createAlbum(Album(
        id: 'alb-2',
        bandId: 'album-band-id',
        title: 'Álbum Dos',
        createdAt: DateTime.now(),
      ));

      expect(await songsRepo.getBandAlbumCount('album-band-id'), equals(2));

      expect(
        () async => await songsRepo.createAlbum(Album(
          id: 'alb-3',
          bandId: 'album-band-id',
          title: 'Álbum Tres (Excedente)',
          createdAt: DateTime.now(),
        )),
        throwsException,
      );
    });
  });
}

class _MockOversizedDeviceService extends DeviceCapabilitiesService {
  final AudioFileSelection oversizedSelection;
  _MockOversizedDeviceService(this.oversizedSelection);

  @override
  Future<AudioFileSelection?> pickAudioFile() async => oversizedSelection;
}

UploadViewModel _createViewModelWithValidAudio({
  required SongsRepository songsRepo,
  required ConfigRepository configRepo,
  required DeviceCapabilitiesService deviceService,
}) {
  const mockAudio = AudioFileSelection(
    path: '/music/track.mp3',
    name: 'track.mp3',
    sizeInBytes: 5 * 1024 * 1024,
  );
  const mockAnalysis = AudioAnalysisResult(
    sha256: 'unique-sha256-hash-for-testing-1234',
    format: 'mp3',
    waveformPeaks: [50, 60, 70],
    byteLength: 5 * 1024 * 1024,
  );

  return _PresetUploadViewModel(
    songsRepo: songsRepo,
    configRepo: configRepo,
    deviceService: deviceService,
    presetAudio: mockAudio,
    presetAnalysis: mockAnalysis,
  );
}

class _PresetUploadViewModel extends UploadViewModel {
  final AudioFileSelection presetAudio;
  final AudioAnalysisResult presetAnalysis;

  _PresetUploadViewModel({
    required super.songsRepo,
    required super.configRepo,
    required super.deviceService,
    required this.presetAudio,
    required this.presetAnalysis,
  });

  @override
  AudioFileSelection? get selectedAudio => presetAudio;

  @override
  AudioAnalysisResult? get analysisResult => presetAnalysis;
}
