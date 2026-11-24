import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Recuadro para mostrar un error de forma clara: QUÉ falló (título), la
/// explicación para el usuario (que arma `describeError`) y, si tiene sentido,
/// un botón para reintentar. Nunca muestra el error técnico crudo.
///
/// [warning] = algo secundario falló pero el resto de la pantalla sirve
/// (naranja). Sin [warning] = la acción principal falló (rojo).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, this.title, required this.message, this.onRetry, this.warning = false});

  /// Qué falló. Opcional: si [message] ya lo dice ("No se pudo X. ..."), se omite.
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppTheme.accentOrange : AppTheme.errorRed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning ? Icons.warning_amber_rounded : Icons.error_outline, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(message, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, size: 16, color: color),
              label: Text('Reintentar', style: TextStyle(color: color, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// SnackBar de error con el mismo formato que [ErrorBanner] (ícono + qué falló
/// + explicación). Para acciones puntuales: pagar, guardar, borrar...
void showErrorSnackBar(BuildContext context, {String? title, required String message}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.errorRed,
        duration: const Duration(seconds: 6),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
}
