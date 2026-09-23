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

### Trois clartés, quatre rôles

Les bandes sont produites à trois clartés :

| Clarté | L | Emploi | Garantie mesurée |
|---|---|---|---|
| **ink** | 0.49 | Texte sur chrome clair ; **aplats pleins** dans les deux thèmes | ≥ 4.5:1 sur le fond clair **et** sous du texte blanc |
| **vivid** | 0.62 | Progression, anneaux, pastilles, halos | ≥ 3:1 sous texte blanc ; visible comme aplat sur le fond |
| **glow** | 0.70 | Texte et icônes sur chrome sombre | ≥ 4.5:1 sur le fond sombre |

Les six bandes : violet (la marque), magenta, rose, ambre, vert, cyan.

Ces clartés sont **résolues** en quatre rôles sémantiques. C'est la partie qui
compte, parce que c'est celle qu'un site d'appel choisit :

| Rôle | Ce qu'il vaut | Pour quoi |
|---|---|---|
| **le nom nu** — `p.error` | **s'adapte** : ink en clair, glow en sombre | texte, icône, filet, bordure |
| **`*Fill`** — `p.errorFill` | ink dans les deux thèmes | un aplat qui porte du texte blanc |
| **`*OnSurface`** | identique au nom nu | quand on veut nommer l'intention |
| **`*Soft`** | lavis | teinter une région entière |

> **La règle derrière la règle : le défaut doit être sûr, l'exception doit être
> nommée.** Un site d'appel qui écrit `color: p.error` sans réfléchir doit
> obtenir un résultat lisible dans les deux apparences.

**Pourquoi le nom nu s'adapte.** Le premier plan est le cas courant, dans un
rapport mesuré de **108 contre 6** sur cet arbre. Une teinte interactive doit
donc changer d'apparence, exactement comme `systemBlue` chez Apple. La première
version tenait `light.primary == dark.primary` : six accents sur sept sont
tombés entre 2.6 et 3.1:1 en sombre, sous le seuil des icônes, sur l'apparence
livrée par défaut.

**Pourquoi l'aplat ne s'adapte pas.** Un aplat se pose *par-dessus* le chrome
et porte son propre texte blanc ; s'il s'éclaircissait en sombre, le blanc
tomberait avec lui. C'est arrivé au CTA de l'écran d'ouverture : **2.73:1** là
où le rôle d'aplat donne 7.05:1.

Ces deux erreurs sont opposées et il faut les tenir ensemble : corriger l'une
sans énumérer l'autre déplace le défaut au lieu de le supprimer. Deux gardes
les couvrent — `prism_contrast_contract_test` vérifie que chaque *rôle* est
lisible, `prism_fill_role_guard_test` vérifie que chaque *site d'appel* choisit
le bon. Le contraste seul ne peut pas attraper une erreur de sélection.

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
- **L'écart entre onglet sélectionné et non sélectionné est faible en clarté** :
  1.28:1 en sombre, 1.03:1 en clair. Les deux états se distinguent surtout par
  la teinte. Ce n'est pas un défaut : l'icône change de **forme** (pleine /
  contour), le libellé change de graisse, et la pastille de fond bouge de
  1.37:1 — trois signaux sur quatre survivent au niveau de gris. iOS lui-même
  tient sa barre d'onglets autour de 1.2:1 avec le même motif. Forcer un écart
  de clarté ferait descendre `textSecondary` sous son plancher sur le verre,
  là où se trouvent quatre onglets sur cinq. Mesure connue, pas dette.
- **Le réglage « Sons » ne commande encore rien.** L'interrupteur s'intitulait
  « Sons & vibrations » alors que `soundsEnabledProvider` n'était lu que par
  l'interrupteur lui-même. La moitié « vibrations » est désormais un réglage
  séparé et réellement branché ; la moitié « sons » reste décorative tant que
  `NullSoundPlayer` est la seule implémentation de `SoundPlayer` — brancher un
  vrai moteur audio suppose des assets, délibérément hors de ce lot.
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
8. **Le défaut doit être sûr, l'exception doit être nommée.** Un premier plan
   s'adapte au thème ; un aplat ne s'adapte pas. Confondre les deux ne casse
   ni la compilation ni le mode clair, où les rôles coïncident.
