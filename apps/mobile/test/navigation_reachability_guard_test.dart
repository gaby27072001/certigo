import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde structurelle : **aucune destination de premier niveau ne redevient
/// orpheline**.
///
/// Pourquoi ce test existe — la régression qu'il ferme :
///
/// Ce dépôt construit des mécanismes complets et oublie de les brancher
/// (`docs/GOVERNANCE.md` §7). Une destination déclarée dans `router.dart` mais
/// qu'aucun écran ne nomme reste **joignable par URL et invisible dans
/// l'application** : elle compile, ses tests d'écran passent, sa route répond —
/// et personne ne peut l'atteindre. Rien, aujourd'hui, ne rougit dans ce cas.
///
/// Ce fichier lit la source et refuse deux situations distinctes :
///
///  1. une constante de [Routes] qu'aucune rubrique ci-dessous ne classe —
///     ajouter une route **force** donc à déclarer si elle est une destination ;
///  2. une destination classée que plus aucun écran atteignable ne nomme.
///
/// **Relation de joignabilité.** On part des cinq écrans d'onglet (joignables
/// par construction : la barre les porte), on suit les widgets **réellement
/// construits** de proche en proche, et on relève tout `Routes.X` rencontré.
///
/// Trois choix rendent l'instrument discriminant plutôt que vide :
///
///  - **la fermeture est à la classe, pas au fichier.** Cesser de construire
///    `_ExploreSection()` la sort de la fermeture même si son code reste dans
///    `home_screen.dart` — c'est la forme exacte du défaut visé : du code
///    vivant que plus personne n'appelle.
///  - **`app/router.dart` n'est jamais traversé.** C'est la table des routes :
///    elle nomme forcément toutes les destinations, et tout écran l'importe.
///    La traverser rendrait ce test vert quoi qu'il arrive — un instrument muet
///    au sens du §7.
///  - **toute mention de `Routes.X` dans une classe joignable compte comme un
///    câblage**, pas seulement `context.push(Routes.X)` : la grille « Explorer »
///    navigue indirectement (`route: Routes.shop` rangé dans un champ, puis
///    `context.push(item.route)`). Exiger la forme directe raterait six
///    destinations sur sept et crierait « orphelin » sans avoir rien lu.
///
/// Le test « témoin négatif » est le contrôle exigé par le §7c : il rejoue le
/// calcul sur une copie mutée d'où le câblage a été retiré, et échoue si le
/// verdict ne change pas.
void main() {
  final _RouteTable table = _RouteTable.read();
  final Map<String, String> sources = _readLibSources();

  // --- Classement des constantes de `Routes` -----------------------------
  //
  // Toute constante doit tomber dans exactement une rubrique. Une route
  // nouvelle n'appartient à aucune, et casse le test tant que quelqu'un n'a pas
  // tranché : destination à câbler, ou sous-flux justifié.

  /// Les cinq onglets. Joignables par construction — la barre les porte.
  const Set<String> shellTabs = <String>{'home', 'path', 'library', 'leaderboard', 'profile'};

  /// Destinations de premier niveau présentées au-dessus de la coquille.
  /// **C'est la liste que ce fichier protège.**
  const Set<String> aboveShellDestinations = <String>{
    'achievements',
    'seasons',
    'quests',
    'shop',
    'friends',
    'exam',
    'dailyShare',
  };

  /// Surfaces d'avant-authentification : ce ne sont pas des destinations de
  /// l'application lancée, le garde d'auth y mène ou en sort tout seul.
  const Set<String> preAuth = <String>{'splash', 'landing', 'auth'};

  /// Sous-flux paramétrés d'un parcours (`/lesson/:trackId/:lessonId`). On y
  /// entre avec une leçon en main, jamais « depuis le menu ».
  const Set<String> parameterisedFlows = <String>{'lesson', 'quiz'};

  /// Flux de compte : `accountDeletion` s'ouvre depuis Profil › Mon compte et
  /// n'existe que sous `AppEnv.accountDeletionEnabled` ; `accountDeleted` est
  /// l'écran terminal, atteint après la suppression et hors session.
  const Set<String> accountFlows = <String>{'accountDeletion', 'accountDeleted'};

  /// Portail entreprise : paramétré (`/enterprise/:organizationId`) et derrière
  /// `AppEnv.managerPortalEnabled`. Son entrée vit dans le sélecteur d'espace
  /// de travail de la coquille, pas dans la navigation d'apprentissage.
  const Set<String> featureFlagged = <String>{'manager'};

  final Set<String> classified = <String>{
    ...shellTabs,
    ...aboveShellDestinations,
    ...preAuth,
    ...parameterisedFlows,
    ...accountFlows,
    ...featureFlagged,
  };

  // --- Plancher de lecture (§7b) -----------------------------------------
  //
  // Un instrument qui n'a rien lu doit échouer, pas rendre zéro. Ces bornes
  // sont des minorants : elles ne dérivent pas quand le projet grossit.

  test('l\'instrument a réellement lu le routeur et l\'arbre d\'écrans', () {
    expect(
      table.constants.length,
      greaterThanOrEqualTo(12),
      reason: 'Moins de 12 constantes lues dans `abstract class Routes` : le parseur n\'a '
          'rien trouvé. Un verdict rendu sur cette base ne mesure rien.',
    );
    expect(
      sources.length,
      greaterThanOrEqualTo(50),
      reason: 'Moins de 50 fichiers Dart lus sous `lib/` : la lecture a échoué.',
    );
    expect(
      table.shellTabRoutes.length,
      5,
      reason: 'Le routeur doit déclarer exactement 5 branches d\'onglet. '
          'Lues : ${table.shellTabRoutes}',
    );
    expect(
      table.rootScreenClasses.length,
      5,
      reason: 'Chaque onglet doit résoudre vers une classe d\'écran. '
          'Résolues : ${table.rootScreenClasses}',
    );
  });

  test('les onglets déclarés dans le routeur sont bien les cinq attendus', () {
    expect(table.shellTabRoutes.toSet(), shellTabs);
  });

  test('toute constante de Routes est classée — une route neuve force un choix', () {
    final Set<String> unclassified = table.constants.keys.toSet().difference(classified);
    expect(
      unclassified,
      isEmpty,
      reason: 'Ces routes ne sont dans aucune rubrique de ce fichier :\n'
          '${unclassified.map((String r) => '  - Routes.$r').join('\n')}\n\n'
          'Ce n\'est pas un détail de test : une route que personne n\'a classée est '
          'exactement la forme qu\'ont prise les destinations orphelines. Ajoute-la à '
          '`aboveShellDestinations` (et câble-la depuis un écran), ou à la rubrique de '
          'sous-flux qui la décrit, avec la raison.',
    );
  });

  test('aucune rubrique ne classe une route qui n\'existe plus', () {
    final Set<String> ghosts = classified.difference(table.constants.keys.toSet());
    expect(
      ghosts,
      isEmpty,
      reason: 'Ces noms sont classés ici mais absents de `Routes` : $ghosts. '
          'Le classement doit suivre le routeur, pas le précéder.',
    );
  });

  // --- Le cœur : joignabilité --------------------------------------------

  test('les 12 destinations de premier niveau sont joignables', () {
    final Set<String> wired = _wiredRoutes(sources, table.rootScreenClasses);

    final Set<String> orphans = aboveShellDestinations.difference(wired);
    expect(
      orphans,
      isEmpty,
      reason: 'Ces destinations ne sont nommées par aucun écran joignable depuis les '
          'cinq onglets :\n'
          '${orphans.map((String r) => '  - Routes.$r (${table.constants[r]})').join('\n')}\n\n'
          'Elles restent joignables par URL et invisibles dans l\'application. '
          'Rends-les atteignables depuis un écran de la coquille.',
    );

    // Contrôle de présence : l'ensemble mesuré doit contenir les 7, sinon le
    // « isEmpty » ci-dessus pourrait être vrai faute d'avoir rien lu.
    expect(
      wired.intersection(aboveShellDestinations).length,
      aboveShellDestinations.length,
      reason: 'Câblages relevés : ${wired.intersection(aboveShellDestinations)}',
    );
  });

  // --- Témoin négatif (§7c) : l'instrument sait rendre une absence --------

  test('témoin négatif — retirer un câblage rend bien la destination orpheline', () {
    // Même calcul, sur une copie où toute mention de `Routes.achievements` a
    // disparu des écrans. Si le verdict ne bouge pas, ce fichier ne mesure rien
    // et les tests ci-dessus sont décoratifs.
    const String victim = 'achievements';
    final Map<String, String> mutated = sources.map(
      (String path, String src) =>
          MapEntry<String, String>(path, src.replaceAll('Routes.$victim', 'Routes.home')),
    );

    final Set<String> wired = _wiredRoutes(mutated, table.rootScreenClasses);

    expect(
      wired.contains(victim),
      isFalse,
      reason: 'Le câblage de `Routes.$victim` a été retiré de la copie et l\'instrument '
          'la dit toujours joignable : il ne discrimine rien.',
    );
    // …et il continue de voir les autres : l'absence est ciblée, pas globale.
    expect(
      wired.containsAll(aboveShellDestinations.difference(<String>{victim})),
      isTrue,
      reason: 'La mutation a éteint plus que sa cible : l\'instrument est cassé, '
          'pas discriminant. Relevé : $wired',
    );
  });
}

