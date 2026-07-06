/// Validation e-mail/mot de passe **partagée** par le flux d'inscription
/// progressif, reprenant la logique déjà utilisée par `SignInScreen` :
/// - e-mail : un `@` unique, un point après le `@`, et pas de point final ;
/// - mot de passe : au moins 8 caractères.
///
/// Fonctions pures (Dart, sans dépendance Flutter) afin d'être réutilisables et
/// testables unitairement.
library;

/// Vrai si [value] ressemble à une adresse e-mail valide (même règle simple que
/// `SignInScreen._validateEmail`).
bool isValidEmail(String? value) {
  final String email = (value ?? '').trim();
  final int at = email.indexOf('@');
  return at > 0 &&
      at == email.lastIndexOf('@') &&
      email.indexOf('.', at) > at &&
      !email.endsWith('.');
}

/// Vrai si [value] contient au moins 8 caractères (règle de `SignInScreen`).
bool isValidPassword(String? value) => (value ?? '').length >= 8;

/// Fautes de frappe fréquentes sur le domaine, mappées vers leur correction.
const Map<String, String> _commonDomainTypos = <String, String>{
  'gmial.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gnail.com': 'gmail.com',
  'hotmial.com': 'hotmail.com',
  'hotmai.com': 'hotmail.com',
  'hotmal.com': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outook.com': 'outlook.com',
  'yaho.com': 'yahoo.com',
  'yahou.com': 'yahoo.com',
  'iclould.com': 'icloud.com',
  'iclou.com': 'icloud.com',
};

/// Propose une correction d'e-mail quand le domaine ressemble à une faute de
/// frappe connue (ex. `jean@gmial.com` → `jean@gmail.com`), sinon `null`.
///
/// Purement indicatif : l'utilisateur reste libre de conserver sa saisie.
String? suggestEmailCorrection(String? value) {
  final String email = (value ?? '').trim().toLowerCase();
  final int at = email.indexOf('@');
  if (at <= 0 || at != email.lastIndexOf('@')) return null;
  final String local = email.substring(0, at);
  final String domain = email.substring(at + 1);
  final String? fixed = _commonDomainTypos[domain];
  if (fixed == null || fixed == domain) return null;
  return '$local@$fixed';
}
