import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/data/services/audio/audio_analyzer_service.dart';

void main() {
  group('AudioAnalyzerService - Isolate worker (SendPort/ReceivePort)', () {
    late AudioAnalyzerService analyzer;
    setUp(() => analyzer = AudioAnalyzerService());
    tearDown(() => analyzer.dispose());

    test('Verifica cabecera binaria ID3 de MP3, calcula SHA-256 y extrae 40 picos de onda en Isolate', () async {
      // Simular archivo MP3 con cabecera ID3 y bytes de audio variables
      final bytesList = <int>[
        0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Header ID3
      ];
      for (int i = 0; i < 200; i++) {
        bytesList.add((i * 17) % 256);
      }
      final rawBytes = Uint8List.fromList(bytesList);

      final expectedSha = sha256.convert(rawBytes).toString();

      final result = await analyzer.analyzeAudio(rawBytes: rawBytes);

      expect(result.format, equals('mp3'));
      expect(result.sha256, equals(expectedSha));
      expect(result.waveformPeaks.length, equals(40));
      expect(result.byteLength, equals(rawBytes.length));

      // Todos los picos deben estar en el rango normalizado de 10 a 100
      for (final peak in result.waveformPeaks) {
        expect(peak, greaterThanOrEqualTo(10));
        expect(peak, lessThanOrEqualTo(100));
      }
    });

    test('Verifica cabecera binaria RIFF/WAVE de archivo WAV legítimo', () async {
      final wavBytes = <int>[
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x24, 0x00, 0x00, 0x00, // ChunkSize
        0x57, 0x41, 0x56, 0x45, // WAVE
      ];
      for (int i = 0; i < 150; i++) {
        wavBytes.add((i * 31) % 256);
      }
      final rawBytes = Uint8List.fromList(wavBytes);

      final result = await analyzer.analyzeAudio(rawBytes: rawBytes);

      expect(result.format, equals('wav'));
      expect(result.waveformPeaks.length, equals(40));
    });

    test('Verifica cabecera binaria ftyp de archivo M4A/AAC', () async {
      final m4aBytes = <int>[
        0x00, 0x00, 0x00, 0x20, // size
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x4D, 0x34, 0x41, 0x20, // M4A
      ];
      for (int i = 0; i < 120; i++) {
        m4aBytes.add((i * 13) % 256);
      }
      final rawBytes = Uint8List.fromList(m4aBytes);

      final result = await analyzer.analyzeAudio(rawBytes: rawBytes);

      expect(result.format, equals('m4a'));
      expect(result.waveformPeaks.length, equals(40));
    });

    test('Rechaza archivo con cabeceras inválidas arrojando AudioFormatValidationException', () async {
      final fakeBytes = Uint8List.fromList(utf8.encode('ESTO NO ES UN ARCHIVO DE AUDIO VALIDO NI MP3 NI WAV'));

      expect(
        () async => await analyzer.analyzeAudio(rawBytes: fakeBytes),
        throwsA(isA<AudioFormatValidationException>()),
      );
    });
  });

  group('Worker de audio reutilizable', () {
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
}