/// Ensemble des routes nommées par une classe joignable depuis [rootClasses].
///
/// La fermeture est **à la classe**, pas au fichier : on part des écrans
/// d'onglet et on suit les widgets réellement construits (`_ExploreSection()`,
/// `AccountSection(...)`, `createState()`…). Une classe qu'on cesse de
/// construire sort de la fermeture même si son code reste dans le fichier —
/// c'est précisément la forme qu'a prise le défaut ici : du code vivant, plus
/// personne pour l'appeler.
///
/// `app/router.dart` n'est jamais traversé (voir l'en-tête) : c'est la table
/// des routes, elle nomme toutes les destinations et tout écran l'importe.
Set<String> _wiredRoutes(Map<String, String> sources, List<String> rootClasses) {
  final RegExp routeUse = RegExp(r'\bRoutes\.(\w+)');
  // Construction de widget : `Foo(`, `_Foo(`. Les noms du SDK (`Text`, `Row`)
  // ne sont pas dans l'index et sont ignorés sans bruit.
  final RegExp construction = RegExp(r'\b(_?[A-Z]\w*)\s*\(');

  final _ClassIndex index = _ClassIndex.from(sources);
  final Set<String> found = <String>{};
  final Set<String> seen = <String>{};
  final List<_ClassRef> queue = <_ClassRef>[
    for (final String name in rootClasses)
      if (index.resolve(name, null) != null) index.resolve(name, null)!,
  ];

  while (queue.isNotEmpty) {
    final _ClassRef ref = queue.removeLast();
    if (!seen.add('${ref.file}::${ref.name}')) continue;
    if (ref.file == _routerPath) continue;

    for (final RegExpMatch m in routeUse.allMatches(ref.body)) {
      found.add(m.group(1)!);
    }
    for (final RegExpMatch m in construction.allMatches(ref.body)) {
      final _ClassRef? target = index.resolve(m.group(1)!, ref.file);
      if (target != null) queue.add(target);
    }
  }
  return found;
}

