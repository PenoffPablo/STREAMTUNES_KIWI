import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const QrScannerDialog(),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final _manualInputController = TextEditingController();
  bool _useManualInput = false;
  MobileScannerController? _scannerController;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final val = barcode.rawValue;
      if (val != null && val.isNotEmpty) {
        _hasDetected = true;
        Navigator.of(context).pop(val);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repos = RepositoriesScope.of(context);
    final hasCamera = repos.deviceService.hasCamera;

    // En escritorio forzar modo manual por defecto
    final showScanner = hasCamera && !_useManualInput;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner, color: AppTheme.primary),
          SizedBox(width: 10),
          Text('Escanear QR de Banda', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 360,
        child: Column(
          children: [
            const Text(
              'Apunta al cartel o remera de la banda para sumarte al instante:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: showScanner
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.keyboard, size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _manualInputController,
                            decoration: const InputDecoration(
                              labelText: 'Código o Slug de Banda',
                              hintText: 'Ej. los-fuzzers',
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              final text = _manualInputController.text.trim();
                              if (text.isNotEmpty) {
                                Navigator.of(context).pop(text);
                              }
                            },
                            child: const Text('Conectar'),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            if (hasCamera)
              TextButton.icon(
                onPressed: () => setState(() => _useManualInput = !_useManualInput),
                icon: Icon(
                  _useManualInput ? Icons.camera_alt : Icons.edit,
                  size: 16,
                  color: AppTheme.primary,
                ),
                label: Text(
                  _useManualInput ? 'Usar Cámara' : 'Ingreso Manual (Emulador / PC)',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

