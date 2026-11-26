import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_overview.dart';
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

  /// Bandas ya aprobadas o suspendidas (las pendientes están en _pendingBands).
  final List<Band> _otherBands = [
    Band(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      slug: 'los-fuzzers',
      name: 'Los Fuzzers',
      bio: 'Garage rock de sótano.',
      genre: 'Rock',
      location: 'Buenos Aires, AR',
      status: BandStatus.approved,
      followerCount: 128,
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
    ),
    Band(
      id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      slug: 'cumbia-del-conurbano',
      name: 'Cumbia del Conurbano',
      genre: 'Cumbia',
      location: 'Lanús, AR',
      status: BandStatus.suspended,
      followerCount: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  @override
  Future<List<BandOverview>> getAllBands() async => [
        for (final b in [..._pendingBands, ..._otherBands])
          BandOverview(band: b, songCount: b.isApproved ? 3 : 0, ownerName: 'Usuario de prueba'),
      ];

  @override
  Future<void> setBandStatus(String bandId, BandStatus status) async {
    for (final list in [_pendingBands, _otherBands]) {
      final idx = list.indexWhere((b) => b.id == bandId);
      if (idx != -1) list[idx] = list[idx].copyWith(status: status);
    }
  }

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
