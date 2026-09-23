import 'package:data/data.dart';
import 'package:flutter/material.dart';

import '../../../shared/errors/error_copy.dart';

/// Copy of the « Ma série » flow, named so tests assert the string the screen
/// renders instead of duplicating a literal.
///
/// Every number in these sentences is a server value — the streak, the price,
/// the balance, the deadline. The copy formats them; it never derives one.
abstract final class StreakLabels {
  static const String title = 'Ma série';

  /// French keeps 0 and 1 singular.
  static String days(int n) => n <= 1 ? '$n jour' : '$n jours';
  static String gems(int n) => n <= 1 ? '$n gemme' : '$n gemmes';

  // ── Offer ────────────────────────────────────────────────────────────────
  static String pausedTitle(int streakDays) => 'Ta série de ${days(streakDays)} est en pause';
  static String lastActive(String day) => 'Dernière journée validée : $day.';
  static const String offerTitle = 'La réparation';
  static String offerBody(int streakDays) =>
      'Ta série reprend à ${days(streakDays)}. Atteins ensuite ton objectif du jour '
      'pour la prolonger.';

  /// The trap the learner cannot see: meeting today's goal on a broken streak
  /// restarts it at 1 (`StreakService.UpdateStreak`), and then nothing is left
  /// to repair.
  static const String beforeGoal = 'Répare-la avant d\u2019atteindre ton objectif du jour : '
      'sinon, ta série repartira de 1.';
  static String price(int cost) => 'Prix : ${gems(cost)}';
  static String balance(int gems) => 'Ton solde : ${StreakLabels.gems(gems)}';
  static String deadline(String when) => 'Possible jusqu\u2019au $when';
  static const String noDeadline =
      'Ne tarde pas : une série ne se répare que quelques jours après son interruption.';
  static const String repair = 'Réparer ma série';
  static const String repairAnyway = 'Réparer quand même';
  static const String checking = 'Vérification de ta série\u2026';
  static String missing(int gems) =>
      'Il te manque ${StreakLabels.gems(gems)} pour cette réparation.';
  static const String missingHint = 'Les leçons rapportent des gemmes, mais atteindre ton '
      'objectif du jour relancera ta série à 1.';

  /// When a freeze covers the gap, meeting the goal *saves* the streak: the
  /// reset warning above would tell the learner to avoid the one free fix.
  static const String missingFreezeHint = 'Pas besoin de gemmes pour la sauver : atteins ton '
      'objectif aujourd\u2019hui et ton gel s\u2019en charge.';

  // ── The last re-read failed: no gem leaves on an old snapshot ───────────
  static const String unverifiedTitle = 'Ta série n\u2019a pas pu être revérifiée';
  static const String unverifiedBody = 'Aucune gemme ne part sur des données anciennes. '
      'Revérifie ta série, puis répare-la.';
  static const String recheck = 'Revérifier ma série';

  // ── A freeze already covers the gap ─────────────────────────────────────
  static const String freezeTitle = 'Ton gel de série couvre ce jour manqué';
  static String freezeBody(int streakDays) =>
      'Atteins ton objectif aujourd\u2019hui : ta série de ${days(streakDays)} continue, '
      'sans rien payer.';
  static const String freezeRepairNote = 'Réparer garde ton gel en réserve pour une autre fois.';

  // ── Granted ─────────────────────────────────────────────────────────────
  static const String grantedTitle = 'Série réparée !';
  static String grantedBody(int streakDays) =>
      'Ta série de ${days(streakDays)} est sauvée. Atteins ton objectif du jour '
      'pour la prolonger.';
  static String newBalance(int gems) => 'Nouveau solde : ${StreakLabels.gems(gems)}';
  static const String continueLearning = 'Continuer mon parcours';

  // ── Nothing to repair ───────────────────────────────────────────────────
  static String intactTitle(int streakDays) => 'Ta série de ${days(streakDays)} est intacte';
  static const String intactBody =
      'Continue d\u2019atteindre ton objectif chaque jour pour la prolonger.';
  static String freezeReserve(int tokens) => tokens <= 1
      ? '$tokens gel de série en réserve : il protège ta série si tu manques un jour.'
      : '$tokens gels de série en réserve : chacun protège ta série si tu manques un jour.';
  static String expiredTitle(int streakDays) =>
      'Ta série de ${days(streakDays)} s\u2019est arrêtée';
  static const String expiredBody = 'Trop de jours ont passé pour la réparer. Ta prochaine '
      'journée validée lance une nouvelle série.';
  static const String noneTitle = 'Pas encore de série';
  static const String noneBody = 'Atteins ton objectif du jour pour lancer ta première série.';
  static const String unavailableTitle = 'Réparation indisponible';
  static const String unavailableBody = 'Ta série ne peut pas être réparée pour le moment. '
      'Continue tes leçons pour la faire vivre.';
  static const String startLesson = 'Commencer une leçon';

  // ── Status could not be read, and retrying cannot help ──────────────────
  static const String statusMissingTitle = 'Ta série est indisponible pour l\u2019instant';
  static const String statusMissingBody = 'Le serveur ne sait pas encore la fournir. '
      'Retrouve ton compteur de série sur l\u2019accueil, puis reviens plus tard.';
  static const String backHome = 'Revenir à l\u2019accueil';

  // ── Refusals: rulings, with their cause ─────────────────────────────────
  static const String notCharged = 'Rien ne t\u2019a été débité.';
  static String refusedShort(int balance) =>
      'Ton solde de ${gems(balance)} ne couvre pas le prix de la réparation.';
  static const String refusedIntact = 'Ta série n\u2019avait plus besoin d\u2019être réparée.';
  static const String refusedExpired = 'La fenêtre de réparation s\u2019est refermée.';
  static const String refusedNoStreak = 'Il n\u2019y a plus de série à réparer.';
  static const String refusedOther = 'La réparation n\u2019a pas abouti. Réessaie dans un instant.';

