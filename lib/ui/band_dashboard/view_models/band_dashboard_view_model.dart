import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';
import 'package:streamtunes/data/services/reports/band_metrics_service.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_daily_report.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';

class BandDashboardViewModel extends ViewModel {
  final BandsRepository bandsRepo;
  final SongsRepository songsRepo;
  final PayoutsRepository? payoutsRepo;
  final DonationsRepository? donationsRepo;
  final DeviceCapabilitiesService? deviceService;
  final BandMetricsService metricsService;

  /// Reloj inyectable (tests): define el día y la hora del corte de las 00:00.
  final DateTime Function() clock;
  final String bandId;
  final SharedPreferences? prefs;

  Band? _band;
  BandAggregatedStats? _stats;
  List<TopFanStat> _topFans = [];
  List<BandEvent> _events = [];
  List<BandPhoto> _photos = [];
  List<Song> _songs = [];
  BandBalance? _balance;
  List<BandPayout> _payouts = [];
  String? _metricsError;
  String? _accountError;
  int _accountRequestId = 0;
  int _songCount = 0;
  bool _isLoading = false;
  bool _isLoadingMetrics = false;
  String? _errorMessage;

  // Métricas del día: se calculan una vez por día de calendario y se renuevan
  // a las 00:00 (protege la base y la CPU del teléfono).
  BandDailyReport? _report;
  bool _isMetricsFromCache = false;
  Timer? _midnightTimer;

