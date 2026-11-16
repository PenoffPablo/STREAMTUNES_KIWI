import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';

/// Implementación real conectada a Supabase
class SupabaseBandsRepository implements BandsRepository {
  final SupabaseClient _client;

  SupabaseBandsRepository(this._client);

  @override
  Future<List<Band>> getBands({
    BandStatus? status,
    String? genre,
    String? query,
  }) async {
    var req = _client.from('bands').select('*, band_follows(count)');
    if (status != null) {
      req = req.eq('status', status.toDbString());
    }
    if (genre != null && genre != 'Todos') {
      req = req.ilike('genre', genre);
    }
    if (query != null && query.isNotEmpty) {
      req = req.or('name.ilike.%$query%,bio.ilike.%$query%');
    }

    final data = await req.order('created_at', ascending: false).withNetworkTimeout();
    return (data as List).map((json) {
      final followsList = json['band_follows'] as List?;
      final count = followsList?.isNotEmpty == true
          ? (followsList!.first['count'] as num?)?.toInt() ?? 0
          : 0;
      return Band.fromJson(json, followerCount: count);
    }).toList();
  }

  @override
  Future<Band?> getBandById(String id) async {
    try {
      final res =
          await (_client
                  .from('bands')
                  .select('*, band_follows(count)')
                  .eq('id', id)
                  .maybeSingle())
              .withNetworkTimeout();
      if (res == null) return null;
      final followsList = res['band_follows'] as List?;
      final count = followsList?.isNotEmpty == true
          ? (followsList!.first['count'] as num?)?.toInt() ?? 0
          : 0;
      return Band.fromJson(res, followerCount: count);
    } catch (e) {
      debugPrint('[SupabaseBandsRepository] Error getBandById: $e');
      return null;
    }
  }

  @override
  Future<Band?> getBandBySlug(String slug) async {
    try {
      final res =
          await (_client
                  .from('bands')
                  .select('*, band_follows(count)')
                  .eq('slug', slug)
                  .maybeSingle())
              .withNetworkTimeout();
      if (res == null) return null;
      final followsList = res['band_follows'] as List?;
      final count = followsList?.isNotEmpty == true
          ? (followsList!.first['count'] as num?)?.toInt() ?? 0
          : 0;
      return Band.fromJson(res, followerCount: count);
    } catch (e) {
      debugPrint('[SupabaseBandsRepository] Error getBandBySlug: $e');
      return null;
    }
  }

  @override
  Future<Band> createBand(Band band, String userId) async {
    final payload = band.toJson()..remove('id');
    payload['created_by'] = userId;
    payload['status'] = 'pending'; // Nace en pending

    final res = await (_client.from('bands').insert(payload).select().single())
        .withNetworkTimeout();
    final newBand = Band.fromJson(res);

    // Asignar al creador como 'owner' en band_members
    await (_client.from('band_members').insert({
      'band_id': newBand.id,
      'user_id': userId,
      'role': 'owner',
    })).withNetworkTimeout();

    return newBand;
  }

  @override
  Future<Band> updateBand(Band band) async {
    final res =
        await (_client
                .from('bands')
                .update(band.toJson())
                .eq('id', band.id)
                .select()
                .single())
            .withNetworkTimeout();
    return Band.fromJson(res);
  }

  @override
  Future<bool> followBand(String bandId, String userId) async {
    await (_client.from('band_follows').upsert({
      'band_id': bandId,
      'user_id': userId,
    })).withNetworkTimeout();
    return true;
  }

  @override
  Future<bool> unfollowBand(String bandId, String userId) async {
    await (_client
            .from('band_follows')
            .delete()
            .eq('band_id', bandId)
            .eq('user_id', userId))
        .withNetworkTimeout();
    return true;
  }

  @override
  Future<bool> isFollowing(String bandId, String userId) async {
    final res =
        await (_client
                .from('band_follows')
                .select('band_id')
                .eq('band_id', bandId)
                .eq('user_id', userId)
                .maybeSingle())
            .withNetworkTimeout();
    return res != null;
  }

