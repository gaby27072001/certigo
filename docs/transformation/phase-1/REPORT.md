# Phase 1 — Prism foundations — Rapport

## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED

**COMPLETE pour les fondations et la validation portable approuvée par coordination.**
Prism, les flags, le contrat analytics, les garde-fous, le moteur de snapshot et D-1 sont livrés.
Le découpage conserve les corps hérités ; aucune migration d'écran de production n'est effectuée.
Ce statut ne signifie ni compilation iOS exécutée, ni validation visuelle/VoiceOver/Instruments.
Le checkpoint Git est matérialisé par la PR de cette branche et son tag après fusion.

## 2. Livré (liens vers fichiers, captures)

- [Package.swift](../../../apps/apple/CertigoKit/Package.swift) : produit `Prism`,
  cible iOS 26, macOS 14 et compatibilité Linux conservées, aucune dépendance ajoutée.
- [Prism](../../../apps/apple/CertigoKit/Sources/Prism) : espacement, rayon, dimensions,
  couleurs, régions/soft, syntaxe, typographie, mouvement, haptiques, sons, matériaux,
  niveaux de célébration ; adaptation SwiftUI/UIKit conditionnelle.
- [Catalogue](../../../apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets) :
  30 couleurs à quatre variantes. Régénération :
  `python tools/generate_prism_assets.py`. Les neutres système utilisent les rôles UIKit ;
  les valeurs portables servent de références déterministes, non de mesure des pixels iOS.
- [FeatureFlags.swift](../../../apps/apple/CertigoKit/Sources/CertigoDomain/FeatureFlags.swift) :
  valeurs compilées, surcharges persistées exclusivement Debug, kill switches JSON atomiques.
- [AnalyticsClient.swift](../../../apps/apple/CertigoKit/Sources/CertigoDomain/AnalyticsClient.swift) :
  contrat interne typé sans SDK, collecte ni transport ajouté.
- [Sources natives](../../../apps/apple/CertigoNative/Sources) : 12 fichiers issus du
  monolithe, enregistrés dans les quatre surfaces du projet Xcode.
  [Fixture de caractérisation](../../../tools/tests/fixtures/native_extraction.json) dérivée
  du blob `778f9c24`, jamais recalculée à partir des nouvelles vues pour masquer un écart.
- [ArchitectureTests](../../../apps/apple/CertigoKit/Tests/ArchitectureTests) :
  diagnostics `fichier:ligne`, contrôle du domaine et baseline fermée des fichiers hérités.
  Prism est également audité ; seule sa définition arithmétique de palette est autorisée
  pour la règle de couleur. Aucun dossier Prism n'est exempté globalement.
- [PrismSnapshotHarness](../../../apps/apple/CertigoKit/Sources/Prism/PrismSnapshotHarness.swift) :
  `ImageRenderer`, pixels RGBA8 prémultipliés sRGB, comparaison sans métadonnées PNG,
  dimensions et débordements contrôlés ; empreinte FNV-1a diagnostique, non cryptographique.
- [D-1](../../../apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift) :
  lanceur, galerie des familles de tokens, surcharges et éditeur des kill switches,
  entièrement sous `#if DEBUG`. Aucun actif `BrandAssets` livré avant 2B.

**Flags et contrat de configuration.** Tous les nouveaux parcours sont désactivés par défaut :
`prism.enabled`, `brand.icons.v1`, `nav.v2`, `today.v2`, `session.v2`, `feedback.v2`,
`daily.situation`, `atlas.v1`, `readiness.v2`, `rhythm.v1`, `celebrations.v1`, `missions.v1`,
`events.v1`, `social.v2`, `ai.contextual`, `onboarding.v2`, `pro.v1`, `widgets.v1`.
`rhythm.dailyStreakOptIn` reste **true**, sans modification de l'icône Série en danger.
Les huit fournisseurs ont une valeur compilée true mais dépendent du flag global des icônes :
microsoft, github, aws, google, cncf, cisco, python, linux.
`developer.demo` vaut true pour documenter la gouvernance différée de DR-009 ; il n'est pas
branché à `NativeProductionEntry` en Phase 1.

Le JSON est un objet plat, par exemple `{"nav.v2":false,"rhythm.dailyStreakOptIn":false}`.
Priorité : kill distant false, dépendance globale des icônes, surcharge Debug, défaut compilé.
Un true distant ne peut pas activer une expérience ; un nouvel objet remplace l'ensemble
des kills précédents ; `{}` les retire. Un JSON invalide lève une erreur sans changer l'état.
Les clés inconnues sont ignorées pour compatibilité ascendante.
Ni endpoint, ni téléchargement automatique, ni authenticité du transport ne sont inventés :
le futur adaptateur de configuration devra fournir des données approuvées au resolver.

## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)

Preuves exécutées le **22 octobre 2026**, Windows ARM64 / WSL Ubuntu, Swift 6.2.3.
Leur validité est bornée aux sources de cette PR ; toute modification de ces sources,
des tests, du SDK ou des réglages de compilation invalide la preuve correspondante.
Les sorties détaillées sont conservées dans le dossier `files` de la session
`ce959992-4368-4407-9968-3546724637fc` ; les résultats utiles sont transcrits ci-dessous.

| Porte | Résultat et portée exacte |
|---|---|
| BUILD | **Portable vérifié** : Debug via `swift test`, Release via `swift build -c release`, tous deux avec `-Xswiftc -warnings-as-errors`. Release : `Build complete! (45.47s)`. Aucun warning Swift ; avertissement GNU ld RWX du runtime XCTest déjà présent en Phase 0. Compilation SwiftUI/UIKit/MSAL, catalogue Apple et application iOS : **non exécutés**. |
| TEST | **Vérifié** : 187 XCTest + 9 Swift Testing, zéro échec ; harnais NativeModel réussi ; NativeDemoFlow : 3 304 PASS, zéro échec. Python : 249 tests, 235 réussis, 14 ignorés, zéro échec en 601,905 s. Les deux suites Python dépendant de Swift sont aussi exécutées sous WSL : 38 + 6 tests, zéro ignoré. Node public-pages : 38 tests, 27 réussis, 11 ignorés POSIX sous Windows, zéro échec. Référence projet régénérée après le commit source `1f7512bf`, puis `Project state is current.`. |
| VISUAL | **Substitut portable approuvé** : 12 empreintes de caractérisation préservent le contenu extrait ; pixels/dimensions déterministes et empreinte attendue `a5aac2e9e121144e`. Tests Apple de rendu/aller-retour PNG ajoutés (4 apparences × 3 tailles de texte × 3 langues), mais **non exécutés** ici. Pas de captures iOS nouvelles ni de revue de pixels d'écrans revendiquée. |
| A11Y | **Substitut portable approuvé** : seuils WCAG texte ≥4,5, non textuel ≥3, syntaxe HC ≥7 ; paires de galerie comprenant les fonds région soft et lignes signalées. Reduce Motion, repli opaque et mode calme testés. Audit statique/architecture vert. `performAccessibilityAudit()` et parcours VoiceOver **non exécutés**. |
| PERF | **Contrôle statique uniquement** : aucun écran de production migré, aucune minuterie, collecte réseau ou animation permanente ajoutée ; capture plafonnée à 8192 points par dimension. Les durées de tests ne sont pas des métriques de l'application. Lancement, hitches, mémoire et taille iOS **non mesurés**. |
| REPORT | Ce rapport suit le gabarit §39, documente les arbitrages, les valeurs des flags, les commandes et les limites des preuves. |
| CHECKPOINT | Base Phase 0 fusionnée `2db0e3e61f6000438ff13b2cee43a40cad0eed28`, branche `gaby27072001-phase-1-prism-foundations`. La PR fusionnée et `transform-phase-1-done` constituent la preuve Git finale ; ne pas interpréter la rédaction pré-fusion du rapport comme une fusion déjà exécutée. Retour arrière de sources testé en index isolé (§9). |

Le contournement des validations Apple n'est pas une preuve de leur réussite :
la coordination a explicitement autorisé les substituts portables pour cette phase
sans changement de production. La validation propriétaire reste distincte.
Les messages d'erreur de publications de contenu dans le journal Python proviennent
des fixtures négatives du validateur ; le résultat final de la suite est `OK`.

Commandes portables (depuis la racine ; chemins POSIX dans WSL) :

```bash
export PATH=/opt/certigo-swift-2a7c23af/swift-6.2.3-RELEASE-ubuntu24.04-aarch64/usr/bin:/usr/local/bin:/usr/bin:/bin
export LD_LIBRARY_PATH=/opt/certigo-swift-2a7c23af/runtime/usr/lib/aarch64-linux-gnu
swift test --package-path apps/apple/CertigoKit \
  --scratch-path /tmp/certigo-prism-ce959992 -Xswiftc -warnings-as-errors
swift build -c release --package-path apps/apple/CertigoKit \
  --scratch-path /tmp/certigo-prism-ce959992 -Xswiftc -warnings-as-errors
bash tools/test_apple_model.sh
bash tools/test_apple_demo.sh /tmp/certigo-prism-ce959992
python3 -m unittest discover -s tools/tests -p test_native_prism_presentation.py
python3 -m unittest discover -s tools/tests -p test_prism_foundations.py
```

