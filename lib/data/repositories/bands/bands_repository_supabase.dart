import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/utils/ids.dart';

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
  /// Devuelve `null` solo si la banda NO existe. Los errores de red se
  /// propagan: así quien llama puede distinguir "no existe" de "sin señal"
  /// (por ejemplo, para encolar el follow del QR en el sótano).
  Future<Band?> getBandById(String id) async {
    if (!isUuid(id)) return null; // un slug no puede ser un id
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
  }

  @override
  /// Devuelve `null` solo si la banda NO existe. Los errores de red se
  /// propagan: así quien llama puede distinguir "no existe" de "sin señal"
  /// (por ejemplo, para encolar el follow del QR en el sótano).
  Future<Band?> getBandBySlug(String slug) async {
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
  }

  /// Registra una banda nueva. Nace PENDIENTE: la aprueba un moderador.
  ///
  /// * El creador queda como dueño por el trigger `on_band_created` (acá no
  ///   se inserta en band_members: sería un duplicado).
  /// * Si el slug ya existe se prueba con un sufijo (-2, -3...).
  /// * Si [Band.coverUrl] es una ruta local, se sube la foto después de crear
  ///   la banda (la carpeta del bucket es el id de la banda). Si falla, la
  ///   banda queda registrada sin foto.
  @override
  Future<Band> createBand(Band band, String userId) async {
    final payload = <String, dynamic>{
      'name': band.name.trim(),
      'genre': band.genre,
      'bio': band.bio,
      'location': band.location,
      'created_by': userId,
      'status': 'pending',
    };

    Band? created;
    for (var attempt = 1; created == null; attempt++) {
      payload['slug'] = attempt == 1 ? band.slug : '${band.slug}-$attempt';
      try {
        final res = await (_client.from('bands').insert(payload).select().single()).withNetworkTimeout();
        created = Band.fromJson(res);
      } on PostgrestException catch (e) {
        final slugTaken = e.code == '23505' && e.message.contains('slug');
        if (!slugTaken || attempt >= 5) rethrow;
      }
    }

    final localCover = band.coverUrl;
    if (localCover != null && localCover.isNotEmpty && !localCover.startsWith('http') && !kIsWeb) {
      try {
        final file = File(localCover);
        if (file.existsSync()) {
          final path = '${created.id}/band_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await (_client.storage
                  .from('covers')
                  .upload(path, file, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg')))
              .withNetworkTimeout(const Duration(seconds: 60));
          final url = _client.storage.from('covers').getPublicUrl(path);
          await (_client.from('bands').update({'cover_url': url}).eq('id', created.id)).withNetworkTimeout();
          created = created.copyWith(coverUrl: url);
        }
      } catch (e) {
        debugPrint('[SupabaseBandsRepository] Foto de la banda no subida, queda sin foto: $e');
      }
    }
    return created!;
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

    // Archivo local -> bucket 'photos'. Si la subida falla se propaga el error:
    // NO se guarda una ruta del celular que nadie más puede ver.
    if (!photoUrl.startsWith('http')) {
      final file = File(photoUrl);
      if (!await file.exists()) {
        throw const AppException('No se encontró la foto seleccionada.');
      }
      final storagePath =
          '${photo.bandId}/${DateTime.now().millisecondsSinceEpoch}_photo.jpg';
      await _client.storage.from('photos').upload(storagePath, file);
      photoUrl = _client.storage.from('photos').getPublicUrl(storagePath);
    }

    final payload = photo.copyWith(photoUrl: photoUrl).toJson()..remove('id');
    final res =
        await (_client.from('band_photos').insert(payload).select().single())
            .withNetworkTimeout();
    return BandPhoto.fromJson(res);
  }

  /// Si falla, propaga el error. Antes devolvía ceros y el panel los
  /// guardaba en caché por 24 h como si fueran datos reales.
  @override
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId) async {
    final res = await (_client.rpc(
      'band_aggregated_stats',
      params: {'p_band': bandId},
    )).withNetworkTimeout();
    return BandAggregatedStats.fromJson(res as Map<String, dynamic>);
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
        rethrow; // el ViewModel decide cómo degradar (no se cachea un fallo)
      }
    }
  }
}
