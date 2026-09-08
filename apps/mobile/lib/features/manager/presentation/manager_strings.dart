import 'package:flutter/widgets.dart';

class ManagerStrings {
  const ManagerStrings._(this.isFrench);

  final bool isFrench;

  static ManagerStrings of(BuildContext context) {
    return ManagerStrings._(
      Localizations.localeOf(context).languageCode == 'fr',
    );
  }

  String pick(String french, String english) => isFrench ? french : english;

  String get personal => pick('Personnel', 'Personal');
  String get enterprise => pick('Entreprise', 'Enterprise');
  String get portalTitle => pick('Pilotage de la formation', 'Learning management');
  String get privacyNotice => pick(
        'Uniquement des agrégats de cohorte. Aucune identité ni acquis individuel.',
        'Cohort aggregates only. No identity or individual learning records.',
      );
  String get dashboard => pick('Tableau de bord', 'Dashboard');
  String get members => pick('Membres', 'Members');
  String get teams => pick('Équipes', 'Teams');
  String get assignments => pick('Assignations', 'Assignments');
  String get exports => pick('Exports', 'Exports');
  String get audit => pick('Audit', 'Audit');
  String get loading => pick('Chargement du portail manager…', 'Loading manager portal…');
  String get unavailable => pick('Ressource indisponible', 'Resource unavailable');
  String get unavailableMessage => pick(
        'Cette organisation est introuvable ou ton rôle ne permet pas d’y accéder.',
        'This organization cannot be found or your role does not allow access.',
      );
  String get retry => pick('Réessayer', 'Retry');
  String get unknown => pick('Inconnu', 'Unknown');
  String get noData => pick('Aucune donnée agrégée', 'No aggregate data');
  String get noDataMessage => pick(
        'Les métriques apparaîtront quand une cohorte atteindra le seuil de confidentialité.',
        'Metrics appear once a cohort reaches the privacy threshold.',
      );
}
