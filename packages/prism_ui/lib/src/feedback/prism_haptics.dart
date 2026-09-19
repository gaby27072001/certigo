import 'package:flutter/services.dart';

/// L'intensité haptique qu'un contrôle Prism déclare pour son activation.
///
/// Ce vocabulaire est **volontairement court**. Il n'existe que trois valeurs
/// parce qu'un contrôle n'a que trois choses à dire : *rien* (le cas normal),
/// *tu viens de changer une valeur*, *tu viens d'engager quelque chose*.
///
/// [none] est le défaut de chaque contrôle qui l'expose. Un retour haptique se
/// demande explicitement, au site d'appel, et se justifie là.
enum PrismHaptic { none, selection, light }

/// Le point de passage **unique** de toutes les vibrations de Certigo.
///
/// ## Pourquoi ce fichier existe
///
/// Mesuré avant correction : `prism_button.dart` appelait
/// `HapticFeedback.lightImpact()` sans condition à chaque appui. Comme c'est
/// le bouton de toute l'application, **chaque appui sur chaque bouton
/// vibrait** — y compris « Précédent », « Suivant » ou « Annuler ». Et
/// `hapticsEnabled`, `hapticService`, `enableHaptics` ne figuraient nulle part
/// dans le dépôt : il n'existait aucun moyen de couper cela, ni pour
/// l'utilisateur, ni pour le code.
///
/// Un retour haptique permanent cesse d'être une information. C'est l'un des
/// anti-patterns nommés des HIG : *« éviter tout haptic sur les taps
/// ordinaires ; l'excès transforme la qualité en bruit »*.
///
/// ## Pourquoi une porte statique, et pas un provider
///
/// `prism_ui` ne dépend que de `flutter` — vérifié dans son `pubspec.yaml`, il
/// n'y a ni Riverpod ni aucune dépendance applicative, et c'est une propriété
/// à préserver. Mais la préférence utilisateur vit, elle, dans l'application.
///
/// Il faut aussi que `lesson_feedback.dart` passe par la même porte : c'est une
/// classe de la couche application, **sans `BuildContext`**, donc un
/// `InheritedWidget` ne l'atteindrait pas.
///
/// Une porte statique est la seule forme que les deux côtés peuvent franchir.
/// L'application la pilote depuis sa préférence ; le paquet n'apprend rien de
/// l'application.
///
/// ## L'invariant
///
/// **Aucun `HapticFeedback.*` ne doit être appelé ailleurs qu'ici.** C'est ce
/// qui rend le réglage utilisateur vrai : une seule porte à fermer. Cet
/// invariant est tenu par une garde exécutée en CI,
/// `apps/mobile/test/haptics_discipline_test.dart`.
class PrismHaptics {
  PrismHaptics._();

  /// Vrai tant que l'utilisateur n'a pas coupé les vibrations.
  ///
  /// Le défaut est `true` : l'application vibre pour les moments qui le
  /// méritent tant que personne n'a rien demandé. Ce qui change, ce n'est pas
  /// la valeur par défaut de ce drapeau — c'est le nombre de moments qui le
  /// franchissent.
  static bool enabled = true;

  /// Une valeur discrète vient d'être sélectionnée.
  static void selection() => _fire(HapticFeedback.selectionClick);

  /// Un engagement léger : l'utilisateur vient de valider quelque chose.
  static void light() => _fire(HapticFeedback.lightImpact);

  /// Une réponse juste — le registre intermédiaire.
  static void medium() => _fire(HapticFeedback.mediumImpact);

  /// Une erreur — le registre le plus marqué.
  static void heavy() => _fire(HapticFeedback.heavyImpact);

  /// Joue l'intensité qu'un contrôle a déclarée.
  static void play(PrismHaptic haptic) {
    switch (haptic) {
      case PrismHaptic.none:
        break;
      case PrismHaptic.selection:
        selection();
        break;
      case PrismHaptic.light:
        light();
        break;
    }
  }

  static void _fire(void Function() action) {
    if (!enabled) return;
    try {
      action();
    } catch (_) {
      // Une vibration est un agrément. Un canal de plateforme absent — en test
      // unitaire pur, par exemple — ne doit jamais remonter en erreur de leçon.
      // Cette protection vient de `HapticLessonFeedback._safe`, dont elle
      // reprend le rôle pour tout le dépôt.
    }
  }
}
