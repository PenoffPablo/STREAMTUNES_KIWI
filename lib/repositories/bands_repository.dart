import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/band_event.dart';
import 'package:streamtunes/models/band_photo.dart';
import 'package:streamtunes/models/band_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BandsRepository {
  Future<List<Band>> getBands({BandStatus? status, String? genre, String? query});
  Future<Band?> getBandById(String id);
  Future<Band?> getBandBySlug(String slug);
  Future<Band> createBand(Band band, String userId);
  Future<Band> updateBand(Band band);
  Future<bool> followBand(String bandId, String userId);
  Future<bool> unfollowBand(String bandId, String userId);
  Future<bool> isFollowing(String bandId, String userId);
  Future<List<Band>> getFollowedBands(String userId);
  Future<List<BandEvent>> getBandEvents(String bandId);
  Future<BandEvent> addBandEvent(BandEvent event);
  Future<void> deleteBandEvent(String eventId);
  Future<List<BandPhoto>> getBandPhotos(String bandId);
  Future<BandPhoto> addBandPhoto(BandPhoto photo);
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId);
  Future<List<TopFanStat>> getBandTopFans(String bandId, {int days = 30});
}

//// Implementación en memoria determinista (Modo Dual / Offline / Pruebas)
class FakeBandsRepository implements BandsRepository {
  final List<Band> _bands = [
    Band(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      slug: 'los-fuzzers',
      name: 'Los Fuzzers',
      bio: 'Rock de garage, fuzz distorsionado y letras de medianoche desde el conurbano.',
      genre: 'Rock',
      location: 'Buenos Aires, AR',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
      merchUrl: 'https://merch.losfuzzers.com',
      socialLinks: {'instagram': 'https://instagram.com/losfuzzers'},
      donationGoal: 45000.0,
      donationsCollected: 18500.0,
      status: BandStatus.approved,
      createdBy: '22222222-2222-2222-2222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      followerCount: 142,
    ),
    Band(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      slug: 'nebulosa-subterranea',
      name: 'Nebulosa Subterránea',
      bio: 'Post-punk atmosférico grabado en cassettes vírgenes de 1994.',
      genre: 'Indie',
      location: 'La Plata, AR',
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6',
      donationGoal: 30000.0,
      donationsCollected: 0.0,
      status: BandStatus.pending,
      createdBy: '22222222-2222-2222-2222-222222222222',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      followerCount: 18,
    ),
  ];

  final Set<String> _follows = {'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa_33333333-3333-3333-3333-333333333333'};

  final List<BandEvent> _events = [
    BandEvent(
      id: 'evt-1',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      title: 'Ciclo Ruido Subterráneo',
      venue: 'Salón Pueyrredón',
      city: 'Buenos Aires',
      eventDate: DateTime.now().add(const Duration(days: 5)),
      ticketUrl: 'https://entradas.salonpueyrredon.com/ruido',
      createdAt: DateTime.now(),
    ),
    BandEvent(
      id: 'evt-2',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      title: 'Festival Fuzz del Conurbano',
      venue: 'El Galpón de Hurlingham',
      city: 'Hurlingham',
      eventDate: DateTime.now().add(const Duration(days: 18)),
      createdAt: DateTime.now(),
    ),
  ];

