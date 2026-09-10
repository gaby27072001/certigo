# Certigo — le monde visuel

Ce document décrit le monde tel qu'il est construit, pas tel qu'il était rêvé.
Chaque règle ici est vérifiée par un test dans `packages/prism_ui/test/`, et
chaque nombre a été mesuré avant d'être écrit.

Le brief du propriétaire, mot pour mot : **« coloré, joyeux, mais bien organisé,
fluide et intégré nativement à liquid glass d'Apple pour que ce soit beau comme
l'application Apple Music ».**

---

## 1. Ce qui n'allait pas, en chiffres

Le verdict « moche, boutons mal détourés, couleurs qui se confondent,
surbrillance mal faite, très amateur » n'était pas une impression. Chaque mot
correspondait à une valeur mesurable.

| Le mot | La mesure |
|---|---|
| boutons mal détourés | Trait du verre en clair : **1.008:1** contre son propre fond. `1.000` = couleur identique. |
| boutons mal détourés | Bordure hairline : **1.231:1** (clair), **1.342:1** (sombre). |
| couleurs se confondent | Carte vs fond : **1.019:1** en clair, **1.017:1** en sombre. La carte n'existait pas. |
| surbrillance mal faite | `overlayColor: Colors.transparent` à **trois** endroits → aucun survol nulle part. |
| surbrillance mal faite | Survol **1.07:1** vs highlight **1.08:1** — 1 % d'alpha d'écart, deux états identiques à l'œil. |
| surbrillance mal faite | **Quatre** dessins de focus différents, dont un codé en dur `Colors.black`/`Colors.white`. |
| amateur | `xpGold` **1.61:1**, `ember` **2.59:1** comme texte sur blanc (seuil 4.5). |
| amateur | Onze titres rendus dans la police de la **plateforme**, pas celle de la marque. |

Ce dernier point mérite son paragraphe. `PrismTypography.build` définissait
douze des quinze créneaux de `TextTheme`. `ThemeData` fusionne par-dessus le
défaut de la plateforme : un créneau non défini ne casse pas, il rend
silencieusement en San Francisco ou Roboto. `displaySmall`, `headlineLarge` et
`headlineSmall` manquaient — et `displaySmall` porte **les deux lignes du titre
héros de l'écran d'ouverture**, le tout premier texte que voit un utilisateur.

---

## 2. La couleur — un spectre réfracté

Le design system s'appelle **Prism**. Un prisme fait une chose : il prend une
lumière et la sépare en un spectre. C'est tout le modèle de couleur.

Chaque piste de certification possède **une bande réfractée de la même
lumière**. C'est la mécanique d'Apple Music transposée honnêtement : là-bas la
couleur vient de la pochette et irradie sa région ; ici elle vient de la piste
en cours.

### La loi, et pourquoi ce n'est pas celle qu'on croit

L'intuition dit « chroma constant pour que rien ne crie ». **La mesure dit le
contraire.** Le cyan plafonne à C≈0.11 dans le gamut sRGB quand le magenta
atteint C≈0.28 : un chroma commun tirerait tout le spectre vers le plancher du
cyan et viderait exactement la joie demandée.

Ce qui organise réellement, c'est la **clarté**. À L fixe, le contraste contre
un fond donné reste dans une fenêtre étroite (mesuré **3.4–4.2** contre blanc à
L=0.62) quel que soit le ton, alors même que le chroma varie du simple au
quadruple.

> **Clarté constante → ordre et lisibilité uniformes.
> Chroma poussé au plafond de chaque teinte → couleur et joie.**
> Les deux mots du brief, satisfaits par une seule règle.

### Trois rôles, parce qu'une couleur ne fait pas trois métiers

