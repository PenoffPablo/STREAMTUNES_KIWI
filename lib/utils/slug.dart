/// Convierte un nombre en un slug para la URL y el QR de la banda:
/// "Los Fuzzers del Sótano" -> "los-fuzzers-del-sotano".
String slugify(String text) {
  const accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  final lower = text.trim().toLowerCase();
  final plain = StringBuffer();
  for (final ch in lower.split('')) {
    plain.write(accents[ch] ?? ch);
  }
  final slug = plain
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'banda' : (slug.length > 50 ? slug.substring(0, 50).replaceAll(RegExp(r'-+$'), '') : slug);
}
