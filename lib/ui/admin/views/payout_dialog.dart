import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Datos de una liquidación que carga el moderador.
typedef PayoutData = ({double amount, String? reference, String? note});

/// Diálogo para registrar que KIWI le transfirió dinero a una banda.
///
/// StatefulWidget dueño de sus `TextEditingController` (se liberan en
/// `dispose`). Solo junta y valida los datos: la acción la ejecuta la View con
/// el ViewModel.
class PayoutDialog extends StatefulWidget {
  const PayoutDialog({super.key, required this.balance});

  final BandBalance balance;

  static Future<PayoutData?> show(BuildContext context, BandBalance balance) =>
      showDialog<PayoutData>(context: context, builder: (_) => PayoutDialog(balance: balance));

  @override
  State<PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends State<PayoutDialog> {
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Por defecto se propone liquidar todo el saldo pendiente.
    _amount = TextEditingController(text: widget.balance.pending.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresá un monto mayor a cero.');
      return;
    }
    if (amount > widget.balance.pending + 0.001) {
      setState(() => _error =
          'Supera el saldo pendiente (\$${widget.balance.pending.toStringAsFixed(2)}).');
      return;
    }
    final ref = _reference.text.trim();
    final note = _note.text.trim();
    Navigator.of(context).pop<PayoutData>(
      (amount: amount, reference: ref.isEmpty ? null : ref, note: note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Pagar a ${b.bandName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo pendiente: \$${b.pending.toStringAsFixed(2)} ARS\n'
              'Registrá el pago DESPUÉS de hacer la transferencia desde la cuenta de KIWI.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto transferido (ARS) *', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reference,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'N.º de operación de Mercado Pago',
                hintText: 'Para poder rastrear la transferencia',
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Registrar pago')),
      ],
    );
  }
}
