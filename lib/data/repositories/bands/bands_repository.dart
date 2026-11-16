import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/domain/models/band_event.dart';
import 'package:streamtunes/domain/models/band_photo.dart';
import 'package:streamtunes/domain/models/band_stats.dart';

abstract class BandsRepository {
  Future<List<Band>> getBands({
    BandStatus? status,
    String? genre,
    String? query,
  });
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
