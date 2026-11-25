import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Datos que devuelve [AddEventDialog].
typedef NewEventData = ({
  String title,
  String venue,
  String city,
  DateTime date,
  String? ticketUrl,
});

/// Datos que devuelve [EditSongDialog].
typedef SongEditData = ({String title, String genre, String? lyricsLrc});

/// Diálogo para cargar una fecha de show.
///
/// Es un StatefulWidget dueño de sus 4 `TextEditingController` (se liberan en
/// `dispose`). Antes se creaban en un método de la View y nunca se liberaban.
/// Solo junta datos: la acción la ejecuta la View con el ViewModel.
class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  static Future<NewEventData?> show(BuildContext context) =>
      showDialog<NewEventData>(context: context, builder: (_) => const AddEventDialog());

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _city = TextEditingController(text: 'Buenos Aires');
  final _ticket = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _city.dispose();
    _ticket.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final venue = _venue.text.trim();
    if (title.isEmpty || venue.isEmpty) return;
    final ticket = _ticket.text.trim();
    Navigator.of(context).pop<NewEventData>((
      title: title,
      venue: venue,
      city: _city.text.trim(),
      date: _date,
      ticketUrl: ticket.isEmpty ? null : ticket,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Agregar Fecha de Show'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Nombre del Evento *')),
            const SizedBox(height: 10),
            TextField(controller: _venue, decoration: const InputDecoration(labelText: 'Lugar / Venue *')),
            const SizedBox(height: 10),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad *')),
            const SizedBox(height: 10),
            TextField(controller: _ticket, decoration: const InputDecoration(labelText: 'Link de Entradas (Opcional)')),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'),
                TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

/// Diálogo para editar título, género y letra LRC de una canción.
class EditSongDialog extends StatefulWidget {
  const EditSongDialog({super.key, required this.song});

  final Song song;

  static Future<SongEditData?> show(BuildContext context, Song song) =>
      showDialog<SongEditData>(context: context, builder: (_) => EditSongDialog(song: song));

  @override
  State<EditSongDialog> createState() => _EditSongDialogState();
}

class _EditSongDialogState extends State<EditSongDialog> {
  late final TextEditingController _title;
  late final TextEditingController _genre;
  late final TextEditingController _lyrics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.song.title);
    _genre = TextEditingController(text: widget.song.genre);
    _lyrics = TextEditingController(text: widget.song.lyricsLrc ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _genre.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final genre = _genre.text.trim();
    if (title.isEmpty || genre.isEmpty) {
      setState(() => _error = 'El título y género no pueden estar vacíos.');
      return;
    }
    final lyrics = _lyrics.text.trim();
    Navigator.of(context).pop<SongEditData>(
      (title: title, genre: genre, lyricsLrc: lyrics.isEmpty ? null : lyrics),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Row(
        children: [
          const Icon(Icons.edit_note, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Editar "${widget.song.title}"',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título de la canción *')),
            const SizedBox(height: 12),
            TextField(
              controller: _genre,
              decoration: const InputDecoration(labelText: 'Género musical *', hintText: 'Ej. Indie Rock, Post-punk'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lyrics,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Letra sincronizada (LRC opcional)',
                hintText: '[00:15.00] Primera línea de letra...',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
