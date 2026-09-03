import 'package:core/core.dart';
import 'package:flutter/widgets.dart';

class ReleaseStrings {
  const ReleaseStrings._(this._french);

  factory ReleaseStrings.of(BuildContext context) {
    return ReleaseStrings._(Localizations.localeOf(context).languageCode == 'fr');
  }

  final bool _french;

  String get soon => _french ? 'Bientôt' : 'Coming soon';
  String get unavailable => _french ? 'Indisponible' : 'Unavailable';
  String get privateAlpha => _french ? 'Alpha privée' : 'Private alpha';
  String get privateAlphaLimit => _french ? '5 testeurs max.' : 'Up to 5 testers';
  String get invitationOnly =>
      _french ? 'Accès réservé aux testeurs invités' : 'Access is limited to invited testers';
  String get invitedAccountHint => _french
      ? 'Connecte-toi avec le compte test qui t’a été attribué. '
            'L’inscription publique est fermée.'
      : 'Sign in with the test account assigned to you. Public sign-up is closed.';
  String get backToSignIn => _french ? 'Se connecter' : 'Sign in';
  String get backToApp => _french ? 'Retour à Certigo' : 'Back to Certigo';

  String unavailableSemantics(String label, CapabilityAvailability availability) {
    final String state = availability == CapabilityAvailability.upcoming
        ? (_french ? 'indisponible, bientôt' : 'unavailable, coming soon')
        : (_french ? 'indisponible' : 'unavailable');
    return '$label, $state';
  }

  String unavailableTitle(CapabilityAvailability availability) {
    if (availability == CapabilityAvailability.upcoming) {
      return _french ? 'Bientôt dans Certigo' : 'Coming soon to Certigo';
    }
    return _french ? 'Fonction indisponible' : 'Feature unavailable';
  }

  String unavailableMessage(AppCapability? capability, CapabilityAvailability availability) {
    if (capability == AppCapability.publicRegistration) {
      return invitedAccountHint;
    }
    if (availability == CapabilityAvailability.upcoming) {
      return _french
          ? 'Cette fonction est prévue pour une prochaine mise à jour. '
                'Aucune action n’est requise.'
          : 'This feature is planned for a future update. No action is required.';
    }
    return _french
        ? 'Cette fonction n’est pas activée dans cette version de Certigo.'
        : 'This feature is not enabled in this version of Certigo.';
  }
}
