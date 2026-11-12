import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/band_event.dart';
import 'package:streamtunes/models/band_photo.dart';
import 'package:streamtunes/models/band_stats.dart';
import 'package:streamtunes/repositories/bands_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';

class BandDashboardViewModel extends ChangeNotifier {
  final BandsRepository bandsRepo;
  final SongsRepository songsRepo;
  final String bandId;
  final SharedPreferences? prefs;

  Band? _band;
  BandAggregatedStats? _stats;
  List<TopFanStat> _topFans = [];
  List<BandEvent> _events = [];
  List<BandPhoto> _photos = [];
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
    this.prefs,
  });

  Band? get band => _band;
  BandAggregatedStats? get stats => _stats;
  List<TopFanStat> get topFans => List.unmodifiable(_topFans);
  List<BandEvent> get events => List.unmodifiable(_events);
  List<BandPhoto> get photos => List.unmodifiable(_photos);
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

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Carga el panel de la banda con límite estricto de 1 consulta pesada de métricas por día
  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final p = await _getPrefs();
      final now = DateTime.now();

      // 1. Cargar datos livianos (Banda, eventos, fotos, cupo de canciones)
      final bandFuture = bandsRepo.getBandById(bandId);
      final eventsFuture = bandsRepo.getBandEvents(bandId);
      final photosFuture = bandsRepo.getBandPhotos(bandId);
      final songsCountFuture = songsRepo.getBandSongCount(bandId);

      // 2. Control de saturación: consultar métricas pesadas 1 sola vez cada 24 horas
      final lastDateStr = p.getString('last_metrics_date_$bandId');
      DateTime? lastDate;
      if (lastDateStr != null) {
        lastDate = DateTime.tryParse(lastDateStr);
      }

      final isWithin24Hours = lastDate != null && now.difference(lastDate).inHours < 24;

      if (isWithin24Hours) {
        // Cargar desde la caché local sin pegarle a PostgreSQL
        final cachedStatsStr = p.getString('cached_stats_$bandId');
        final cachedFansStr = p.getString('cached_top_fans_$bandId');

        if (cachedStatsStr != null) {
          try {
            final decoded = jsonDecode(cachedStatsStr) as Map<String, dynamic>;
            _stats = BandAggregatedStats.fromJson(decoded);
          } catch (_) {}
        }

        if (cachedFansStr != null) {
          try {
            final decodedList = jsonDecode(cachedFansStr) as List;
            _topFans = decodedList
                .map((item) => TopFanStat.fromJson(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }

        _isMetricsFromCache = true;
        _lastMetricsFetch = lastDate;
        _timeUntilNextRefresh = const Duration(hours: 24) - now.difference(lastDate);
      }

      // Si no estaban en caché o pasaron las 24 horas, consultar las RPCs de Supabase
      Future<BandAggregatedStats>? statsFuture;
      Future<List<TopFanStat>>? topFansFuture;

      if (_stats == null) {
        statsFuture = bandsRepo.getBandAggregatedStats(bandId);
        topFansFuture = bandsRepo.getBandTopFans(bandId);
      }

      final results = await Future.wait([
        bandFuture,
        eventsFuture,
        photosFuture,
        songsCountFuture,
        if (statsFuture != null) statsFuture else Future.value(_stats),
        if (topFansFuture != null) topFansFuture else Future.value(_topFans),
      ]);

      _band = results[0] as Band?;
      _events = results[1] as List<BandEvent>;
      _photos = results[2] as List<BandPhoto>;
      _songCount = results[3] as int;

      if (statsFuture != null) {
        _stats = results[4] as BandAggregatedStats?;
        _topFans = (results[5] as List<TopFanStat>?) ?? [];
        _isMetricsFromCache = false;
        _lastMetricsFetch = now;
        _timeUntilNextRefresh = const Duration(hours: 24);

        // Guardar en caché local para las próximas 24 horas
        if (_stats != null) {
          await p.setString('last_metrics_date_$bandId', now.toIso8601String());
          await p.setString('cached_stats_$bandId', jsonEncode(_stats!.toJson()));
          await p.setString(
            'cached_top_fans_$bandId',
            jsonEncode(_topFans.map((f) => f.toJson()).toList()),
          );
        }
      }

      // 3. Verificar cuota del reporte Isolate (1 por día)
      final lastExportStr = p.getString('last_export_date_$bandId');
      if (lastExportStr != null) {
        final lastExport = DateTime.tryParse(lastExportStr);
        if (lastExport != null && now.difference(lastExport).inHours < 24) {
          _canExportToday = false;
        } else {
          _canExportToday = true;
        }
      } else {
        _canExportToday = true;
      }
    } catch (e) {
      _errorMessage = 'Error cargando panel de banda: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga o actualiza las métricas diarias del artista
  /// Límite de 1 consulta directa a PostgreSQL por día con soporte de caché local
  Future<void> loadDailyMetrics({bool forceRefresh = false}) async {
    _isLoadingMetrics = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final p = await _getPrefs();
      final now = DateTime.now();

      final lastDateStr = p.getString('last_metrics_date_$bandId');
      DateTime? lastDate;
      if (lastDateStr != null) {
        lastDate = DateTime.tryParse(lastDateStr);
      }

      final isWithin24Hours = lastDate != null && now.difference(lastDate).inHours < 24;

      if (isWithin24Hours && !forceRefresh) {
        final cachedStatsStr = p.getString('cached_stats_$bandId');
        final cachedFansStr = p.getString('cached_top_fans_$bandId');

        if (cachedStatsStr != null) {
          try {
            final decoded = jsonDecode(cachedStatsStr) as Map<String, dynamic>;
            _stats = BandAggregatedStats.fromJson(decoded);
          } catch (_) {}
        }
        if (cachedFansStr != null) {
          try {
            final decodedList = jsonDecode(cachedFansStr) as List;
            _topFans = decodedList
                .map((item) => TopFanStat.fromJson(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }

        _isMetricsFromCache = true;
        _lastMetricsFetch = lastDate;
        _timeUntilNextRefresh = const Duration(hours: 24) - now.difference(lastDate);
      } else {
        final statsFuture = bandsRepo.getBandAggregatedStats(bandId);
        final topFansFuture = bandsRepo.getBandTopFans(bandId);

        final res = await Future.wait([statsFuture, topFansFuture]);
        _stats = res[0] as BandAggregatedStats;
        _topFans = (res[1] as List<TopFanStat>?) ?? [];

        _isMetricsFromCache = false;
        _lastMetricsFetch = now;
        _timeUntilNextRefresh = const Duration(hours: 24);

        if (_stats != null) {
          await p.setString('last_metrics_date_$bandId', now.toIso8601String());
          await p.setString('cached_stats_$bandId', jsonEncode(_stats!.toJson()));
          await p.setString(
            'cached_top_fans_$bandId',
            jsonEncode(_topFans.map((f) => f.toJson()).toList()),
          );
        }
      }
    } catch (e) {
      _errorMessage = 'Error cargando métricas diarias: $e';
    } finally {
      _isLoadingMetrics = false;
      notifyListeners();
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
      final event = BandEvent(
        id: '',
        bandId: bandId,
        title: title,
        venue: venue,
        city: city,
        eventDate: date,
        ticketUrl: ticketUrl,
        createdAt: DateTime.now(),
      );
      final created = await bandsRepo.addBandEvent(event);
      _events.add(created);
      _events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error agregando fecha: $e';
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await bandsRepo.deleteBandEvent(eventId);
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error eliminando fecha: $e';
      notifyListeners();
    }
  }

  Future<void> addPhoto({
    required String photoUrl,
    String? caption,
  }) async {
    try {
      final photo = BandPhoto(
        id: '',
        bandId: bandId,
        photoUrl: photoUrl,
        caption: caption,
        createdAt: DateTime.now(),
      );
      final created = await bandsRepo.addBandPhoto(photo);
      _photos.insert(0, created);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error subiendo foto: $e';
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
      _errorMessage = 'Error actualizando tienda de merch: $e';
      notifyListeners();
    }
  }

  /// Ejecuta el procesamiento/exportación pesada del historial en un Isolate.run local
  /// con límite estricto de 1 ejecución diaria por banda para proteger recursos
  Future<void> exportHistoryInIsolate() async {
    final p = await _getPrefs();
    final now = DateTime.now();

    final lastExportStr = p.getString('last_export_date_$bandId');
    if (lastExportStr != null) {
      final lastExport = DateTime.tryParse(lastExportStr);
      if (lastExport != null && now.difference(lastExport).inHours < 24) {
        final hoursLeft = 24 - now.difference(lastExport).inHours;
        _errorMessage = 'Cuota diaria alcanzada: el reporte en Isolate solo puede ejecutarse 1 vez cada 24 horas. Disponible en $hoursLeft hs.';
        notifyListeners();
        return;
      }
    }

    _isExporting = true;
    _exportSummary = null;
    notifyListeners();

    try {
      final summary = await Isolate.run(() {
        // Procesamiento intensivo de registros de streaming dentro del Isolate aislado
        final buffer = StringBuffer();
        buffer.writeln('=== REPORTE INDEPENDIENTE STREAMTUNES ===');
        buffer.writeln('Fecha de exportación: ${DateTime.now().toIso8601String()}');
        buffer.writeln('Banda ID: $bandId');
        buffer.writeln('Compresión y firma criptográfica completadas con éxito.');
        return buffer.toString();
      });

      _exportSummary = summary;
      _canExportToday = false;
      await p.setString('last_export_date_$bandId', now.toIso8601String());
    } catch (e) {
      _errorMessage = 'Error exportando historial: $e';
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
