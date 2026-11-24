import 'dart:async';

import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/data/services/device/external_launcher_service.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

class BandPublicViewModel extends ViewModel {
  final BandsRepository bandsRepo;
  final SongsRepository songsRepo;
  final DonationsRepository donationsRepo;
  final String bandId;
  final ExternalLauncherService? launcher;

  Band? _band;
  List<Song> _songs = [];
  List<BandEvent> _events = [];
  List<BandPhoto> _photos = [];
  List<TopFanStat> _topFans = [];
  List<Donation> _recentDonations = [];
  Donation? _latestLiveDonation;
  bool _isFollowing = false;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<Donation>? _donationSub;

  BandPublicViewModel({
    required this.bandsRepo,
    required this.songsRepo,
    required this.donationsRepo,
    required this.bandId,
    this.launcher,
  });

  Band? get band => _band;
  List<Song> get songs => List.unmodifiable(_songs);
  List<BandEvent> get events => List.unmodifiable(_events);
  List<BandPhoto> get photos => List.unmodifiable(_photos);
  List<TopFanStat> get topFans => List.unmodifiable(_topFans);
  List<Donation> get recentDonations => List.unmodifiable(_recentDonations);
  Donation? get latestLiveDonation => _latestLiveDonation;
  bool get isFollowing => _isFollowing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Se suscribe al stream de donaciones en vivo y carga el perfil.
  /// Lo llama la View en `initState` (no el constructor).
  Future<void> init({String? currentUserId}) {
    // Stream filtrado: solo donaciones aprobadas de ESTA banda.
    _donationSub ??= donationsRepo.donationCreatedStream
        .where((d) => d.bandId == bandId && d.isApproved)
        .listen(
          _onLiveDonation,
          onError: (Object e) => _errorMessage = 'Se perdió la conexión en vivo: ${describeError(e)}',
        );
    return loadBandData(currentUserId);
  }

  void _onLiveDonation(Donation donation) {
    if (_recentDonations.any((d) => d.id == donation.id && d.id.isNotEmpty)) {
      return;
    }
    _latestLiveDonation = donation;
    _recentDonations.insert(0, donation);
    if (_band != null) {
      _band = _band!.copyWith(donationsCollected: _band!.donationsCollected + donation.amountArs);
    }
    notifyListeners();
  }

  void dismissLiveDonationAlert() {
    _latestLiveDonation = null;
    notifyListeners();
  }

  Future<void> loadBandData(String? currentUserId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (band, songs, events, photos, topFans, donations, isFollowing) = await (
        bandsRepo.getBandById(bandId),
        songsRepo.getSongsByBand(bandId),
        bandsRepo.getBandEvents(bandId),
        bandsRepo.getBandPhotos(bandId),
        // El ranking es secundario: si falla, el perfil se muestra igual sin él.
        bandsRepo.getBandTopFans(bandId).catchError((Object _) => <TopFanStat>[]),
        donationsRepo.getDonationsByBand(bandId),
        currentUserId != null ? bandsRepo.isFollowing(bandId, currentUserId) : Future.value(false),
      ).wait;

      _band = band;
      _songs = songs;
      _events = events;
      _photos = photos;
      _topFans = topFans;
      _recentDonations = List.of(donations);
      _isFollowing = isFollowing;
    } catch (e) {
      _errorMessage = 'No se pudo cargar el perfil de la banda. ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String userId) async {
    try {
      if (_isFollowing) {
        await bandsRepo.unfollowBand(bandId, userId);
        _isFollowing = false;
        if (_band != null) {
          _band = _band!.copyWith(followerCount: (_band!.followerCount - 1).clamp(0, 999999));
        }
      } else {
        await bandsRepo.followBand(bandId, userId);
        _isFollowing = true;
        if (_band != null) {
          _band = _band!.copyWith(followerCount: _band!.followerCount + 1);
        }
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo actualizar el seguimiento. ${describeError(e)}';
      notifyListeners();
    }
  }

  /// Abre un link externo (tienda de merch, entradas). Devuelve `false` si no se pudo.
  Future<bool> openExternalLink(String? url) async {
    if (url == null || url.trim().isEmpty || launcher == null) return false;
    return launcher!.openUrl(url.trim());
  }

  @override
  void dispose() {
    _donationSub?.cancel();
    super.dispose();
  }
}
