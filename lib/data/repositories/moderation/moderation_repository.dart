import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_overview.dart';
import 'package:streamtunes/domain/models/report.dart';

abstract class ModerationRepository {
  Future<List<Band>> getPendingBands();
  Future<void> reviewBand(String bandId, bool approve);

  /// Todas las bandas del colectivo (aprobadas, pendientes y suspendidas),
  /// con seguidores, cantidad de temas y creador. Solo para moderadores.
  Future<List<BandOverview>> getAllBands();

  /// Cambia el estado de una banda (aprobar, suspender o reactivar).
  Future<void> setBandStatus(String bandId, BandStatus status);
  Future<List<SongReport>> getOpenReports();
  Future<void> resolveReport(String reportId, bool hideSong);
  Future<void> createReport(String songId, String userId, String reason);
}
