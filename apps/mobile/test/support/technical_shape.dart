/// Détection de la **forme** d'un détail technique rendu tel quel.
///
/// Une garde qui vérifierait l'absence d'une chaîne précise ne prouverait rien :
/// il suffirait de changer cette chaîne. Ce qu'on attrape ici, ce sont les
/// formes qu'un détail technique prend quand il traverse une couche de
/// présentation sans traduction — un nom de type d'exception, une paire
/// `clé=valeur` de diagnostic, un code de statut HTTP, une trame de pile, un
/// `Instance of '…'`, une URI `package:`.
///
/// Le détecteur est épinglé des deux côtés par
/// `error_message_discipline_test.dart` : [technicalCorpus] doit rester détecté
/// (affaiblir un motif fait rougir), et la copie propre de
/// `ErrorCopy` doit rester non détectée (durcir un motif fait rougir aussi).
library;

/// Les formes recherchées, nommées pour que l'échec soit lisible.
final List<({String name, RegExp pattern})> technicalShapes = <({String name, RegExp pattern})>[
  (
    name: 'nom de type d\u2019exception ou d\u2019erreur',
    pattern: RegExp(r'\b\w*(?:Exception|Error)\b'),
  ),
  (
    name: 'marqueur [technique]',
    pattern: RegExp(r'\[technique\]', caseSensitive: false),
  ),
  (
    name: 'paire clé=valeur de diagnostic',
    pattern: RegExp(
      r'\b(?:code|errno|status|statusCode|msg|details?|domain)\s*=\s*\S',
      caseSensitive: false,
    ),
  ),
  (
    name: 'code de statut HTTP',
    pattern: RegExp(r'\b(?:HTTP|status(?:Code)?)\s*[:=]?\s*[1-5]\d{2}\b', caseSensitive: false),
  ),
  (
    // L'anti-patron nommé par le référentiel : « Alert "Erreur 500" ».
    name: 'numéro d\u2019erreur brut',
    pattern: RegExp(r'\b(?:erreur|error)\s+[1-5]\d{2}\b', caseSensitive: false),
  ),
  (
    name: 'Failure.toString()',
    pattern: RegExp(r'\b\w*Failure\s*\('),
  ),
  (
    name: 'objet Dart opaque',
    pattern: RegExp(r"Instance of '"),
  ),
  (
    name: 'trame de pile',
    pattern: RegExp(r'#\d+\s+\S+\s+\('),
  ),
  (
    name: 'URI de source Dart',
    pattern: RegExp(r'\b(?:package|dart|file):[\w/.]+'),
  ),
  (
    name: 'Duration.toString()',
    pattern: RegExp(r'\b\d+:\d{2}:\d{2}\.\d{6}\b'),
  ),
  (
    name: 'appel de fonction rendu',
    pattern: RegExp(r'\b[a-z]\w*\(\)\s'),
  ),
];

/// Le nom de la première forme technique trouvée dans [text], ou `null` si le
/// texte est propre.
String? technicalShapeIn(String text) {
  for (final ({String name, RegExp pattern}) shape in technicalShapes) {
    final RegExpMatch? match = shape.pattern.firstMatch(text);
    if (match != null) return '${shape.name} → « ${match.group(0)} »';
  }
  return null;
}

/// Chaînes techniques **réelles** que les couches basses fabriquent. Si un
/// motif est affaibli, l'un de ces cas repasse pour propre et la garde rougit.
const List<({String label, String sample})> technicalCorpus = <({String label, String sample})>[
  (
    label: 'SocketException de Dio',
    sample: 'SocketException: Failed host lookup: \'api.certigo.invalid\' '
        '(OS Error: nodename nor servname provided, errno = 8)',
  ),
  (
    label: 'délai de connexion Dio',
    sample: 'DioException [connection timeout]: The request connection took '
        'longer than 0:00:30.000000 and it was aborted.',
  ),
  (
    label: 'PlatformException flutter_appauth',
    sample: 'PlatformException code=authorize_and_exchange_code_failed '
        'msg=Failed to authorize details=Error Domain=org.openid.appauth.general Code=-3',
  ),
  (
    label: 'marqueur de diagnostic concaténé',
    sample: 'Connexion Microsoft échouée.\n[technique] TimeoutException après 90s',
  ),
  (
    label: 'Failure.toString()',
    sample: 'Failure(network, Connexion indisponible)',
  ),
  (
    label: 'objet sans toString()',
    sample: 'Instance of \'_Exception\'',
  ),
  (
    label: 'trame de pile',
    sample: '#0      ApiClient._guard (package:data/src/api/api_client.dart:220:7)',
  ),
  (
    label: 'statut HTTP nu',
    sample: 'La requête a échoué (HTTP 503).',
  ),
  (
    label: 'l\u2019anti-patron du référentiel',
    sample: 'Erreur 500',
  ),
  (
    label: 'trace d\u2019appel interne',
    sample: 'authorize() est revenu sans authorizationCode',
  ),
  (
    label: 'type Dart nu',
    sample: 'MissingPluginException : No implementation found for method authorize',
  ),
];
