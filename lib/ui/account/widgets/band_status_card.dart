import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_registration/widgets/band_registration_view.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// En "Cuenta": invita a registrar una banda o, si ya la registró, muestra
/// que está en revisión (o suspendida) con un botón para ver si ya la
/// aprobaron.
class BandStatusCard extends StatefulWidget {
  const BandStatusCard({super.key, required this.bandUnderReview, required this.onRefresh});

  /// Banda registrada que todavía no está aprobada. `null`: no tiene banda.
  final Band? bandUnderReview;
  final Future<void> Function() onRefresh;

  @override
  State<BandStatusCard> createState() => _BandStatusCardState();
}

class _BandStatusCardState extends State<BandStatusCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await widget.onRefresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final band = widget.bandUnderReview;
    final suspended = band?.isSuspended ?? false;
    final color = band == null ? AppTheme.primary : (suspended ? AppTheme.errorRed : AppTheme.accentOrange);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                band == null ? Icons.add_circle_outline : (suspended ? Icons.block : Icons.hourglass_top),
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  band == null
                      ? '¿Tenés una banda?'
                      : (suspended ? '${band.name}: no aprobada' : '${band.name}: en revisión'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            band == null
                ? 'Registrala para subir tus temas, recibir aportes de tus fans y ver tus métricas.'
                : (suspended
                    ? 'Un moderador no aprobó la banda. Si creés que es un error, escribinos.'
                    : 'Un moderador la está revisando. Cuando la aprueben vas a ver "Subir" y "Mi Banda".'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: band == null
                ? ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const BandRegistrationView()),
                    ),
                    icon: const Icon(Icons.music_note, size: 18),
                    label: const Text('Registrar mi banda'),
                  )
                : (suspended
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        onPressed: _refreshing ? null : _refresh,
                        icon: _refreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('¿Ya la aprobaron?'),
                      )),
          ),
        ],
      ),
    );
  }
}
