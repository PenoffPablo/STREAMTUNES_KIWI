import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acceso a capacidades de la plataforma: abrir URLs/apps externas y portapapeles.
///
/// Antes esta lógica (MethodChannel + 4 fallbacks de url_launcher) estaba dentro
/// del widget `DonationModal`. Ahora vive en la capa de datos y el ViewModel la usa.
class ExternalLauncherService {
  static const MethodChannel _channel = MethodChannel('streamtunes/native_app_launcher');

  Future<void> copyToClipboard(String text) => Clipboard.setData(ClipboardData(text: text));

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

  /// Intenta abrir la app de Mercado Pago con varios mecanismos, en orden:
  /// canal nativo Android -> intent -> esquema -> Play Store -> web.
  Future<bool> openMercadoPagoApp() async {
    try {
      final res = await _channel.invokeMethod<bool>('openMercadoPago');
      if (res == true) return true;
    } catch (_) {
      // Canal nativo no disponible (iOS, web, escritorio o tests).
    }

    const candidates = [
      'intent://#Intent;package=com.mercadopago.wallet;end;',
      'mercadopago://',
      'market://details?id=com.mercadopago.wallet',
    ];
    for (final url in candidates) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri) &&
            await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
    return openUrl('https://www.mercadopago.com.ar');
  }
}
