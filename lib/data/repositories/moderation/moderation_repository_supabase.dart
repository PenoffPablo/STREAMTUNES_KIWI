import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase
class SupabaseModerationRepository implements ModerationRepository {
  final SupabaseClient _client;

  SupabaseModerationRepository(this._client);

  @override
  Future<List<Band>> getPendingBands() async {
    final res =
        await (_client
                .from('bands')
                .select()
                .eq('status', 'pending')
                .order('created_at', ascending: true))
            .withNetworkTimeout();
    return (res as List).map((json) => Band.fromJson(json)).toList();
  }

  @override
  Future<void> reviewBand(String bandId, bool approve) async {
    await (_client
            .from('bands')
            .update({'status': approve ? 'approved' : 'suspended'})
            .eq('id', bandId))
        .withNetworkTimeout();
  }

  @override
  Future<List<SongReport>> getOpenReports() async {
    final res =
        await (_client
                .from('reports')
                .select('*, songs(title, bands(name))')
                .eq('status', 'open')
                .order('created_at', ascending: false))
            .withNetworkTimeout();

    return (res as List).map((json) => SongReport.fromJson(json)).toList();
  }

  @override
  Future<void> resolveReport(String reportId, bool hideSong) async {
    // Si hideSong es true, además de resolver el reporte se oculta la canción
    if (hideSong) {
      final rep =
          await (_client
                  .from('reports')
                  .select('song_id')
                  .eq('id', reportId)
                  .single())
              .withNetworkTimeout();
      final songId = rep['song_id'] as String;
      await (_client.from('songs').update({'hidden': true}).eq('id', songId))
          .withNetworkTimeout();
    }
    await (_client
            .from('reports')
            .update({'status': hideSong ? 'resolved' : 'dismissed'})
            .eq('id', reportId))
        .withNetworkTimeout();
  }

  @override
  Future<void> createReport(String songId, String userId, String reason) async {
    await (_client.from('reports').insert({
      'song_id': songId,
      'reporter_user_id': userId,
      'reason': reason,
      'status': 'open',
    })).withNetworkTimeout();
  }
}
