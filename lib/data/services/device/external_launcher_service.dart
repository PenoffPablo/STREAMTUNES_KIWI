import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre URLs en apps externas (checkout de Mercado Pago, merch, entradas).
///
/// Encapsula `url_launcher` en la capa de datos: los ViewModels lo reciben
/// inyectado y las Views nunca usan la plataforma directamente.
class ExternalLauncherService {
  /// Abre una URL en una app externa. Devuelve `true` si se pudo abrir.
  Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[ExternalLauncherService] No se pudo abrir $url: $e');
      return false;
    }
  }
}