9. **Un réglage d'accessibilité du système doit atteindre la couleur.** Les
   couleurs système d'Apple s'adaptent seules ; les nôtres sont toutes
   personnalisées, donc elles doivent fournir leurs variantes ou le réglage ne
   fait rien.
10. **Une vibration informe ; elle ne ponctue pas.** Un retour haptique se
    demande explicitement et se justifie au site d'appel. Le défaut d'un
    contrôle est `PrismHaptic.none`, et **toute** vibration passe par
    `PrismHaptics` — une seule porte, donc un réglage utilisateur qui ferme
    réellement tout. Mesuré avant correction : `PrismButton` appelait
    `HapticFeedback.lightImpact()` sans condition, donc les 38 sites d'appel du
    bouton de l'application vibraient, et rien ne pouvait les couper.

Ces règles sont des **tests**, pas des vœux, et elles re-dérivent leurs seuils
au lieu de figer des valeurs hexadécimales — pour qu'une modification qui
*paraît* bonne mais détruit la lisibilité échoue en CI plutôt qu'en production.

| Garde | Ce qu'elle empêche |
|---|---|
| `tokens/prism_colors_test.dart` | une primitive qui cesse de tenir son plancher |
| `theme/prism_contrast_contract_test.dart` | un **rôle** sémantique illisible sur carte / page / surface alternative / verre, **dans les huit combinaisons** |
| `theme/prism_fill_role_guard_test.dart` | un **site d'appel** qui choisit le mauvais rôle |
| `theme/prism_typography_contract_test.dart` | un créneau de `TextTheme` qui retombe sur la police plateforme |
| `theme/prism_voiceover_contract_test.dart` | une jauge ou un compteur qui perd son annonce de valeur |
| `theme/prism_accessibility_scope_test.dart` | un axe d'accessibilité résolu mais jamais branché |
| `apps/mobile/test/haptics_discipline_test.dart` | un `HapticFeedback` hors de `PrismHaptics`, un tap ordinaire qui vibre, un réglage « Vibrations » qui ne coupe pas tout |
| `apps/mobile/test/prism_button_accessibility_guard_test.dart` | un `PrismButton` qui ampute son libellé à grand texte, ou dont VoiceOver fusionne l'action avec le texte voisin |

Les quatre dernières existent parce que les défauts correspondants ont
réellement été livrés, puis mesurés. Chacune a été vérifiée **en cassant
délibérément le code pour la voir rougir** : une garde qui ne peut pas échouer
est une décoration.

La dernière est donnée avec son chemin complet parce qu'elle est la seule à
**ne pas** vivre dans `packages/prism_ui/test/`. Mesuré : ce répertoire compte
41 fichiers de test et `ci-mobile.yml` n'en exécute qu'**un seul**
(`test/rendering/renderer_golden_test.dart`) ; le job requis lance
`flutter test` dans `apps/mobile` uniquement. Une garde posée à côté du code
qu'elle protège y serait verte et incapable de bloquer une fusion — c'est le
même raisonnement que `apps/mobile/test/prism_tokens_contract_test.dart`.

Et une leçon de méthode, payée deux fois : **un correctif qui déplace un défaut
d'un endroit à un autre n'est pas un correctif tant qu'on n'a pas énuméré les
deux côtés.** Le contraste sombre a été corrigé pour 108 sites de premier plan
en cassant 6 sites d'aplat, parce que seul le premier groupe avait été traité.

---

## 11. Les axes d'accessibilité — de deux apparences à huit

Le système portait une dimension : clair ou sombre. Il en porte trois.

### Ce que Flutter donne, et ce qu'il ne donne pas

