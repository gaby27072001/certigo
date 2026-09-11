# Démarrer l'application iOS native — à faire lundi soir

**Temps prévu : 10 minutes si tout va bien. 30 minutes s'il faut corriger.**

Ce document se suit dans l'ordre, sans réfléchir. À la fin, l'application
Certigo native se lance dans le simulateur.

---

## ⚠️ À lire avant de commencer (30 secondes)

**Tout le code Swift de ce dossier a été écrit sur un PC Windows. Il n'a jamais
été compilé. Pas une seule ligne.**

Ce n'est pas de la négligence : SwiftUI et UIKit n'existent pas sur Windows, et
n'existeront jamais. Ce sont des bibliothèques d'Apple, livrées uniquement avec
le SDK d'Apple, qui ne tourne que sur macOS.

**Conséquence concrète pour toi :** il est *normal* qu'il y ait des erreurs au
premier lancement. Elles sont prévues, et la section « Les trois erreurs les
plus probables » plus bas donne la correction de chacune.

**Ton Mac est le premier compilateur que ce code rencontre.** C'est pour ça que
la pull request reste en brouillon jusqu'à ce que tu aies vu l'application se
lancer.

---

## Étape 1 — Vérifier la machine (1 minute)

Ouvre le Terminal et tape ces deux commandes, l'une après l'autre :

```bash
sw_vers
```

➜ Tu dois voir `ProductName: macOS` et un numéro de version.

```bash
xcodebuild -version
```

➜ **Tu dois voir `Xcode 26.6`.**

### Si Xcode n'est pas installé

Installe-le depuis l'App Store (c'est gros, compte 1 h de téléchargement),
puis **ouvre-le une fois** pour accepter la licence. Ensuite :

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Si tu vois un autre numéro que 26.6

C'est important, pas cosmétique : la chaîne de livraison (Codemagic) est
épinglée à Xcode 26.6. Un écart entre ton Mac et la CI produit des pannes très
difficiles à diagnostiquer — ce qui marche ici casse là-bas.

Si tu as plusieurs Xcode installés :

```bash
sudo xcode-select -s /Applications/Xcode-26.6.app/Contents/Developer
```

Si tu veux quand même essayer avec ta version, le script te laissera passer :

```bash
CERTIGO_IGNORER_XCODE=1 ./Scripts/demarrer.sh
```

---

## Étape 2 — Les deux commandes (5 minutes)

### Commande 1 — installer l'outil qui fabrique le projet Xcode

```bash
brew install xcodegen
```

> **Pourquoi ?** Le fichier `Certigo.xcodeproj` n'est pas dans Git. Il est
> reconstruit à partir d'un fichier texte lisible (`project.yml`). C'est ce qui
> permet à plusieurs personnes — ou plusieurs agents — de travailler en même
> temps sans conflits illisibles. Voir
> [`docs/adr/ADR-023-generation-projet-xcode.md`](../../docs/adr/ADR-023-generation-projet-xcode.md).

Si Homebrew n'est pas installé :

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Commande 2 — tout faire

```bash
cd apps/ios && ./Scripts/demarrer.sh
```

C'est tout. Cette commande fait, dans l'ordre :

