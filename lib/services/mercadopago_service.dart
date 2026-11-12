import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Servicio oficial de integración con la API de Mercado Pago
class MercadoPagoService {
  static const String _accessToken =
      'APP_USR-7613599433502528-111202-21e9e54b88ca697bdca97d682d2a7d69-611041232';

  /// Crea una preferencia de pago oficial en Mercado Pago con el monto exacto y bloqueado
  static Future<String?> createDonationPreference({
    required String bandId,
    required String bandName,
    required double amount,
    String? donorUserId,
    String? donorName,
    String? message,
    bool isAnonymous = false,
    String? externalReference,
  }) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('https://api.mercadopago.com/checkout/preferences');
      final request = await client.postUrl(uri);

      request.headers.set('Authorization', 'Bearer $_accessToken');
      request.headers.set('Content-Type', 'application/json');

      final extRef = externalReference ??
          jsonEncode({
            'band_id': bandId,
            'donor_user_id': donorUserId,
            'donor_name': donorName,
            'message': message,
            'is_anonymous': isAnonymous,
          });

      final payload = {
        'items': [
          {
            'id': 'donacion-$bandId',
            'title': 'Aporte a $bandName (StreamTunes)',
            'description': 'Aporte directo a la banda independiente mediante StreamTunes',
            'quantity': 1,
            'currency_id': 'ARS',
            'unit_price': amount,
          }
        ],
        'back_urls': {
          'success': 'https://streamtunes.app/band/$bandId?status=success',
          'failure': 'https://streamtunes.app/band/$bandId?status=failure',
          'pending': 'https://streamtunes.app/band/$bandId?status=pending',
        },
        'auto_return': 'approved',
        'notification_url':
            'https://fajwcwabcdxetuffoiuh.supabase.co/functions/v1/mercadopago-webhook',
        'external_reference': extRef,
        'statement_descriptor': 'STREAMTUNES',
      };

      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final initPoint = data['init_point'] as String?;
        return initPoint;
      } else {
        debugPrint('[MercadoPagoService] Error creando preferencia: $body');
        return null;
      }
    } catch (e) {
      debugPrint('[MercadoPagoService] Excepción creando preferencia: $e');
      return null;
    }
  }

  /// Consulta a Mercado Pago si existe un pago aprobado para una referencia externa
  static Future<bool> isPaymentApproved(String externalReference) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(
          'https://api.mercadopago.com/v1/payments/search?external_reference=${Uri.encodeComponent(externalReference)}&sort=date_created&criteria=desc&limit=1');
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $_accessToken');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final status = first['status'] as String?;
          return status == 'approved';
        }
      }
      return false;
    } catch (e) {
      debugPrint('[MercadoPagoService] Error verificando pago: $e');
      return false;
    }
  }
}

