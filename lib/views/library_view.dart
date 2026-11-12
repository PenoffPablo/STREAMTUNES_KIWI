import 'package:flutter/material.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/playlist.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/views/band_public_view.dart';
import 'package:streamtunes/views/playlist_detail_view.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;
    if (user != null && !user.isAnonymous && user.id != _lastLoadedUserId) {
      _lastLoadedUserId = user.id;
      LibraryScope.of(context).loadLibrary(user.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog(String userId) {
    final titleCtrl = TextEditingController();
    final libVM = LibraryScope.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Nueva Playlist'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la playlist',
            hintText: 'Ej. Post-punk de sótano',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                await libVM.createPlaylist(userId, title);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;
    final libraryVM = LibraryScope.of(context);

    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Biblioteca')),
        body: const EmptyStateView(
          icon: Icons.library_music_outlined,
          title: 'Guarda tu Música Favorita',
          description: 'Inicia sesión con tu cuenta para crear playlists personalizadas y seguir a tus bandas de cabecera.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            tooltip: 'Crear Playlist',
            onPressed: () => _showCreatePlaylistDialog(user.id),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Playlists'),
            Tab(text: 'Bandas que sigues'),
          ],
        ),
      ),
      body: libraryVM.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                // Pestaña 1: Playlists
                _buildPlaylistsTab(libraryVM.playlists, user.id),

                // Pestaña 2: Bandas seguidas
                _buildFollowedBandsTab(libraryVM.followedBands, user.id),
              ],
            ),
    );
  }

  Widget _buildPlaylistsTab(List<Playlist> playlists, String userId) {
    if (playlists.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => LibraryScope.of(context).loadLibrary(userId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: EmptyStateView(
                icon: Icons.queue_music,
                title: 'No tienes playlists creadas',
                description: 'Arma tus listas personalizadas para tus viajes en tren o previas de recitales.',
                actionLabel: 'Crear primera playlist',
                onAction: () => _showCreatePlaylistDialog(userId),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => LibraryScope.of(context).loadLibrary(userId),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: playlists.length,
        itemBuilder: (context, idx) {
          final pl = playlists[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.playlist_play, color: AppTheme.primary, size: 28),
              ),
              title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${pl.songIds.length} canciones guardadas'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => PlaylistDetailView(playlist: pl),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowedBandsTab(List<Band> bands, String userId) {
    if (bands.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => LibraryScope.of(context).loadLibrary(userId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const EmptyStateView(
                icon: Icons.groups_outlined,
                title: 'Aún no sigues a ninguna banda',
                description: 'Escanea el código QR de una banda en un recital o toca "Seguir" en sus perfiles.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => LibraryScope.of(context).loadLibrary(userId),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: bands.length,
        itemBuilder: (context, idx) {
          final b = bands[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  color: AppTheme.surfaceLight,
                  child: b.coverUrl != null
                      ? Image.network(
                          b.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.groups),
                        )
                      : const Icon(Icons.groups),
                ),
              ),
              title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${b.genre} • ${b.followerCount} seguidores'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => BandPublicView(bandId: b.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