  final List<BandPhoto> _photos = [
    BandPhoto(
      id: 'photo-1',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      photoUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745',
      caption: 'Sótano en San Telmo - Setiembre 2026',
      createdAt: DateTime.now(),
    ),
    BandPhoto(
      id: 'photo-2',
      bandId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      photoUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
      caption: 'Probando sonido en el festival',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Band>> getBands({BandStatus? status, String? genre, String? query}) async {
    return _bands.where((b) {
      if (status != null && b.status != status) return false;
      if (genre != null && genre != 'Todos' && b.genre.toLowerCase() != genre.toLowerCase()) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        final matches = b.name.toLowerCase().contains(q) ||
            (b.bio?.toLowerCase().contains(q) ?? false) ||
            b.genre.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Band?> getBandById(String id) async {
    try {
      return _bands.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Band?> getBandBySlug(String slug) async {
    try {
      return _bands.firstWhere((b) => b.slug.toLowerCase() == slug.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Band> createBand(Band band, String userId) async {
    final newBand = band.copyWith(
      id: band.id.isNotEmpty ? band.id : 'band-${DateTime.now().millisecondsSinceEpoch}',
      status: BandStatus.pending, // Nace siempre en pending
      createdBy: userId,
      createdAt: DateTime.now(),
    );
    _bands.add(newBand);
    return newBand;
  }

  @override
  Future<Band> updateBand(Band band) async {
    final idx = _bands.indexWhere((b) => b.id == band.id);
    if (idx != -1) {
      _bands[idx] = band;
      return band;
    }
    _bands.add(band);
    return band;
  }

  @override
  Future<bool> followBand(String bandId, String userId) async {
    final key = '${bandId}_$userId';
    if (!_follows.contains(key)) {
      _follows.add(key);
      final idx = _bands.indexWhere((b) => b.id == bandId);
      if (idx != -1) {
        _bands[idx] = _bands[idx].copyWith(followerCount: _bands[idx].followerCount + 1);
      }
    }
    return true;
  }

  @override
  Future<bool> unfollowBand(String bandId, String userId) async {
    final key = '${bandId}_$userId';
    if (_follows.remove(key)) {
      final idx = _bands.indexWhere((b) => b.id == bandId);
      if (idx != -1) {
        _bands[idx] = _bands[idx].copyWith(
            followerCount: (_bands[idx].followerCount - 1).clamp(0, 999999));
      }
    }
    return true;
  }

  @override
  Future<bool> isFollowing(String bandId, String userId) async {
    return _follows.contains('${bandId}_$userId');
  }

  @override
  Future<List<Band>> getFollowedBands(String userId) async {
    final ids = _follows
        .where((k) => k.endsWith('_$userId'))
        .map((k) => k.split('_').first)
        .toSet();
    return _bands.where((b) => ids.contains(b.id)).toList();
  }

  @override
  Future<List<BandEvent>> getBandEvents(String bandId) async {
    return _events.where((e) => e.bandId == bandId).toList();
  }

  @override
  Future<BandEvent> addBandEvent(BandEvent event) async {
    _events.add(event);
    return event;
  }

  @override
  Future<void> deleteBandEvent(String eventId) async {
    _events.removeWhere((e) => e.id == eventId);
  }

  @override
  Future<List<BandPhoto>> getBandPhotos(String bandId) async {
    return _photos.where((p) => p.bandId == bandId).toList();
  }

  @override
  Future<BandPhoto> addBandPhoto(BandPhoto photo) async {
    _photos.add(photo);
    return photo;
  }

  @override
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId) async {
    return BandAggregatedStats(
      bandId: bandId,
      totalPlays: 304,
      totalMinutes: 1045,
      last7DaysPlays: 87,
      topSongs: const [
        TopSongStat(id: 'd1', title: 'Noches en el Andén', durationSeconds: 210, playCount: 142, recentPlays: 45),
        TopSongStat(id: 'd2', title: 'Vapor y Distorsión', durationSeconds: 185, playCount: 98, recentPlays: 28),
        TopSongStat(id: 'd3', title: 'Cintas de Caset Viejas', durationSeconds: 195, playCount: 64, recentPlays: 14),
      ],
    );
  }

  @override
  Future<List<TopFanStat>> getBandTopFans(String bandId, {int days = 30}) async {
    // Simula top fans respetando opt-in de privacidad
    return const [
      TopFanStat(
        rank: 1,
        userId: '33333333-3333-3333-3333-333333333333',
        displayName: 'Valeria Indie',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        minutesListened: 120,
        isPublic: true,
      ),
      TopFanStat(
        rank: 2,
        userId: '44444444-4444-4444-4444-444444444444',
        displayName: 'Fan anónimo', // Enmascarado por isPublic = false
        avatarUrl: null,
        minutesListened: 85,
        isPublic: false,
      ),
      TopFanStat(
        rank: 3,
        userId: '55555555-5555-5555-5555-555555555555',
        displayName: 'Fan anónimo',
        avatarUrl: null,
        minutesListened: 60,
        isPublic: false,
      ),
    ];
  }
}

//// Implementación real conectada a Supabase
class SupabaseBandsRepository implements BandsRepository {
  final SupabaseClient _client;

  SupabaseBandsRepository(this._client);

  @override
  Future<List<Band>> getBands({BandStatus? status, String? genre, String? query}) async {
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

    final data = await req.order('created_at', ascending: false);
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
      final res = await _client
          .from('bands')
          .select('*, band_follows(count)')
          .eq('id', id)
          .maybeSingle();
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
      final res = await _client
          .from('bands')
          .select('*, band_follows(count)')
          .eq('slug', slug)
          .maybeSingle();
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

    final res = await _client.from('bands').insert(payload).select().single();
    final newBand = Band.fromJson(res);

    // Asignar al creador como 'owner' en band_members
    await _client.from('band_members').insert({
      'band_id': newBand.id,
      'user_id': userId,
      'role': 'owner',
    });

    return newBand;
  }

  @override
  Future<Band> updateBand(Band band) async {
    final res = await _client
        .from('bands')
        .update(band.toJson())
        .eq('id', band.id)
        .select()
        .single();
    return Band.fromJson(res);
  }

  @override
  Future<bool> followBand(String bandId, String userId) async {
    await _client.from('band_follows').upsert({
      'band_id': bandId,
      'user_id': userId,
    });
    return true;
  }

  @override
  Future<bool> unfollowBand(String bandId, String userId) async {
    await _client
        .from('band_follows')
        .delete()
        .eq('band_id', bandId)
        .eq('user_id', userId);
    return true;
  }

  @override
  Future<bool> isFollowing(String bandId, String userId) async {
    final res = await _client
        .from('band_follows')
        .select('band_id')
        .eq('band_id', bandId)
        .eq('user_id', userId)
        .maybeSingle();
    return res != null;
  }

  @override
  Future<List<Band>> getFollowedBands(String userId) async {
    try {
      final res = await _client
          .from('band_follows')
          .select('bands(*, band_follows(count))')
          .eq('user_id', userId);

      return (res as List)
          .where((row) => row != null && row['bands'] != null)
          .map((row) {
        final bandJson = row['bands'] as Map<String, dynamic>;
        final followsList = bandJson['band_follows'] as List?;
        final count = followsList?.isNotEmpty == true
            ? (followsList!.first['count'] as num?)?.toInt() ?? 0
            : 0;
        return Band.fromJson(bandJson, followerCount: count);
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseBandsRepository] Error getFollowedBands: $e');
      return [];
    }
  }

  @override
  Future<List<BandEvent>> getBandEvents(String bandId) async {
    final res = await _client
        .from('band_events')
        .select()
        .eq('band_id', bandId)
        .order('event_date', ascending: true);
    return (res as List).map((json) => BandEvent.fromJson(json)).toList();
  }

  @override
  Future<BandEvent> addBandEvent(BandEvent event) async {
    final payload = event.toJson()..remove('id');
    final res = await _client.from('band_events').insert(payload).select().single();
    return BandEvent.fromJson(res);
  }

  @override
  Future<void> deleteBandEvent(String eventId) async {
    await _client.from('band_events').delete().eq('id', eventId);
  }

  @override
  Future<List<BandPhoto>> getBandPhotos(String bandId) async {
    final res = await _client
        .from('band_photos')
        .select()
        .eq('band_id', bandId)
        .order('created_at', ascending: false);
    return (res as List).map((json) => BandPhoto.fromJson(json)).toList();
  }

  @override
  Future<BandPhoto> addBandPhoto(BandPhoto photo) async {
    final payload = photo.toJson()..remove('id');
    final res = await _client.from('band_photos').insert(payload).select().single();
    return BandPhoto.fromJson(res);
  }

  @override
  Future<BandAggregatedStats> getBandAggregatedStats(String bandId) async {
    // Invocación a RPC nativo de PostgreSQL (Corrección de la cátedra)
    try {
      final res = await _client.rpc('band_aggregated_stats', params: {'p_band': bandId});
      return BandAggregatedStats.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SupabaseBandsRepository] Advertencia band_aggregated_stats RPC: $e');
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
  Future<List<TopFanStat>> getBandTopFans(String bandId, {int days = 30}) async {
    // Invocación a función RPC nativa con consentimiento de privacidad (opt-in) (soporta band_top_fans y band_top_listeners)
    try {
      final res = await _client.rpc('band_top_fans', params: {
        'p_band': bandId,
        'p_days': days,
      });
      return (res as List).map((row) => TopFanStat.fromJson(row as Map<String, dynamic>)).toList();
    } catch (_) {
      try {
        final res = await _client.rpc('band_top_listeners', params: {
          'p_band': bandId,
          'p_days': days,
        });
        return (res as List).map((row) => TopFanStat.fromJson(row as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('[SupabaseBandsRepository] Advertencia getBandTopFans RPC: $e');
        return [];
      }
    }
  }
}

