import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ModerationRepository {
  Future<List<Band>> getPendingBands();
  Future<void> reviewBand(String bandId, bool approve);
  Future<List<SongReport>> getOpenReports();
  Future<void> resolveReport(String reportId, bool hideSong);
  Future<void> createReport(String songId, String userId, String reason);
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
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
    _reports.add(SongReport(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      songId: songId,
      reporterUserId: userId,
      reason: reason,
      status: 'open',
      createdAt: DateTime.now(),
    ));
  }
}

//// Implementación real conectada a Supabase
class SupabaseModerationRepository implements ModerationRepository {
  final SupabaseClient _client;

  SupabaseModerationRepository(this._client);

  @override
  Future<List<Band>> getPendingBands() async {
    final res = await _client
        .from('bands')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return (res as List).map((json) => Band.fromJson(json)).toList();
  }

  @override
  Future<void> reviewBand(String bandId, bool approve) async {
    await _client.from('bands').update({
      'status': approve ? 'approved' : 'suspended',
    }).eq('id', bandId);
  }

  @override
  Future<List<SongReport>> getOpenReports() async {
    final res = await _client
        .from('reports')
        .select('*, songs(title, bands(name))')
        .eq('status', 'open')
        .order('created_at', ascending: false);

    return (res as List).map((json) => SongReport.fromJson(json)).toList();
  }

  @override
  Future<void> resolveReport(String reportId, bool hideSong) async {
    // Si hideSong es true, además de resolver el reporte se oculta la canción
    if (hideSong) {
      final rep = await _client.from('reports').select('song_id').eq('id', reportId).single();
      final songId = rep['song_id'] as String;
      await _client.from('songs').update({'hidden': true}).eq('id', songId);
    }
    await _client.from('reports').update({
      'status': hideSong ? 'resolved' : 'dismissed',
    }).eq('id', reportId);
  }

  @override
  Future<void> createReport(String songId, String userId, String reason) async {
    await _client.from('reports').insert({
      'song_id': songId,
      'reporter_user_id': userId,
      'reason': reason,
      'status': 'open',
    });
  }
}
