import 'package:flutter/foundation.dart';
import 'package:streamtunes/domain/models/album.dart';
import 'package:streamtunes/domain/models/song.dart';

abstract class SongsRepository {
  Future<List<Song>> getLatestSongs({
    int limit = 20,
    String? genre,
    String? query,
  });
  Future<List<Song>> getSongsByBand(String bandId);
  Future<Song?> getSongById(String id);

  /// Sube el audio (y la portada si es local) a Storage y registra la canción.
  /// [audioBytes] se usa cuando no hay ruta local (por ejemplo en web).
  /// Lanza una excepción si el archivo no se pudo subir: nunca se registra una
  /// canción apuntando a una ruta local del dispositivo.
  Future<Song> uploadSong(
    Song song, {
    Uint8List? audioBytes,
    String? audioExtension,
  });
  Future<int> getBandSongCount(String bandId);
  Future<int> getBandAlbumCount(String bandId);
  Future<List<Album>> getBandAlbums(String bandId);
  Future<Album> createAlbum(Album album);
  Future<void> logPlayEvent(
    String songId,
    String bandId,
    String? userId,
    int secondsListened,
  );
  Future<bool> isSha256Duplicate(String sha256);
  Future<Song> updateSong(Song song);
  Future<void> deleteSong(String songId);
}
