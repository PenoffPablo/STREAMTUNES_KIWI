import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/band_public/view_models/donation_view_model.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';

/// Modal de aportes voluntarios a bandas mediante Mercado Pago.
///
/// Es una View "tonta": dibuja el estado de [DonationViewModel] y le delega las
/// acciones. El ViewModel se crea en `initState` y se libera en `dispose`.
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

  void _showSnack(
    String text, {
    Color? background,
    Color textColor = Colors.white,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: background,
        content: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _copyAlias() async {
    await _vm.copyAlias();
    if (!mounted || !_vm.aliasCopied) return;
    _showSnack(
      '¡Alias "${_vm.alias}" copiado al portapapeles!',
      background: const Color(0xFF009EE3),
    );
  }

  Future<void> _startCheckout() async {
    await _vm.startCheckout();
    if (!mounted) return;
    final error = _vm.errorMessage;
    if (error != null) _showSnack(error, background: AppTheme.accentOrange);
  }

  Future<void> _confirm() async {
    // Se capturan antes del await: después del pop() este context ya no es válido.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = _vm.amount.toInt();
    final ok = await _vm.confirmDonation();
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          content: Text(
            '¡Aporte de \$$amount ARS registrado con éxito!',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      _showSnack(
        _vm.errorMessage ?? 'Error al procesar el aporte.',
        background: AppTheme.errorRed,
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
    final alias = vm.alias;

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
            // Encabezado del modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Apoyar a ${widget.band.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Text(
              'Aporte directo y sin intermediarios discográficos mediante Mercado Pago.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Tarjeta del alias: solo si la banda cargó uno propio.
            if (alias != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF009EE3).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF009EE3).withAlpha(120),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payment, size: 18, color: Color(0xFF009EE3)),
                        SizedBox(width: 8),
                        Text(
                          'Mercado Pago Oficial (Argentina)',
                          style: TextStyle(
                            color: Color(0xFF009EE3),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alias de destino:',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              SelectableText(
                                alias,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009EE3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _copyAlias,
                          icon: Icon(
                            vm.aliasCopied ? Icons.check : Icons.copy,
                            size: 16,
                          ),
                          label: Text(
                            vm.aliasCopied ? 'Copiado' : 'Copiar Alias',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Botones de selección rápida con montos predefinidos
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

            // Campo de monto personalizado, con el tope de app_config
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto a donar en pesos (ARS)',
                prefixText: '\$ ',
                helperText:
                    'Aporte libre de hasta \$${vm.maxAmount.toInt()} ARS.',
                errorText: vm.exceedsMax
                    ? 'El máximo por donación es \$${vm.maxAmount.toInt()} ARS.'
                    : null,
              ),
              onChanged: vm.setAmountText,
            ),
            const SizedBox(height: 12),

            // Mensaje de aliento para la banda
            TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mensaje de aliento para la banda (opcional)',
                hintText: '¡Aguante el show del sábado!',
              ),
              onChanged: vm.setMessage,
            ),
            const SizedBox(height: 8),

            // Opción de Donación Anónima
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Donar de forma anónima',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Tu nombre no aparecerá en el muro público ni en rankings de fans.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: vm.isAnonymous,
              activeThumbColor: AppTheme.primary,
              onChanged: vm.setAnonymous,
            ),
            const Divider(color: AppTheme.surfaceLight),

            // Desglose Transparente del aporte
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a aportar:',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '\$${vm.amount.toStringAsFixed(2)} ARS',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Comisión estimada de pasarela (6%):',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '-\$${vm.estimatedFee.toStringAsFixed(2)} ARS',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Neto directo a la banda:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${vm.netBandAmount.toStringAsFixed(2)} ARS',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (alias == null) ...[
              const Text(
                'Esta banda todavía no configuró un alias: el aporte se hace con el '
                'checkout de Mercado Pago y queda registrado automáticamente al aprobarse el pago.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
            ],

            // Mensaje orientativo (solo transferencias por alias)
            if (vm.transferInitiated && alias != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Si pagaste con el checkout, el aporte se registra solo. Si transferiste \$${vm.amount.toInt()} ARS al alias "$alias", presioná "Ya transferí" para publicarlo en el muro.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botón 1: Abrir Mercado Pago y Copiar Alias
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF009EE3),
                  side: const BorderSide(color: Color(0xFF009EE3), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: vm.canPay ? _startCheckout : null,
                icon: vm.isOpeningCheckout
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF009EE3),
                        ),
                      )
                    : const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  vm.isOpeningCheckout
                      ? 'Conectando con Mercado Pago...'
                      : '1. Pagar \$${vm.amount.toInt()} ARS con Mercado Pago Oficial',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Botón 2: confirmación de transferencia por alias (no aplica sin alias).
            if (alias != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: vm.canConfirmTransfer ? _confirm : null,
                  icon: vm.isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.favorite, size: 20),
                  label: Text(
                    vm.isSubmitting
                        ? 'Registrando aporte...'
                        : '2. Ya transferí (Confirmar mi donación)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
