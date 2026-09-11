import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// The heart of the adaptation — the Certigo equivalent of the reference flow's
/// "which language?" question: pick the certification you're aiming for. Each
/// option is a shared [CertificationCard] (the same design-system component the
/// library catalogue and course picker use), tinted with its exam-domain accent.
class CertificationScreen extends ConsumerStatefulWidget {
  const CertificationScreen({super.key});

  @override
  ConsumerState<CertificationScreen> createState() => _CertificationScreenState();
}

class _CertificationScreenState extends ConsumerState<CertificationScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _continue(TargetCertification target, String catalogTrackId) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ActiveTrackSaveResult result =
        await ref.read(activeTrackProvider.notifier).select(catalogTrackId);
    if (!mounted) return;
    if (!result.accepted) {
      setState(() {
        _saving = false;
        _error = result.failure?.message ?? 'Impossible d\'enregistrer cette certification.';
      });
      return;
    }

    try {
      await ref.read(onboardingControllerProvider).complete();
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Impossible d’enregistrer la fin de l’introduction. Réessaie.';
      });
      return;
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final AsyncValue<List<TrackSummary>> catalog = ref.watch(catalogProvider);
    final TargetCertification? target = c.targetCertification;
    final List<TrackSummary> published = catalog.asData?.value
            .where((TrackSummary track) => track.hasLearningContent && track.isActive)
            .toList(growable: false) ??
        const <TrackSummary>[];

    TrackSummary? trackFor(TargetCertification cert) {
      for (final TrackSummary track in published) {
        if (cert.matchesTrack(track)) return track;
      }
      return null;
    }

    final TrackSummary? selectedTrack = target == null ? null : trackFor(target);

    return OnboardingScaffold(
      progress: 1,
      // Cohérent avec le geste iOS de retour par balayage : on dépile si la pile
      // le permet, sinon on retombe sur la navigation logique.
      onBack: _saving
          ? null
          : () => context.canPop() ? context.pop() : context.go(OnboardingRoutes.welcome),
      primaryLabel: CertificationLabels.start,
      primaryLoading: _saving,
      onPrimary: target != null && selectedTrack != null && !_saving
          ? () => _continue(target, selectedTrack.id)
          : null,
      // The body owns its own scrolling so the list can fade out under the
      // sticky CTA. With the scaffold's default scroller the sixth card was
      // sliced flat by the CTA's top border at rest — a guillotine, not a
      // scroll hint, on a screen every new learner sees.
      scrollable: false,
      child: catalog.when(
        data: (_) => ShaderMask(
          shaderCallback: (Rect bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: <double>[0, 0.94, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView(
            // No `physics:` on purpose — ScrollBehavior resolves the platform's
            // own physics (bounce on iOS, clamp on Android). See
            // test/structural/scroll_physics_platform_test.dart.
            padding: const EdgeInsets.only(bottom: PrismSpacing.xl),
            children: <Widget>[
              const SizedBox(height: 8),
              const MascotPrompt(message: CertificationLabels.question),
              const SizedBox(height: 12),
              Text(
                CertificationLabels.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.prism.textSecondary),
              ),
              const SizedBox(height: 20),
              for (final TargetCertification cert in availableTargetCertifications)
                if (trackFor(cert) case final TrackSummary track) ...<Widget>[
                  CertificationCard(
                    code: track.displayCode,
                    title: track.title,
                    accent: context.prism.accentFor(cert.domainIndex),
                    selected: target == cert,
                    onTap: _saving ? null : () => c.setTargetCertification(cert),
                  ),
                  const SizedBox(height: 12),
                ],
              if (published.every(
                (TrackSummary track) => !availableTargetCertifications.any(
                  (TargetCertification cert) => cert.matchesTrack(track),
                ),
              ))
                const PrismStatusView(
                  icon: Icons.school_outlined,
                  title: CertificationLabels.emptyTitle,
                  message: CertificationLabels.emptyMessage,
                ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.prism.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => PrismStatusView.error(
          message: error is Failure
              ? error.message
              : 'Impossible de charger les certifications disponibles.',
          onRetry: () => ref.invalidate(catalogProvider),
        ),
      ),
    );
  }
}

/// Copy asserted by tests. Named so a wording change cannot leave an assertion
/// silently passing for the wrong reason — `onboarding_versioned_catalog_test`
/// checks that [emptyTitle] is *absent*, which a rename would satisfy vacuously.
abstract final class CertificationLabels {
  static const String question = 'Quelle certification veux-tu préparer ?';
  static const String subtitle = 'Tu pourras en changer plus tard.';
  static const String start = 'Commencer ce parcours';
  static const String emptyTitle = 'Aucun parcours disponible';
  static const String emptyMessage = 'Réessaie quand le catalogue de leçons aura été synchronisé.';
}
