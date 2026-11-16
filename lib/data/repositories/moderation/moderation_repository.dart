import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/report.dart';

abstract class ModerationRepository {
  Future<List<Band>> getPendingBands();
  Future<void> reviewBand(String bandId, bool approve);
  Future<List<SongReport>> getOpenReports();
  Future<void> resolveReport(String reportId, bool hideSong);
  Future<void> createReport(String songId, String userId, String reason);
}
