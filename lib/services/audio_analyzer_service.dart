import 'dart:io' show File;
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class AudioFormatValidationException implements Exception {
  final String message;
  const AudioFormatValidationException(this.message);

  @override
  String toString() => message;
}

class AudioAnalysisResult {
  final String sha256;
  final String format; // 'mp3' | 'wav' | 'm4a'
  final List<int> waveformPeaks; // Array de 40 muestras normalizadas (0 a 100)
  final int byteLength;

  const AudioAnalysisResult({
    required this.sha256,
    required this.format,
    required this.waveformPeaks,
    required this.byteLength,
  });

  Map<String, dynamic> toJson() => {
        'sha256': sha256,
        'format': format,
        'waveform_peaks': waveformPeaks,
        'byte_length': byteLength,
      };
}

class AudioAnalyzerPayload {
  final String? filePath;
  final Uint8List? rawBytes;

  const AudioAnalyzerPayload({this.filePath, this.rawBytes});
}

class AudioAnalyzerService {
  /// Ejecuta el análisis pesado de audio en un Isolate.run separado (Criterio D3)
  /// Verifica cabeceras binarias (magic bytes), calcula SHA-256 y extrae 40 picos de onda.
  static Future<AudioAnalysisResult> analyzeAudio({
    String? filePath,
    Uint8List? rawBytes,
  }) async {
    final payload = AudioAnalyzerPayload(filePath: filePath, rawBytes: rawBytes);
    return await Isolate.run(() => _performHeavyAudioAnalysis(payload));
  }

  /// Función ejecutada dentro del Isolate aislado
  static AudioAnalysisResult _performHeavyAudioAnalysis(AudioAnalyzerPayload payload) {
    Uint8List bytes;
    if (payload.rawBytes != null && payload.rawBytes!.isNotEmpty) {
      bytes = payload.rawBytes!;
    } else if (payload.filePath != null && payload.filePath!.isNotEmpty) {
      final file = File(payload.filePath!);
      if (!file.existsSync()) {
        throw const AudioFormatValidationException('El archivo de audio no existe en el almacenamiento local.');
      }
      bytes = file.readAsBytesSync();
    } else {
      throw const AudioFormatValidationException('No se proporcionaron bytes ni ruta de archivo para el análisis.');
    }

    if (bytes.length < 32) {
      throw const AudioFormatValidationException('El archivo de audio está corrupto o es demasiado pequeño.');
    }

    // 1. Verificación de Magic Bytes reales
    final format = _detectAudioFormat(bytes);

    // 2. Cálculo criptográfico SHA-256 en Isolate
    final digest = sha256.convert(bytes);
    final hashString = digest.toString();

    // 3. Extracción de 40 muestras de amplitud normalizadas (waveform)
    final peaks = _extractWaveformPeaks(bytes, sampleCount: 40);

    return AudioAnalysisResult(
      sha256: hashString,
      format: format,
      waveformPeaks: peaks,
      byteLength: bytes.length,
    );
  }

  static String _detectAudioFormat(Uint8List bytes) {
    // MP3 con tag ID3: 'ID3' (0x49, 0x44, 0x33)
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return 'mp3';
    }

    // MP3 sin ID3: Frame sync (0xFF seguido de 0xE0 mask)
    if (bytes[0] == 0xFF && ((bytes[1] & 0xE0) == 0xE0)) {
      return 'mp3';
    }

    // WAV: 'RIFF' en byte 0-3 y 'WAVE' en byte 8-11
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x41 && bytes[10] == 0x56 && bytes[11] == 0x45) {
      return 'wav';
    }

    // M4A: 'ftyp' en bytes 4-7
    if (bytes.length >= 8 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      return 'm4a';
    }

    throw const AudioFormatValidationException(
      'Formato de audio no reconocido por cabecera binaria. Solo se admiten archivos MP3, WAV o M4A legítimos.',
    );
  }

  static List<int> _extractWaveformPeaks(Uint8List bytes, {int sampleCount = 40}) {
    final List<int> peaks = [];
    final int chunkSize = (bytes.length / sampleCount).floor();
    if (chunkSize <= 0) {
      return List.filled(sampleCount, 50);
    }

    int globalMax = 1;
    final List<int> rawChunkPeaks = [];

    for (int i = 0; i < sampleCount; i++) {
      final start = i * chunkSize;
      final end = (i == sampleCount - 1) ? bytes.length : start + chunkSize;

      int maxVariance = 0;
      // Muestrear a saltos regulares dentro del chunk para eficiencia y representatividad
      final step = max(1, (end - start) ~/ 128);
      for (int j = start; j < end - 1; j += step) {
        final diff = (bytes[j] - bytes[j + 1]).abs();
        if (diff > maxVariance) {
          maxVariance = diff;
        }
      }

      rawChunkPeaks.add(maxVariance);
      if (maxVariance > globalMax) {
        globalMax = maxVariance;
      }
    }

    // Normalizar a escala de 10 a 100 para dibujo uniforme del waveform
    for (final raw in rawChunkPeaks) {
      final normalized = ((raw / globalMax) * 90).round() + 10;
      peaks.add(normalized.clamp(10, 100));
    }

    return peaks;
  }
}

