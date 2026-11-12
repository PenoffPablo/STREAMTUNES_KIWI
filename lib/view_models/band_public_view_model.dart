import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/band_event.dart';
import 'package:streamtunes/models/band_photo.dart';
import 'package:streamtunes/models/band_stats.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/donations_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';

class BandPublicViewModel extends ChangeNotifier {
  final BandsRepository bandsRepo;
  final SongsRepository songsRepo;
  final DonationsRepository donationsRepo;
  final String bandId;

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

  StreamSubscription? _donationSub;

  BandPublicViewModel({
    required this.bandsRepo,
    required this.songsRepo,
    required this.donationsRepo,
    required this.bandId,
  }) {
    _initRealtime();
  }

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

  void _initRealtime() {
    _donationSub = donationsRepo.donationCreatedStream.listen((donation) {
      if (donation.bandId == bandId) {
        _latestLiveDonation = donation;
        _recentDonations.insert(0, donation);
        if (_band != null) {
          _band = _band!.copyWith(
            donationsCollected: _band!.donationsCollected + donation.amountArs,
          );
        }
        notifyListeners();
      }
    });
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
      final bandFuture = bandsRepo.getBandById(bandId);
      final songsFuture = songsRepo.getSongsByBand(bandId);
      final eventsFuture = bandsRepo.getBandEvents(bandId);
      final photosFuture = bandsRepo.getBandPhotos(bandId);
      final topFansFuture = bandsRepo.getBandTopFans(bandId);
      final donationsFuture = donationsRepo.getDonationsByBand(bandId);
      final followFuture = currentUserId != null
          ? bandsRepo.isFollowing(bandId, currentUserId)
          : Future.value(false);

      final results = await Future.wait([
        bandFuture,
        songsFuture,
        eventsFuture,
        photosFuture,
        topFansFuture,
        donationsFuture,
        followFuture,
      ]);

      _band = results[0] as Band?;
      _songs = results[1] as List<Song>;
      _events = results[2] as List<BandEvent>;
      _photos = results[3] as List<BandPhoto>;
      _topFans = results[4] as List<TopFanStat>;
      _recentDonations = List.from(results[5] as List<Donation>);
      _isFollowing = results[6] as bool;
    } catch (e) {
      _errorMessage = 'Error cargando perfil de la banda: $e';
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
      _errorMessage = 'Error actualizando seguimiento: $e';
      notifyListeners();
    }
  }

  Future<bool> submitDonation({
    required String? donorUserId,
    required String donorName,
    required double amountArs,
    String? message,
    required bool isAnonymous,
  }) async {
    try {
      final donation = Donation(
        id: '',
        bandId: bandId,
        donorUserId: donorUserId,
        donorName: isAnonymous ? 'Fan anónimo' : donorName,
        amountArs: amountArs,
        message: message,
        isAnonymous: isAnonymous,
        status: 'approved',
        createdAt: DateTime.now(),
      );

      await donationsRepo.createDonation(donation);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _donationSub?.cancel();
    super.dispose();
  }
}
