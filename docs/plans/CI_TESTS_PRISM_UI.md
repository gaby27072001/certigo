# Élargir la CI de `prism_ui` — une ligne, à jouer file de PR vide

> **Fait volatil, daté et borné.** Mesuré le **2026-09-11** sur `156c3117`.
> **Invalidé** le jour où le job `prism-goldens` de `.github/workflows/ci-mobile.yml`
> exécute `flutter test` sans argument de chemin — c'est-à-dire le jour où ce document
> devient sans objet et doit être supprimé.

## Le geste

Dans `.github/workflows/ci-mobile.yml`, job `prism-goldens`, étape de test
(`working-directory: packages/prism_ui`) :

```diff
-        run: flutter test test/rendering/renderer_golden_test.dart
+        run: flutter test
```

**Une ligne. Aucun autre changement.**

> ⚠️ Le numéro de ligne dérive — il valait `331` au 2026-09-11. **Repérer l'étape par son
> `working-directory: packages/prism_ui`, pas par son numéro.**

## La raison, chiffrée

`packages/prism_ui/test/` contient **34 fichiers `*_test.dart`**. La CI en exécute **un
seul**.

| Mesure (2026-09-11, comptage statique des déclarations `test(` / `testWidgets(`) | Valeur |
|---|---:|
| Fichiers de test dans `packages/prism_ui/test/` | 34 |
| Fichiers exécutés par la CI | **1** |
| Déclarations dans `renderer_golden_test.dart` (exécutées) | **11** |
| Déclarations dans l'arbre `prism_ui` (total) | **≥ 195** |

> **Provenance du chiffre.** `195` est un **plancher** obtenu par comptage statique des
> déclarations, pas un décompte d'exécution : `content_schema_test.dart` génère des cas
> dans une boucle `for (… in _validFixtures.entries)`, donc le nombre réel à l'exécution
> est supérieur. Une revue antérieure avançait `274` ; **je n'ai pas pu le reproduire** et
> je ne le reprends pas. Le rapport qui décide ne dépend pas de l'écart : **la CI exécute
> 1 fichier sur 34.**

## La démonstration — deux régressions, deux gardes, zéro morsure

Le 2026-09-10, en **27 minutes** :

| PR | Titre | Garde écrite | Exécutée par la CI ? |
|---|---|---|---|
| #465 (13:02:05Z) | *réparer la régression de contraste que j'ai introduite en mode sombre* | `test/theme/prism_color_scheme_test.dart` (7), `test/theme/prism_contrast_contract_test.dart` (9) | **non** |
| #466 (13:29:42Z) | *rendre son rôle d'aplat au CTA et aux marques, **cassé par #465*** | `test/theme/prism_fill_role_guard_test.dart` (2) | **non** |

**#466 répare ce que #465 a cassé vingt-sept minutes plus tôt — et #465 était elle-même
une réparation de régression.** Les deux auteurs ont fait exactement ce qu'il fallait :
ils ont écrit la garde. **Les 18 tests de garde produits dans cette fenêtre sont dans les
33 fichiers que la CI ne lance pas.**

Le cliquet est écrit, commité, vert en local — et **muet en CI**. C'est un instrument vide
au sens de `docs/GOVERNANCE.md` : il ne rend pas faux, il ne rend rien.

## La condition d'exécution — pourquoi pas aujourd'hui

**Attendre une file de PR vide.**

`.github/scripts/account-deletion-cosmos-policy.test.mjs` compare chaque workflow au
manifeste **de la base de la PR**. Modifier un fichier de `.github/workflows/` ouvre donc
une fenêtre pendant laquelle **toute PR ouverte échoue** sur un contrôle étranger à son
contenu, jusqu'à rebase. Au 2026-09-11 il y a une dizaine de PR en vol : le coût dépasse
le gain.

Rappel de plomberie pour l'exécutant :

- le workflow **et** `workflow-semantic-manifest.json` **et** `manifestGoldenDigest`
  doivent changer **dans un seul commit** ; fractionner casse la CI de tout le monde ;
- `ci-mobile.yml` **n'est pas scellé à l'octet** — vérifié le 2026-09-11 : il ne contient
  ni `secrets.`, ni `environment:`, ni permission d'écriture, donc il n'est pas
  « privilégié » au sens de `.github/scripts/backend-deploy-workflow-policy.mjs`. La
  contrainte ci-dessus est la seule qui s'applique.

## Le risque si on l'oublie

**Chaque garde écrite dans `prism_ui` hors `renderer_golden_test.dart` est aujourd'hui
décorative.** Le dépôt continuera de produire des régressions réparées par des PR qui
écrivent des gardes qui ne mordront pas — le motif est déjà mesuré deux fois le même jour,
par deux auteurs, sans concertation.

**Et le premier `flutter test` complet en CI sera peut-être rouge.** Ces 33 fichiers n'ont
jamais tourné sur un runner. C'est le résultat attendu et c'est l'intérêt du geste : il
révèle ce que personne ne surveille. **Prévoir de traiter les échecs, pas de reculer
devant eux** — reculer reviendrait à choisir de ne pas savoir.

## Geste voisin, même fichier, à faire dans la même fenêtre

Le job de `ci-mobile.yml` nommé **« Flutter app + UI packages »** ne teste **aucun package
UI** : toutes ses étapes portent `working-directory: apps/mobile`. Les packages sont
couverts ailleurs (`core`/`cortex`/`data` dans le job `packages`, `prism_ui` dans
`prism-goldens`).

Renommer en **« Flutter app »**.

C'est le motif décrit par `docs/GOVERNANCE.md`, section « Le nom qui contredit l'état » :
le nom porte une portée que l'objet n'a pas, et le lecteur lit le nom. La règle d'écriture
de cette section s'applique directement.