  BandDashboardViewModel({
    required this.bandsRepo,
    required this.songsRepo,
    required this.bandId,
    this.payoutsRepo,
    this.donationsRepo,
    this.deviceService,
    this.metricsService = const BandMetricsService(),
    this.prefs,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Band? get band => _band;
  BandAggregatedStats? get stats => _stats;
  List<TopFanStat> get topFans => List.unmodifiable(_topFans);
  List<BandEvent> get events => List.unmodifiable(_events);
  List<BandPhoto> get photos => List.unmodifiable(_photos);
  List<Song> get songs => List.unmodifiable(_songs);

  /// Estado de cuenta con KIWI: recaudado (verificado por Mercado Pago),
  /// ya liquidado y saldo pendiente. `null` si no se pudo cargar.
  BandBalance? get balance => _balance;

  StreamSubscription<Donation>? _liveSub;

  /// Pagos que KIWI le hizo a la banda, más reciente primero.
  List<BandPayout> get payouts => List.unmodifiable(_payouts);

  /// Error de métricas (no bloquea el resto del panel).
  String? get metricsError => _metricsError;

  /// Error al cargar el estado de cuenta. Se muestra sobre los últimos datos
  /// buenos (no se borra la tarjeta por un corte de red).
  String? get accountError => _accountError;
  int get songCount => _songCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMetrics => _isLoadingMetrics;
  String? get errorMessage => _errorMessage;

  /// Desglose por tema calculado en el isolate (null hasta que carga).
  BandDailyReport? get report => _report;

  /// `true` si las métricas de hoy salen del caché local (ya se calcularon hoy).
  bool get isMetricsFromCache => _isMetricsFromCache;

  /// Cuánto falta para las 00:00, cuando se calculan las métricas del nuevo día.
  Duration get timeUntilNextRefresh => _nextMidnight(clock()).difference(clock());

  Future<SharedPreferences> _getPrefs() async => prefs ?? await SharedPreferences.getInstance();

  String get _metricsDayKey => 'metrics_day_$bandId';
  String get _reportKey => 'cached_report_$bandId';
  String get _statsKey => 'cached_stats_$bandId';
  String get _fansKey => 'cached_top_fans_$bandId';

  /// Carga el panel: datos livianos siempre + métricas pesadas (máx. 1 vez por día).
  Future<void> loadDashboard() async {
    // En vivo: cuando el webhook aprueba un aporte para ESTA banda, se
    // recalcula el estado de cuenta sin recargar todo el panel.
    _liveSub ??= donationsRepo?.donationCreatedStream
        .where((d) => d.bandId == bandId && d.isApproved)
        .listen((_) => unawaited(refreshAccount()));
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final p = await _getPrefs();
      // Las métricas y el estado de cuenta son secundarios: si fallan, el
      // resto del panel carga igual.
      final (band, events, photos, songs, _, _) = await (
        bandsRepo.getBandById(bandId),
        bandsRepo.getBandEvents(bandId),
        bandsRepo.getBandPhotos(bandId),
        songsRepo.getSongsByBand(bandId),
        _loadMetricsSafely(p),
        _reloadAccount(),
      ).wait.withNetworkTimeout();

      _band = band;
      _events = List.of(events);
      _photos = List.of(photos);
      _songs = List.of(songs);
      _songCount = songs.length;
    } catch (e) {
      _errorMessage = 'No se pudo cargar el panel de tu banda. ${describeError(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga las métricas del día: si ya se calcularon hoy salen del caché; si
  /// no, se consultan y se calculan. También lo dispara el corte de las 00:00
  /// y el botón "Reintentar" cuando falló la carga.
  Future<void> loadDailyMetrics() async {
    _isLoadingMetrics = true;
    _metricsError = null;
    notifyListeners();
    try {
      await _loadMetrics(await _getPrefs()).withNetworkTimeout();
    } catch (e) {
      _metricsError = 'No se pudieron actualizar las métricas. ${describeError(e)}';
    } finally {
      _isLoadingMetrics = false;
      notifyListeners();
    }
  }

  Future<void> _loadMetricsSafely(SharedPreferences p) async {
    _metricsError = null;
    try {
      await _loadMetrics(p);
    } catch (e) {
      _metricsError = 'No se pudieron cargar las métricas. ${describeError(e)}';
    }
  }

  /// Recarga solo el estado de cuenta (recaudado, cobrado, saldo y pagos).
  /// La dispara un pago nuevo de esta banda (realtime).
  Future<void> refreshAccount() async {
    await _reloadAccount();
    notifyListeners();
  }

  /// Carga el estado de cuenta aplicando "la última petición gana": varios
  /// avisos seguidos del mismo pago no pueden dejar números viejos. Si falla,
  /// se CONSERVAN el saldo y los pagos anteriores y el error queda visible.
  Future<void> _reloadAccount() async {
    final repo = payoutsRepo;
    if (repo == null) return;
    final requestId = ++_accountRequestId;
    try {
      final (balance, payouts) = await (repo.getBandBalance(bandId), repo.getPayouts(bandId)).wait;
      if (requestId != _accountRequestId || isDisposed) return;
      _balance = balance;
      _payouts = payouts;
      _accountError = null;
    } catch (e) {
      if (requestId != _accountRequestId || isDisposed) return;
      _accountError = 'No se pudo actualizar tu saldo con KIWI. ${describeError(e)}';
    }
  }

  /// Día de calendario local (aaaa-mm-dd).
  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _nextMidnight(DateTime now) => DateTime(now.year, now.month, now.day + 1);

  /// Métricas del día. Si ya se calcularon hoy, salen del caché local y no se
  /// consulta PostgreSQL. Si no, se piden al servidor (totales y top fans) y el
  /// desglose por tema se calcula en un isolate. Un fallo no se cachea: se
  /// reintenta en la próxima carga.
  Future<void> _loadMetrics(SharedPreferences p) async {
    final now = clock();
    final today = _dayKey(now);

    if (p.getString(_metricsDayKey) == today) {
      final cached = _readCachedMetrics(p);
      if (cached != null) {
        _stats = cached.$1;
        _topFans = cached.$2;
        _report = cached.$3;
        _isMetricsFromCache = true;
        _scheduleMidnightRefresh();
        return;
      }
    }

    final (stats, fans, songs) = await (
      bandsRepo.getBandAggregatedStats(bandId),
      bandsRepo.getBandTopFans(bandId),
      songsRepo.getSongsByBand(bandId),
    ).wait;
    // Se copian a datos planos ANTES de cruzar al isolate.
    final report = await metricsService.compute([
      for (final s in songs) (title: s.title, durationSeconds: s.durationSeconds, playCount: s.playCount),
    ]);
    if (isDisposed) return;

    _stats = stats;
    _topFans = fans;
    _report = report;
    _isMetricsFromCache = false;

    await (
      p.setString(_metricsDayKey, today),
      p.setString(_statsKey, jsonEncode(stats.toJson())),
      p.setString(_fansKey, jsonEncode(fans.map((f) => f.toJson()).toList())),
      p.setString(_reportKey, jsonEncode(report.toJson())),
    ).wait;
    _scheduleMidnightRefresh();
  }

  /// A las 00:00 se calculan solas las métricas del nuevo día (si el panel
  /// sigue abierto). El timer se cancela en `dispose`.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    if (isDisposed) return;
    _midnightTimer = Timer(timeUntilNextRefresh + const Duration(seconds: 1), () {
      if (!isDisposed) unawaited(loadDailyMetrics());
    });
  }

  (BandAggregatedStats, List<TopFanStat>, BandDailyReport)? _readCachedMetrics(SharedPreferences p) {
    try {
      final statsStr = p.getString(_statsKey);
      final reportStr = p.getString(_reportKey);
      if (statsStr == null || reportStr == null) return null;
      final stats = BandAggregatedStats.fromJson(jsonDecode(statsStr) as Map<String, dynamic>);
      final fans = (jsonDecode(p.getString(_fansKey) ?? '[]') as List)
          .map((item) => TopFanStat.fromJson(item as Map<String, dynamic>))
          .toList();
      final report = BandDailyReport.fromJson(jsonDecode(reportStr) as Map<String, dynamic>);
      return (stats, fans, report);
    } catch (e) {
      debugPrint('[BandDashboardViewModel] Caché de métricas corrupta, se recalcula: $e');
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
      final created = await bandsRepo.addBandEvent(
        BandEvent(
          id: '',
          bandId: bandId,
          title: title,
          venue: venue,
          city: city,
          eventDate: date,
          ticketUrl: ticketUrl,
          createdAt: DateTime.now(),
        ),
      );
      _events
        ..add(created)
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo agregar la fecha. ${describeError(e)}';
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await bandsRepo.deleteBandEvent(eventId);
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo eliminar la fecha. ${describeError(e)}';
      notifyListeners();
    }
  }

  /// Abre el selector de imágenes del dispositivo (la View no toca el servicio).
  Future<String?> pickPhoto() async => deviceService?.pickCoverPhoto();

  Future<void> addPhoto({required String photoUrl, String? caption}) async {
    try {
      final created = await bandsRepo.addBandPhoto(
        BandPhoto(id: '', bandId: bandId, photoUrl: photoUrl, caption: caption, createdAt: DateTime.now()),
      );
      _photos.insert(0, created);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo subir la foto. ${describeError(e)}';
      notifyListeners();
    }
  }

  bool _isSavingProfile = false;
  String? _profileError;

  /// Se está guardando el perfil de la banda (foto, nombre, bio...).
  bool get isSavingProfile => _isSavingProfile;

  /// Por qué no se pudo guardar el perfil (se muestra en el formulario).
  String? get profileError => _profileError;

  static const int maxNameLength = 60;
  static const int maxBioLength = 500;

  /// Normaliza un link: vacío -> null; sin "http" se le agrega "https://".
  /// Devuelve `false` en `.$2` si no parece una dirección web.
  static (String?, bool) normalizeLink(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return (null, true);
    final url = text.startsWith('http://') || text.startsWith('https://') ? text : 'https://$text';
    final uri = Uri.tryParse(url);
    final ok = uri != null && uri.host.contains('.') && !url.contains(' ');
    return (url, ok);
  }

  /// Guarda el perfil de la banda. Si [newCoverPath] es una foto nueva, la
  /// sube primero. Devuelve `true` si quedó guardado; si no, el motivo queda
  /// en [profileError] y los datos anteriores siguen intactos.
  Future<bool> updateProfile({
    required String name,
    required String genre,
    String? location,
    String? bio,
    required double donationGoal,
    Map<String, String> socialLinks = const {},
    String? merchUrl,
    String? newCoverPath,
  }) async {
    final current = _band;
    if (current == null || _isSavingProfile) return false;

    final cleanName = name.trim();
    final cleanBio = bio?.trim() ?? '';
    final links = <String, dynamic>{};
    String? problem;
    if (cleanName.length < 2) {
      problem = 'Escribí el nombre de la banda.';
    } else if (cleanName.length > maxNameLength) {
      problem = 'El nombre puede tener hasta $maxNameLength caracteres.';
    } else if (cleanBio.length > maxBioLength) {
      problem = 'La biografía puede tener hasta $maxBioLength caracteres.';
    } else if (donationGoal < 0 || donationGoal > 100000000) {
      problem = 'La meta de recaudación tiene que ser un monto entre \$0 y \$100.000.000.';
    }
    for (final entry in socialLinks.entries) {
      if (problem != null) break;
      final (url, ok) = normalizeLink(entry.value);
      if (!ok) problem = 'El link de ${kBandSocialNetworks[entry.key] ?? entry.key} no parece una dirección web.';
      if (url != null) links[entry.key] = url;
    }
    final (merch, merchOk) = normalizeLink(merchUrl);
    if (problem == null && !merchOk) problem = 'El link de la tienda no parece una dirección web.';
    if (problem != null) {
      _profileError = problem;
      notifyListeners();
      return false;
    }

    _isSavingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      var coverUrl = current.coverUrl;
      if (newCoverPath != null) coverUrl = await bandsRepo.uploadBandCover(bandId, newCoverPath);

      // Se conservan las otras redes que pudiera tener guardadas.
      final mergedLinks = {...current.socialLinks}
        ..removeWhere((k, _) => kBandSocialNetworks.containsKey(k))
        ..addAll(links);

      // Se arma explícitamente (no copyWith): así borrar la ciudad, la bio o
      // el link de merch deja el campo vacío en vez de conservar el anterior.
      final saved = await bandsRepo.updateBand(Band(
        id: current.id,
        slug: current.slug, // no cambia: es la dirección del QR ya impreso
        name: cleanName,
        genre: genre,
        location: (location?.trim().isEmpty ?? true) ? null : location!.trim(),
        bio: cleanBio.isEmpty ? null : cleanBio,
        coverUrl: coverUrl,
        merchUrl: merch,
        socialLinks: mergedLinks,
        donationGoal: donationGoal,
        donationsCollected: current.donationsCollected,
        status: current.status,
        createdBy: current.createdBy,
        createdAt: current.createdAt,
        followerCount: current.followerCount,
      ));
      if (isDisposed) return true;
      _band = saved;
      return true;
    } catch (e) {
      _profileError = 'No se pudo guardar el perfil de la banda. ${describeError(e)}';
      return false;
    } finally {
      _isSavingProfile = false;
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
      _errorMessage = 'No se pudo actualizar la tienda de merch. ${describeError(e)}';
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
      final saved = await songsRepo.updateSong(_songs[idx].copyWith(title: title, genre: genre, lyricsLrc: lyricsLrc));
      _songs[idx] = saved;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo actualizar la canción. ${describeError(e)}';
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
      _errorMessage = 'No se pudo eliminar la canción. ${describeError(e)}';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }
}
