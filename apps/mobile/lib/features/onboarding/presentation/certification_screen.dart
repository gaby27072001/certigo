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

  Future<void> _continue(TargetCertification target) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ActiveTrackSaveResult result =
        await ref.read(activeTrackProvider.notifier).select(target.trackId);
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
        if (track.id == cert.trackId) return track;
      }
      return null;
    }

    final bool selectedTrackIsPublished = target != null && trackFor(target) != null;

    return OnboardingScaffold(
      progress: 1,
      onBack: _saving ? null : () => context.go(OnboardingRoutes.welcome),
      primaryLabel: 'COMMENCER CE PARCOURS',
      primaryLoading: _saving,
      onPrimary: selectedTrackIsPublished && !_saving ? () => _continue(target) : null,
      child: catalog.when(
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            const MascotPrompt(message: 'Quelle certification veux-tu préparer ?'),
            const SizedBox(height: 12),
            Text(
              'Seuls les parcours publiés avec des leçons sont proposés.',
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
                (TargetCertification cert) => cert.trackId == track.id,
              ),
            ))
              const PrismStatusView(
                icon: Icons.school_outlined,
                title: 'Aucun parcours disponible',
                message: 'Réessaie quand le catalogue de leçons aura été synchronisé.',
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
