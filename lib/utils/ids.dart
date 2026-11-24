final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// `true` si [value] tiene formato UUID (los ids de la base).
///
/// Sirve para no mandar un *slug* (ej. `los-fuzzers`) a una columna uuid:
/// Postgres respondería con un error de tipo que se confundiría con un
/// error de red.
bool isUuid(String value) => _uuidRe.hasMatch(value.trim());