| Rôle | L | Emploi | Garantie mesurée |
|---|---|---|---|
| **ink** | 0.515 | Texte, aplats pleins | ≥ 4.5:1 sur le fond clair **et** sous du texte blanc |
| **vivid** | 0.62 | Progression, anneaux, pastilles, halos, grands titres | ≥ 3:1 sous texte blanc ; ≥ 1.5:1 visible sur le fond |
| **glow** | 0.68 | Texte et icônes sur chrome sombre | ≥ 4.5:1 sur le fond sombre |

Les six bandes : violet (la marque), magenta, rose, ambre, vert, cyan.

### Le bleu Microsoft

L'ancien code déclarait son intention : *« so the app instantly reads as Azure »*.
C'est précisément ce qui faisait lire le produit comme la console d'un
fournisseur plutôt que comme lui-même. Le bleu Fluent **n'est pas supprimé** :
il devient `PrismColors.azureTrack`, la couleur de la piste Azure — là où une
couleur de fournisseur a sa place.

---

## 3. Le chrome — des plans, pas une feuille

La toile est un gris teinté, les cartes sont blanches. Une carte est donc un
plan **plus clair** flottant au-dessus de son fond. L'ancien schéma faisait
l'inverse (carte blanche sur fond quasi blanc, 1.019:1), ce qui écrasait tout
en une seule surface.

| | Avant | Après | Plancher testé |
|---|---|---|---|
| Carte vs fond (clair) | 1.019 | **1.159** | ≥ 1.12 |
| Carte vs fond (sombre) | 1.017 | **1.158** | ≥ 1.12 |
| Bordure vs surface (clair) | 1.231 | **1.704** | ≥ 1.60 |
| Bordure vs surface (sombre) | 1.342 | **1.773** | ≥ 1.60 |

Le clair et le sombre sont désormais séparés de façon **équivalente** (1.159 vs
1.158). C'est délibéré : `ThemeMode.system` est le défaut livré, donc le sombre
est ce que voit tout utilisateur en réglage automatique.

---

## 4. Le matériau — l'arête est directionnelle

Liquid Glass est un **matériau**, et un matériau ne se lit qu'à son arête.

La règle, qui est la correction du défaut d'origine :

> **En clair, l'arête est plus SOMBRE que son fond. En sombre, plus CLAIRE.**

Un trait blanc sur une surface claire ne peut pas séparer — c'est une identité,
pas un choix esthétique. Le test `prism_colors_test.dart` vérifie le *sens* de
la luminance, pas seulement le ratio, pour que le défaut ne puisse pas revenir
sous une autre valeur.

### Ce que la mesure a interdit

Le liseré de lumière (le haut éclairé du verre) est un mécanisme de **chrome
sombre uniquement**. Mesuré : blanc à 0.55–0.85 d'alpha sur le fond de verre
clair donne **1.00:1**. Invisible. Du bruit.

Le mode clair ne le porte donc pas — `litEdge` y est délibérément transparent —
et confie sa profondeur à l'ombre et à l'arête sombre. C'est une déviation
assumée par rapport à la copie littérale d'Apple, imposée par la mesure.

Les ombres portent toutes un décalage et un flou. Une lueur colorée sans
décalage est une décoration, pas une profondeur. `PrismElevation.toned()` prend
sa teinte de l'appelant — auparavant le niveau 3 codait en dur le bleu de
marque, si bien qu'un bouton teinté en rose recevait un halo bleu.

---

## 5. Les états — un seul vocabulaire

Un état n'existe que s'il se **voit**. Chaque opacité ci-dessous a été vérifiée
comme déplaçant la surface d'au moins 1.04:1 par rapport au repos.

| État | Clair | Sombre |
|---|---|---|
| Survol | 0.06 → 1.068:1 | 0.10 → 1.157:1 |
| Pressé | 0.12 → 1.145:1 | 0.18 → 1.329:1 |
| Sélectionné | 0.16 → 1.203:1 | 0.24 → 1.480:1 |
| Halo de focus | 0.22 → 1.294:1 | 0.30 → 1.659:1 |

