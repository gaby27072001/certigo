import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Écran de configuration invalide, affiché **à la place** de l'application
/// quand un build strict (prod/staging) démarre avec une configuration
/// runtime erronée (voir [AppEnv.validate]).
///
/// Objectif : **échouer fort et visiblement** plutôt que de laisser l'app
/// démarrer sur une config dev/incohérente (API dev en prod, Entra partiel,
/// schéma de redirection incompatible…). Autonome : aucun routeur, aucun
/// provider, aucune dépendance réseau — il doit s'afficher même quand tout le
/// reste est mal configuré.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.report, super.key});

  final AppConfigReport report;

  @override
  Widget build(BuildContext context) {
    final List<AppConfigIssue> errors = report.errors;
    final List<AppConfigIssue> warnings = report.warnings;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB00020),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF6B6B)),
                    const SizedBox(height: 16),
                    Text(
                      'Configuration invalide',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'L\'application ne peut pas démarrer en environnement '
                      '« ${AppEnv.flavor.name} » : la configuration '
                      'runtime est incomplète ou incohérente. '
                      'Corrigez les points ci-dessous (--dart-define / CI) puis '
                      'reconstruisez l\'application.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (errors.isNotEmpty) ...<Widget>[
                      _SectionTitle('Erreurs bloquantes (${errors.length})'),
                      const SizedBox(height: 8),
                      for (final AppConfigIssue issue in errors)
                        _IssueTile(issue: issue, blocking: true),
                    ],
                    if (warnings.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _SectionTitle('Avertissements (${warnings.length})'),
                      const SizedBox(height: 8),
                      for (final AppConfigIssue issue in warnings)
                        _IssueTile(issue: issue, blocking: false),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Références : docs/CONFIG_AUTH.md et docs/RELEASE_MOBILE.md',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue, required this.blocking});

  final AppConfigIssue issue;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final Color accent = blocking ? const Color(0xFFFF6B6B) : const Color(0xFFFFC46B);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(blocking ? Icons.block : Icons.warning_amber_rounded, size: 18, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    issue.key,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(issue.message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
