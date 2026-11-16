import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/report.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository.dart';

/// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeModerationRepository implements ModerationRepository {
  final List<Band> _pendingBands = [
    Band(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      slug: 'nebulosa-subterranea',
      name: 'Nebulosa Subterránea',
      bio: 'Post-punk atmosférico grabado en cassettes vírgenes de 1994.',
      genre: 'Indie',
      location: 'La Plata, AR',
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6',
      status: BandStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final List<SongReport> _reports = [
    SongReport(
      id: 'rep-1',
      songId: 'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3',
      reporterUserId: '44444444-4444-4444-4444-444444444444',
      reason: 'El sample inicial pertenece a un disco con copyright sin autorización.',
      status: 'open',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      songTitle: 'Cintas de Caset Viejas',
      bandName: 'Los Fuzzers',
    ),
  ];

  @override
  Future<List<Band>> getPendingBands() async {
    return _pendingBands.where((b) => b.isPending).toList();
  }

  @override
  Future<void> reviewBand(String bandId, bool approve) async {
    final idx = _pendingBands.indexWhere((b) => b.id == bandId);
    if (idx != -1) {
      _pendingBands[idx] = _pendingBands[idx].copyWith(
        status: approve ? BandStatus.approved : BandStatus.suspended,
      );
    }
  }

  @override
  Future<List<SongReport>> getOpenReports() async {
    return _reports.where((r) => r.isOpen).toList();
  }

  @override
  Future<void> resolveReport(String reportId, bool hideSong) async {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: hideSong ? 'resolved' : 'dismissed',
      );
    }
  }

  @override
  Future<void> createReport(String songId, String userId, String reason) async {
    _reports.add(
      SongReport(
        id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
        songId: songId,
        reporterUserId: userId,
        reason: reason,
        status: 'open',
        createdAt: DateTime.now(),
      ),
    );
  }
}