  // ── Repair sent, no ruling received ─────────────────────────────────────
  static const String failedTitle = 'Réparation non confirmée';
  static const String neverTwice = 'Réessayer ne te fera jamais payer deux fois.';

  // ── Home ────────────────────────────────────────────────────────────────
  static String bannerTitle(int streakDays) => 'Ta série de ${days(streakDays)} est en pause';
  static String bannerBody(int cost, String? until) => until == null
      ? 'Répare-la pour ${gems(cost)}.'
      : 'Répare-la pour ${gems(cost)} jusqu\u2019au $until.';
  static const String bannerFreezeTitle = 'Ton gel de série veille';
  static String bannerFreezeBody(int streakDays) =>
      'Atteins ton objectif aujourd\u2019hui pour garder ta série de ${days(streakDays)}.';
  static const String badgeHint = 'Ouvre le détail de ta série';
}

/// A calendar day as the learner reads it. The day is kept as UTC fields by the
/// data layer, so it is formatted as-is and never shifted by the device zone.
String formatStreakDay(MaterialLocalizations l10n, DateTime day) => l10n.formatFullDate(day);

/// The repair deadline in the learner's own zone. The server publishes an
/// exclusive UTC instant precisely so that this conversion is the client's only
/// job: a bare date would be hours wrong for anyone away from UTC.
String formatRepairDeadline(
  MaterialLocalizations l10n,
  DateTime local, {
  required bool alwaysUse24HourFormat,
}) {
  final String day = l10n.formatFullDate(local);
  final String time = l10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
  return '$day à $time';
}

/// Why `GET /streak` could not be shown, and what to do.
///
/// Retryable causes keep the shared copy, which already names « ta série ». The
/// others would send the learner to the library, which has nothing to do with a
/// streak; here the only real way out is Home, where the streak counter lives.
ErrorCopy streakStatusErrorCopy(Object? error) {
  final ErrorCopy copy = describeFailure(error, subject: ErrorSubject.streak);
  if (copy.retryResolves) return copy;
  final bool outdated = copy.kind == ErrorKind.appOutdated;
  return ErrorCopy(
    kind: copy.kind,
    title: outdated ? copy.title : StreakLabels.statusMissingTitle,
    message: outdated ? copy.message : StreakLabels.statusMissingBody,
    actionLabel: StreakLabels.backHome,
    actionIcon: Icons.home_rounded,
    icon: copy.icon,
  );
}

/// What to say when a repair was sent but no ruling came back.
///
/// Classified on the failure's sealed type, never on its text — the same
/// invariant as `describeFailure`. The outcome is unknown, so every retryable
/// cause also says the one thing the learner fears: paying twice. That promise
/// is true because the retry replays the same `clientRepairId`.
({String title, String message, bool retryResolves}) repairFailureCopy(Object? error) {
  final ErrorKind kind = errorKindOf(error);
  final String? cause = switch (kind) {
    ErrorKind.offline => 'Tu es hors ligne. Réactive le Wi-Fi ou les données mobiles, '
        'puis réessaie.',
    ErrorKind.connectSlow => 'Le serveur n\u2019a pas pu être joint à temps. '
        'Réessaie dans un instant.',
    ErrorKind.serverSilent => 'Ta connexion fonctionne, mais le serveur a tardé à répondre. '
        'Réessaie dans un instant.',
    ErrorKind.serverDown => 'Le service est momentanément indisponible. '
        'Réessaie dans quelques minutes.',
    ErrorKind.throttled => 'Trop de tentatives en peu de temps. Patiente quelques minutes '
        'avant de réessayer.',
    ErrorKind.sessionExpired => 'Ta session a expiré. Réessaie ; si ça ne passe pas, '
        'reconnecte-toi.',
    ErrorKind.rejected => 'Le serveur n\u2019a pas pu traiter la demande. '
        'Réessaie dans un instant.',
    ErrorKind.unexpected ||
    ErrorKind.noOfflineCopy ||
    ErrorKind.empty =>
      'Quelque chose a échoué de notre côté. Réessaie dans un instant.',
    ErrorKind.notFound || ErrorKind.appOutdated => null,
  };
  if (cause != null) {
    return (
      title: StreakLabels.failedTitle,
      message: '$cause ${StreakLabels.neverTwice}',
      retryResolves: true,
    );
  }
  return (
    title: StreakLabels.failedTitle,
    message: kind == ErrorKind.appOutdated
        ? 'Cette version de Certigo ne comprend pas la réponse du serveur. '
            'Mets l\u2019app à jour depuis l\u2019App Store.'
        : 'La réparation n\u2019est pas disponible sur ce serveur pour l\u2019instant. '
            'Reviens plus tard.',
    retryResolves: false,
  );
}

/// The sentence for a refused repair: its cause, then — only when the server's
/// own figure says so — that nothing was charged.
String refusalMessage(StreakRepairResult result) {
  final String cause = switch (result.refusal) {
    StreakRepairRefusal.insufficientGems => StreakLabels.refusedShort(result.gemsBalance),
    StreakRepairRefusal.alreadyIntact => StreakLabels.refusedIntact,
    StreakRepairRefusal.expired => StreakLabels.refusedExpired,
    StreakRepairRefusal.noStreak => StreakLabels.refusedNoStreak,
    StreakRepairRefusal.conflict ||
    StreakRepairRefusal.unknown ||
    null =>
      StreakLabels.refusedOther,
  };
  return result.gemsSpent == 0 ? '$cause ${StreakLabels.notCharged}' : cause;
}