```powershell
python -m unittest discover -s tools\tests
node --test tools\tests\build_public_pages.test.mjs
# Après commit des sources observables :
python tools\project_state.py --refresh-reference
python tools\project_state.py --check
git diff --check
```

**Validation Apple à exécuter dans le checkout permanent, sans recréation :**

```bash
cd /Users/gabrielchambaud/Developer/Certigo-final-validation.miqgke/source
git status --short
# Préserver toute modification avant de continuer. Xcode 26+ et runtime iOS 26+ requis.
xcrun simctl list devices available
export CERTIGO_SIMULATOR_ID='<UUID existant iOS 26+>'
export CERTIGO_APPLE_LOG_ROOT="$HOME/Library/Logs/Certigo"
bash tools/validate_apple_mac_one_shot.sh
```

Ce script refuse un checkout modifié, conserve les journaux/xcresult hors du dépôt,
met à jour `main` en fast-forward, exécute SwiftPM, le build Debug simulateur et
les tests iOS de protection. **Son code 3 signale l'absence de couverture UI configurée** :
ne pas le présenter comme un passage de tests UI.
Pour Release, reprendre le même projet après cette vérification :

```bash
run=$(mktemp -d "$CERTIGO_APPLE_LOG_ROOT/prism-release.XXXXXX")
xcodebuild build \
  -project apps/apple/CertigoNative/CertigoNative.xcodeproj \
  -scheme CertigoNative -configuration Release \
  -destination "platform=iOS Simulator,id=$CERTIGO_SIMULATOR_ID" \
  -derivedDataPath "$run/DerivedData" \
  -resultBundlePath "$run/Release.xcresult" CODE_SIGNING_ALLOWED=NO
```

SwiftPM exécuté sur l'hôte macOS ne lance pas les tests `canImport(UIKit)` :
exécuter `PrismTests.nativeRendererRoundTripsPNGInEveryAppearance` sur une destination
iOS du package dans Xcode, puis conserver son résultat réel.
Les captures clair/sombre/AX3 fr/en, VoiceOver, audit XCTest et Instruments nécessitent
une exécution distincte ; le script ne les simule pas.

## 4. Critères d'acceptation Given/When/Then — résultat

| Given / When / Then | Résultat observé |
|---|---|
| Blob baseline figé / extraction en 12 fichiers / mêmes tokens Swift hors visibilité explicitement autorisée et lanceur Debug | Test de caractérisation vert ; entrée réduite de 8 565 à 108 lignes. |
| Projet Xcode / nouveaux fichiers et Prism / références, groupes, build files et phase sources cohérents | Contrats Python verts, graphe OpenStep vérifié ; pas de `plutil` Apple revendiqué. |
| Palette à quatre apparences / calcul de luminance et composition / seuils §21 respectés | Test WCAG vert, y compris blanc sur `#5B52F0` et syntaxe HC sur les deux fonds. |
| Flags compilés / tentative d'activation distante ou JSON invalide / non-activation et atomicité | Tests Swift verts. |
| Flag fournisseur / global désactivé ou kill distant / fournisseur désactivé même avec surcharge Debug | Tests Swift verts. |
| Build sans DEBUG / appel de l'API de surcharge / rejet du compilateur | Test Python exécuté avec `swiftc` sous WSL, API absente en Release. |
| Sources héritées / audit avec baseline / aucune dette supplémentaire et exceptions résolues à retirer | ArchitectureTests verts ; diagnostics testés sur chaque famille interdite. |
| Même RGBA / empreinte et comparaison / identité stable, dimensions/pixels différents détectés | Test portable vert ; ce n'est pas une preuve ImageRenderer. |
| Parcours de démo et modèle / harnais existants après extraction / comportement portable conservé | NativeModel et 3 304 contrôles Demo réussis. |
| Flutter gelé / diff de Phase 1 / aucun changement | `git diff -- apps/mobile packages/prism_ui` vide. |

## 5. Écarts vs spécification (et justification) / dettes créées

- DR-009 originel demandait de masquer les entrées Démo/Connecteur immédiatement.
  L'arbitrage de coordination impose au contraire la conservation de production en Phase 1.
  D-1 et les surcharges sont Debug-only ; l'isolation du parcours hérité reste à réaliser
  lors de la bascule Phase 3 (`nav.v2` / `today.v2`). Ne pas confondre ces deux garanties.