**Le focus : un seul anneau.** Une bague colorée séparée du contrôle par un
espace dans la couleur de la surface. C'est cet espace qui permet à une seule
couleur d'anneau de rester visible sur n'importe quel fond — y compris sur un
bouton rempli de cette même couleur, où l'anneau seul disparaîtrait.

**Le désactivé est une couleur, pas un voile.** Faire fondre tout le contrôle
poussait le libellé à 1.48:1 : illisible, et impossible à distinguer d'un bug
d'affichage. Un contrôle désactivé prend un aplat `surface` avec une vraie
arête, et son libellé en `textDisabled` — mesuré **3.53:1** en clair, **3.83:1**
en sombre. Inerte, mais lisible.

---

## 6. La typographie — une famille, deux axes

**Archivo** (SIL OFL 1.1), variable : poids 100–900, largeur 62–125.

L'ancien système appariait Plus Jakarta Sans et Inter. L'appariement
n'achetait rien : deux linéales géométriques neutres qui lisent comme la même
voix, si bien que la hiérarchie reposait sur la seule taille. Une UI produit n'a
pas besoin d'un couple display/texte — elle a besoin d'une famille bien réglée.

La hiérarchie vient donc du **poids et de la largeur** :

| Bande | Poids | Largeur |
|---|---|---|
| Display | 800 | 112 |
| Headline | 750–780 | 112 |
| Title | 650–700 | 104 |
| Corps, libellés | 400–600 | 100 |

Les tailles sont **inchangées** : corps à 17, plancher à 11, ce qui correspond
déjà aux métriques iOS. Ce changement porte sur la voix, pas sur la mise en
page. JetBrains Mono reste pour le code — là un chasse-fixe est un instrument de
mesure, pas un costume.

**Les quinze créneaux sont définis.** Deux tests le garantissent : un sur le
constructeur, un sur le thème fusionné, parce que c'est la fusion qui laissait
passer la police de la plateforme.

---

## 7. La largeur — l'axe qui manquait

`tokens/` contenait couleur, élévation, mouvement, rayons, espacement et
typographie. **Rien pour la largeur.** Chaque écran qui en avait besoin
inventait donc son littéral : 320, 340, 420, 480, 640, 760, 840 et 1120 étaient
tous en circulation, aucun derrière un token — et un seul corps d'écran de
l'application était borné.

Ce n'est pas une anticipation matérielle. Un corps non borné s'étire à la
largeur qu'on lui donne, ce qui est déjà le cas quotidien sur iPad, en paysage
et en Split View. Une ligne de texte large de 1100 px est illisible quel que
soit l'appareil qui l'a produite.

`PrismLayout` nomme donc l'axe **par rôle, pas par taille** : `compact` (320),
`form` (420), `panel` (480), `controlBar` (640), `reading` (760), `canvas`
(840), `workspace` (1120).

Ce sont des **mesures de lecture, pas des points de rupture**. Prism ne branche
pas sur une classe d'appareil : il plafonne la mesure et laisse la mise en page
se centrer, ce qui reste juste à n'importe quelle taille. C'est exactement ce
que demandent les recommandations d'Apple — *« Avoid fixed widths and
display-specific dependencies »* et *« Don't reinvent your app when it resizes;
allow the existing layout to expand based on the available space instead »*. Un
plafond de mesure applique ce principe ; un `if (appareil)` le viole.

La granularité utile n'est d'ailleurs pas « téléphone / tablette » mais
**compact / regular** au sens des size classes iOS : écran externe compact,
écran interne regular.

**Aucune primitive de charnière n'est introduite.** Non parce qu'Apple n'en
aurait pas — les *reserved regions* existent — mais parce que Flutter ne les
relaie pas : `MediaQuery.displayFeatures` est documenté *« populated only on
Android »*. Le jour où cela vaudra le coup, ce sera un canal de plateforme
écrit à la main, pas une attente de Flutter. La distinction compte : ce n'est
pas une impasse, c'est un travail non commencé.

---

## 8. Le mouvement — registre continu

