import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_public/view_models/donation_view_model.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

const _mercadoPagoBlue = Color(0xFF009EE3);

/// Modal de aportes voluntarios a bandas.
///
/// El fan paga con el checkout de Mercado Pago (cuenta de KIWI); KIWI después
/// le liquida el aporte a la banda. Es una View "tonta": dibuja el estado de
/// [DonationViewModel] y le delega las acciones. El ViewModel se crea en
/// `initState` y se libera en `dispose`.
class DonationModal extends StatefulWidget {
  final Band band;

  const DonationModal({super.key, required this.band});

  static Future<void> show(BuildContext context, Band band) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DonationModal(band: band),
    );
  }

  @override
  State<DonationModal> createState() => _DonationModalState();
}

class _DonationModalState extends State<DonationModal> {
  late final DonationViewModel _vm;
  final _amountController = TextEditingController(text: '1000');
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final session = SessionScope.read(context);
    _vm = DependenciesScope.of(context).createDonationViewModel(
      band: widget.band,
      currentUser: session.currentUser,
      maxAmount: session.config.maxDonationArs,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    await _vm.startCheckout();
    if (!mounted) return;
    final error = _vm.errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentOrange,
          content: Text(error, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final vm = _vm;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Apoyar a ${widget.band.name}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Text(
              'Pagás con Mercado Pago. KIWI recibe tu aporte y se lo transfiere a la banda.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Montos rápidos (solo los que no superan el tope)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: vm.presets.map((preset) {
                final isSelected = vm.amount == preset;
                return ChoiceChip(
                  label: Text('\$${preset.toInt()}'),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    _amountController.text = preset.toInt().toString();
                    vm.setAmountText(_amountController.text);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Monto personalizado, con el tope de app_config
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto a aportar en pesos (ARS)',
                prefixText: '\$ ',
                helperText: 'Aporte libre de hasta \$${vm.maxAmount.toInt()} ARS.',
                errorText: vm.exceedsMax
                    ? 'El máximo por aporte es \$${vm.maxAmount.toInt()} ARS.'
                    : null,
              ),
              onChanged: vm.setAmountText,
            ),
            const SizedBox(height: 12),

            // Mensaje para la banda
            TextField(
              controller: _messageController,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Mensaje de aliento para la banda (opcional)',
                hintText: '¡Aguante el show del sábado!',
              ),
              onChanged: vm.setMessage,
            ),

            // Anónimo
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aportar de forma anónima', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Tu nombre no aparecerá en el muro público ni en rankings de fans.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: vm.isAnonymous,
              activeThumbColor: AppTheme.primary,
              onChanged: vm.setAnonymous,
            ),
            const Divider(color: AppTheme.surfaceLight),

            // Desglose transparente
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _row('Total a aportar:', '\$${vm.amount.toStringAsFixed(2)} ARS', bold: true),
                  const SizedBox(height: 4),
                  _row(
                    'Comisión estimada de Mercado Pago (6%):',
                    '-\$${vm.estimatedFee.toStringAsFixed(2)} ARS',
                    secondary: true,
                  ),
                  const SizedBox(height: 4),
                  _row(
                    'Neto estimado para la banda:',
                    '\$${vm.netBandAmount.toStringAsFixed(2)} ARS',
                    bold: true,
                    highlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Qué pasa después de pagar
            if (vm.checkoutOpened) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(100)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cuando Mercado Pago apruebe el pago, tu aporte aparece en el muro '
                        'de la banda automáticamente. No hace falta hacer nada más.',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Pagar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mercadoPagoBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: vm.canPay ? _startCheckout : null,
                icon: vm.isOpeningCheckout
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_outline, size: 20),
                label: Text(
                  vm.isOpeningCheckout
                      ? 'Conectando con Mercado Pago...'
                      : 'Pagar \$${vm.amount.toInt()} ARS con Mercado Pago',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool secondary = false, bool highlight = false}) {
    final color = highlight ? AppTheme.primary : (secondary ? AppTheme.textSecondary : null);
    final size = secondary ? 12.0 : 13.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label, style: TextStyle(fontSize: size, color: color, fontWeight: highlight ? FontWeight.bold : null)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : null),
        ),
      ],
    );
  }
}
