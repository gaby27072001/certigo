import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/credentials_gateway.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ApiClient] qui échoue toujours avec un [NetworkFailure] de cause imposée.
///
/// Évite de dépendre du client HTTP dans ce test : la traduction
/// `DioExceptionType` → [NetworkFailureKind] est couverte côté `packages/data`
/// (`api_client_failure_kind_test.dart`). Ici on vérifie uniquement le maillon
/// suivant — la cause devient-elle le bon message pour l'utilisateur.
class _FailingApiClient extends ApiClient {
  _FailingApiClient(this.failure) : super(tokenProvider: _noToken);

  final NetworkFailure failure;

  static Future<String?> _noToken() async => null;

  @override
  Future<Result<T>> postJson<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) parse, {
    Map<String, dynamic>? headers,
  }) async =>
      Err<T>(failure);
}

Future<AuthGatewayException> loginFailure(NetworkFailure failure) async {
  final HttpCredentialsGateway gateway = HttpCredentialsGateway(
    client: _FailingApiClient(failure),
  );
  try {
    await gateway.login(email: 'qa@certigo.co', password: 'Audit123!');
  } on AuthGatewayException catch (e) {
    return e;
  }
  fail('attendu : un échec de connexion');
}

void main() {
  group('message affiché selon la cause réelle de l\'échec de transport', () {
    test('hors ligne : demander de vérifier le réseau est justifié', () async {
      final AuthGatewayException e = await loginFailure(const NetworkFailure());
      expect(e.message, contains('Vérifiez votre réseau'));
      expect(e.cause, AuthFailureCause.network);
    });

    // Non-régression du défaut mesuré sur un backend en démarrage à froid : la
    // connexion avait abouti, le serveur était simplement lent — et l'app
    // envoyait l'utilisateur réparer un réseau qui fonctionnait.
    test('délai de RÉPONSE : le réseau a fait ses preuves, on ne l\'accuse pas', () async {
      final AuthGatewayException e = await loginFailure(const NetworkFailure.responseTimeout());
      expect(
        e.message,
        isNot(contains('Vérifiez votre réseau')),
        reason: 'la connexion a abouti : accuser le réseau est une contre-vérité',
      );
      expect(e.message, contains('serveur'));
      expect(e.cause, AuthFailureCause.timeout);
    });

    test('délai de CONNEXION : cause ambiguë, aucune des deux n\'est imputée', () async {
      final AuthGatewayException e = await loginFailure(const NetworkFailure.connectTimeout());
      expect(e.cause, AuthFailureCause.timeout);
      expect(e.message, contains('expiré'));
      expect(e.message, isNot(contains('Pas de connexion.')));
    });

    test('les trois messages sont distincts', () async {
      final Set<String> messages = <String>{
        (await loginFailure(const NetworkFailure())).message,
        (await loginFailure(const NetworkFailure.connectTimeout())).message,
        (await loginFailure(const NetworkFailure.responseTimeout())).message,
      };
      expect(messages, hasLength(3));
    });
  });
}