`MediaQueryData` expose `highContrast` et `boldText`. Il **n'expose pas**
`reduceTransparency` : mesuré sur le SDK 3.44.9, le symbole est absent de tout
`packages/flutter/lib/src`, et `AccessibilityFeatures` de `dart:ui` ne déclare
que `accessibleNavigation`, `invertColors`, `disableAnimations`, `boldText`,
`reduceMotion`, `highContrast` et `onOffSwitchLabels`. Le même instrument rend
236 occurrences pour `highContrast` et 0 pour un motif inexistant : l'absence
est réelle, pas un instrument muet.

Le réglage arrive donc par un **canal de plateforme écrit à la main**
(`com.certigo.mobileapp/accessibility`), ce que le §7 avait déjà tranché pour
les charnières : quand Flutter ne relaie pas une information de plateforme, ce
n'est pas une impasse, c'est un canal à écrire. Toute plateforme qui ne répond
pas vaut `false` — le verre reste du verre, et un canal absent ne peut pas
aplatir le matériau par accident.

### Les huit combinaisons, mesurées

Les valeurs sont **re-dérivées** depuis les deux bases, jamais figées : une
table de huit jeux de valeurs hexadécimales serait exactement la dérive que
l'export de jetons existe pour empêcher. Deux déplacements suffisent — 0.25
pour l'encre, 0.34 pour les arêtes, la seconde plus grande parce qu'une arête
part de 1.70:1 quand une encre part de 5.94:1.

Pire cas mesuré sur chaque colonne, tous accents et domaines confondus :

| Combinaison | Encre / carte | / page | / surfaceAlt | / verre | Aplat sous blanc | Désactivé | Trait du verre | Verre vs page |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| clair | 5.94 | 5.13 | 4.51 | 5.76 | 5.94 | 3.53 | 1.65 | 1.123 |
| clair + opaque | 5.94 | 5.13 | 4.51 | 5.76 | 5.94 | 3.53 | **3.68** | 1.123 |
| clair + contraste | **8.79** | **7.58** | **6.67** | **8.51** | **8.79** | **5.72** | **3.68** | 1.123 |
| clair + contraste + opaque | 8.79 | 7.58 | 6.67 | 8.51 | 8.79 | 5.72 | 3.68 | 1.123 |
| sombre | 5.52 | 6.39 | 4.55 | 4.99 | 5.94 | 3.83 | 2.33 | 1.282 |
| sombre + opaque | 5.52 | 6.39 | 4.55 | 4.99 | 5.94 | 3.83 | **4.98** | 1.282 |
| sombre + contraste | **7.18** | **8.31** | **5.92** | **6.48** | **8.79** | **5.93** | **4.98** | 1.282 |
| sombre + contraste + opaque | 7.18 | 8.31 | 5.92 | 6.48 | 8.79 | 5.93 | 4.98 | 1.282 |

Le verre opaque vaut `#FBFBFD` en clair et `#232736` en sombre. Ce ne sont pas
des couleurs nouvelles : c'est **le pixel déjà affiché** quand la barre flotte
au-dessus de la page, aplati. La séparation des plans est donc rigoureusement
inchangée dans les huit lignes — 1.123 et 1.282, au-dessus du plancher de 1.12.

### Ce qui ne bouge pas, et pourquoi c'est le sujet

Énumérer les huit combinaisons a surtout servi à interdire trois déplacements
de défaut que les quatre premières n'auraient pas montrés :

- **Les plans ne bougent pas.** Pousser un lavis vers le blanc en mode clair
  l'aurait rendu identique à `surface` (`#FFFFFF`) : un défaut de contraste
  remplacé par une perte de hiérarchie.
- **`litEdge` n'est jamais transformé.** En clair il vaut `0x00FFFFFF`,
  transparent par décision mesurée ; un déplacement vers le noir lui aurait
  donné un alpha et fait apparaître un liseré **sombre** en haut du verre
  clair — le défaut que le §4 a supprimé, réintroduit par la porte de service.
- **Reduce Transparency ne touche que le verre.** Renforcer au passage les
  bordures de toutes les cartes aurait été un effet de bord que le réglage n'a
  pas demandé.

Les trois sont des tests, pas des intentions.

### Increase Contrast s'arrête avant 7.0 sur deux surfaces

