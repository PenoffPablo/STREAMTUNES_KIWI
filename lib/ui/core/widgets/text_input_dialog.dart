import 'package:flutter/material.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Diálogo de un campo de texto que ES DUEÑO de su `TextEditingController`.
///
/// Antes los diálogos hacían `final ctrl = TextEditingController();` dentro de
/// un método y nunca lo liberaban (fuga de memoria). Al ser un StatefulWidget,
/// el controller se crea en `initState` y se libera en `dispose`.
///
/// Devuelve el texto confirmado (sin espacios extremos) o `null` si se canceló.
class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.title,
    required this.label,
    this.hint,
    this.initialValue = '',
    this.confirmLabel = 'Guardar',
    this.allowEmpty = false,
    this.keyboardType,
    this.header,
  });

  final String title;
  final String label;
  final String? hint;
  final String initialValue;
  final String confirmLabel;
  final bool allowEmpty;
  final TextInputType? keyboardType;

  /// Contenido opcional sobre el campo (por ejemplo, la vista previa de una foto).
  final Widget? header;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    String? hint,
    String initialValue = '',
    String confirmLabel = 'Guardar',
    bool allowEmpty = false,
    TextInputType? keyboardType,
    Widget? header,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => TextInputDialog(
        title: title,
        label: label,
        hint: hint,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        allowEmpty: allowEmpty,
        keyboardType: keyboardType,
        header: header,
      ),
    );
  }

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty && !widget.allowEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.header != null) ...[widget.header!, const SizedBox(height: 12)],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
