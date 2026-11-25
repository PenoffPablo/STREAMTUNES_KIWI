import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Agenda de shows: alta y baja de fechas.
class EventsCard extends StatelessWidget {
  const EventsCard({super.key, required this.events, required this.onAdd, required this.onDelete});

  final List<BandEvent> events;
  final VoidCallback onAdd;
  final ValueChanged<BandEvent> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AGENDA DE SHOWS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppTheme.primary),
                onPressed: onAdd,
              ),
            ],
          ),
          if (events.isEmpty)
            const Text(
              'No hay fechas cargadas.',
              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            )
          else
            ...events.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${e.venue} • ${e.city} (${e.eventDate.day}/${e.eventDate.month})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                  onPressed: () => onDelete(e),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
