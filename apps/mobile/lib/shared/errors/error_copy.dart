/// Traduction d'un échec technique en **cause comprise + action à faire**.
///
/// Le référentiel UX pose qu'« un message d'erreur explique ce qui s'est passé
/// ET quoi faire ». Deux défauts symétriques y contreviennent, et les deux
/// existaient ici : propager `Failure.message` (qui peut contenir la chaîne
/// brute de Dio, voir `ApiClient._mapDioError`) donne trop d'information et
/// aucune action ; afficher « Une erreur est survenue » n'en donne aucune des
/// deux.
///
/// ## Pourquoi cette couche ne lit jamais `Failure.message`
///
/// C'est l'invariant central. [describeFailure] classe **sur le type scellé**
/// et rien d'autre : aucun chemin ne recopie le texte porté par l'échec. Un
/// détail technique ne peut donc pas traverser cette couche, même si une
/// couche basse en fabrique un — ce que `ServerFailure(detail ?? e.message)`
/// fait aujourd'hui. Le détail part dans les journaux ; l'apprenant reçoit une
/// phrase qui dit quoi faire.
library;

import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Ce que l'écran tentait d'obtenir, pour que le message **nomme la chose**
/// plutôt que de parler de « données ».
enum ErrorSubject {
  catalogue('les certifications'),
  chapters('les chapitres'),
  lesson('la leçon'),
  quiz('le quiz'),
  account('ton compte'),
  streak('ta série'),
  generic('ces informations');

  const ErrorSubject(this.label);

  /// Groupe nominal inséré dans les phrases, déjà déterminé.
  final String label;
}

/// Les causes que l'application **sait réellement distinguer**.
///
/// Cette liste n'invente rien : elle décalque les sous-types de [Failure]
/// produits par `ApiClient._mapDioError` et les caches. Là où la couche basse
/// ne distingue pas (une 4xx inattendue, un `UnknownFailure`), on ne devine pas
/// une cause : on l'assume en disant quand même quoi faire.
enum ErrorKind {
  /// Aucune connexion établie : hors ligne, DNS, pas de route.
  offline,

  /// Délai dépassé avant d'établir la connexion. Cause **ambiguë** : ni le
  /// réseau ni le serveur ne peut être accusé.
  connectSlow,

  /// Connexion établie puis silence du serveur. Le réseau a fait ses preuves —
  /// demander de le vérifier serait une contre-vérité.
  serverSilent,

  /// Le serveur a répondu 5xx.
  serverDown,

  /// Le serveur a répondu 429.
  throttled,

  /// Jeton absent, expiré ou refusé (401/403).
  sessionExpired,

  /// La ressource demandée n'existe pas (404).
  notFound,

  /// Refus métier : une 4xx que le serveur a choisi de renvoyer.
  rejected,

  /// Rien en cache et pas de réseau pour aller chercher.
  noOfflineCopy,

  /// La réponse ne correspond pas au contrat que cette version comprend.
  appOutdated,

  /// Le serveur a répondu, correctement, qu'il n'y a rien à montrer.
  empty,

  /// Tout ce que les couches basses n'ont pas su qualifier.
  unexpected,
}

/// Le texte affichable d'un état d'erreur : une cause, et une action.
@immutable
class ErrorCopy {
  const ErrorCopy({
    required this.kind,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.icon,
  });

  final ErrorKind kind;

  /// Titre court : ce qui s'est passé.
  final String title;

  /// Phrase qui dit **quoi faire**. Jamais vide.
  final String message;

  /// Libellé du bouton. Il nomme son action — « Voir la bibliothèque » n'est
  /// pas « Réessayer ».
  final String actionLabel;

  /// Glyphe du bouton, accordé à [actionLabel]. `PrismStatusView` accepte un
  /// `actionIcon` depuis #488 précisément pour qu'un bouton de navigation ne
  /// porte plus l'icône de rafraîchissement.
  final IconData actionIcon;

  /// Glyphe de l'état lui-même.
  final IconData icon;

  /// Vrai quand refaire la même chose a une chance d'aboutir. Faux quand la
  /// phrase envoie l'apprenant **ailleurs** : réessayer y serait un mensonge,
  /// et l'écran doit alors offrir la sortie que le message nomme.
  bool get retryResolves => switch (kind) {
        ErrorKind.offline ||
        ErrorKind.connectSlow ||
        ErrorKind.serverSilent ||
        ErrorKind.serverDown ||
        ErrorKind.throttled ||
        ErrorKind.sessionExpired ||
        ErrorKind.rejected ||
        ErrorKind.noOfflineCopy ||
        ErrorKind.unexpected =>
          true,
        ErrorKind.notFound || ErrorKind.appOutdated || ErrorKind.empty => false,
      };

  @override
  String toString() => 'ErrorCopy($kind, $title)';
}

/// Classe [error] et rend la phrase à afficher.
///
/// Accepte `Object?` parce que c'est ce que rend `AsyncValue.error` : un
/// [Failure] la plupart du temps, parfois une exception nue. Une exception nue
/// n'est **jamais** rendue telle quelle — elle tombe dans [ErrorKind.unexpected].
ErrorCopy describeFailure(
  Object? error, {
  ErrorSubject subject = ErrorSubject.generic,
}) =>
    copyFor(errorKindOf(error), subject: subject);

