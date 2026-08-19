import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

/// Honest destination for an assignment link while assignment detail is not yet
/// backed by a mobile domain/API contract.
class AssignmentLinkScreen extends StatelessWidget {
  const AssignmentLinkScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: SafeArea(
        child: PrismStatusView(
          icon: Icons.assignment_outlined,
          title: 'Affectation',
          message:
              'L’affectation « $assignmentId » n’est pas disponible dans cette version de Certigo.',
          actionLabel: 'Retour à l’accueil',
          onAction: () => context.go('/home'),
        ),
      ),
    );
  }
}