Le plancher du texte passe de 4.5 à **7.0** sur la carte et la page. Sur la
surface alternative et sur le verre il ne passe qu'à **5.5**, et c'est un
arbitrage nommé : le pire rôle sur le verre sombre plafonne à 6.48. Atteindre
7.00 y demanderait un déplacement de 0.32 au lieu de 0.25, c'est-à-dire faire
converger les six bandes du spectre vers le blanc. La règle 5 — « la clarté
organise ; le chroma réjouit » — coûte ici un point et demi de rapport.

### Bold Text — ce qui est vrai, et ce qui reste ouvert

`Text.build` fusionne `FontWeight.bold`, c'est-à-dire **w700 en dur**, dès que
`MediaQuery.boldTextOf` est vrai (`widgets/text.dart:722`), et ne touche pas à
`fontVariations`. Or Prism épingle son axe `wght` par `fontVariations` sur les
quinze créneaux, et ses registres hauts sont **plus lourds que w700** : Display
à 800, Headline à 750–780.

Selon que le moteur honore l'axe variable ou le `FontWeight`, w700 est donc
soit sans effet, soit un **amincissement** des plus gros titres. **Cette
question n'est pas tranchée ici** : la trancher demande un rendu sur appareil
avec la vraie fonte variable, que la police de test ne fournit pas.

Le correctif est donc écrit pour être juste dans les deux cas — il fait monter
l'axe lui-même et ne supprime rien du comportement de Flutter. Chaque créneau
parcourt 60 % de ce qui le sépare de 900 : le corps atteint exactement 700, la
graisse que Flutter visait, et la hiérarchie reste strictement croissante
(700 < 780 < 800 < 820 < 840 < 852 < 860) là où un w700 uniforme l'aplatissait.
Si l'axe gagne, tout s'alourdit ; s'il perd, le rendu est celui d'aujourd'hui.
Aucune branche n'amincit.

### La jauge était muette

`ReadinessGauge` porte le score de préparation — la métrique North-Star, et
l'information la plus dense du produit. Elle n'annonçait **rien** : un
`CustomPaint` ne produit aucun nœud sémantique, et les deux `Text` du centre se
lisaient comme un nombre nu suivi d'un mot, sans jamais dire que l'un est la
valeur de l'autre. `SignalBars`, qui code le niveau de connaissance par un
nombre de barres, ne disait rien du tout.

Le modèle correct existait déjà dans le même paquet — `PrismProgressBar` annonce
un `label` et une `value` — et il a été généralisé plutôt que réinventé. La
valeur annoncée est le score **visé**, pas l'image de l'animation : lire la
trame ferait parler VoiceOver à chaque frame du tween.

### Le bouton coupait son nom, et VoiceOver le noyait

Deux défauts de `PrismButton`, mesurés en livrant « Ma série », tous deux dans le
composant — donc sur chacun de ses sites d'appel.

- **Troncature.** La face faisait 54 pt **fixes** et le libellé s'élidait. Rendu
  avec les vraies polices à Dynamic Type 2× sur 390 pt, « Réparer ma série » était
  peint dans 233 px et coupé. Une action dont le nom est amputé n'en nomme plus
  aucune. 54 pt devient un **plancher** : un libellé qui ne tient plus sur une ligne
  passe à la ligne et la face grandit. À 1× — et à 2× tant qu'il tient sur une
  ligne — le bouton garde exactement sa hauteur, donc aucun écran ne bouge.
- **Fusion VoiceOver.** Sans `container`, l'étiquette et l'action du bouton
  fusionnaient dans la frontière sémantique la plus proche. Dans un élément de
  liste, toute la carte — titre, texte, faits **et** bouton — était annoncée comme
  un seul bouton. Les boutons Material de Flutter posent `container: true` pour
  cette raison ; `PrismButton` le pose désormais aussi.

La garde vit dans `apps/mobile/test/`, avec un témoin qui prouve que l'instrument
sait voir une fusion : sans lui, « un seul nœud trouvé » pourrait venir d'une mesure
qui n'en voit jamais.