1. vérifie macOS et Xcode ;
2. vérifie que XcodeGen est là ;
3. **lance les tests** (sans Xcode, c'est plus rapide et plus fiable) ;
4. **fabrique** le projet Xcode ;
5. **compile** pour le simulateur ;
6. **installe et lance** l'application.

Elle choisit toute seule un simulateur iPhone disponible. Tu n'as rien à
configurer.

---

## Étape 3 — Ce que tu dois voir

### Dans le Terminal

```
▸ 3/6  Tests unitaires (paquet CertigoKit, sans Xcode)
  ✓ 54 tests découverts (plancher : 50)
  ✓ 54 tests exécutés, tous verts
▸ 4/6  Génération du projet Xcode
  ✓ Certigo.xcodeproj généré
▸ 5/6  Compilation pour le simulateur
  ✓ Compilation réussie
▸ 6/6  Lancement dans le simulateur
  ✓ Application lancée
```

### À l'écran du simulateur

Prends trente secondes pour regarder. C'est **ta** partie du travail : je peux
écrire le code, je ne peux pas juger le rendu.

| Ce que tu dois voir | Ce que ça prouve |
|---|---|
| Un dégradé **violet** en haut de l'écran, qui s'éteint vers le bas | La couleur vient du contenu et irradie sa région — la mécanique du halo de pochette d'Apple Music, appliquée à la certification « Azure Fundamentals » |
| Le mot **Certigo** en très gros, violet | La typographie Prism est chargée |
| Une liste de **six parcours de six couleurs différentes** : violet, magenta, rose, ambre, vert, cyan | Le spectre OKLCH à clarté constante est en place, une bande par certification |
| Quand tu touches un parcours, le dégradé du haut **glisse** vers sa couleur | Le mouvement est continu, pas un changement brutal |
| Les 15 tailles de texte, avec leur nom | L'échelle typographique complète a survécu à la traduction |
| 9 mesures de contraste, **toutes en vert** | Les couleurs restent lisibles — la garde d'accessibilité a traversé |
| Le bouton **« Échouer »** affiche une erreur **avec un bouton « Réessayer » qui marche** | Il est devenu impossible d'afficher une erreur sans offrir de reprise |

### Liquid Glass — la preuve visuelle qui compte le plus

En bas de l'écran flotte une **pilule**. Regarde-la attentivement.

**✅ Si Liquid Glass s'applique correctement :**

- La pilule **ne touche aucun bord**. Elle flotte au-dessus du contenu.
- Le texte de la liste **passe dessous** et reste partiellement visible à
  travers — déformé, pas simplement flouté. On voit la **réfraction** : les
  lettres se courbent en passant sous le bord de la pilule.
- Il y a un **reflet** sur le bord de la pilule, comme sur du verre réel.
- En haut de l'écran, le contenu qui défile **se fond progressivement** en
  approchant du bord, au lieu d'être coupé net.
- **Touche la pilule** : elle **s'étire** en trois pilules. Elle ne disparaît
  pas pour laisser apparaître autre chose — elle se déforme, en continu. C'est
  le trait le plus reconnaissable de Liquid Glass.
- Bascule le simulateur en mode sombre (`⌘⇧A`) : la pilule s'assombrit **toute
  seule**, et le texte dessus passe au clair sans que rien ne l'ait demandé.

**❌ Si ce n'est qu'un rectangle gris flou, sans reflet ni déformation :**

Ton simulateur tourne sous iOS 18 ou moins. Liquid Glass demande **iOS 26**.
Le code le détecte et retombe volontairement sur l'ancien matériau — donc
l'application marche, mais tu ne vois pas ce qui compte.

Choisis un simulateur iOS 26 :

```bash
xcrun simctl list devices available        # voir la liste
CERTIGO_SIMULATEUR="iPhone 17" ./Scripts/demarrer.sh
```

> **Un point que je n'ai pas pu vérifier :** la refonte Flutter avait mesuré
> que le liseré de lumière d'Apple rend **1.00:1** en mode clair — donc
> rigoureusement invisible — et avait choisi de le remplacer par une ombre.
> Ici, on utilise le **vrai** matériau d'Apple, qui gère lui-même sa
> profondeur : Apple documente qu'il *réduit* son ombre sur fond clair uni et
> l'*augmente* au-dessus du texte. En théorie le problème ne se pose donc pas.
> **Je n'ai pas pu le vérifier.** Regarde la pilule sur fond clair : si elle
> semble plate et posée sur rien, dis-le-moi, c'est une vraie information.

---

## Les trois erreurs les plus probables

Elles sont classées par probabilité. Dans les trois cas, **l'application
finira par se lancer** : aucune n'est bloquante.

---

### Erreur 1 — Liquid Glass ne compile pas

**Ce que tu verras :**

```
error: value of type 'some View' has no member 'glassEffect'
error: cannot find 'GlassEffectContainer' in scope
error: extra argument 'spacing' in call
```

**Pourquoi :** ces appels ont été écrits depuis une documentation, sans jamais
être compilés. C'est l'erreur la plus attendue de tout le squelette.

**La bonne nouvelle : il n'y a qu'un seul fichier à corriger.** Toute l'API
Liquid Glass est confinée dans :

```
apps/ios/Packages/CertigoKit/Sources/DesignSystem/PrismGlass.swift
```

**Correction en 10 secondes** — pour voir l'application tout de suite, ouvre ce
fichier et remplace `iOS 26.0, macOS 26.0` par `iOS 99.0, macOS 99.0` partout
(6 endroits). Le code retombe alors sur les matériaux classiques, qui eux sont
sûrs. L'application se lance, sans Liquid Glass.

```bash
cd apps/ios
sed -i '' 's/iOS 26.0, macOS 26.0/iOS 99.0, macOS 99.0/g' \
  Packages/CertigoKit/Sources/DesignSystem/PrismGlass.swift
./Scripts/demarrer.sh
```

**Puis dis-moi l'erreur exacte**, et je corrige le fichier proprement. Ne perds
pas ta soirée dessus : c'est du travail d'agent, pas du tien.

---

### Erreur 2 — XcodeGen refuse `project.yml`

**Ce que tu verras :**

```
Spec validation error: Invalid key 'xxx'
Found invalid Swift version
```

**Pourquoi :** `project.yml` décrit le projet Xcode dans un format que je n'ai
pas pu exécuter.

**Correction :** le message indique la ligne fautive. Le plus souvent, il
suffit de supprimer la ligne signalée — les options sont presque toutes
facultatives. Les seules lignes **indispensables** sont `name`, `targets`,
`sources`, `dependencies` et `schemes`.

Si tu veux juste avancer : supprime la ligne, relance. Recommence si besoin.

**Puis dis-moi quelle ligne tu as dû supprimer.**

---

### Erreur 3 — Swift 6 refuse le code à cause de la concurrence

**Ce que tu verras :**

```
error: main actor-isolated property cannot be referenced from a nonisolated context
error: capture of 'self' with non-sendable type ... in a '@Sendable' closure
```

**Pourquoi :** le projet active la vérification stricte de concurrence dès le
premier jour. C'est un choix délibéré — l'activer plus tard, sur 20 000 lignes,
serait un chantier entier. Mais cela veut dire que du code non compilé a de
bonnes chances de la déclencher.

**Correction temporaire :** ouvre `apps/ios/project.yml` et change :

```yaml
    SWIFT_STRICT_CONCURRENCY: complete
```

en :

```yaml
    SWIFT_STRICT_CONCURRENCY: targeted
```

Puis relance. **C'est temporaire** : on remet `complete` une fois les erreurs
corrigées, pas l'inverse.

**Puis envoie-moi la liste des erreurs.** Elles sont mécaniques à corriger.

---

### Les autres, plus rares

| Symptôme | Correction |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen` (étape 2) |
| `No such module 'DesignSystem'` | Le paquet n'a pas été résolu. `cd apps/ios/Packages/CertigoKit && swift build` |
| `Aucun simulateur iPhone disponible` | Xcode ▸ Settings ▸ Components ▸ installer un runtime iOS |
| L'app se lance mais l'écran est **vide et blanc** | La vue a planté au rendu. Dans le simulateur : `⌘⇧H` puis relance. Envoie-moi la console Xcode. |
| L'app s'affiche **en petit, avec des bandes noires** | `UILaunchScreen` manquant dans le plist généré. Un test le vérifie — lance `./Scripts/demarrer.sh --tests-seuls`. |
| Les tests passent mais l'app ne compile pas | Normal : les tests ne compilent que le paquet, pas la cible d'application. L'erreur est dans `App/Sources/`. |

---

## ⚠️ La CI en dit moins que tu ne crois — dans les deux sens

**Ne te laisse pas décourager par la page de la pull request. Et ne lui fais pas
non plus dire ce qu'elle ne dit pas.**

### Un rouge ne veut pas dire que ton squelette est cassé

**Aucun contrôle de CI de ce dépôt ne compile du Swift** — il n'existe aucune
machine macOS dans la CI. Les contrôles qui tournent sur cette PR vérifient le
Flutter, le backend, le contenu et l'infrastructure : **ils ne savent rien de
`apps/ios/`**. Un rouge chez eux et un problème dans ton squelette sont deux
sujets indépendants.

Deux causes connues de rouge **sans aucun rapport** avec ton travail :

- **`docs/active-content-reference.json` expire le 2026-09-19.** Passé cette
  date, un contrôle rougit tout seul, sur toutes les PR ouvertes, sans que
  personne n'ait rien changé. C'est traité en parallèle.
- **Une PR sœur peut casser un contrôle partagé.** Les fichiers d'état générés
  (`docs/ETAT_DU_PROJET.md`, `docs/project-state-reference.json`) sont touchés
  par presque toutes les PR, donc un conflit y apparaît dès qu'une autre est
  fusionnée.

### Un vert ne veut pas dire que tout est vérifié

C'est le sens inverse, et il est tout aussi important à connaître.

**Mesuré le 2026-09-11 dans `.github/workflows/ci-mobile.yml` :** le paquet
`packages/prism_ui` — le système de design dont ton squelette transcrit les
valeurs — contient **39 fichiers de tests, et la CI n'en exécute qu'un seul**
(`test/rendering/renderer_golden_test.dart`, ligne 331). L'autre commande de
test, `flutter test --coverage` ligne 231, tourne dans `apps/mobile` et **ne
couvre pas ce paquet**.

**38 fichiers de tests sur 39 sont donc écrits, verts en local, et incapables
de bloquer quoi que ce soit.** Une tentative de les activer a été étudiée puis
**annulée** : elle cassait le validateur de workflows.

> **Ce que ça change pour toi, concrètement :** un vert sur la page GitHub ne
> te dit **rien** sur le système de design, et **rien** sur le Swift. Les deux
> sont hors de portée de la CI actuelle.

**Le seul verdict qui compte pour ton squelette, c'est ton Terminal.** Si
`./Scripts/demarrer.sh` va jusqu'au bout et que l'application s'affiche, le
squelette marche — quelle que soit la couleur de la page GitHub.

Et c'est précisément pour cette raison que `Scripts/verifier-tests.sh` **compte
les tests exécutés** au lieu de se fier au code de retour, et que
`Scripts/prouver-le-rouge.sh` existe : dans un dépôt où des centaines de tests
peuvent être verts sans jamais tourner, **un lot qui ne mord pas est le défaut
par défaut.**

---

## Ce que tu peux faire d'autre, si tu as le temps

### Ouvrir le projet dans Xcode et regarder les aperçus

```bash
cd apps/ios
open Certigo.xcodeproj
```

Ouvre `PrismShowcaseView.swift`, puis le canevas d'aperçu (`⌥⌘↩`). Il y a
**trois aperçus** écrits pour toi : clair, sombre, et texte agrandi.

> C'est la seule chose que je ne peux pas faire à ta place. J'écris les
> aperçus, tu les regardes. Le mode « texte agrandi » est celui à regarder en
> priorité : c'est là que les interfaces cassent.

### Vérifier que les tests mordent vraiment

```bash
./Scripts/prouver-le-rouge.sh
```

Ce script ajoute un test volontairement faux, vérifie que le lot **rougit**,
puis le retire et vérifie qu'il **reverdit**. Il ne laisse aucune trace.

> Un lot de tests entièrement vert ne prouve rien tant qu'on n'a pas vu un test
> échouer. C'est la seule façon de distinguer « tout passe » de « rien ne
> s'exécute ». `swift test` rend le code `0` quand il ne trouve **aucun** test.

### Lancer seulement les tests

```bash
./Scripts/verifier-tests.sh
```

---

## Ce que ce squelette ne fait **pas** — et c'est voulu

Pour éviter toute confusion en le découvrant :

- **Aucun écran n'est migré.** Quatre des cinq onglets affichent un écran
  d'attente qui dit son nom. L'application Flutter reste l'application réelle.
- **Aucun appel réseau.** Le client d'API est branché sur `.failing` : il
  échoue toujours, volontairement. Il n'y a aucune URL de production dans ce
  dossier.
- **Aucun secret, aucune signature.** Le squelette ne compile que pour le
  **simulateur**. Voir plus bas pour un vrai iPhone.
- **La police Archivo n'est pas embarquée.** Les tailles et les graisses de
  Prism sont exactes, mais la police est celle du système. Les textes auront
  donc le bon rythme et la mauvaise voix.
- **Pas de mode hors-ligne, pas d'authentification, pas de Cortex.** Le serveur
  reste autoritaire, et rien de tout cela n'appartient à un squelette.
- **Pas de test d'interface (XCUITest).** Lent, instable, et inutile tant
  qu'il n'y a qu'un écran.

---

## Lancer sur un vrai iPhone

Le squelette désactive la signature de code exprès : c'est un mode de panne en
moins pour le premier soir. Pour installer sur ton iPhone :

1. ouvre `apps/ios/project.yml` ;
2. supprime les trois lignes `CODE_SIGNING_REQUIRED`, `CODE_SIGNING_ALLOWED` et
   `CODE_SIGN_IDENTITY` ;
3. ajoute `DEVELOPMENT_TEAM: TONIDENTIFIANT` ;
4. relance `./Scripts/demarrer.sh --sans-lancer`, puis lance depuis Xcode.

L'identifiant de l'application est `com.certigo.native` — **volontairement
différent** de `com.certigo.mobileapp`, qui est celui de l'application Flutter.
Installer le squelette **ne remplacera pas** Certigo sur ton téléphone. Un test
automatique vérifie que cela reste vrai.

> ### ⚠️ Piège : ne suis pas ce que dit `mobile-secrets.env.example`
>
> Si tu cherches comment signer, tu vas tomber sur
> `tools/secrets/mobile-secrets.env.example`, qui recommande **fastlane
> `match`** — au présent, sans avertissement.
>
> **Cette recommandation est morte.** `codemagic.yaml:14` dit explicitement
> « no fastlane match », la documentation correspondante est barrée, et les
> deux seuls appelants de la chaîne fastlane portent « ⛔ MIGRÉ VERS
> CODEMAGIC ». Monter `match` te ferait perdre une soirée pour rien.
>
> **La signature de production passe uniquement par Codemagic.** Pour un
> simple essai sur ton propre iPhone, la signature automatique de Xcode
> (`DEVELOPMENT_TEAM` ci-dessus) suffit et ne demande aucune de ces
> mécaniques. Une session sœur est en train de dater ce fichier ; ce squelette
> ne s'appuie sur rien de cette chaîne.

---

## Si ça échoue : quoi me rapporter

Envoie-moi, dans cet ordre :

1. **La commande exacte** que tu as tapée.
2. **Le message d'erreur complet**, copié-collé tel quel. Pas résumé — les
   erreurs Swift sont longues mais chaque ligne compte.
3. Le contenu de **`apps/ios/.build/compilation.log`** s'il existe.
4. Le résultat de ces trois lignes :

```bash
sw_vers -productVersion && xcodebuild -version | head -1 && xcodegen --version
```

5. **À quelle étape ça a cassé** (le script les numérote : 1/6 à 6/6).

**Ne cherche pas à corriger toi-même au-delà des corrections ci-dessus.** Les
erreurs de compilation Swift sont mécaniques et c'est exactement le genre de
travail qu'un agent fait vite et bien. Ton temps sur le Mac est précieux pour
une seule chose : **regarder et juger** ce que personne d'autre ne peut voir.

---

## Ce qui se passe ensuite

Quand l'application se lance et que tu as regardé l'écran :

1. Dis-le-moi.
2. La pull request sort du brouillon et peut être fusionnée.
3. Le vrai travail commence : la fondation de vérification (un job de CI qui
   compile le Swift), puis les écrans, un par un.

**Tant que tu n'as pas vu l'application se lancer, la PR reste en brouillon.**
Aucun contrôle automatique de ce dépôt ne peut vérifier que du Swift compile :
il n'existe aucune machine macOS dans la CI. Une PR « toute verte » ne
prouverait donc **rien du tout**.

---

## Références

| Sujet | Où |
|---|---|
| Pourquoi cette architecture | `docs/adr/ADR-022-architecture-ios-native.md` |
| Pourquoi le projet Xcode est généré | `docs/adr/ADR-023-generation-projet-xcode.md` |
| Pourquoi iOS 17 minimum | `docs/adr/ADR-024-cible-ios-minimale.md` |
| Pourquoi Liquid Glass natif | `docs/adr/ADR-025-liquid-glass-natif.md` |
| Structure du dossier | `apps/ios/README.md` |
