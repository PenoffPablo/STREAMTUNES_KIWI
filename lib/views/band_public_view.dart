import 'package:flutter/material.dart';
import 'package:streamtunes/models/band.dart';
import 'package:streamtunes/models/band_event.dart';
import 'package:streamtunes/models/band_photo.dart';
import 'package:streamtunes/models/band_stats.dart';
import 'package:streamtunes/models/donation.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/scopes/app_scopes.dart';
import 'package:streamtunes/theme/app_theme.dart';
import 'package:streamtunes/view_models/band_public_view_model.dart';
import 'package:streamtunes/widgets/add_to_playlist_dialog.dart';
import 'package:streamtunes/widgets/donation_modal.dart';
import 'package:streamtunes/widgets/empty_state_view.dart';
import 'package:url_launcher/url_launcher.dart';

class BandPublicView extends StatefulWidget {
  final String bandId;

  const BandPublicView({super.key, required this.bandId});

  @override
  State<BandPublicView> createState() => _BandPublicViewState();
}

class _BandPublicViewState extends State<BandPublicView> {
  BandPublicViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel == null) {
      final repos = RepositoriesScope.of(context);
      _viewModel = BandPublicViewModel(
        bandsRepo: repos.bandsRepository,
        songsRepo: repos.songsRepository,
        donationsRepo: repos.donationsRepository,
        bandId: widget.bandId,
      );
      final user = SessionScope.of(context).currentUser;
      _viewModel!.loadBandData(user?.id);
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  void _openMerch(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace de la tienda.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    final vm = _viewModel!;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final band = vm.band;

        return Scaffold(
          appBar: AppBar(
            title: Text(band?.name ?? 'Perfil de Banda'),
            actions: [
              if (band != null)
                TextButton.icon(
                  onPressed: () => DonationModal.show(context, band, vm),
                  icon: const Icon(Icons.volunteer_activism, color: AppTheme.primary, size: 18),
                  label: const Text('Apoyar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : band == null
                  ? const EmptyStateView(
                      icon: Icons.error_outline,
                      title: 'Banda no encontrada',
                      description: 'No pudimos encontrar la información de esta banda en el colectivo.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Disposición adaptativa (2 columnas en pantallas >= 800px)
                        final isDesktop = constraints.maxWidth >= 800;

                        return Stack(
                          children: [
                            isDesktop
                                ? _buildDesktopLayout(band, vm)
                                : _buildMobileLayout(band, vm),

                            // Aviso animado de donación en vivo en tiempo real
                            if (vm.latestLiveDonation != null)
                              Positioned(
                                top: 12,
                                left: 16,
                                right: 16,
                                child: _LiveDonationToast(
                                  donation: vm.latestLiveDonation!,
                                  onDismiss: () => vm.dismissLiveDonationAlert(),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
        );
      },
    );
  }

  Widget _buildMobileLayout(Band band, BandPublicViewModel vm) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildBandHeader(band, vm),
        const SizedBox(height: 16),
        _buildDonationGoalCard(band, vm),
        const SizedBox(height: 20),
        _buildSongsSection(vm.songs),
        const SizedBox(height: 20),
        _buildTourDatesSection(vm.events),
        const SizedBox(height: 20),
        _buildPhotosSection(vm.photos),
        const SizedBox(height: 20),
        _buildTopFansSection(vm.topFans),
        const SizedBox(height: 20),
        _buildDonationWall(vm.recentDonations),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDesktopLayout(Band band, BandPublicViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Izquierda: Perfil, Meta, Fotos, Tienda
          Expanded(
            flex: 4,
            child: ListView(
              children: [
                _buildBandHeader(band, vm),
                const SizedBox(height: 16),
                _buildDonationGoalCard(band, vm),
                const SizedBox(height: 20),
                _buildPhotosSection(vm.photos),
                const SizedBox(height: 20),
                _buildTourDatesSection(vm.events),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Columna Derecha: Canciones, Top Fans, Muro de Donaciones
          Expanded(
            flex: 6,
            child: ListView(
              children: [
                _buildSongsSection(vm.songs),
                const SizedBox(height: 20),
                _buildTopFansSection(vm.topFans),
                const SizedBox(height: 20),
                _buildDonationWall(vm.recentDonations),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandHeader(Band band, BandPublicViewModel vm) {
    final sessionVM = SessionScope.of(context);
    final user = sessionVM.currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 100,
                  color: AppTheme.surfaceLight,
                  child: band.coverUrl != null
                      ? Image.network(
                          band.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.groups, size: 48, color: AppTheme.textSecondary),
                        )
                      : const Icon(Icons.groups, size: 48, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      band.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${band.genre} • ${band.location ?? "Argentina"}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${band.followerCount} seguidores',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (user != null) {
                          vm.toggleFollow(user.id);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inicia sesión para seguir a esta banda.')),
                          );
                        }
                      },
                      icon: Icon(
                        vm.isFollowing ? Icons.check : Icons.person_add,
                        size: 16,
                      ),
                      label: Text(vm.isFollowing ? 'Siguiendo' : 'Seguir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: vm.isFollowing ? AppTheme.surfaceLight : AppTheme.primary,
                        foregroundColor: vm.isFollowing ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (band.bio != null && band.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              band.bio!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
          if (band.merchUrl != null && band.merchUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openMerch(band.merchUrl),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: AppTheme.primary),
              label: const Text('Tienda de Merch (Remeras y Vinilos)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDonationGoalCard(Band band, BandPublicViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'META DE RECAUDACIÓN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${band.donationsCollected.toInt()} / \$${band.donationGoal.toInt()} ARS',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: band.donationProgress,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => DonationModal.show(context, band, vm),
              icon: const Icon(Icons.volunteer_activism, size: 16),
              label: const Text('Aportar al Fondo de la Banda'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsSection(List<Song> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANCIONES MÁS ESCUCHADAS',
          style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        if (songs.isEmpty)
          const Text('La banda no tiene canciones disponibles aún.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
        else
          ...songs.map((song) => _BandSongTile(song: song, allSongs: songs)),
      ],
    );
  }

  Widget _buildTourDatesSection(List<BandEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRÓXIMAS FECHAS EN VIVO',
          style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('No hay fechas confirmadas por el momento.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
        else
          ...events.map((event) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${event.eventDate.day}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          Text(
                            _monthAbbr(event.eventDate.month),
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${event.venue} • ${event.city}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (event.ticketUrl != null)
                      TextButton(
                        onPressed: () => _openMerch(event.ticketUrl),
                        child: const Text('Entradas', style: TextStyle(color: AppTheme.primary)),
                      ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildPhotosSection(List<BandPhoto> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GALERÍA DE SHOWS',
          style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final photo = photos[idx];
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 160,
                  color: AppTheme.surfaceLight,
                  child: Image.network(
                    photo.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.camera_alt, color: AppTheme.textSecondary)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopFansSection(List<TopFanStat> fans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOP 10 FANS EN VIVO (ÚLTIMOS 30 DÍAS)',
          style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        if (fans.isEmpty)
          const Text('Aún no hay reproducciones suficientes para el ranking.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: fans.map((fan) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text(
                          '#${fan.rank}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: fan.rank <= 3 ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.surfaceLight,
                        backgroundImage: fan.isPublic && fan.avatarUrl != null
                            ? NetworkImage(fan.avatarUrl!)
                            : null,
                        onBackgroundImageError: fan.isPublic && fan.avatarUrl != null
                            ? (exception, stackTrace) {}
                            : null,
                        child: !fan.isPublic || fan.avatarUrl == null
                            ? const Icon(Icons.person, size: 16, color: AppTheme.textSecondary)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fan.isPublic ? fan.displayName : 'Fan anónimo (Privado)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: fan.isPublic ? AppTheme.textPrimary : AppTheme.textSecondary,
                            fontStyle: fan.isPublic ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ),
                      Text(
                        '${fan.minutesListened} min',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDonationWall(List<Donation> donations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MURO DE APORTES EN VIVO (REALTIME)',
          style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        if (donations.isEmpty)
          const Text('Sé el primer fan en apoyar a la banda en su meta.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
        else
          ...donations.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.favorite, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  d.isAnonymous ? 'Fan anónimo' : d.donorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+\$${d.amountArs.toInt()} ARS',
                                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          if (d.message != null && d.message!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '"${d.message!}"',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  String _monthAbbr(int month) {
    const m = ['', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    return m[month];
  }
}

class _LiveDonationToast extends StatelessWidget {
  final Donation donation;
  final VoidCallback onDismiss;

  const _LiveDonationToast({required this.donation, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(150),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.black, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '¡NUEVO APORTE EN VIVO!',
                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                  Text(
                    '${donation.isAnonymous ? "Fan anónimo" : donation.donorName} aportó \$${donation.amountArs.toInt()} ARS',
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _BandSongTile extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;

  const _BandSongTile({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context) {
    final playerVM = PlayerScope.of(context);
    final isCurrent = playerVM.currentSong?.id == song.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: Icon(
            isCurrent && playerVM.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: AppTheme.primary,
            size: 30,
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            '${song.formattedDuration} • ${song.playCount} reproducciones',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
            tooltip: 'Sumar a Playlist',
            onPressed: () => AddToPlaylistDialog.show(context, song),
          ),
          onTap: () {
            if (isCurrent) {
              playerVM.togglePlayPause();
            } else {
              playerVM.playSong(song, queue: allSongs);
            }
          },
        ),
      ),
    );
  }
}