- Les labels secondaires/tertiaires restent des couleurs sémantiques système ; ils ne sont
  pas annoncés comme des couleurs de texte courant garantissant 4,5 sur tous les fonds.
  Les paires de texte de la galerie utilisent des rôles audités.
- Les sons, matériaux et haptiques sont des tokens, pas un moteur de lecture livré en avance.
  Déclic conserve un repli natif success ; la courbe expressive expose sa durée et un adaptateur
  standard, pas une chorégraphie de célébration produite en Phase 1.
- La baseline d'architecture conserve **144 occurrences / 115 clés dans neuf fichiers hérités**.
  Elle n'est pas une permission d'ajouter une violation. Ne pas régénérer la baseline pour
  faire passer un test ; retirer/réduire les seules exceptions effectivement résolues.
- Les snapshots natifs et la compilation Apple demeurent à exécuter sur Apple.
  Aucun golden iOS, niveau de performance, audit de lecteur d'écran ou déploiement n'est inventé.

## 6. Decision Requests ouvertes / tranchées

DR-001 à DR-010 sont conservées exactement depuis la Phase 0 fusionnée,
y compris le renvoi de langue corrigé dans `10_BUSINESS_LOGIC_CONTRACTS.md`.
DR-002 autorise iOS 26 ; DR-003 gèle Flutter ; DR-005 conserve la série quotidienne ;
DR-006/010 reportent les actifs officiels à 2B ; DR-007/008 fixent snapshot et analytics.

Arbitrages de coordination reçus dans cette mission :
seuil général texte 4,5 et seuil syntaxe HC 7 sans altérer `accentFill` ;
maintien des écrans de production malgré DR-009 ; acceptation des preuves portables
pour les portes visuelle/accessibilité/performance de Phase 1.
Aucune autre décision produit, de notation, d'authentification ou de signature n'est prise.

## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)

Référence : [Baseline technique Phase 0](../phase-0/02_BASELINE.md).
Les 187 XCTest existants restent verts ; neuf tests Swift Testing sont ajoutés.
Le test Node couplé à l'ancien monolithe/localisation a été réaligné sur les vrais
composants sans affaiblir la frontière accès/lecture.
L'exécution portable ne mesure pas lancement, hitches, mémoire ou taille de l'app :
aucun delta iOS n'est calculable et aucune amélioration de ces métriques n'est revendiquée.
Les mesures historiques de Phase 0 ne sont pas recyclées comme preuve de cette révision.

## 8. Risques pour la phase suivante

La compilation Apple des adaptateurs et de D-1 doit précéder leur utilisation produit.
Les captures doivent figer SDK, simulateur, échelle, locale, contraste et Dynamic Type.
Les neutres UIKit peuvent varier avec le SDK ; tester leurs pixels réels plutôt que
confondre les couleurs de référence Linux avec ces valeurs.
Brancher la source distante authentifiée, l'analytics avec consentement et les flags
aux parcours seulement dans leurs phases approuvées.
Migrer la dette héritée progressivement, sans exemption de nouveaux composants.
Arrêt après Phase 1 : aucune Phase 2 démarrée sans validation propriétaire.

## 9. Procédure de retour arrière testée (oui/non + preuve)

**Oui pour les sources ; non pour un rollback d'application installée.**
Un index Git temporaire a reçu l'arbre candidat de Phase 1 ; le diff binaire inverse
`--full-index` a été appliqué avec `git apply --cached --reverse --binary`.
L'arbre reconstruit est exactement
`36d4d2914c37a41ebb3d83fff74fca8505fcc028`, arbre de `2db0e3e6`.
Sortie : `Rollback index-only PASS`, sans toucher au worktree ni à l'index réel.
La preuve porte sur les 66 fichiers de code/tests/catalogue stagés avant ce rapport.

Après fusion, créer une branche depuis `main`, exécuter `git revert -m 1 <merge-phase-1>`,
régénérer la référence projet après commit des sources, puis faire vérifier/fusionner la PR
de retour arrière. Ne pas déplacer les tags, réinitialiser `main` ou contourner la revue.
Les flags restent OFF pour les nouveaux parcours ; leur désactivation seule ne supprime
pas un linkage SPM ni le relèvement du minimum iOS, qui nécessitent le revert de sources.

## 10. Phrase de clôture : "PHASE 1 TERMINÉE — EN ATTENTE DE VALIDATION."

PHASE 1 TERMINÉE — EN ATTENTE DE VALIDATION.
