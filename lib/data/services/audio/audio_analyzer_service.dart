import 'dart:async';
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

/// Eventos del análisis en curso (jerarquía `sealed`: el `switch` es exhaustivo).
sealed class AnalysisEvent {
  const AnalysisEvent();
}

/// Avance del análisis, entre 0.0 y 1.0.
class AnalysisProgress extends AnalysisEvent {
  final double fraction;
  final String stage;
  const AnalysisProgress(this.fraction, this.stage);
}

/// Análisis terminado.
class AnalysisDone extends AnalysisEvent {
  final AudioAnalysisResult result;
  const AnalysisDone(this.result);
}

/// Análisis de audio en un **isolate de larga vida** (worker).
///
/// Comunicación bidireccional con `SendPort` / `ReceivePort`:
///
///   main ──[id, path, bytes]──────────▶ worker
///   main ◀──[id, 'progress', 0.42]───── worker   (varias veces)
///   main ──[id, 'cancel']─────────────▶ worker   (si el usuario cancela)
///   main ◀──[id, 'done', {...}]──────── worker
///
/// * El worker se crea la primera vez que se usa (lazy) y se reutiliza.
/// * Un `Completer` espera el "handshake" inicial (el worker manda su SendPort).
/// * Cada pedido tiene un `id` para emparejar respuestas concurrentes.
/// * La API pública es un generador `async*` que emite [AnalysisEvent].
class AudioAnalyzerService {
  AudioAnalyzerService();

  Isolate? _isolate;
  ReceivePort? _fromWorker;
  SendPort? _toWorker;
  Completer<void>? _ready;
  int _nextRequestId = 0;
  final Map<int, StreamController<AnalysisEvent>> _pending = {};
  bool _disposed = false;

  /// Análisis con progreso. Cancelar la suscripción (o hacer `break` en un
  /// `await for`) envía un mensaje de cancelación al worker.
  Stream<AnalysisEvent> analyzeWithProgress({String? filePath, Uint8List? rawBytes}) async* {
    if (_disposed) throw StateError('AudioAnalyzerService ya fue liberado');

    // Web no soporta Isolate.spawn: se analiza en el hilo principal.
    if (kIsWeb) {
      yield const AnalysisProgress(0, 'Analizando');
      yield AnalysisDone(_performHeavyAudioAnalysis(
        AudioAnalyzerPayload(filePath: filePath, rawBytes: rawBytes),
      ));
      return;
    }

    await _ensureWorker();
    final id = _nextRequestId++;
    final controller = StreamController<AnalysisEvent>();
    _pending[id] = controller;
    _toWorker!.send([id, filePath, rawBytes]);

    var finished = false;
    try {
      await for (final event in controller.stream) {
        if (event is AnalysisDone) finished = true;
        yield event; // re-emite hacia quien escucha
      }
    } finally {
      _pending.remove(id);
      // Si el consumidor dejó de escuchar antes de terminar -> cancelar en el worker.
      if (!finished && !_disposed) _toWorker?.send([id, 'cancel']);
    }
  }

  /// Versión sin progreso: espera el resultado final.
  Future<AudioAnalysisResult> analyzeAudio({String? filePath, Uint8List? rawBytes}) async {
    await for (final event in analyzeWithProgress(filePath: filePath, rawBytes: rawBytes)) {
      if (event is AnalysisDone) return event.result;
    }
    throw StateError('El análisis terminó sin resultado');
  }

  Future<void> _ensureWorker() {
    final ready = _ready;
    if (ready != null) return ready.future;
    final completer = _ready = Completer<void>();
    final inbox = _fromWorker = ReceivePort('audio-analyzer-main');
    inbox.listen(_onWorkerMessage);
    Isolate.spawn(_workerMain, inbox.sendPort, debugName: 'audio-analyzer').then(
      (isolate) => _isolate = isolate,
      onError: (Object e, StackTrace st) {
        _ready = null; // permitir reintentar
        completer.completeError(e, st);
      },
    );
    return completer.future;
  }

