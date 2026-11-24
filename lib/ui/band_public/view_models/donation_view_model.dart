import 'package:uuid/uuid.dart';
import 'package:streamtunes/data/repositories/payments/payments_repository.dart';
import 'package:streamtunes/data/services/device/external_launcher_service.dart';
import 'package:streamtunes/domain/models/app_user.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Comisión estimada de Mercado Pago (se muestra como desglose informativo).
const double kGatewayFeeRate = 0.06;

/// ViewModel del modal de aportes.
///
/// Modelo de cobro: todos los aportes se pagan con el checkout de Mercado
/// Pago en la cuenta de KIWI. El webhook verifica cada pago contra la API de
/// Mercado Pago y recién ahí lo registra; después KIWI le liquida a la banda.
/// La app no registra donaciones: solo abre el checkout.
class DonationViewModel extends ViewModel {
  DonationViewModel({
    required this.band,
    required this.currentUser,
    required this.paymentsRepo,
    required this.launcher,
    this.maxAmount = 5000,
  });

  final Band band;
  final AppUser? currentUser;
  final PaymentsRepository paymentsRepo;
  final ExternalLauncherService launcher;

  /// Tope por aporte (app_config.max_donation_ars). La base rechaza montos
  /// mayores, así que no se ofrecen ni se cobran.
  final double maxAmount;

  /// Id del ÚLTIMO intento de pago (uno nuevo cada vez que se toca "Pagar").
  /// Viaja a Mercado Pago solo para trazabilidad: la idempotencia del webhook
  /// usa el id del pago de MP. Si el fan paga dos veces desde el mismo modal,
  /// son dos aportes distintos y quedan registrados los dos.
  String? _donationId;
  String? get donationId => _donationId;

  static const List<double> _allPresets = [1000, 2500, 5000, 10000];

  double _amount = 1000;
  String _message = '';
  bool _isAnonymous = false;
  bool _isOpeningCheckout = false;
  bool _checkoutOpened = false;
  String? _errorMessage;

  double get amount => _amount;
  bool get isAnonymous => _isAnonymous;
  bool get isOpeningCheckout => _isOpeningCheckout;

  /// `true` cuando ya se abrió el checkout (para mostrar qué pasa después).
  bool get checkoutOpened => _checkoutOpened;
  String? get errorMessage => _errorMessage;

  /// Montos rápidos que no superan el tope.
  List<double> get presets => _allPresets.where((p) => p <= maxAmount).toList(growable: false);

  bool get exceedsMax => _amount > maxAmount;
  bool get canPay => _amount > 0 && !exceedsMax && !_isOpeningCheckout;
  double get estimatedFee => _amount * kGatewayFeeRate;
  double get netBandAmount => (_amount - estimatedFee).clamp(0.0, double.infinity);


  void setAmountText(String text) {
    _amount = double.tryParse(text.replaceAll(',', '.')) ?? 0;
    notifyListeners();
  }

  void setMessage(String text) => _message = text.trim();

  void setAnonymous(bool value) {
    _isAnonymous = value;
    notifyListeners();
  }

  /// Crea el cobro en Mercado Pago (Edge Function, cuenta de KIWI) y abre el
  /// checkout. El aporte aparece en el muro cuando Mercado Pago lo aprueba.
  Future<void> startCheckout() async {
    if (!canPay) return;
    final attemptId = _donationId = const Uuid().v4(); // un id por intento
    _isOpeningCheckout = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final initPoint = await paymentsRepo
          .createDonationCheckout(
            donationId: attemptId,
            bandId: band.id,
            amount: _amount,
            message: _message.isEmpty ? null : _message,
            isAnonymous: _isAnonymous,
          )
          .withNetworkTimeout();

      if (initPoint == null) {
        _errorMessage = 'Los pagos con Mercado Pago no están disponibles en este momento.';
      } else if (await launcher.openUrl(initPoint)) {
        _checkoutOpened = true;
      } else {
        _errorMessage = 'No se pudo abrir Mercado Pago en este dispositivo.';
      }
    } catch (e) {
      _errorMessage = describeError(e);
    } finally {
      _isOpeningCheckout = false;
      notifyListeners();
    }
  }
}
