import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/utils/slug.dart';

/// Registro de una banda nueva. La banda nace PENDIENTE: un moderador la
/// revisa (música propia, datos reales) antes de que pueda subir temas.
class BandRegistrationViewModel extends ViewModel {
  BandRegistrationViewModel({required this.bandsRepo, required this.session, this.deviceService});

  final BandsRepository bandsRepo;
  final SessionViewModel session;
  final DeviceCapabilitiesService? deviceService;

  static const int minNameLength = 2;
  static const int maxNameLength = 60;
  static const int maxBioLength = 500;

  String _genre = kBandGenres.first;
  String? _coverPath;
  bool _isSubmitting = false;
  String? _errorMessage;

  String get genre => _genre;
  String? get coverPath => _coverPath;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasCamera => deviceService?.hasCamera ?? false;

  void selectGenre(String genre) {
    if (!kBandGenres.contains(genre) || genre == _genre) return;
    _genre = genre;
    notifyListeners();
  }

  Future<void> pickCover({bool fromCamera = false}) async {
    final path = await deviceService?.pickCoverPhoto(fromCamera: fromCamera);
    if (path == null) return;
    _coverPath = path;
    notifyListeners();
  }

  void removeCover() {
    _coverPath = null;
    notifyListeners();
  }

  /// Valida y registra la banda. Devuelve `true` si quedó registrada (en
  /// revisión); si no, el motivo queda en [errorMessage].
  Future<bool> submit({required String name, String? location, String? bio}) async {
    if (_isSubmitting) return false;
    final user = session.currentUser;
    final cleanName = name.trim();
    final cleanBio = bio?.trim();

    String? problem;
    if (user == null || user.isAnonymous) {
      problem = 'Tenés que iniciar sesión con tu cuenta para registrar una banda.';
    } else if (cleanName.length < minNameLength) {
      problem = 'Escribí el nombre de la banda.';
    } else if (cleanName.length > maxNameLength) {
      problem = 'El nombre puede tener hasta $maxNameLength caracteres.';
    } else if (cleanBio != null && cleanBio.length > maxBioLength) {
      problem = 'La biografía puede tener hasta $maxBioLength caracteres.';
    }
    if (problem != null) {
      _errorMessage = problem;
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await bandsRepo.createBand(
        Band(
          id: '',
          slug: slugify(cleanName),
          name: cleanName,
          genre: _genre,
          location: (location?.trim().isEmpty ?? true) ? null : location!.trim(),
          bio: (cleanBio?.isEmpty ?? true) ? null : cleanBio,
          coverUrl: _coverPath,
          createdAt: DateTime.now(),
        ),
        user!.id,
      );
      // El usuario ya es dueño de la banda (en revisión): se recarga la sesión.
      await session.refreshUser();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo registrar la banda. ${describeError(e)}';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
