import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Encapsula `app_links` y expone los deep links como un Stream de slugs de banda.
///
/// Transforma `Stream<Uri>` -> `Stream<String>` con operadores de Stream
/// (`where` + `map` + `distinct`) en vez de procesar todo en un callback de la View.
class DeepLinkService {
  DeepLinkService({this._appLinks});

  AppLinks? _appLinks;

  /// Slugs/IDs de banda recibidos por `streamtunes://band/<slug>` o
  /// `https://streamtunes.app/band/<slug>`.
  Stream<String> get bandLinks {
    final Stream<Uri> source;
    try {
      _appLinks ??= AppLinks();
      source = _appLinks!.uriLinkStream;
    } catch (e) {
      debugPrint('[DeepLinkService] No soportado en este entorno: $e');
      return const Stream<String>.empty();
    }
    return source
        .handleError((Object e) => debugPrint('[DeepLinkService] Error en link: $e'))
        .map(extractBandSlug)
        .where((slug) => slug != null && slug.isNotEmpty)
        .cast<String>()
        .distinct();
  }

  /// Extrae el slug de banda de un link. Devuelve `null` si no es un link de banda.
  @visibleForTesting
  static String? extractBandSlug(Uri uri) {
    final raw = uri.toString();
    if (!raw.contains('/band/')) return null;
    return raw.split('/band/').last.split('?').first.replaceAll(RegExp(r'/+$'), '').trim();
  }
}
