import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';
import 'package:streamtunes/data/services/reports/band_report_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

class BandDashboardViewModel extends ViewModel {
  final BandsRepository bandsRepo;
  final SongsRepository songsRepo;
  final DonationsRepository? donationsRepo;
  final DeviceCapabilitiesService? deviceService;
  final BandReportService reportService;
  final String bandId;
  final SharedPreferences? prefs;

  Band? _band;
  BandAggregatedStats? _stats;
  List<TopFanStat> _topFans = [];
  List<BandEvent> _events = [];
  List<BandPhoto> _photos = [];
  List<Song> _songs = [];
  List<Donation> _pendingDonations = [];
  final Set<String> _reviewing = {};
  String? _metricsError;
  int _songCount = 0;
  bool _isLoading = false;
  bool _isLoadingMetrics = false;
  bool _isExporting = false;
  String? _exportSummary;
  String? _errorMessage;

  // Control de cuota diaria (1 vez al día) para proteger recursos de base de datos y CPU
  bool _isMetricsFromCache = false;
  DateTime? _lastMetricsFetch;
  Duration? _timeUntilNextRefresh;
  bool _canExportToday = true;

  BandDashboardViewModel({
    required this.bandsRepo,
    required this.songsRepo,
    required this.bandId,
    this.donationsRepo,
    this.deviceService,
    this.reportService = const BandReportService(),
    this.prefs,
  });

  Band? get band => _band;
  BandAggregatedStats? get stats => _stats;
  List<TopFanStat> get topFans => List.unmodifiable(_topFans);
  List<BandEvent> get events => List.unmodifiable(_events);
  List<BandPhoto> get photos => List.unmodifiable(_photos);
  List<Song> get songs => List.unmodifiable(_songs);

  /// Transferencias al alias que la banda todavía no confirmó.
  List<Donation> get pendingDonations => List.unmodifiable(_pendingDonations);
  bool isReviewing(String donationId) => _reviewing.contains(donationId);

  /// Error de métricas (no bloquea el resto del panel).
  String? get metricsError => _metricsError;
  int get songCount => _songCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMetrics => _isLoadingMetrics;
  bool get isExporting => _isExporting;
  String? get exportSummary => _exportSummary;
  String? get errorMessage => _errorMessage;

  bool get isMetricsFromCache => _isMetricsFromCache;
  DateTime? get lastMetricsFetch => _lastMetricsFetch;
  Duration? get timeUntilNextRefresh => _timeUntilNextRefresh;
  bool get canExportToday => _canExportToday;

  Future<SharedPreferences> _getPrefs() async => prefs ?? await SharedPreferences.getInstance();

  String get _metricsDateKey => 'last_metrics_date_$bandId';
  String get _statsKey => 'cached_stats_$bandId';
  String get _fansKey => 'cached_top_fans_$bandId';
  String get _exportKey => 'last_export_date_$bandId';

  /// Carga el panel: datos livianos siempre + métricas pesadas (máx. 1 vez por día).
  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final p = await _getPrefs();
      // Las métricas y los aportes pendientes son secundarios: si fallan, el
      // resto del panel carga igual (cada uno guarda su propio error).
      final (band, events, photos, songs, _, pending) = await (
        bandsRepo.getBandById(bandId),
        bandsRepo.getBandEvents(bandId),
        bandsRepo.getBandPhotos(bandId),
        songsRepo.getSongsByBand(bandId),
        _loadMetricsSafely(p),
        _loadPendingSafely(),
      ).wait.withNetworkTimeout();

