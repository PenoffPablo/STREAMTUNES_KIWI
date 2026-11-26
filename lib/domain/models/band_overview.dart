import 'package:streamtunes/domain/models/band.dart';

/// Banda vista desde el panel de moderación: sus datos más lo que el
/// moderador necesita para decidir (cuántos temas tiene y quién la creó).
class BandOverview {
  const BandOverview({required this.band, this.songCount = 0, this.ownerName});

  final Band band;

  /// Temas subidos (incluye los ocultos: el moderador ve todo).
  final int songCount;

  /// Nombre visible de quien registró la banda.
  final String? ownerName;

  BandOverview copyWith({Band? band}) => BandOverview(band: band ?? this.band, songCount: songCount, ownerName: ownerName);

  /// Lee una fila de `bands` con `band_follows(count)`, `songs(count)` y el
  /// perfil del creador (`owner`).
  factory BandOverview.fromJson(Map<String, dynamic> json) {
    int count(String key) {
      final list = json[key] as List?;
      return list != null && list.isNotEmpty ? (list.first['count'] as num?)?.toInt() ?? 0 : 0;
    }

    final owner = json['owner'];
    return BandOverview(
      band: Band.fromJson(json, followerCount: count('band_follows')),
      songCount: count('songs'),
      ownerName: owner is Map ? owner['display_name'] as String? : null,
    );
  }
}
