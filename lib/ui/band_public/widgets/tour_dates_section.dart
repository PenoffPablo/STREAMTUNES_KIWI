import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Próximas fechas en vivo con link a la venta de entradas.
class TourDatesSection extends StatelessWidget {
  const TourDatesSection({super.key, required this.events, required this.onOpenTickets});

  final List<BandEvent> events;
  final ValueChanged<String?> onOpenTickets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRÓXIMAS FECHAS EN VIVO',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text(
            'No hay fechas confirmadas por el momento.',
            style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
          )
        else
          ...events.map(
            (event) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Text(
                          '${event.eventDate.day}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                        Text(
                          _monthAbbr(event.eventDate.month),
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${event.venue} • ${event.city}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (event.ticketUrl != null)
                    TextButton(
                      onPressed: () => onOpenTickets(event.ticketUrl),
                      child: const Text('Entradas', style: TextStyle(color: AppTheme.primary)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _monthAbbr(int month) {
  const m = ['', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
  return m[month];
}