      _band = band;
      _events = List.of(events);
      _photos = List.of(photos);
      _songs = List.of(songs);
      _songCount = songs.length;
      _pendingDonations = pending;
      _canExportToday = !_isWithin24Hours(p.getString(_exportKey));
    } catch (e) {
      _errorMessage = 'Error cargando panel de banda: ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza solo las métricas diarias (botón "actualizar").
  Future<void> loadDailyMetrics({bool forceRefresh = false}) async {
    _isLoadingMetrics = true;
    _metricsError = null;
    notifyListeners();
    try {
      await _loadMetrics(await _getPrefs(), forceRefresh: forceRefresh).withNetworkTimeout();
    } catch (e) {
      _metricsError = 'Error cargando métricas diarias: ${describeError(e)}';
    } finally {
      _isLoadingMetrics = false;
      notifyListeners();
    }
  }

  Future<void> _loadMetricsSafely(SharedPreferences p) async {
    _metricsError = null;
    try {
      await _loadMetrics(p, forceRefresh: false);
    } catch (e) {
      _metricsError = 'No se pudieron cargar las métricas: ${describeError(e)}';
    }
  }

  Future<List<Donation>> _loadPendingSafely() async {
    final repo = donationsRepo;
    if (repo == null) return const [];
    try {
      return await repo.getPendingDonations(bandId);
    } catch (e) {
      debugPrint('[BandDashboardViewModel] Aportes pendientes no disponibles: $e');
      return const [];
    }
  }

  /// La banda confirma que recibió la transferencia (o la rechaza).
  /// Al confirmarla, el trigger de la base suma el monto al total y el aporte
  /// aparece en el muro en vivo.
  Future<bool> reviewDonation(Donation donation, {required bool approved}) async {
    final repo = donationsRepo;
    if (repo == null || _reviewing.contains(donation.id)) return false;
    _reviewing.add(donation.id);
    notifyListeners();
    try {
      await repo.reviewDonation(donation.id, approved: approved);
      _pendingDonations = [
        for (final d in _pendingDonations)
          if (d.id != donation.id) d,
      ];
      if (approved && _band != null) {
        _band = _band!.copyWith(
          donationsCollected: _band!.donationsCollected + donation.amountArs,
        );
      }
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo actualizar el aporte: ${describeError(e)}';
      return false;
    } finally {
      _reviewing.remove(donation.id);
      notifyListeners();
    }
  }

  bool _isWithin24Hours(String? isoDate) {
    final date = isoDate != null ? DateTime.tryParse(isoDate) : null;
    return date != null && DateTime.now().difference(date).inHours < 24;
  }

  /// Métricas con caché local de 24 h: si hay caché vigente no se consulta PostgreSQL.
  Future<void> _loadMetrics(SharedPreferences p, {required bool forceRefresh}) async {
    final now = DateTime.now();
    final lastDate = DateTime.tryParse(p.getString(_metricsDateKey) ?? '');

    if (!forceRefresh && lastDate != null && now.difference(lastDate).inHours < 24) {
      final cached = _readCachedMetrics(p);
      if (cached != null) {
        final (stats, fans) = cached;
        _stats = stats;
        _topFans = fans;
        _isMetricsFromCache = true;
        _lastMetricsFetch = lastDate;
        _timeUntilNextRefresh = const Duration(hours: 24) - now.difference(lastDate);
        return;
      }
    }

    final (stats, fans) = await (
      bandsRepo.getBandAggregatedStats(bandId),
      bandsRepo.getBandTopFans(bandId),
    ).wait;
    _stats = stats;
    _topFans = fans;
    _isMetricsFromCache = false;
    _lastMetricsFetch = now;
    _timeUntilNextRefresh = const Duration(hours: 24);

    await (
      p.setString(_metricsDateKey, now.toIso8601String()),
      p.setString(_statsKey, jsonEncode(stats.toJson())),
      p.setString(_fansKey, jsonEncode(fans.map((f) => f.toJson()).toList())),
    ).wait;
  }

  (BandAggregatedStats, List<TopFanStat>)? _readCachedMetrics(SharedPreferences p) {
    try {
      final statsStr = p.getString(_statsKey);
      if (statsStr == null) return null;
      final stats = BandAggregatedStats.fromJson(jsonDecode(statsStr) as Map<String, dynamic>);
      final fans = (jsonDecode(p.getString(_fansKey) ?? '[]') as List)
          .map((item) => TopFanStat.fromJson(item as Map<String, dynamic>))
          .toList();
      return (stats, fans);
    } catch (e) {
      debugPrint('[BandDashboardViewModel] Caché de métricas corrupta, se reconsulta: $e');
      return null;
    }
  }

  Future<void> addEvent({
    required String title,
    required String venue,
    required String city,
    required DateTime date,
    String? ticketUrl,
  }) async {
    try {
      final created = await bandsRepo.addBandEvent(BandEvent(
        id: '',
        bandId: bandId,
        title: title,
        venue: venue,
        city: city,
        eventDate: date,
        ticketUrl: ticketUrl,
        createdAt: DateTime.now(),
      ));
      _events
        ..add(created)
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error agregando fecha: ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await bandsRepo.deleteBandEvent(eventId);
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error eliminando fecha: ${describeError(e)}';
      notifyListeners();
    }
  }

  /// Abre el selector de imágenes del dispositivo (la View no toca el servicio).
  Future<String?> pickPhoto() async => deviceService?.pickCoverPhoto();

  Future<void> addPhoto({required String photoUrl, String? caption}) async {
    try {
      final created = await bandsRepo.addBandPhoto(BandPhoto(
        id: '',
        bandId: bandId,
        photoUrl: photoUrl,
        caption: caption,
        createdAt: DateTime.now(),
      ));
      _photos.insert(0, created);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error subiendo foto: ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> updateMerchUrl(String merchUrl) async {
    if (_band == null) return;
    try {
      final updated = _band!.copyWith(merchUrl: merchUrl);
      await bandsRepo.updateBand(updated);
      _band = updated;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error actualizando tienda de merch: ${describeError(e)}';
      notifyListeners();
    }
  }

  /// Genera el historial exportable (CSV firmado con SHA-256) en otro isolate.
  /// Límite: 1 ejecución cada 24 h por banda para proteger recursos.
  Future<void> exportHistoryInIsolate() async {
    final p = await _getPrefs();
    final lastExport = DateTime.tryParse(p.getString(_exportKey) ?? '');
    if (lastExport != null && DateTime.now().difference(lastExport).inHours < 24) {
      final hoursLeft = 24 - DateTime.now().difference(lastExport).inHours;
      _errorMessage = 'Cuota diaria alcanzada: el reporte solo puede generarse 1 vez cada '
          '24 horas. Disponible en $hoursLeft hs.';
      notifyListeners();
      return;
    }

    _isExporting = true;
    _exportSummary = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // Se copian a datos planos ANTES de cruzar al isolate.
      final rows = [
        for (final s in _songs)
          (title: s.title, durationSeconds: s.durationSeconds, playCount: s.playCount),
      ];
      final report = await reportService.generate(
        bandId: bandId,
        bandName: _band?.name ?? 'Banda',
        songs: rows,
      );
      _exportSummary = report.summary;
      _canExportToday = false;
      await p.setString(_exportKey, report.generatedAt.toIso8601String());
    } catch (e) {
      _errorMessage = 'Error exportando historial: ${describeError(e)}';
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Edita los metadatos de una canción subida por la banda (título, género, letra LRC)
  Future<bool> editSong({
    required String songId,
    required String title,
    required String genre,
    String? lyricsLrc,
  }) async {
    try {
      final idx = _songs.indexWhere((s) => s.id == songId);
      if (idx == -1) return false;
      final saved = await songsRepo.updateSong(
        _songs[idx].copyWith(title: title, genre: genre, lyricsLrc: lyricsLrc),
      );
      _songs[idx] = saved;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error actualizando canción: ${describeError(e)}';
      notifyListeners();
      return false;
    }
  }

  /// Elimina una canción subida por la banda y libera el cupo de la banda
  Future<bool> deleteSong(String songId) async {
    try {
      await songsRepo.deleteSong(songId);
      _songs.removeWhere((s) => s.id == songId);
      _songCount = _songs.length;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error eliminando canción: ${describeError(e)}';
      notifyListeners();
      return false;
    }
  }
}
