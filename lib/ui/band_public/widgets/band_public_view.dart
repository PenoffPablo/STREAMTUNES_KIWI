import 'package:flutter/material.dart';
import 'package:streamtunes/domain/models/band.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/band_public/view_models/band_public_view_model.dart';
import 'package:streamtunes/ui/band_public/widgets/donation_modal.dart';
import 'package:streamtunes/ui/band_public/widgets/band_header.dart';
import 'package:streamtunes/ui/band_public/widgets/band_songs_section.dart';
import 'package:streamtunes/ui/band_public/widgets/donation_goal_card.dart';
import 'package:streamtunes/ui/band_public/widgets/donation_wall.dart';
import 'package:streamtunes/ui/band_public/widgets/live_donation_toast.dart';
import 'package:streamtunes/ui/band_public/widgets/photos_gallery.dart';
import 'package:streamtunes/ui/band_public/widgets/top_fans_section.dart';
import 'package:streamtunes/ui/band_public/widgets/tour_dates_section.dart';
import 'package:streamtunes/ui/core/widgets/empty_state_view.dart';

class BandPublicView extends StatefulWidget {
  final String bandId;

  const BandPublicView({super.key, required this.bandId});

  @override
  State<BandPublicView> createState() => _BandPublicViewState();
}

class _BandPublicViewState extends State<BandPublicView> {
  late final BandPublicViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final userId = SessionScope.read(context).currentUser?.id;
    _viewModel = DependenciesScope.of(context).createBandPublicViewModel(widget.bandId)..init(currentUserId: userId);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openLink(String? url) async {
    final opened = await _viewModel.openExternalLink(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _viewModel;

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
                  onPressed: () => DonationModal.show(context, band),
                  icon: const Icon(Icons.volunteer_activism, color: AppTheme.primary, size: 18),
                  label: const Text(
                    'Apoyar',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
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
                        isDesktop ? _buildDesktopLayout(band, vm) : _buildMobileLayout(band, vm),

                        // Aviso animado de donación en vivo en tiempo real
                        if (vm.latestLiveDonation != null)
                          Positioned(
                            top: 12,
                            left: 16,
                            right: 16,
                            child: LiveDonationToast(
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
        BandHeader(band: band, isFollowing: vm.isFollowing, onFollow: vm.toggleFollow, onOpenLink: _openLink),
        const SizedBox(height: 16),
        DonationGoalCard(band: band),
        const SizedBox(height: 20),
        BandSongsSection(songs: vm.songs),
        const SizedBox(height: 20),
        TourDatesSection(events: vm.events, onOpenTickets: _openLink),
        const SizedBox(height: 20),
        PhotosGallery(photos: vm.photos),
        const SizedBox(height: 20),
        TopFansSection(fans: vm.topFans),
        const SizedBox(height: 20),
        DonationWall(donations: vm.recentDonations),
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
                BandHeader(band: band, isFollowing: vm.isFollowing, onFollow: vm.toggleFollow, onOpenLink: _openLink),
                const SizedBox(height: 16),
                DonationGoalCard(band: band),
                const SizedBox(height: 20),
                PhotosGallery(photos: vm.photos),
                const SizedBox(height: 20),
                TourDatesSection(events: vm.events, onOpenTickets: _openLink),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Columna Derecha: Canciones, Top Fans, Muro de Donaciones
          Expanded(
            flex: 6,
            child: ListView(
              children: [
                BandSongsSection(songs: vm.songs),
                const SizedBox(height: 20),
                TopFansSection(fans: vm.topFans),
                const SizedBox(height: 20),
                DonationWall(donations: vm.recentDonations),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
