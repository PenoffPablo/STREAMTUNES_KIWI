class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '${timestamp.inMilliseconds}ms: $text';
}