Un élément **s'étire vers son état suivant** au lieu de disparaître et d'être
remplacé. D'où des courbes d'ease-out asymétriques : le mouvement part vite et
arrive lentement, ce qui donne à une surface l'impression d'avoir une masse.

- `state` 120 ms — retour d'état, attaché au pointeur
- `morph` 280 ms — un élément qui en devient un autre
- `continuous` `cubic(0.16, 1, 0.30, 1)` — la courbe du registre

Les transitions produit restent dans la bande 150–250 ms : l'utilisateur est
dans une tâche, il n'attend pas une chorégraphie. Seul `celebrate` a le droit
d'être regardé. `PrismMotion.resolve()` rend tout cela nul quand la plateforme
demande un mouvement réduit.

---

## 9. Ce qui reste ouvert

Honnêteté sur les limites de cette livraison.

- **Les transitions Prism ne s'exécutent pas sur iOS.** `step_page.dart:30`
  renvoie un `CupertinoPage` et ignore le paramètre `begin`, seul réglage que
  module `router.dart` sur 17 routes. Un utilisateur iPhone n'a donc jamais vu
  le mouvement de Prism. **Non corrigé ici volontairement** : le `CupertinoPage`
  est aussi ce qui fournit le geste de retour par balayage livré en #446, et
  les deux doivent coexister. À traiter dans une session dédiée au routage.
- **Le texte en dégradé et le sur-titre** de l'écran d'ouverture restent en
  place. Ce sont des défauts d'écran, hors du périmètre « fondations ».
- **Cinq écrans n'ont pas pu être capturés** (Accueil, Parcours, Ligue, Profil,
  Boutique) : le backend de développement ne publie aucun parcours avec leçons,
  donc l'onboarding ne peut pas se terminer.
- **Les 37 corps d'écran ne sont pas convertis.** `PrismLayout` livre l'axe ;
  faire passer chaque écran par `PrismContentFrame` est une PR de suite,
  mécanique et vérifiable, délibérément séparée pour ne pas mélanger une
  décision de système et son application mécanique. Seul `app_shell` est
  corrigé ici, parce que la primitive y existait déjà et visait la barre de
  navigation au lieu du corps.
- **La barre d'onglets reste horizontale en bas.** Apple place barres d'outils
  et d'onglets sur le côté de l'écran externe d'un appareil pliant, mais
  seulement *« if you use standard system components »* — or la nôtre est
  dessinée à la main et Flutter ne rend aucun composant UIKit. Ce n'est pas une
  casse, c'est un écart de convention, et l'abstraire sans appareil pour juger
  produirait une abstraction non vérifiée.
- **Neuf valeurs d'espacement hors grille**, 38 usages, documentées comme dette
  dans `prism_spacing.dart`.
- **85 widgets Material bruts**, dont 32 sur le seul écran Profil.
- **Le bloc « à retenir » garde une barre latérale colorée épaisse**
  (`key_takeaway_block.dart`), ce que le plancher de craft refuse au-delà d'un
  pixel. Défaut d'écran préexistant, non corrigé ici.

---

## 10. Les règles qui ne se négocient pas

1. Une arête doit contraster avec ce qu'elle borde, **dans le bon sens**.
2. Un état qui ne se voit pas n'existe pas. Un seul anneau de focus, partout.
3. Le désactivé reste lisible.
4. Chaque créneau de `TextTheme` appartient à la marque.
5. La clarté organise ; le chroma réjouit.
6. Le mouvement informe ; il ne décore pas.
7. Le clair et le sombre sont tenus à égalité — le sombre est un défaut livré.

Ces règles sont des tests, pas des vœux. Elles vivent dans
`packages/prism_ui/test/tokens/prism_colors_test.dart` et
`prism_typography_test.dart`, et elles re-dérivent leurs seuils au lieu de figer
des valeurs hexadécimales — pour qu'une modification future qui *paraît* bonne
mais détruit la lisibilité échoue ici plutôt qu'en production.
