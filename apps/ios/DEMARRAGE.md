# Démarrer l'application iOS native sur le Mac

**Les trois commandes sont juste en dessous. Tout le reste de ce document ne
sert qu'en cas de problème.**

---

## Les 3 commandes

**Prérequis : Xcode doit être installé.** Voir juste en dessous — c'est le
piège n° 1 et il coûte une heure si on le découvre trop tard.

Ouvre le **Terminal** et tape-les dans l'ordre. Attends que chacune finisse.

### ① Les outils

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ; brew install gh xcodegen ; gh auth login
```

➜ Si Homebrew est déjà installé, la première partie dit juste qu'il est là :
c'est normal, la suite s'exécute quand même. `gh auth login` ouvre ton
navigateur pour te connecter à GitHub.

### ② Le code

```bash
gh repo clone gchambaud_microsoft/Certigo ~/Certigo && cd ~/Certigo && git checkout gchambaud-microsoft-squelette-ios-natif
```

➜ Tu dois voir `Switched to branch 'gchambaud-microsoft-squelette-ios-natif'`.

**Si tu as déjà le dépôt quelque part** — ou si tu reviens après une
correction de ma part — **rien n'est supprimé ni écrasé**. On crée un
checkout séparé, dans un dossier neuf :

```bash
cd ~/Certigo && git fetch origin

# 1. La version publiée, résolue MAINTENANT (aucun numéro à recopier)
ATTENDU=$(git rev-parse origin/gchambaud-microsoft-squelette-ios-natif)
echo "Version publiée : $ATTENDU"

# 2. Un dossier neuf, horodaté : il ne peut pas déjà exister
ESSAI=~/certigo-ios-$(date +%Y%m%d-%H%M%S)
echo "Dossier d'essai : $ESSAI"

# 3. Le checkout exact de CETTE version
git worktree add "$ESSAI" "$ATTENDU"

# 4. Le HEAD réellement obtenu est-il celui qu'on visait ?
if [ "$(git -C "$ESSAI" rev-parse HEAD)" = "$ATTENDU" ]; then
  echo "✅ Checkout conforme à la version publiée"
else
  echo "❌ Écart — ne continue pas, signale-le-moi"
fi
```

➜ **Attends la ligne `✅`.** Si tu vois `❌`, arrête-toi et dis-le-moi.

Puis lance depuis **ce** dossier — celui que la commande 2 a affiché :

```bash
cd "$ESSAI/apps/ios" && ./Scripts/demarrer.sh
```

> ### Pourquoi un dossier horodaté plutôt qu'un nom fixe
>
> Un nom fixe finirait par exister déjà, et la seule façon de le réutiliser
> serait de le supprimer. **Un dossier daté ne peut pas entrer en collision**,
> donc la question de l'écrasement ne se pose jamais.
>
> Si un dossier d'essai précédent traîne, **il reste où il est**. Il contient
> peut-être des commits locaux, des journaux ou des artefacts qui te servent —
> et de toute façon, **un ancien commit reste une version reproductible**, pas
> du jetable. Le supprimer est une décision, pas une étape.
>
> ### Pourquoi ce contrôle-là, et pas un numéro recopié
>
> Cette branche est **réécrite** (rebase) chaque fois qu'elle est remise à jour
> sur `main` — plusieurs fois par jour. **Un numéro de commit noté dans un
> message devient donc caduc en quelques minutes.** Mesuré deux fois le
> 2026-09-19.
>
> La commande ci-dessus ne te demande de recopier **aucun** numéro : elle
> **résout** la version au moment où tu la lances, puis **vérifie** que le
> dossier obtenu porte bien cette version-là. Elle reste juste quel que soit le
> nombre de réécritures, et elle garde la traçabilité — `$ATTENDU` te dit
> exactement ce que tu as testé, à rapporter en cas d'échec.
>
> ### Pourquoi pas `git pull`
>
> Après une réécriture, `git pull` ne ramène pas la correction : il échoue, ou
> fabrique une fusion qui mélange l'ancien et le nouveau. **C'est déjà arrivé**
> — une version antérieure avait été relancée sans que personne ne le sache.
> Le checkout neuf ci-dessus n'a pas ce problème : il part directement de la
> version publiée.

**Ce que ça touche, exactement :**

- ✅ Les **fichiers de travail** et la **branche** de `~/Certigo` ne sont pas
  modifiés. Rien de ce que tu as en cours n'est perdu.
- ✅ **Aucun dossier existant n'est supprimé ni modifié.**
- ⚠️ En revanche les **métadonnées Git** le sont : `git fetch` met à jour les
  références distantes, et `git worktree add` inscrit le nouveau worktree dans
  `.git/worktrees`. Ce n'est pas destructeur — mais ce n'est pas « rien ».

**Le nettoyage est une décision séparée, et elle t'appartient.** Quand tu
auras fini, et seulement si tu as vérifié que le dossier ne contient rien que
tu veux garder :

```bash
git worktree remove "$ESSAI"     # volontaire, jamais un préalable
```

### ③ Lancer

```bash
cd ~/Certigo/apps/ios && ./Scripts/demarrer.sh
```

➜ **C'est la seule commande qui compte.** Elle vérifie ta machine, lance les
tests, fabrique le projet Xcode, compile, et ouvre l'application dans le
simulateur. Compte 3 à 5 minutes la première fois.

**Ce que tu dois voir à la fin :**

```
  ✓ 54 tests découverts (plancher : 50)
  ✓ 54 tests exécutés, tous verts
  ✓ Certigo.xcodeproj généré
  ✓ Compilation réussie
  ✓ Application lancée
