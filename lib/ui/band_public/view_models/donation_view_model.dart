import 'package:uuid/uuid.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository.dart';
import 'package:streamtunes/data/services/device/external_launcher_service.dart';
import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Comisión estimada de la pasarela (se muestra como desglose informativo).
const double kGatewayFeeRate = 0.06;

/// ViewModel del modal de donaciones.
///
/// Antes todo esto vivía dentro del widget `DonationModal`: cálculo de montos,
/// armado del pago, llamada a Mercado Pago, MethodChannel y fallbacks de URLs.
class DonationViewModel extends ViewModel {
  DonationViewModel({
    required this.band,
    required this.currentUser,
    required this.donationsRepo,
    required this.paymentsRepo,
    required this.launcher,
    this.maxAmount = 5000,
    String? donationId,
  }) : donationId = donationId ?? const Uuid().v4();

  /// Tope por donación (app_config.max_donation_ars). El trigger
  /// validate_donation rechaza montos mayores: no se ofrecen ni se cobran.
  final double maxAmount;

  final Band band;
  final AppUser? currentUser;
  final DonationsRepository donationsRepo;
  final PaymentsRepository paymentsRepo;
  final ExternalLauncherService launcher;

  /// Id de ESTE intento de donación. Se usa como `id` de la fila y viaja en el
  /// `external_reference` de Mercado Pago: si el webhook registra el pago y el
  /// fan además toca "Ya transferí", ambos escriben la misma fila (sin duplicar).
  final String donationId;

  static const List<double> _allPresets = [1000, 2500, 5000, 10000];

  /// Montos rápidos que no superan el tope.
  List<double> get presets =>
      _allPresets.where((p) => p <= maxAmount).toList(growable: false);

  double _amount = 1000;
  String _message = '';
  bool _isAnonymous = false;
  bool _isOpeningCheckout = false;
  bool _isSubmitting = false;
  bool _aliasCopied = false;
  bool _transferInitiated = false;
  String? _errorMessage;

  double get amount => _amount;
  bool get isAnonymous => _isAnonymous;
  bool get isOpeningCheckout => _isOpeningCheckout;
  bool get isSubmitting => _isSubmitting;
  bool get isBusy => _isOpeningCheckout || _isSubmitting;
  bool get aliasCopied => _aliasCopied;
  bool get transferInitiated => _transferInitiated;
  String? get errorMessage => _errorMessage;

  bool get exceedsMax => _amount > maxAmount;
  bool get canPay => _amount > 0 && !exceedsMax && !isBusy;
  double get estimatedFee => _amount * kGatewayFeeRate;
  double get netBandAmount =>
      (_amount - estimatedFee).clamp(0.0, double.infinity);

  String get donorName => _isAnonymous
      ? 'Fan anónimo'
      : (currentUser?.displayName ?? 'Fan de la banda');

  /// Alias de Mercado Pago de la banda, o `null` si no cargó uno.
  ///
  /// Ya NO hay alias por defecto: antes, si la banda no tenía alias, la plata
  /// se transfería a una cuenta personal ajena a la banda.
  String? get alias {
    final rawAlias = band.socialLinks['alias'] as String?;
    if (rawAlias != null && rawAlias.trim().isNotEmpty) return rawAlias.trim();
    final rawMp = band.socialLinks['mercadopago'] as String?;
    if (rawMp != null && rawMp.trim().isNotEmpty && !rawMp.startsWith('http')) {
      return rawMp.trim();
    }
    return null;
  }

  bool get hasAlias => alias != null;

  /// "Ya transferí" solo tiene sentido si hubo una transferencia a un alias real.
  bool get canConfirmTransfer => hasAlias && canPay;

  void setAmountText(String text) {
    _amount = double.tryParse(text.replaceAll(',', '.')) ?? 0;
    notifyListeners();
  }

  void setMessage(String text) => _message = text.trim();

  void setAnonymous(bool value) {
    _isAnonymous = value;
    notifyListeners();
  }

  Future<void> copyAlias() async {
    final value = alias;
    if (value == null) return;
    await launcher.copyToClipboard(value);
    _aliasCopied = true;
    notifyListeners();
  }

  /// Paso 1: crea la preferencia de pago (Edge Function) y abre el checkout.
  /// Si no se puede y la banda tiene alias, abre la app de Mercado Pago con el
  /// alias copiado. Sin alias no hay a dónde transferir: se informa el error.
  Future<void> startCheckout() async {
    if (!canPay) return;
    _isOpeningCheckout = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? initPoint;
      try {
        initPoint = await paymentsRepo
            .createDonationCheckout(
              donationId: donationId,
              bandId: band.id,
              bandName: band.name,
              amount: _amount,
              donorUserId: currentUser?.id,
              donorName: donorName,
              message: _message.isEmpty ? null : _message,
              isAnonymous: _isAnonymous,
            )
            .withNetworkTimeout();
      } catch (e) {
        _errorMessage = 'No se pudo abrir el checkout (${describeError(e)}).';
      }

      if (initPoint != null && await launcher.openUrl(initPoint)) {
        _transferInitiated = true;
        return;
      }

      if (!hasAlias) {
        _errorMessage =
            'El pago con Mercado Pago no está disponible y la banda no '
            'configuró un alias para transferencias. Probá más tarde.';
        return;
      }
      _errorMessage = _errorMessage == null
          ? null
          : '$_errorMessage Transferí al alias.';
      await copyAlias();
      _transferInitiated = true;
      await launcher.openMercadoPagoApp();
    } finally {
      _isOpeningCheckout = false;
      notifyListeners();
    }
  }

  /// Paso 2: el fan confirma que transfirió al alias y se publica en el muro.
  /// Usa el mismo [donationId] que el checkout: si el webhook ya lo registró,
  /// el repositorio devuelve esa fila en lugar de crear otra.
  Future<bool> confirmDonation() async {
    if (!canConfirmTransfer) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await donationsRepo
          .createDonation(
            Donation(
              id: donationId,
              bandId: band.id,
              donorUserId: currentUser?.id,
              donorName: donorName,
              amountArs: _amount,
              message: _message.isEmpty ? null : _message,
              isAnonymous: _isAnonymous,
              status: 'approved',
              createdAt: DateTime.now(),
            ),
          )
          .withNetworkTimeout();
      return true;
    } catch (e) {
      _errorMessage = describeError(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