  @override
  Future<List<Band>> getFollowedBands(String userId) async {
    try {
      final res =
          await (_client
                  .from('band_follows')
                  .select('bands(*, band_follows(count))')
                  .eq('user_id', userId))
              .withNetworkTimeout();

      return (res as List)
          .where((row) => row != null && row['bands'] != null)
          .map((row) {
            final bandJson = row['bands'] as Map<String, dynamic>;
            final followsList = bandJson['band_follows'] as List?;
            final count = followsList?.isNotEmpty == true
                ? (followsList!.first['count'] as num?)?.toInt() ?? 0
                : 0;
            return Band.fromJson(bandJson, followerCount: count);
          })
          .toList();
    } catch (e) {
      debugPrint('[SupabaseBandsRepository] Error getFollowedBands: $e');
      return [];
    }
  }

  @override
  Future<List<BandEvent>> getBandEvents(String bandId) async {
    final res =
        await (_client
                .from('band_events')
                .select()
                .eq('band_id', bandId)
                .order('event_date', ascending: true))
            .withNetworkTimeout();
    return (res as List).map((json) => BandEvent.fromJson(json)).toList();
  }

  @override
  Future<BandEvent> addBandEvent(BandEvent event) async {
    final payload = event.toJson()..remove('id');
    final res =
        await (_client.from('band_events').insert(payload).select().single())
            .withNetworkTimeout();
    return BandEvent.fromJson(res);
  }

  @override
  Future<void> deleteBandEvent(String eventId) async {
    await (_client.from('band_events').delete().eq('id', eventId))
        .withNetworkTimeout();
  }

  @override
  Future<List<BandPhoto>> getBandPhotos(String bandId) async {
    final res =
        await (_client
                .from('band_photos')
                .select()
                .eq('band_id', bandId)
                .order('created_at', ascending: false))
            .withNetworkTimeout();
    return (res as List).map((json) => BandPhoto.fromJson(json)).toList();
  }

  @override
  Future<BandPhoto> addBandPhoto(BandPhoto photo) async {
    String photoUrl = photo.photoUrl;

    // Si es un archivo local del dispositivo, subirlo a Supabase Storage bucket 'photos'
    if (!photoUrl.startsWith('http')) {
      try {
        final file = File(photoUrl);
        if (await file.exists()) {
          final storagePath =
              '${photo.bandId}/${DateTime.now().millisecondsSinceEpoch}_photo.jpg';
          await _client.storage.from('photos').upload(storagePath, file);
          photoUrl = _client.storage.from('photos').getPublicUrl(storagePath);
        }
      } catch (e) {
        debugPrint(
          '[SupabaseBandsRepository] Error subiendo foto a Storage: $e',
        );
      }
    }

    final payload = photo.copyWith(photoUrl: photoUrl).toJson()..remove('id');
    final res =
        await (_client.from('band_photos').insert(payload).select().single())
            .withNetworkTimeout();
    return BandPhoto.fromJson(res);
  }

  @override
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId) async {
    // Invocación a RPC nativo de PostgreSQL
    try {
      final res = await (_client.rpc(
        'band_aggregated_stats',
        params: {'p_band': bandId},
      )).withNetworkTimeout();
      return BandAggregatedStats.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint(
        '[SupabaseBandsRepository] Advertencia band_aggregated_stats RPC: $e',
      );
      return BandAggregatedStats(
        bandId: bandId,
        totalPlays: 0,
        totalMinutes: 0,
        last7DaysPlays: 0,
        topSongs: const [],
      );
    }
  }

  @override
  Future<List<TopFanStat>> getBandTopFans(
    String bandId, {
    int days = 30,
  }) async {
    // Invocación a función RPC nativa con consentimiento de privacidad (opt-in) (soporta band_top_fans y band_top_listeners)
    try {
      final res = await (_client.rpc(
        'band_top_fans',
        params: {'p_band': bandId, 'p_days': days},
      )).withNetworkTimeout();
      return (res as List)
          .map((row) => TopFanStat.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final res = await (_client.rpc(
          'band_top_listeners',
          params: {'p_band': bandId, 'p_days': days},
        )).withNetworkTimeout();
        return (res as List)
            .map((row) => TopFanStat.fromJson(row as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint(
          '[SupabaseBandsRepository] Advertencia getBandTopFans RPC: $e',
        );
        return [];
      }
    }
  }
}
