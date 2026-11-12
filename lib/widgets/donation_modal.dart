import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/services/mercadopago_service.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal interactivo de aportes voluntarios directos a bandas mediante Mercado Pago
class DonationModal extends StatefulWidget {
  final Band band;
  final BandPublicViewModel viewModel;

  const DonationModal({
    super.key,
    required this.band,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, Band band, BandPublicViewModel vm) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DonationModal(band: band, viewModel: vm),
    );
  }

  @override
  State<DonationModal> createState() => _DonationModalState();
}

class _DonationModalState extends State<DonationModal> {
  final _amountController = TextEditingController(text: '1000');
  final _messageController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  bool _copiedAlias = false;
  bool _transferInitiated = false;

  final List<double> _presets = [1000, 2500, 5000, 10000];

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_amountController.text) ?? 0.0;

  // Desglose transparente: Comisión externa estimada de pasarela (~6%) vs Neto directo para la banda
  double get _estimatedFee => _currentAmount * 0.06;
  double get _netBandAmount => (_currentAmount - _estimatedFee).clamp(0.0, double.infinity);

  /// Obtiene el Alias oficial de Mercado Pago para la banda (por defecto penoff.pablo)
  String get _mercadoPagoAlias {
    final rawAlias = widget.band.socialLinks['alias'] as String?;
    if (rawAlias != null && rawAlias.trim().isNotEmpty) {
      return rawAlias.trim();
    }
    final rawMp = widget.band.socialLinks['mercadopago'] as String?;
    if (rawMp != null && rawMp.trim().isNotEmpty && !rawMp.startsWith('http')) {
      return rawMp.trim();
    }
    return 'penoff.pablo';
  }

  /// Copia el alias al portapapeles del dispositivo
  Future<void> _copyAliasToClipboard(String alias) async {
    await Clipboard.setData(ClipboardData(text: alias));
    setState(() => _copiedAlias = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF009EE3),
          duration: const Duration(seconds: 3),
          content: Text(
            '¡Alias "$alias" copiado al portapapeles!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  static const _platform = MethodChannel('streamtunes/native_app_launcher');

  String _currentExtRef = '';

  /// Abre la pasarela oficial de Mercado Pago con el monto exacto bloqueado
  Future<void> _launchMercadoPago(String alias) async {
    await _copyAliasToClipboard(alias);
    setState(() {
      _transferInitiated = true;
      _isSubmitting = true;
    });

    _currentExtRef = 'st_don_${DateTime.now().millisecondsSinceEpoch}_${widget.band.id.substring(0, 8)}';

    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;
    final donorName = _isAnonymous ? 'Fan anónimo' : (user?.displayName ?? 'Fan de la banda');

    // 1. Intentar crear preferencia oficial en Mercado Pago con el monto exacto
    final initPoint = await MercadoPagoService.createDonationPreference(
      bandId: widget.band.id,
      bandName: widget.band.name,
      amount: _currentAmount,
      donorUserId: user?.id,
      donorName: donorName,
      message: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
      isAnonymous: _isAnonymous,
      externalReference: _currentExtRef,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    if (initPoint != null) {
      final uri = Uri.parse(initPoint);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        debugPrint('[MercadoPago] Error abriendo init_point: $e');
      }
    }

    // 2. Si falló la creación de preferencia, invocar canal nativo Android
    bool openedNatively = false;
    try {
      final res = await _platform.invokeMethod<bool>('openMercadoPago');
      openedNatively = res == true;
    } catch (_) {}

    if (openedNatively) return;

    // 3. Fallback a esquemas universales
    final intentUri = Uri.parse('intent://#Intent;package=com.mercadopago.wallet;end;');
    final schemeUri = Uri.parse('mercadopago://');
    final playStoreUri = Uri.parse('market://details?id=com.mercadopago.wallet');
    final webUri = Uri.parse('https://www.mercadopago.com.ar');

    try {
      if (await canLaunchUrl(intentUri)) {
        openedNatively = await launchUrl(intentUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (!openedNatively) {
      try {
        if (await canLaunchUrl(schemeUri)) {
          openedNatively = await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    if (!openedNatively) {
      try {
        if (await canLaunchUrl(playStoreUri)) {
          openedNatively = await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    if (!openedNatively) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[MercadoPago] Error abriendo navegador: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;
    final alias = _mercadoPagoAlias;

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
              'Aporte directo y sin intermediarios discográficos mediante Mercado Pago.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Tarjeta de Datos Oficiales de Mercado Pago
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF009EE3).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF009EE3).withAlpha(120)),
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
                            const Text('Alias de destino:',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _copyAliasToClipboard(alias),
                        icon: Icon(_copiedAlias ? Icons.check : Icons.copy, size: 16),
                        label: Text(_copiedAlias ? 'Copiado' : 'Copiar Alias'),
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
              children: _presets.map((preset) {
                final isSelected = _currentAmount == preset;
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
                    setState(() {
                      _amountController.text = preset.toInt().toString();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Campo de monto personalizado sin límite superior
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto a donar en pesos (ARS)',
                prefixText: '\$ ',
                helperText: 'Aporte libre y personalizado. Puedes ingresar cualquier valor sin límite.',
              ),
              onChanged: (_) => setState(() {}),
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
            ),
            const SizedBox(height: 8),

            // Opción de Donación Anónima
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Donar de forma anónima', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Tu nombre no aparecerá en el muro público ni en rankings de fans.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: _isAnonymous,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) => setState(() => _isAnonymous = val),
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
                      const Text('Total a aportar:', style: TextStyle(fontSize: 13)),
                      Text('\$${_currentAmount.toStringAsFixed(2)} ARS',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Comisión estimada de pasarela (6%):',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text('-\$${_estimatedFee.toStringAsFixed(2)} ARS',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Neto directo a la banda:',
                          style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      Text('\$${_netBandAmount.toStringAsFixed(2)} ARS',
                          style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Mensaje orientativo de confirmación
            if (_transferInitiated) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transferí \$${_currentAmount.toInt()} ARS al alias "$alias". Luego presiona "Confirmar mi donación" para que se publique en el muro.',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _currentAmount <= 0 ? null : () => _launchMercadoPago(alias),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF009EE3)),
                      )
                    : const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  _isSubmitting
                      ? 'Conectando con Mercado Pago...'
                      : '1. Pagar \$${_currentAmount.toInt()} ARS con Mercado Pago Oficial',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Botón 2: Confirmación consciente y registro en la base de datos
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting || _currentAmount <= 0
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        final donorName = _isAnonymous
                            ? 'Fan anónimo'
                            : (user?.displayName ?? 'Fan de la banda');

                        // Registrar donación en Supabase
                        final success = await widget.viewModel.submitDonation(
                          donorUserId: user?.id,
                          donorName: donorName,
                          amountArs: _currentAmount,
                          message: _messageController.text.trim().isNotEmpty
                              ? _messageController.text.trim()
                              : null,
                          isAnonymous: _isAnonymous,
                        );

                        if (context.mounted) {
                          setState(() => _isSubmitting = false);
                          if (success) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.primary,
                                content: Text(
                                  '¡Aporte de \$${_currentAmount.toInt()} ARS registrado con éxito!',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.errorRed,
                                content: Text(widget.viewModel.errorMessage ?? 'Error al procesar el aporte.'),
                              ),
                            );
                          }
                        }
                      },
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.favorite, size: 20),
                label: Text(
                  _isSubmitting
                      ? 'Registrando aporte...'
                      : '2. Ya transferí (Confirmar mi donación)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
