import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Brouillon d'inscription progressif : accumule les champs saisis au fil des
/// écrans (nom → e-mail → mot de passe) **avant** l'appel réel au backend
/// (`AuthController.registerWithEmail`).
///
/// Volontairement immuable et minimal : aucun secret n'y est persisté (il ne
/// vit qu'en mémoire, le temps du flux), et il est remis à zéro une fois le
/// compte créé pour qu'une nouvelle inscription reparte propre.
class RegisterDraft {
  const RegisterDraft({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.password = '',
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;

  /// Nom affiché transmis au backend : « Prénom Nom » nettoyé (le nom de
  /// famille étant facultatif, on retombe proprement sur le seul prénom).
  String get displayName => '$firstName $lastName'.trim();

  RegisterDraft copyWith({String? firstName, String? lastName, String? email, String? password}) {
    return RegisterDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }
}

/// Source de vérité du brouillon d'inscription, partagée par les écrans du flux.
class RegisterDraftController extends Notifier<RegisterDraft> {
  @override
  RegisterDraft build() => const RegisterDraft();

  void setName({required String firstName, required String lastName}) {
    state = state.copyWith(firstName: firstName.trim(), lastName: lastName.trim());
  }

  void setEmail(String email) => state = state.copyWith(email: email.trim());

  void setPassword(String password) => state = state.copyWith(password: password);

  /// Repart d'un brouillon vierge (après création réussie ou abandon du flux).
  void reset() => state = const RegisterDraft();
}

/// Provider du brouillon d'inscription (feature `auth`).
final registerDraftProvider = NotifierProvider<RegisterDraftController, RegisterDraft>(
  RegisterDraftController.new,
);