/// Détermine la cause à partir du **type** de l'échec, jamais de son texte.
///
/// Nommée `errorKindOf` et non `classifyFailure` : `package:data` exporte déjà
/// un `classifyFailure` (routage de la file de synchronisation), et les deux
/// cohabitent dans `lesson_controller.dart`.
ErrorKind errorKindOf(Object? error) {
  if (error is! Failure) return ErrorKind.unexpected;
  return switch (error) {
    NetworkFailure(:final NetworkFailureKind kind) => switch (kind) {
        NetworkFailureKind.unreachable => ErrorKind.offline,
        NetworkFailureKind.connectTimeout => ErrorKind.connectSlow,
        NetworkFailureKind.responseTimeout => ErrorKind.serverSilent,
      },
    AuthFailure() => ErrorKind.sessionExpired,
    NotFoundFailure() => ErrorKind.notFound,
    CacheFailure() => ErrorKind.noOfflineCopy,
    ParseFailure() => ErrorKind.appOutdated,
    CatalogEmptyFailure() => ErrorKind.empty,
    ServerFailure(:final int? statusCode) => switch (statusCode) {
        429 => ErrorKind.throttled,
        final int s when s >= 500 => ErrorKind.serverDown,
        final int s when s >= 400 => ErrorKind.rejected,
        // Une `ServerFailure` sans code vient d'un transport que Dio n'a pas su
        // typer : on ne prétend pas savoir laquelle des deux moitiés a lâché.
        _ => ErrorKind.unexpected,
      },
    UnknownFailure() => ErrorKind.unexpected,
  };
}

/// Le texte d'une cause, pour un sujet donné.
ErrorCopy copyFor(ErrorKind kind, {ErrorSubject subject = ErrorSubject.generic}) {
  final String what = subject.label;
  return switch (kind) {
    ErrorKind.offline => ErrorCopy(
        kind: kind,
        title: 'Tu es hors ligne',
        message: 'Réactive le Wi-Fi ou les données mobiles, puis réessaie de charger $what.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.cloud_off_rounded,
      ),
    ErrorKind.connectSlow => ErrorCopy(
        kind: kind,
        title: 'La connexion n\u2019a pas abouti',
        // La cause est ambiguë (réseau lent ou serveur injoignable) : la
        // nommer serait inventer. On donne l'action, pas un coupable.
        message: 'Le délai a été dépassé avant d\u2019atteindre le serveur. '
            'Réessaie dans un instant.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.timer_off_rounded,
      ),
    ErrorKind.serverSilent => ErrorCopy(
        kind: kind,
        // La connexion a abouti : envoyer l'utilisateur vérifier son réseau
        // l'enverrait réparer ce qui n'est pas cassé.
        title: 'Le serveur met trop de temps',
        message: 'Ta connexion fonctionne, c\u2019est le serveur qui tarde. '
            'Réessaie dans un instant.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.hourglass_empty_rounded,
      ),
    ErrorKind.serverDown => ErrorCopy(
        kind: kind,
        title: 'Service momentanément indisponible',
        message: 'Le problème vient de nous, pas de toi. Réessaie dans quelques minutes.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.cloud_off_rounded,
      ),
    ErrorKind.throttled => ErrorCopy(
        kind: kind,
        title: 'Trop de tentatives',
        message: 'Patiente quelques minutes avant de réessayer.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.hourglass_bottom_rounded,
      ),
    ErrorKind.sessionExpired => ErrorCopy(
        kind: kind,
        title: 'Session expirée',
        // L'app renouvelle les jetons toute seule : réessayer a une vraie
        // chance d'aboutir. On ne renvoie vers l'écran de connexion qu'en
        // second recours, une fois cette tentative faite.
        message: 'Ta session a expiré. Réessaie pour retrouver $what ; '
            'si ça ne passe pas, reconnecte-toi.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.lock_outline_rounded,
      ),
    ErrorKind.notFound => ErrorCopy(
        kind: kind,
        title: 'Contenu introuvable',
        message: 'Impossible de trouver $what. '
            'Reviens à la bibliothèque pour en choisir un autre.',
        actionLabel: 'Voir la bibliothèque',
        actionIcon: Icons.menu_book_rounded,
        icon: Icons.search_off_rounded,
      ),
    ErrorKind.rejected => ErrorCopy(
        kind: kind,
        title: 'Demande refusée',
        message: 'Le serveur n\u2019a pas accepté cette demande. '
            'Vérifie les informations saisies, puis réessaie.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.block_rounded,
      ),
    ErrorKind.noOfflineCopy => ErrorCopy(
        kind: kind,
        title: 'Rien en mémoire hors ligne',
        message: 'Reconnecte-toi une fois pour télécharger $what et y accéder sans réseau.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.download_for_offline_outlined,
      ),
    ErrorKind.appOutdated => ErrorCopy(
        kind: kind,
        title: 'Mise à jour nécessaire',
        message: 'Cette version de Certigo ne comprend pas la réponse du serveur. '
            'Mets l\u2019app à jour depuis l\u2019App Store.',
        actionLabel: 'Voir la bibliothèque',
        actionIcon: Icons.menu_book_rounded,
        icon: Icons.system_update_alt_rounded,
      ),
    ErrorKind.empty => ErrorCopy(
        kind: kind,
        title: 'Rien à afficher pour l\u2019instant',
        message: 'Aucun contenu n\u2019est encore publié ici. Reviens bientôt.',
        actionLabel: 'Voir la bibliothèque',
        actionIcon: Icons.menu_book_rounded,
        icon: Icons.inbox_rounded,
      ),
    ErrorKind.unexpected => ErrorCopy(
        kind: kind,
        title: 'Impossible de charger $what',
        message: 'Quelque chose a échoué de notre côté. Réessaie ; '
            'si ça continue, reviens dans quelques minutes.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh_rounded,
        icon: Icons.error_outline_rounded,
      ),
  };
}
