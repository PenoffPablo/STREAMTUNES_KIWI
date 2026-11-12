import 'package:streamtunes/models/parsed_lrc.dart';

class LrcParserService {
  static final RegExp _lrcRegex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)');

  /// Parsea un texto LRC con formato [mm:ss.xx] o [mm:ss.xxx]
  static List<LrcLine> parse(String? lrcContent) {
    if (lrcContent == null || lrcContent.trim().isEmpty) {
      return [];
    }

    final List<LrcLine> lines = [];
    final rawLines = lrcContent.split('\n');

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final match = _lrcRegex.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3);

        int milliseconds = 0;
        if (millisStr != null) {
          if (millisStr.length == 2) {
            milliseconds = int.parse(millisStr) * 10;
          } else {
            milliseconds = int.parse(millisStr);
          }
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        final text = match.group(4)?.trim() ?? '';
        lines.add(LrcLine(timestamp: duration, text: text));
      }
    }

    // Ordenar cronológicamente por si el archivo no estaba ordenado
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Encuentra el índice del verso actual basado en la posición de reproducción
  static int getCurrentLineIndex(List<LrcLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;
    if (currentPosition < lines.first.timestamp) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }
}