/// Une classe déclarée quelque part sous `lib/`.
class _ClassRef {
  const _ClassRef(this.name, this.file, this.body);
  final String name;
  final String file;
  final String body;
}

/// Index des classes de `lib/`, avec la portée des noms privés.
///
/// Un nom privé (`_ExploreCard`) est **local à son fichier** — et plusieurs
/// fichiers déclarent le même (`_Tab`, `_NavItem`, `_Stat`). Le résoudre
/// globalement ferait sauter la fermeture d'un fichier à l'autre et rendrait ce
/// test faussement vert.
class _ClassIndex {
  _ClassIndex(this._byFile, this._public);

  final Map<String, Map<String, _ClassRef>> _byFile;
  final Map<String, _ClassRef> _public;

  int get length => _byFile.values.fold(0, (int n, Map<String, _ClassRef> m) => n + m.length);

  static _ClassIndex from(Map<String, String> sources) {
    final RegExp decl = RegExp(r'^(?:abstract\s+)?class\s+(\w+)', multiLine: true);
    final Map<String, Map<String, _ClassRef>> byFile = <String, Map<String, _ClassRef>>{};
    final Map<String, _ClassRef> public = <String, _ClassRef>{};

    for (final MapEntry<String, String> entry in sources.entries) {
      for (final RegExpMatch m in decl.allMatches(entry.value)) {
        final String name = m.group(1)!;
        final String body = _braceBlockAt(entry.value, m.end);
        final _ClassRef ref = _ClassRef(name, entry.key, body);
        byFile.putIfAbsent(entry.key, () => <String, _ClassRef>{})[name] = ref;
        if (!name.startsWith('_')) public.putIfAbsent(name, () => ref);
      }
    }
    return _ClassIndex(byFile, public);
  }

