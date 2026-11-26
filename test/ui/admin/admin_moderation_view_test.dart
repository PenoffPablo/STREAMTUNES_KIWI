import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/config/dependencies.dart';
import 'package:streamtunes/data/repositories/auth/auth_repository_fake.dart';
import 'package:streamtunes/data/repositories/bands/bands_repository_fake.dart';
import 'package:streamtunes/data/repositories/config/config_repository_fake.dart';
import 'package:streamtunes/data/repositories/donations/donations_repository_fake.dart';
import 'package:streamtunes/data/repositories/moderation/moderation_repository_fake.dart';
import 'package:streamtunes/data/repositories/payouts/payouts_repository_fake.dart';
import 'package:streamtunes/data/services/audio/audio_player_service.dart';
import 'package:streamtunes/domain/models/band_payout.dart';
import 'package:streamtunes/domain/models/donation.dart';
import 'package:streamtunes/ui/account/view_models/session_view_model.dart';
import 'package:streamtunes/ui/admin/widgets/admin_moderation_view.dart';
import 'package:streamtunes/ui/core/scopes/app_scopes.dart';
import 'package:streamtunes/ui/core/themes/app_theme.dart';
import 'package:streamtunes/ui/player/view_models/player_view_model.dart';

const _bandId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('el panel de moderación entra en un celular de ${width.toInt()} px sin desbordes', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authRepo = FakeAuthRepository();
      final bandsRepo = FakeBandsRepository();
      final configRepo = FakeConfigRepository();
      final donations = FakeDonationsRepository();
      final audio = AudioPlayerService();
      addTearDown(() {
        audio.dispose();
        authRepo.dispose();
        donations.dispose();
      });

      // Datos reales de ejemplo: una banda con saldo, un pago y uno a devolver.
      final payouts = FakePayoutsRepository(
        collected: {_bandId: (name: 'Los Fuzzers del Sótano Profundo', gross: 123456.78, net: 116049.37)},
      )..addRejected(RejectedPayment(
          id: 'r1',
          mpPaymentId: '987654321012',
          amount: 4999.99,
          reason: 'La banda está suspendida: hay que devolver el pago.',
          createdAt: DateTime(2026, 11, 26, 12, 30),
          bandName: 'Los Fuzzers del Sótano Profundo',
        ));
      donations.addApproved(Donation(
        id: 'd1',
        bandId: _bandId,
        donorName: 'Juana de los Andes Rockeros',
        amountArs: 123456.78,
        netAmount: 116049.37,
        kiwiFee: 23209.87,
        mpPaymentId: 'mp-1',
        bandName: 'Los Fuzzers del Sótano Profundo',
        createdAt: DateTime(2026, 11, 26, 12),
      ));

      await authRepo.signInWithEmail('admin@streamtunes.test', 'x');
      final session = SessionViewModel(authRepo: authRepo, bandsRepo: bandsRepo, configRepo: configRepo);
      await session.signInWithEmail('admin@streamtunes.test', 'x');

      await tester.pumpWidget(DependenciesScope(
        dependencies: AppDependencies.fake(
          authRepository: authRepo,
          bandsRepository: bandsRepo,
          configRepository: configRepo,
          donationsRepository: donations,
          moderationRepository: FakeModerationRepository(),
          payoutsRepository: payouts,
          audioPlayerService: audio,
        ),
        child: SessionScope(
          viewModel: session,
          child: PlayerScope(
            viewModel: PlayerViewModel(playerService: audio),
            child: MaterialApp(theme: AppTheme.darkTheme, home: const AdminModerationView()),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('COMISIÓN KIWI'), findsOneWidget);
      // Recorre todo el panel: un desborde en cualquier parte haría fallar el test.
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