```

**Puis regarde le simulateur** → section « Ce que tu dois voir » plus bas.

> **Si le script s'arrête, il te dit toujours pourquoi et quoi faire.** Il
> distingue « Xcode absent », « Command Line Tools seuls », « Xcode ne répond
> pas » et « mauvaise version » — quatre situations dont les remèdes diffèrent.
> Suis ce qu'il affiche, puis relance la commande ③.

---

## ⛔ Étape 0 — installer Xcode (à faire AVANT la commande ③)

**C'est le piège n° 1, et il coûte une heure.**

`demarrer.sh` a besoin de **Xcode complet**. Les « Command Line Tools » ne
suffisent pas — et c'est ce que macOS installe tout seul quand tu tapes ta
première commande `git`. Le piège est là : `xcodebuild` **semble** exister,
mais il refuse de travailler.

### Vérifier ce que tu as — **avant tout téléchargement**

```bash
sw_vers -productVersion && xcodebuild -version
```

Dix secondes, et ça tranche. **Ne télécharge rien avant d'avoir lu ce que
ça répond.**

| Ce que tu lis en 2ᵉ ligne | Ce que ça veut dire |
|---|---|
| `Xcode 26.6` | ✅ C'est bon, va aux 3 commandes |
| `Xcode 27.x` ou une autre version | ⚠️ Version différente de celle visée — voir « Si tu as une autre version » |
| `... requires Xcode, but active developer directory ... CommandLineTools ...` | ❌ **Tu n'as que les Command Line Tools.** Voir « Récupérer Xcode 26.6 ». |
| `command not found` | ❌ Rien d'installé. Voir « Récupérer Xcode 26.6 ». |

### Les versions, et ce qu'elles sont vraiment

Trois choses distinctes, souvent confondues :

| | Valeur | Statut |
|---|---|---|
| **Version d'Xcode visée** | **26.6** | **Un choix de ce projet**, pas une nécessité technique. C'est la version épinglée dans `codemagic.yaml`, la chaîne qui construit l'application publiée. Le script `demarrer.sh` l'exige pour garder la parité. |
| **macOS minimum pour Xcode 26.6** | **macOS Tahoe 26.2** | **Exigence d'Apple**, relevée le 2026-09-19 : *« Xcode 26.6 requires a Mac running macOS Tahoe 26.2 or later. »* — [release notes Xcode 26.6](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_6-release-notes) |
| **SDK iOS livré avec Xcode 26.6** | **iOS 26.5** | Même source. Swift 6.3. Cibles de déploiement iOS 15 → 26.5, donc notre plancher iOS 17 est largement dedans. |

> ⚠️ **Ne déduis jamais le minimum macOS du numéro d'Xcode.** Ils sont alignés
> par année depuis macOS 26, mais ça ne veut pas dire qu'ils sont égaux :
> Xcode 26.4.1, 26.5 et 26.6 partagent **tous** le plancher macOS 26.2.
> Une version antérieure de ce document affirmait « macOS 26.6 nécessaire » —
> **c'était faux**, et déduit de cette fausse égalité.

**Ce document ne te demande aucune mise à jour ni aucun retour arrière de
macOS.** Si `sw_vers` affiche **26.2 ou plus**, la condition d'Apple est
remplie et il n'y a rien à faire. Si elle affiche moins, dis-le-moi : on
décidera ensemble, ça ne se tranche pas dans une checklist.

### Récupérer Xcode 26.6

> 🚫 **Pas depuis le Mac App Store.**
>
> Relevé le **2026-09-19** : la fiche App Store d'Xcode sert la version
> **27.0** (date de publication annoncée : 2026-09-14), et non 26.6. L'App
> Store ne propose que la version courante. Suivre cette voie installerait
> **une autre version que celle visée**, pour ~3 Go téléchargés.

**Le portail développeur, qui permet de choisir la version :**

1. Ouvre **https://developer.apple.com/download/all/**
   → **tu devras t'authentifier** avec un compte Apple développeur (gratuit).
   *Je ne peux ni le faire ni le vérifier à ta place.*
2. Cherche **« Xcode 26.6 »**, télécharge le `.xip`, décompresse-le et place
   `Xcode.app` dans `/Applications`.
3. **Ouvre Xcode une fois** et accepte la licence. Il installera encore
   quelques composants — laisse-le finir.
4. Vérifie :
   ```bash
   xcodebuild -version
   ```

> **[NON VÉRIFIÉ]** Je n'ai pas pu confirmer que le `.xip` d'Xcode 26.6 est
> encore listé sur cette page : elle exige une authentification. Si tu ne l'y
> trouves pas, dis-le-moi plutôt que de prendre la version la plus proche.

### Si Xcode est installé mais que le message parle encore de CommandLineTools

`xcode-select` pointe au mauvais endroit. Une commande le corrige :

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Pour voir où il pointe : `xcode-select -p`

### Si tu as une autre version d'Xcode

Le script s'arrêtera en le disant. Deux possibilités :

- **Tu as plusieurs Xcode installés** — pointe sur le bon :
  ```bash
  sudo xcode-select -s /Applications/Xcode-26.6.app/Contents/Developer
  ```
- **Tu veux quand même essayer avec ta version** :
  ```bash
  CERTIGO_IGNORER_XCODE=1 ./Scripts/demarrer.sh
  ```

  > ⚠️ **Diagnostic uniquement**, tant qu'aucune compilation n'a été observée.
  > Ce garde-fou existe pour détecter l'écart entre ton poste et la chaîne de
  > livraison. Le desserrer pour « passer » masquerait précisément ce qu'il
  > sert à voir. À utiliser pour *comprendre* un échec, pas pour le contourner.

> **La compatibilité réelle n'est pas démontrée.** Rien de ce squelette n'a
> jamais été compilé, avec aucune version d'Xcode. Les versions ci-dessus
> disent ce que le projet **vise** et ce qu'Apple **exige pour installer** —
> elles ne prouvent pas que le code compile.

---

## ⚠️ Deux autres choses à savoir (1 minute de lecture)

### 1. Ce code n'a jamais été compilé. Pas une seule ligne.

Il a été écrit sur un PC **Windows**, où SwiftUI et UIKit **ne peuvent pas
exister** — ce sont des bibliothèques d'Apple, livrées uniquement avec son SDK,
qui ne tourne que sur macOS. Ce n'est pas une négligence, c'est une propriété
permanente.

**Conséquence :** il est *normal* qu'il y ait des erreurs au premier lancement.
Elles sont prévues, et la section « Les trois erreurs les plus probables »
donne la correction de chacune. **Ton Mac est le premier compilateur que ce
code rencontre.**

### 2. La page GitHub ne dira **rien** de ton squelette

**Aucun contrôle de CI de ce dépôt ne compile du Swift** — il n'existe aucune
machine macOS dans la CI.

- **Un rouge** sur la pull request ne veut pas dire que ton squelette est
  cassé. Il parle du Flutter, du backend ou du contenu.
- **Un vert** ne veut pas dire qu'il marche. Ni le Swift, ni le système de
  design ne sont vérifiés par la CI.

**Le seul verdict qui compte, c'est ton Terminal.** Si `demarrer.sh` va
jusqu'au bout et que l'application s'affiche, le squelette marche — quelle que
soit la couleur de la page GitHub. (Le détail est en bas, section « La CI en
dit moins que tu ne crois ».)

---

## Le reste de ce document

Tu n'en as besoin **que si quelque chose ne marche pas**, ou si tu as du temps
après avoir vu l'application tourner.

---

## Vérifier la machine plus en détail

Ouvre le Terminal et tape ces deux commandes, l'une après l'autre :

```bash
sw_vers
```

➜ Tu dois voir `ProductName: macOS` et **`ProductVersion: 26.2`** ou plus
(macOS **Tahoe**). C'est le minimum qu'Apple documente pour installer
Xcode 26.6 — voir la table de l'**Étape 0**, avec sa source et sa date.

```bash
xcodebuild -version
```

➜ **Tu dois voir `Xcode 26.6`** — la version visée par ce projet.

### Si Xcode n'est pas installé

**Pas depuis le Mac App Store** — il ne propose que la version courante.
Récupère la version exacte sur **https://developer.apple.com/download/all/**
(authentification requise). Procédure détaillée à l'**Étape 0**.

Puis **ouvre-le une fois** pour accepter la licence, et enfin :

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

> **Sur un Mac neuf, installer Xcode te donne aussi `git`.** Si tu tapes une
> commande `git` avant, macOS te proposera d'installer les outils en ligne de
> commande — accepte, c'est le même mécanisme en plus léger.

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

## Ce que fait la commande ③, en détail

```bash
cd ~/Certigo/apps/ios && ./Scripts/demarrer.sh
```

Dans l'ordre :

1. vérifie macOS et Xcode ;
2. vérifie que XcodeGen est là ;
3. **lance les tests** (sans Xcode, c'est plus rapide et plus fiable) ;
4. **fabrique** le projet Xcode ;
5. **compile** pour le simulateur ;
6. **installe et lance** l'application.

Elle choisit toute seule un simulateur iPhone disponible. Tu n'as rien à
configurer.

> **Pourquoi faut-il installer XcodeGen ?** Le fichier `Certigo.xcodeproj`
> n'est pas dans Git. Il est reconstruit à partir d'un fichier texte lisible
> (`project.yml`). C'est ce qui permet à plusieurs personnes — ou plusieurs
> agents — de travailler en même temps sans conflits illisibles. Voir
> [`docs/adr/ADR-023-generation-projet-xcode.md`](../../docs/adr/ADR-023-generation-projet-xcode.md).

Deux variantes utiles :

```bash
./Scripts/demarrer.sh --tests-seuls   # s'arrête après les tests
./Scripts/demarrer.sh --sans-lancer   # compile mais ne lance pas
```

> ### ⚠️ `--tests-seuls` ne prouve **pas** que l'application iOS compile
>
> Il s'arrête à l'**étape 3/6** et ne compile que le **paquet Swift**, et
> seulement **pour macOS** — parce que `swift test` tourne sans simulateur.
> Il ne franchit jamais la frontière de plateforme.
>
> C'est utile pour savoir si le Swift pur tient debout. **Ça ne dit rien de
> la cible iOS**, et un vert ici ne répond pas à la question posée.
>
> **Seule la commande complète le démontre** : l'étape **5/6** (`xcodebuild`
> vers le simulateur) compile réellement pour iOS, et la **6/6** lance
> l'application.

---

## Ce que tu dois voir

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
cd ~/Certigo/apps/ios
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
| **Le script s'arrête après « ✓ macOS » sans rien dire** | **Ne devrait plus arriver.** Si ça se produit, c'est un défaut du script : il affiche désormais un code et une ligne. Envoie-les-moi. |
| `... requires Xcode ... CommandLineTools ...` | Tu n'as que les Command Line Tools → **Étape 0** en haut |
| `xcodegen: command not found` | `brew install xcodegen` (commande ①) |
| `No such module 'DesignSystem'` | Le paquet n'a pas été résolu. `cd ~/Certigo/apps/ios/Packages/CertigoKit && swift build` |
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
cd ~/Certigo/apps/ios
open Certigo.xcodeproj
```