  /// Résout [name] vu depuis [fromFile] (`null` = portée globale).
  _ClassRef? resolve(String name, String? fromFile) {
    if (name.startsWith('_')) {
      return fromFile == null ? null : _byFile[fromFile]?[name];
    }
    return (fromFile == null ? null : _byFile[fromFile]?[name]) ?? _public[name];
  }
}

/// Corps `{ … }` qui suit [from], accolades comprises.
String _braceBlockAt(String source, int from) {
  final int open = source.indexOf('{', from);
  if (open < 0) return '';
  int depth = 0;
  for (int i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return '';
}

String _normalise(String path) => path.replaceAll('\\', '/').replaceFirst(RegExp('^/'), '');

const String _libRoot = 'lib';
const String _routerPath = 'lib/app/router.dart';

Map<String, String> _readLibSources() {
  final Map<String, String> out = <String, String>{};
  for (final FileSystemEntity e in Directory(_libRoot).listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    out[_normalise(e.path)] = e.readAsStringSync();
  }
  return out;
}

/// Lecture de `router.dart` : constantes de [Routes], branches d'onglet, et
/// fichier d'écran de chaque onglet.
class _RouteTable {
  _RouteTable({
    required this.constants,
    required this.shellTabRoutes,
    required this.rootScreenClasses,
  });

  /// Nom de constante → chemin (`achievements` → `/achievements`).
  final Map<String, String> constants;

  /// Noms de constantes déclarées dans une `StatefulShellBranch`.
  final List<String> shellTabRoutes;

  /// Classes d'écran des onglets, point de départ de la joignabilité.
  final List<String> rootScreenClasses;

  static _RouteTable read() {
    final String router = File(_routerPath).readAsStringSync();

    final String body = _blockAfter(router, 'abstract class Routes {', open: '{', close: '}');
    final Map<String, String> constants = <String, String>{
      for (final RegExpMatch m in RegExp(
        r"static const String (\w+)\s*=\s*'([^']+)'",
      ).allMatches(body))
        m.group(1)!: m.group(2)!,
    };

    final String shell = _blockAfter(
      router,
      'StatefulShellRoute.indexedStack(',
      open: '(',
      close: ')',
    );

    final List<String> tabs = <String>[];
    final List<String> screens = <String>[];

    for (final RegExpMatch branch in RegExp(r'StatefulShellBranch\(').allMatches(shell)) {
      final String block = _blockAfter(
        shell.substring(branch.start),
        'StatefulShellBranch(',
        open: '(',
        close: ')',
      );
      final RegExpMatch? route = RegExp(r'path:\s*Routes\.(\w+)').firstMatch(block);
      final RegExpMatch? widget = RegExp(r'=>\s*const\s+(\w+)\(').firstMatch(block);
      if (route == null || widget == null) continue;
      tabs.add(route.group(1)!);

      String screen = widget.group(1)!;
      // Un onglet dont l'écran vit dans `router.dart` (cas d'`ActivePathScreen`,
      // simple aiguilleur vers l'écran réel) : on repart de l'écran qu'il
      // construit, sinon la branche ne contribuerait rien — `router.dart`
      // n'étant jamais traversé.
      if (RegExp('^class $screen\\b', multiLine: true).hasMatch(router)) {
        final String cls = _blockAfter(router, 'class $screen extends', open: '{', close: '}');
        final RegExpMatch? inner = RegExp(r'\b(\w+Screen)\(').firstMatch(cls);
        if (inner != null) screen = inner.group(1)!;
      }
      screens.add(screen);
    }

    return _RouteTable(constants: constants, shellTabRoutes: tabs, rootScreenClasses: screens);
  }

  /// Texte du bloc délimité qui suit [marker], délimiteurs compris.
  static String _blockAfter(
    String source,
    String marker, {
    required String open,
    required String close,
  }) {
    final int start = source.indexOf(marker);
    if (start < 0) return '';
    int i = source.indexOf(open, start);
    if (i < 0) return '';
    int depth = 0;
    for (int j = i; j < source.length; j++) {
      if (source[j] == open) depth++;
      if (source[j] == close) {
        depth--;
        if (depth == 0) return source.substring(i, j + 1);
      }
    }
    return '';
  }
}
