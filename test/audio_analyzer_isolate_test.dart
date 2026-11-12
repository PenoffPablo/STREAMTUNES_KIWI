import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/services/audio_analyzer_service.dart';

void main() {
  group('AudioAnalyzerService - Isolate.run Heavy Analysis Test', () {
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

      final result = await AudioAnalyzerService.analyzeAudio(rawBytes: rawBytes);

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

      final result = await AudioAnalyzerService.analyzeAudio(rawBytes: rawBytes);

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

      final result = await AudioAnalyzerService.analyzeAudio(rawBytes: rawBytes);

      expect(result.format, equals('m4a'));
      expect(result.waveformPeaks.length, equals(40));
    });

    test('Rechaza archivo con cabeceras inválidas arrojando AudioFormatValidationException', () async {
      final fakeBytes = Uint8List.fromList(utf8.encode('ESTO NO ES UN ARCHIVO DE AUDIO VALIDO NI MP3 NI WAV'));

      expect(
        () async => await AudioAnalyzerService.analyzeAudio(rawBytes: fakeBytes),
        throwsA(isA<AudioFormatValidationException>()),
      );
    });
  });
}