Ouvre `PrismShowcaseView.swift`, puis le canevas d'aperçu (`⌥⌘↩`). Il y a
**trois aperçus** écrits pour toi : clair, sombre, et texte agrandi.

> C'est la seule chose que je ne peux pas faire à ta place. J'écris les
> aperçus, tu les regardes. Le mode « texte agrandi » est celui à regarder en
> priorité : c'est là que les interfaces cassent.
>
> ⚠️ **Le projet doit avoir été généré au moins une fois** par
> `demarrer.sh`, sinon `Certigo.xcodeproj` n'existe pas encore.

### Vérifier que les tests mordent vraiment

```bash
cd ~/Certigo/apps/ios && ./Scripts/prouver-le-rouge.sh
```

Ce script ajoute un test volontairement faux, vérifie que le lot **rougit**,
puis le retire et vérifie qu'il **reverdit**. Il ne laisse aucune trace.

> Un lot de tests entièrement vert ne prouve rien tant qu'on n'a pas vu un test
> échouer. C'est la seule façon de distinguer « tout passe » de « rien ne
> s'exécute ». `swift test` rend le code `0` quand il ne trouve **aucun** test.

### Lancer seulement les tests

```bash
cd ~/Certigo/apps/ios && ./Scripts/verifier-tests.sh
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
3. Le contenu de **`~/Certigo/apps/ios/.build/compilation.log`** s'il existe.
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
2. La pull request **#482** sort du brouillon et peut être fusionnée.
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