  void _onWorkerMessage(dynamic message) {
    // Primer mensaje: el SendPort del worker (handshake).
    if (message is SendPort) {
      _toWorker = message;
      _ready?.complete();
      return;
    }
    final msg = message as List<Object?>;
    final controller = _pending[msg[0] as int];
    if (controller == null || controller.isClosed) return;

    switch (msg[1]) {
      case 'progress':
        controller.add(AnalysisProgress(msg[2] as double, msg[3] as String));
      case 'done':
        final json = msg[2] as Map<Object?, Object?>;
        controller.add(AnalysisDone(AudioAnalysisResult(
          sha256: json['sha256'] as String,
          format: json['format'] as String,
          waveformPeaks: (json['waveform_peaks'] as List).cast<int>(),
          byteLength: json['byte_length'] as int,
        )));
        controller.close();
      case 'error':
        final isFormatError = msg[2] == 'format';
        controller.addError(isFormatError
            ? AudioFormatValidationException(msg[3] as String)
            : Exception(msg[3] as String));
        controller.close();
      case 'cancelled':
        controller.close();
    }
  }

  /// Mata el worker y libera los puertos. Lo llama la raíz de composición.
  void dispose() {
    _disposed = true;
    for (final c in _pending.values) {
      c.addError(StateError('Análisis interrumpido'));
      c.close();
    }
    _pending.clear();
    _fromWorker?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  // ======================= Código que corre en el WORKER =======================

  /// Punto de entrada del isolate worker. Solo recibe un SendPort: todo lo
  /// demás llega por mensajes (no comparte memoria con la app).
  @pragma('vm:entry-point')
  static void _workerMain(SendPort toMain) {
    final inbox = ReceivePort('audio-analyzer-worker');
    toMain.send(inbox.sendPort); // handshake
    final cancelled = <int>{};

    inbox.listen((dynamic message) async {
      final msg = message as List<Object?>;
      final id = msg[0] as int;
      if (msg[1] == 'cancel') {
        cancelled.add(id);
        return;
      }
      try {
        final result = await _analyzeInChunks(
          AudioAnalyzerPayload(filePath: msg[1] as String?, rawBytes: msg[2] as Uint8List?),
          onProgress: (fraction, stage) => toMain.send([id, 'progress', fraction, stage]),
          isCancelled: () => cancelled.contains(id),
        );
        toMain.send(result == null ? [id, 'cancelled'] : [id, 'done', result.toJson()]);
      } on AudioFormatValidationException catch (e) {
        toMain.send([id, 'error', 'format', e.message]);
      } catch (e) {
        toMain.send([id, 'error', 'other', e.toString()]);
      } finally {
        cancelled.remove(id);
      }
    });
  }

  /// Igual que [_performHeavyAudioAnalysis] pero por bloques: entre bloque y
  /// bloque cede el control (`await`) para poder procesar un 'cancel' y
  /// reportar progreso. Devuelve `null` si se canceló.
  static Future<AudioAnalysisResult?> _analyzeInChunks(
    AudioAnalyzerPayload payload, {
    required void Function(double fraction, String stage) onProgress,
    required bool Function() isCancelled,
  }) async {
    onProgress(0.0, 'Leyendo archivo');
    final bytes = _readBytes(payload);
    final format = _detectAudioFormat(bytes);

    const chunkSize = 256 * 1024;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      if (isCancelled()) return null;
      final end = min(offset + chunkSize, bytes.length);
      hasher.add(Uint8List.sublistView(bytes, offset, end));
      onProgress(0.9 * end / bytes.length, 'Calculando firma SHA-256');
      await Future<void>.delayed(Duration.zero); // deja entrar mensajes ('cancel')
    }
    hasher.close();

    if (isCancelled()) return null;
    onProgress(0.95, 'Extrayendo forma de onda');
    final peaks = _extractWaveformPeaks(bytes, sampleCount: 40);
    onProgress(1.0, 'Listo');

    return AudioAnalysisResult(
      sha256: digestSink.value.toString(),
      format: format,
      waveformPeaks: peaks,
      byteLength: bytes.length,
    );
  }

  static Uint8List _readBytes(AudioAnalyzerPayload payload) {
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
    return bytes;
  }

  /// Análisis completo de una sola pasada (se usa en web, donde no hay isolates).
  static AudioAnalysisResult _performHeavyAudioAnalysis(AudioAnalyzerPayload payload) {
    final bytes = _readBytes(payload);
    return AudioAnalysisResult(
      sha256: sha256.convert(bytes).toString(),
      format: _detectAudioFormat(bytes),
      waveformPeaks: _extractWaveformPeaks(bytes, sampleCount: 40),
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

/// Sink mínimo para recibir el Digest del hash por bloques.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
