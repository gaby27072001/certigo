# CERTIGO PRODUCT & EXPERIENCE BIBLE

> **Version :** 1.1 — 22/10/2026 (v1.1 : icônes officielles des éditeurs — §15.11, ADR-016) · **Statut :** source de vérité de toutes les décisions produit, UX et UI de CertiGo.
> **Dérivée de :** `01_CERTIGO_TOP-10-WORTHY_REPORT.md` (recherche et preuves). Chaque décision structurante porte une étiquette de preuve : **[EVIDENCE-BASED]** · **[INDUSTRY PATTERN]** · **[COMPETITOR OBSERVATION]** · **[DESIGN JUDGMENT]** · **[EXPERIMENTAL BET]**. Les références « R§n » renvoient aux sections du Rapport.
> **Traduction en ingénierie :** `03_MASTER_IMPLEMENTATION_PROMPT.md`.

---

## 0. Comment utiliser cette Bible

1. **Ordre de lecture = ordre de décision :** produit (§1–6) → apprentissage (§7) → architecture de l'information (§8) → parcours (§9–13) → iOS (§14) → langage visuel (§15) → écrans North Star (§16) → validation (§17) → Prism (§18).
2. **Règle de précédence :** une décision d'interface ne peut jamais contredire une décision produit ou pédagogique. Si c'est le cas, l'interface a tort.
3. **Règle de changement :** toute modification passe par une entrée datée du *Journal des décisions* (§20) avec sa justification et son étiquette de preuve.
4. **Vocabulaire :** les termes en *italique* sont définis dans le Lexique (§19) et MUST être utilisés tels quels dans l'interface, la documentation et le code (noms de types).

---

## 1. Vision, positionnement, cibles

### 1.1 Vision
> **Become better at technology, every day.** — *Progresser en tech, chaque jour.*

CertiGo est **le lieu quotidien où l'on devient meilleur en technologie** : quand quelqu'un a 5 minutes et veut apprendre quelque chose de vrai en tech, il ouvre CertiGo. Les certifications restent importantes, mais elles deviennent des **destinations** (des *Objectifs*) sur une carte beaucoup plus large (l'*Atlas*).

### 1.2 La thèse produit (ce que personne ne fait encore)
- Duolingo a fait du **mot** et de la **phrase** l'unité d'apprentissage d'une langue. En technologie, l'unité n'est pas le mot : c'est **l'artefact et la décision** — lire un log, prédire une commande, repérer la mauvaise ligne d'une config, choisir entre deux architectures. **[EVIDENCE-BASED R§10 : hiérarchie lire → tracer → écrire ; Parsons, exemples erronés, dépannage structuré]**
- Les apps mobiles actuelles font de la syntaxe ou des fiches ; la pratique « sur des systèmes » vit sur ordinateur (SadServers, KodeKloud, OverTheWire), et les bacs à sable gratuits de Microsoft Learn ne sont plus disponibles. **[COMPETITOR OBSERVATION R§4, R§10]**
- **Positionnement :** *Duolingo vous apprend à lire et dire des mots. CertiGo vous apprend à lire des systèmes et à agir dessus.*
- **Promesse de marque (conservée) :** *Une question. Une idée plus claire.*

### 1.3 Positionnement (format classique)
**Pour** les professionnels et futurs professionnels de la tech qui veulent progresser chaque jour et réussir leurs certifications, **CertiGo est** l'app iPhone de **pratique quotidienne du jugement technique** : des *Situations* réelles en 2 minutes, une mémoire qui s'ancre grâce à la répétition espacée, une carte honnête de ce que l'on sait vraiment. **Contrairement à** YouTube, ChatGPT, Microsoft Learn ou aux banques de questions, CertiGo **sait ce que vous savez**, vous fait **pratiquer sur de vrais artefacts** et vous dit **honnêtement** quand vous êtes prêt.

### 1.4 Cibles (ordre de priorité)
| Segment | Qui | Pourquoi d'abord | Ce qu'ils attendent |
|---|---|---|---|
| **S1 — Candidat certification** (cœur de lancement) | 22–45 ans, développeurs, admins, consultants, reconversions, préparant AZ-900 / AI-900 / SC-900 / DP-900 puis AZ-104 | Intention claire, résultat mesurable, disposition à payer **[INDUSTRY PATTERN R§2]** | Savoir quoi faire chaque jour, savoir s'il est prêt, ne pas perdre ce qu'il a appris |
| **S2 — Praticien qui veut rester à jour** | Architectes, consultants, SE, DevOps en poste | Usage « entre deux réunions », valeur de la fraîcheur | Rester affûté, comprendre ce qui change, combler des trous |
| **S3 — Curieux / débutant en tech** | Étudiants, profils non techniques en transition | Volume, bouche-à-oreille | Comprendre sans être intimidé, progresser visiblement |
| **S4 — Équipes (plus tard)** | Managers, partenaires, écoles | Monétisation B2B2C après preuve B2C | Suivi, objectifs d'équipe, sièges (StoreKit Multiseat iOS 27) |

**Hors cible au lancement :** enfants et collégiens (âge minimum à confirmer, *Declared Age Range* pour les fonctions sociales et IA). **[DESIGN JUDGMENT]**

### 1.5 Jobs to be done
1. **Quotidien —** « Quand j'ai quelques minutes, aide-moi à faire un vrai progrès en tech sans avoir à décider quoi faire. »
2. **Objectif —** « Quand je m'engage sur une certification, prépare-moi efficacement et dis-moi honnêtement quand je suis prêt. »
3. **Clarté —** « Quand je ne comprends pas, explique-le à partir de là où j'en suis, pour que ça fasse *déclic*. »
4. **Mémoire —** « Ce que j'ai appris il y a trois semaines, fais en sorte que je ne le perde pas. »
5. **Preuve —** « Montre-moi (et aux autres, si je le veux) que je progresse réellement. »
6. **Fraîcheur —** « La tech change chaque mois : dis-moi quand ce que je sais devient faux. »

### 1.6 Proposition de valeur (une phrase par bénéfice)
- **Pratique réelle en 2 minutes :** des *Situations* sur de vrais artefacts (code, logs, configs, commandes, schémas), pas des définitions.
- **Une mémoire qui tient :** révision espacée + rappels différés ; ce que vous apprenez reste.
- **Il sait ce que vous savez :** un modèle personnel par concept (profondeur × mémoire × fausses idées) qui s'enrichit chaque jour.
- **Honnêteté :** une *Préparation* fondée sur des preuves, avec son incertitude, jamais un score décoratif.
- **Natif iPhone :** 1 tap depuis un widget, Siri ou Spotlight ; hors ligne ; accessible à tous.

---

## 2. North Star et système de métriques

### 2.1 Métrique North Star
**WDL — Weekly Durable Learners (Apprenants durables hebdomadaires)** : nombre d'utilisateurs qui, sur 7 jours glissants, ont **(a)** réussi au premier essai **≥ 3 rappels différés** (concepts revus ≥ 72 h après leur dernière exposition) **ou (b)** fait passer **≥ 1 concept** à l'état *Ancré*.
- Pourquoi : la rétention différée est le meilleur indicateur accessible d'apprentissage réel ; elle **ne peut pas** être gonflée par du temps passé ou du volume. **[EVIDENCE-BASED R§5 : testing effect, spacing]**
- Elle distingue **« apprend grâce à CertiGo »** de **« utilise beaucoup CertiGo »**.

### 2.2 Système de métriques
| Famille | Métrique | Définition | Usage |
|---|---|---|---|
| **Valeur d'apprentissage** | Gains durables / utilisateur / semaine | Concepts passés à *Ancré* ou *Maîtrisé* | Pilotage produit |
| | Précision des rappels différés | % correct au 1er essai sur révisions ≥ 72 h | Qualité de l'ordonnancement |
| | **Efficacité d'apprentissage** | Gains durables ÷ minutes actives | Distingue apprendre de consommer |
| | Transfert | % correct sur items *Situation* / artefacts jamais vus d'un concept *Ancré* | Profondeur réelle |
| **Maîtrise** | Profondeur moyenne | Échelon moyen atteint par concept actif (§7.4) | Progression qualitative |
| | Calibration | Score de Brier de la confiance déclarée vs résultat | Métacognition |
| **Régularité** | Semaines de *Rythme* tenues | Semaines où l'objectif hebdo (jours) est atteint | Habitude saine (≠ série quotidienne) |
| **Rétention** | D1 / D7 / D30, W4, W12 | Cohortes | Santé produit |
| | Retours après pause | % qui reviennent après ≥ 7 j d'absence | Absence de culpabilisation |
| **Amour** | « Très déçu si CertiGo disparaissait » | Sondage Sean Ellis (cible ≥ 40 %) | Product-market fit |
| | Note App Store, avis spontanés | — | Qualité perçue |
| **Valeur sociale** | % d'utilisateurs avec ≥ 1 ami ou *Squad* | — | Ancrage social |
| | Objectifs de *Squad* atteints | % des semaines | Coopération |
| | Cartes de capacité partagées | Partages / 1 000 WAU | Bouche-à-oreille qualifié |
| **Résultat** | Réussite déclarée à l'examen | Résultats rapportés (opt-in) | Outcome |
| | Calibration de la *Préparation* | Brier / courbe de fiabilité vs résultats réels | Honnêteté du modèle |
| | Temps jusqu'à *Prêt* | Jours entre objectif et bande *Prêt* | Efficacité |

### 2.3 Garde-fous (alertes si dépassés)
- Taux de désactivation des notifications > 15 % / mois ; désinstallations dans les 24 h suivant une notification.
- Sessions > 2 h/jour (bien-être) ; volume sans gain (minutes ↑, gains durables ↓) ; usage de l'IA avant tentative.
- Signalements d'erreurs de contenu > 1 % des items vus ; réponses IA jugées fausses > 2 %.
- Écart de calibration de la *Préparation* (prévu vs observé) > 10 points.

### 2.4 Ce qu'on n'optimise **jamais** seul
DAU, temps de session, nombre de leçons, XP, longueur de série. **[EVIDENCE-BASED R§7 : la gamification optimise ce qu'elle mesure]**

---

## 3. Trois directions produit et recommandation

> Trois interprétations **produit** (pas trois habillages). Chacune a été évaluée contre la recherche du Rapport.

### Direction A — **Intelligent Learning OS** (« le système qui sait ce que vous savez »)
| Axe | Description |
|---|---|
| Philosophie | CertiGo est votre système d'exploitation d'apprentissage : il planifie, ordonnance, mesure et dit la vérité. Calme, premium, maîtrise. |
| Boucle centrale | Plan → Séance adaptative → Preuves → Mise à jour du modèle → Plan |
| Home | « Aujourd'hui » = un plan : une séance, une prévision mémoire, une préparation chiffrée |
| Apprentissage | Révisions espacées, séances adaptatives, examens blancs, lecture profonde |
| Progression | Maîtrise, mémoire, préparation calibrée ; graphiques |
| Social | Minimal (binôme de responsabilité optionnel) |
| IA | Planificateur et diagnosticien discret ; « pourquoi cette séance ? » |
| Identité visuelle | Calme, quasi monochrome, données en couleur, typographie éditoriale, Swift Charts |
| Forces | Crédibilité, efficacité d'apprentissage, confiance, accessibilité, potentiel B2B |
| Faiblesses | Peu d'attachement émotionnel ; risque d'outil froid ; bouche-à-oreille faible |
| Risques | Retour quotidien dépendant de la discipline ; anxiété du « quantified self » |
| Audience | S1 sous échéance, S2 disciplinés |
| Différenciation | Forte sur l'honnêteté et le modèle de mémoire ; faible en émotion |
| Fit iOS | Excellent (widgets, Live Activities, Charts, Foundation Models) |
| Potentiel long terme | Solide mais de niche (proche d'un « Anki premium ») |

### Direction B — **Professional Duolingo for Tech** (« le jeu quotidien de la tech »)
| Axe | Description |
|---|---|
| Philosophie | Rendre la tech aussi quotidienne qu'un jeu : chemin, série, XP, ligues, quêtes, personnage ; ton pro mais énergique |
| Boucle centrale | Ouvrir → nœud du chemin → leçon → XP / série → ligue → revenir |
| Home | Le chemin linéaire |
| Apprentissage | Leçons courtes, exercices variés, peu de profondeur |
| Progression | XP, niveaux, couronnes, chemin |
| Social | Ligues publiques, amis, quêtes entre amis |
| IA | « Explique ma réponse », jeux de rôle d'incident |
| Identité visuelle | Couleurs vives, mascotte, animations rebondissantes, sons |
| Forces | Habitude, viralité, modèle mental simple ; le genre a gagné un ADA (Duolingo 2023) |
| Faiblesses | Me-too (Mimo, Enki, Sololearn) ; apprentissage superficiel ; XP farming ; infantilisant pour des pros ; le chemin linéaire contredit la révision adaptative |
| Risques | Mécaniques de rétention qui dépassent l'apprentissage ; dark patterns ; image « jeu, pas prépa sérieuse » |
| Audience | S3, débutants |
| Différenciation | Faible (gabarit de catégorie) |
| Fit iOS | Bon mais paradigme générique, transposable partout |
| Potentiel long terme | Élevé seulement avec une exécution exceptionnelle, face à un Duolingo qui s'étend lui-même |

### Direction C — **Living Tech World** (« un monde de la tech à explorer »)
| Axe | Description |
|---|---|
| Philosophie | Un univers vivant de la technologie : régions, découvertes quotidiennes, événements, communauté ; la curiosité comme moteur |
| Boucle centrale | Découvrir → Explorer → Essayer → Suivre un sujet → Communauté → Revenir |
| Home | Carte-monde + découverte du jour + événements |
| Apprentissage | Exploratoire : explications courtes, défis, moins de structure |
| Progression | Exploration de territoires, collections, couverture de la carte |
| Social | Communautés, défis publics, événements saisonniers |
| IA | Fil personnalisé, « ce qui a changé cette semaine » |
| Identité visuelle | Carte riche, éditorial immersif (Apple Music, DailyArt) |
| Forces | Colle à l'ambition « apprendre la tech » ; fraîcheur ; partageable ; marque forte |
| Faiblesses | Efficacité d'apprentissage plus faible (consommation > récupération) ; coûts de contenu et de modération ; valeur diffuse ; démarrage à froid communautaire |
| Risques | Devenir une app d'actualités ; impossible à tenir pour une petite équipe |
| Audience | S2, S3 curieux |
| Différenciation | Forte visuellement, non prouvée pédagogiquement |
| Fit iOS | Correct (widgets, Spotlight) |
| Potentiel long terme | Élevé si une communauté se forme ; plateforme |

### 3.4 Recommandation — **D. « L'Atlas vivant »** (combinaison A + B + C)
- **La colonne vertébrale de A** : modèle d'apprentissage, honnêteté, calme pendant l'effort, *Préparation* fondée sur des preuves.
- **Le rituel et la joie de B**, purgés de leurs dark patterns : *Situation du jour*, *Rythme* hebdomadaire, *Missions* courtes, célébrations *Réfraction*, *Squads* coopératives.
- **Le monde de C**, rendu utile : l'*Atlas* comme carte personnelle de ce que l'on sait (et pas comme un fil de contenus), événements saisonniers rares, *Mises à jour de connaissance* (fraîcheur).
- **Pourquoi :** A seul n'est pas aimé, B seul n'apprend pas assez et n'est pas distinctif, C seul n'est pas tenable. La combinaison maximise apprentissage durable × régularité saine × distinction. **[DESIGN JUDGMENT, fondé sur R§5–R§11]**

---

## 4. Modèle produit

### 4.1 Les boucles qui existent (et celles qui n'existent pas)
| Boucle | Échelle | Étapes | Statut |
|---|---|---|---|
| **Apprentissage** | 30 s – 3 min | Situation ou concept → tentative (récupération) → feedback « pourquoi » → correction de la fausse idée → planification | **Cœur** |
| **Quotidienne** | 1 jour | Signal (heure choisie, widget, curiosité) → *Aujourd'hui* → *Séance* 5/15/45 → *Résultats* (l'Atlas change) → indice pour demain | **Cœur** |
| **Maîtrise** | Semaines | Apprendre → oublier un peu → rappel espacé → renforcer → monter d'échelon (§7.4) → *Ancré* → *Maîtrisé* → entretien | **Cœur** |
| **Objectif / carrière** | Mois | Objectif → plan → progression sur la route → *Préparation* → examen blanc → examen → résultat → débrief → *Passeport* → objectif suivant | **Cœur** (S1) |
| **Sociale** | Jour / semaine | *Situation du jour* → distribution des réponses → partage sans spoiler → un ami joue → comparer le raisonnement → objectif de *Squad* → encouragement | **Secondaire, opt-in** |
| **Découverte** | Ponctuelle | Recherche / Spotlight / curiosité → fiche concept → essai 1 min → ajout à l'Atlas → nouvelles situations | **Secondaire** |
| **Fraîcheur** | Mois | Le service change → contenu mis à jour → *Mise à jour de connaissance* → rafraîchissement 1 min | **Différenciante** |
| **Acquisition** | — | Carte de capacité ou Situation partagée → lien universel (aperçu web / App Clip) → essai → installation | **Secondaire** |

**Boucles volontairement absentes :** XP → ligue publique → XP (récompense l'activité, pas l'apprentissage) ; économie de gemmes ; fil de contenus infini ; pression par la peur de perdre. **[EVIDENCE-BASED R§7, R§6]**

### 4.2 Modèle de contenu (résumé ; détail §7)
*Concept* (nœud de l'Atlas) · *Carte* (expliquer, exemple travaillé, schéma, artefact) · *Item* (un exercice d'un format donné, un échelon donné) · *Situation* (mini-cas : contexte + artefact + 1 à 3 décisions + explication + à retenir) · *Route* (un objectif : certification ou compétence, avec ses objectifs pondérés) · *Source* (lien + date de vérification) · *Fausse idée* (erreur typique nommée, liée à des distracteurs).

Règles : contenu **original** uniquement (aucun « dump », aucune reformulation d'item d'examen — violation des accords candidats Microsoft) ; **chaque item publié est relu par un humain** ; l'IA peut proposer des brouillons et des variantes, jamais publier ; chaque concept porte ses **sources datées** ; chaque route porte la **date de version du programme d'examen**. **[INDUSTRY PATTERN R§10 ; EVIDENCE-BASED R§9 sur la qualité des items générés]**

### 4.3 Modèle de rétention
- **Intrinsèque d'abord** (Autodétermination) : compétence visible (Atlas, échelons, *Déclic*), autonomie (durée, objectif, rythme choisis), appartenance (*Squads*, amis). **[EVIDENCE-BASED R§6–R§7]**
- **Habitude saine :** intention d'implémentation (« quand / où » choisis à l'onboarding), *Rythme* hebdomadaire avec jours de repos, présence passive (widget), rituel (*Situation du jour*). **[EVIDENCE-BASED R§6]**
- **Retour sans honte :** après une absence, l'app accueille (« On reprend en douceur : 3 minutes pour raviver l'essentiel ») ; jamais de compte à rebours de perte.
- **Valeur cumulée :** l'Atlas, l'historique des fausses idées corrigées, les preuves de *Préparation*, le *Passeport* et la personnalisation rendent CertiGo **plus utile au jour 90 qu'au jour 1**.

### 4.4 Principes de monétisation
- **Gratuit, pour toujours :** *Situation du jour*, séances *Express* illimitées, révisions espacées, Atlas, explications standard, amis et *Squads*.
- **CertiGo Pro (abonnement) :** routes de certification complètes, *Séance* et *Plongée* illimitées, examens blancs et débriefs, *Préparation* détaillée et prévision, IA approfondie (expliquer mon erreur à volonté, explain-it-back, comparer, plan), packs hors ligne complets, statistiques de calibration. Ancrages (doc Monétisation, juillet 2026) : 9,99–14,99 €/mois ; 79–99 €/an ; essai gratuit avec rappel avant facturation.
- **Plus tard :** offre *Squad/Famille*, sièges d'équipe (StoreKit Multiseat iOS 27), packs examen ponctuels.
- **Jamais :** publicité dans l'apprentissage ; paywall avant la première valeur ; énergie / vies qui bloquent la pratique ; achat de protection de série ; avantages compétitifs payants ; résiliation difficile. **[EVIDENCE-BASED R§7 dark patterns ; DESIGN JUDGMENT]**

---
## 5. La magie, la marque et la personnalité

### 5.1 La « magie » de CertiGo : une combinaison, pas un gadget
Duolingo a Duo + la série + la boucle de leçon. CertiGo aura **trois éléments indissociables** :

| Élément | Ce que c'est | Pourquoi c'est la bonne magie |
|---|---|---|
| **La Situation du jour** | Chaque jour, une vraie situation technique par région (un log, une config, une décision), identique pour tous, jouée en 2 minutes, révélée avec la distribution des réponses de la communauté, partageable sans spoiler | Rituel fini (« NYT Games / Wordle de la tech »), utile, social, centré apprentissage **[COMPETITOR OBSERVATION R§4 ; INDUSTRY PATTERN R§7]** |
| **L'Atlas** | La carte vivante de ce que **vous** savez : régions, territoires, concepts ; la luminosité suit votre mémoire, la forme suit votre profondeur ; les certifications sont des routes | Valeur qui s'accumule ; visuel ; honnête ; impossible à obtenir d'un chatbot ou d'une vidéo **[DESIGN JUDGMENT R§17]** |
| **Le Déclic** | Le moment signature : quand une fausse idée est corrigée ou qu'un concept s'*ancre*, la lumière se **réfracte** dans la couleur de la région, avec un motif sonore de 3 notes et une haptique « clic » | Un moment physique que l'on raconte **[OFFICIAL APPLE / INDUSTRY PATTERN R§3 : moment signature des lauréats ADA]** |

Évaluation des pistes proposées (critères : utile · unique · mémorable · partageable · visuel · centré apprentissage) :
| Piste | Verdict | Devient |
|---|---|---|
| Daily Tech Challenge | ✅ retenue, transformée | *Situation du jour* (décision sur artefact, pas quiz de culture) |
| Knowledge Map / Skill Galaxy / Tech Tree | ✅ fusionnées | *Atlas* (carte navigable, pas une galaxie décorative ni un arbre de déblocage linéaire) |
| Readiness | ✅ transformée | *Préparation* honnête (§7.7) — ancre de confiance, pas la magie |
| Personal AI Coach | ⚠️ transformée | IA contextuelle sans persona (§6.6, §12) |
| Tech Streak | ⚠️ transformée | *Rythme* hebdomadaire (§6.3) — utile, pas distinctif |
| Mastery Rings | ❌ rejetée | Trop proche de la signature Apple Fitness ; remplacée par la *Profondeur* (§7.4) |
| Interactive Labs | ⚠️ en sortie de téléphone | *Passage au lab* (§7.9) |
| Skill Passport | ✅ secondaire | *Passeport* (preuve partageable, jamais présentée comme une certification) |
| Daily Discovery | ⚠️ absorbée | Dans la *Situation du jour* et l'Atlas |
| Knowledge Battles | ⚠️ différée | *Défis* asynchrones notés sur la justesse et la calibration, pas la vitesse (§6.5) |

### 5.2 Le test Apple Design Award : « pourquoi Apple sélectionnerait CertiGo ? »
Réponse sérieuse, à mériter (aucune app de certification IT n'apparaît parmi ~150 distinctions ADA 2023–2026 : espace libre, mais aucun passe-droit) **[OFFICIAL APPLE R§3]** :
- **Catégorie visée n°1 — Inclusivity.** CertiGo serait la première app où **le code, les logs, les configs et les schémas sont pleinement accessibles** : VoiceOver lit un artefact ligne par ligne (numéro, contenu, anomalie signalée), les schémas ont une description structurée navigable (composants, liaisons), le texte d'artefact supporte AX5 avec retour à la ligne, aucun verdict n'est porté par la couleur seule, 8 langues d'interface, mode audio, temps majoré en examen blanc. Les lauréats Inclusivity récents (Speechify 2025, Guitar Wiz 2026, développeur solo) montrent que la profondeur d'accessibilité bat la taille d'équipe.
- **Catégorie n°2 — Delight and Fun.** Une idée lisible en une phrase (*« une situation technique par jour »*) et un moment physique (*Déclic*).
- **Catégorie n°3 — Interaction.** Trouver l'erreur d'un tap, Composer une commande au pouce, réviser une carte depuis un widget interactif ou Siri, Live Activity d'examen blanc.
- **Concept remarquable :** la tech apprise par ses artefacts et ses décisions, pas par ses définitions.
- **Interaction distinctive :** « taper la ligne fautive » dans un artefact vivant, avec haptique de sélection et révélation explicative.
- **Innovation d'apprentissage :** carte personnelle Profondeur × Mémoire ; fausses idées nommées ; Préparation qui montre son incertitude (cf. *The Outsiders*, finaliste Interaction 2026, pour sa visualisation de readiness).
- **Technologies Apple pertinentes :** Liquid Glass (navigation seulement), WidgetKit interactif, Live Activities, App Intents / Spotlight / Siri, Foundation Models ancrés (sur le modèle de CellWalk), SpeechAnalyzer pour l'explain-it-back, StoreKit 2, Accessibility Nutrition Labels.
- **Brouillon de justification de jury (à mériter, pas à revendiquer) :** « CertiGo transforme l'apprentissage de la tech en situations courtes et réelles. Chaque artefact fonctionne avec VoiceOver et les plus grandes tailles de texte, et un tuteur sur l'appareil explique chaque erreur à partir de contenu vérifié. »

### 5.3 Personnalité de l'app : « Cœur calme, expression méritée »
L'hypothèse du fondateur (*Expressive Minimalism*) est **validée et précisée** : l'expression vient de la **hiérarchie** (échelle, graisse, couleur, contenant, mouvement), pas de l'ornement ; son intensité est **proportionnelle à la rareté** de l'événement. **[EVIDENCE-BASED R§3 : Material 3 Expressive, 46 études ; HIG Motion]**
| Moment | Registre | Exemples |
|---|---|---|
| Pendant l'effort (lecture, réponse) | **Calme** | Fond neutre, une seule zone d'action, aucun mouvement non sollicité |
| Transitions et feedback | **Vivant** | Haptique + ton court ; le panneau de feedback se déploie ; le symbole change par *Magic Replace* |
| Jalons | **Expressif** | Réfraction plein écran, motif sonore, carte de partage |

**Mode Calme** (réglage) : réduit l'intensité des célébrations sans retirer l'information (une minorité significative préfère des versions moins intenses). **[EVIDENCE-BASED R§3]**

**Ce que le fondateur aime dans ses références (et ce qu'on en garde) :**
| Référence | Ce qu'il aime probablement | Principe retenu | Ce qu'on ne copie pas |
|---|---|---|---|
| Apple Music | Le contenu en héros, l'interface s'efface, grandes typos | Le contenu (situation, artefact) occupe l'écran | Les visuels immersifs d'album (pas de contenu équivalent) |
| Airbnb | Délice dans de petits objets tactiles (icônes 3D), flux sobres | Le délice vit dans les **glyphes et moments**, pas dans les écrans de travail | La 3D lourde (coût, performance) |
| Duolingo | Feedback qu'on sent, hiérarchie de récompenses, système unifié | Échelle de célébrations (§13), son + haptique | Personnage omniprésent, culpabilisation, ligues aux minutes |
| DailyArt | Un objet héros par jour + une courte histoire ; rituel calme | *Situation du jour* | — |
| Coursera | Crédibilité par la retenue ; « amical sans être enfantin » | Ton adulte, typographie sérieuse | Le côté institutionnel froid |
| Kartable | Structure, alignement sur l'examen, preuve de résultats | Routes alignées sur les objectifs officiels ; preuves | — |
| Lovable | Chaleur dans une catégorie technique ; un seul champ héros ; un dégradé vivant | Chaleur du ton ; un accent vivant | Le dégradé partout |

**Tensions arbitrées :** personnalité dans un personnage (Duolingo) **vs** dans le contenu (Apple Music, DailyArt) → **dans le contenu et les symboles** ; célébrer chaque réponse **vs** retenue → **haptique + ton à chaque réponse, visuel seulement aux jalons** ; verre et profondeur **vs** lisibilité → **jamais de texte courant sur du verre**. **[EVIDENCE-BASED R§3]**

### 5.4 Personnage de marque : décision
| Option | Verdict |
|---|---|
| A. Garder les 7 mascottes dérivées des icônes Azure | **Rejeté** — hors des conditions d'usage des icônes Microsoft (« Don't use Microsoft product icons to represent your product »), lie la marque à un seul éditeur, risque d'infantilisation **[EVIDENCE-BASED R§3 ; pas un avis juridique]** |
| B. Une troupe de personnages à la Duolingo | **Pas maintenant** — gains d'apprentissage faibles chez l'adulte, coût pluriannuel, risque d'image incompétente |
| C. Un **glyphe compagnon abstrait** dérivé du système de symboles (nom de travail : *la Facette*) | **À tester** — chaleureux sans être enfantin ; n'apparaît que dans 3 types de moments (célébration ≥ niveau 2, états vides, retour après absence) ; **n'enseigne jamais, n'est jamais triste, ne culpabilise jamais** ; absent des écrans de question |
| D. **Aucun personnage** : symboles, mouvement, son, voix | **Base retenue** — le plus premium et crédible (Strava, Linear) |

**Décision :** construire sur **D**, prototyper **C** et le tester contre D auprès de 8–12 apprenants cibles avant tout engagement. **[EVIDENCE-BASED + DESIGN JUDGMENT R§3]**
Corollaires : retirer le bleu **#0078D4** (couleur primaire par défaut de Fluent UI → affiliation implicite à Microsoft) ; citer les éditeurs par leur **nom officiel** (« Préparer AZ-900 ») ; représenter chaque produit réel par son **icône officielle non modifiée**, issue du kit de l'éditeur et accompagnée de son nom (§15.11, décision du fondateur du 22/10/2026) — l'icône d'un éditeur désigne **son** produit, jamais CertiGo ; faire valider la politique par un juriste (DR-010).

**Alerte nom de marque :** un concurrent direct s'appelle **Certingo** (certingo.app, 112 certifications, répétition espacée) et un autre **CertiG33k** → risque de confusion et de conflit de marque à instruire avant tout investissement de marque (Decision Request). Par ailleurs, « Certi- » ancre la perception sur la certification alors que l'ambition est plus large : garder CertiGo à court terme (équité, référencement du coin d'entrée certification) et réévaluer le nom quand l'Atlas dépassera les certifications. **[COMPETITOR OBSERVATION ; DESIGN JUDGMENT]**

### 5.5 Voix et ton : « le pair compétent et bienveillant »
Précis, chaleureux, une pointe d'esprit, jamais aux dépens de l'apprenant ; ni culpabilisant ni infantile. **[COMPETITOR OBSERVATION R§7 : Monzo ; EVIDENCE-BASED R§7 : confirmshaming]**
| Situation | ✅ Écrire | ❌ Ne pas écrire |
|---|---|---|
| Mauvaise réponse | « Pas tout à fait. Le NSG filtre au niveau du sous-réseau ; ici il fallait… » | « Faux ! » · « Dommage ! » |
| Erreur avec certitude | « Tu étais sûr : ces erreurs-là se corrigent très bien. » | « Oups, trop confiant ! » |
| Rappel | « Ta Situation du jour : un log Kubernetes qui ment. 2 min ? » | « Ne casse pas ta série ! 🔥 » · « … compte sur toi » |
| Retour après absence | « Bon retour. On reprend en douceur. » | « Tu nous as manqué… » · « Ta flamme s'est éteinte » |
| Refus de « dump » | « On n'utilise jamais de questions d'examen réelles : c'est interdit et ça n'apprend rien. Voici une situation originale sur ce sujet. » | — |
| Jalon | « *Groupes de sécurité réseau* : ancré. Tu le retrouveras dans 12 jours. » | « Tu es un génie ! » |

### 5.6 Vocabulaire propre
*Situation* · *Situation du jour* · *Atlas* · *Région* · *Territoire* · *Concept* · *Route* · *Déclic* · *Découvert / En pratique / Ancré / Maîtrisé* · *S'estompe* · *Fausse idée* · *Échelon* · *Express / Séance / Plongée* · *Rythme* · *Squad* · *Défi* · *Mission* · *Préparation* · *Passeport* · *Mise à jour de connaissance*. Définitions : §19.

### 5.7 Signature sensorielle
- **Réfraction** (visuel) : un trait de lumière traverse une facette et se décompose dans la couleur de la région ; 3 intensités (§13).
- **Motif « Déclic »** (son) : 3 notes ascendantes, < 600 ms, jouées en session audio *ambient* (respecte le mode silencieux), désactivables.
- **Haptique « Déclic »** : motif Core Haptics court (deux transitoires nettes, la seconde plus intense) ; partout ailleurs, haptiques système selon leur sens documenté.
- **Chaque moment signature existe en 3 variantes :** complète · Reduce Motion (fondu + haptique + son) · silencieuse (visuel seul). **[EVIDENCE-BASED R§3]**

### 5.8 Icône
L'icône actuelle (« C » hexagonal en verre indigo, étincelle centrale) est cohérente avec Liquid Glass et l'accent indigo. L'étincelle à 4 branches est devenue le symbole générique de « l'IA » ; **SHOULD** être explorée une variante où l'étincelle devient une **facette réfractant la lumière** (lien avec Prism / Réfraction). Test de préférence et de reconnaissance avant changement. **[DESIGN JUDGMENT]**

---

## 6. Modèles produit détaillés

### 6.1 Modèle de progression
| Niveau | Mesure | Affichage |
|---|---|---|
| **Concept** | Profondeur (échelon 1–5) × Mémoire (rétention prédite) × fausses idées | État (§7.4), glyphe, historique |
| **Territoire** | Part de concepts *Ancrés* / *Maîtrisés* | Anneau de territoire dans l'Atlas |
| **Région** | Concepts ancrés, profondeur moyenne, **cote de compétence** (Glicko-2, avec incertitude) | Fiche région ; la cote n'apparaît qu'en mode classé (opt-in) |
| **Route (objectif)** | Couverture pondérée, profondeur, mémoire, examens blancs → *Préparation* | Écran Objectif |
| **Personne** | *Passeport* : concepts maîtrisés par région, routes accomplies, résultats d'examen déclarés, calibration | Profil, carte de partage |

**MUST NOT :** XP comme mesure principale, niveaux génériques, « couronnes » de leçons. **[EVIDENCE-BASED R§7]**

### 6.2 Modèle de gamification — « le jeu au service de l'apprentissage »
Règles : (1) récompenser la maîtrise et la régularité espacée, jamais les minutes ; (2) pardonner par défaut ; (3) compétition appariée, plafonnée, opt-in ; (4) social coopératif d'abord, privé par défaut ; (5) ne jamais vendre le soulagement d'une anxiété ; (6) juger chaque test A/B sur l'apprentissage + garde-fous. **[EVIDENCE-BASED R§7]**

| Mécanique existante ou candidate | Verdict | Conception CertiGo | But d'apprentissage | Garde-fou |
|---|---|---|---|---|
| Série quotidienne | **TRANSFORMER** | *Rythme* hebdomadaire primaire (§6.3) ; série quotidienne **optionnelle** (désactivée par défaut, affichée dans Profil seulement) | Régularité espacée | Aucun message de perte |
| Réparation / gel payants (gemmes) | **SUPPRIMER** | Rattrapage gratuit : 3 rappels faits = semaine sauvée ; jours de repos gagnés par les révisions à l'heure | Revenir après un raté | Jamais payant |
| Gemmes + boutique | **SUPPRIMER** (UI) | Aucune monnaie. Plus tard éventuellement : thèmes cosmétiques **gagnés** | — | Pas de monnaie, pas d'aléatoire payant |
| XP (soft cap 2×) | **CACHER / TRANSFORMER** | *Points de maîtrise* internes : 1re réussite × difficulté + gains de maîtrise vérifiés ; contenu répété dégressif ; plafond quotidien ; non affichés comme score | Pondère la vraie progression | Pas de farming |
| Niveaux génériques | **SUPPRIMER** | Remplacés par la Profondeur et l'Atlas | — | — |
| Objectif quotidien | **GARDER, minimal** | « 1 séance Express » suffit pour un jour de Rythme | Seuil bas = habitude | Découplé de toute perte |
| Ligues XP à 10 paliers | **TRANSFORMER** | *Ligues de progression* **opt-in**, appariées par cote et par route ; score = points de maîtrise plafonnés + régularité ; pas de relégation les 4 premières semaines ; 2 semaines de grâce ; affichage des ±3 voisins uniquement | Comparaison atteignable | Opt-in, pas de classement absolu |
| Classements globaux absolus | **SUPPRIMER** | — | — | Exemplars inatteignables = abandon |
| Quêtes | **TRANSFORMER** | *Missions* hebdomadaires, ≤ 3, liées à des compétences (« Ancrer 5 concepts réseau », « Corriger une fausse idée », « Faire une Plongée »), dont 1 coopérative de Squad | Pratique délibérée ciblée | Jamais de corvée |
| Succès | **TRANSFORMER** | Rares, de maîtrise ou d'artisanat (1er concept *Maîtrisé*, territoire complet, examen blanc ≥ 80 %, 10 fausses idées corrigées, passage au lab) | Signal de compétence | Pas de badge de volume |
| Saisons mensuelles | **TRANSFORMER** | 4 temps forts par an au plus, liés à de vrais moments (rentrée, « Sécurité en octobre », sprint de décembre type Advent of Code de 12 jours, après Build) ; objectif communautaire coopératif ; récap | Nouveau départ, communauté | Pas de battle pass |
| Célébrations | **GARDER** | Échelle 0–3 (§13), informatives (« VPC : 82 %, +9 ») | Feedback | Habituation contrôlée |
| Mascottes | **SUPPRIMER** | Voir §5.4 | — | — |
| Barres de progression | **GARDER** | Progression « rapide puis lente » ; crédit du test de placement comme progression initiale | Gradient d'objectif | Pas de lenteur au début |
| Récompenses aléatoires | **CACHER** | Petites surprises gratuites et rares (ex. une Situation bonus) | Curiosité | Jamais payantes |
| Messages d'aversion à la perte | **SUPPRIMER** | « Pas aujourd'hui » neutre | — | DSA art. 25, lignes directrices UE mineurs |

### 6.3 Modèle d'habitude et de rétention
- **Rythme hebdomadaire** : l'utilisateur choisit 3–6 jours par semaine ; un jour compte dès **1 séance Express** (~2–5 min) ; **2 jours de repos** possibles ; pause vacances / examen jusqu'à 4 semaines ; le meilleur rythme reste visible après une pause ; on compte les **semaines tenues**, pas les jours consécutifs. **[EVIDENCE-BASED R§6 : Lally 2010, Milkman 2021, Beshears 2021 ; COMPETITOR OBSERVATION : Apple Fitness pauses]**
- **Retour récompensé** : la première séance après un raté est mise en valeur (« Revenir, c'est ce qui compte ») — la stratégie gagnante de la mégaétude de Milkman. **[EVIDENCE-BASED R§6]**
- **Intention d'implémentation** : à l'onboarding, « quand » et « où » ; rappel aligné sur ce signal. **[EVIDENCE-BASED R§6, effet d = 0,65 ; mais faible à grande échelle → combiner avec le widget]**
- **Indices passifs > notifications** : widget, Live Activity, Situation du jour ; ≤ 1 notification / jour ; arrêt silencieux après 3 ignorées. **[EVIDENCE-BASED R§6]**
- **Nouveau départ** : lundi, début de mois, après un examen : proposer un nouvel objectif ou une Plongée. **[EVIDENCE-BASED R§6 : fresh start]**

### 6.4 Modèle social — coopératif d'abord, privé par défaut
| Fonction | Verdict | Conception |
|---|---|---|
| Amis | **Garder** | Pseudonymes ; ajout par lien / QR / code ; **pas** d'import de contacts par défaut ; ce qu'un ami voit est choisi (Rythme, jalons, Situation du jour) |
| **Squads** (3–8, même route ou même mois d'examen) | **Construire (cœur)** | Objectif hebdomadaire **commun** (ex. 20 jours de Rythme cumulés, 30 concepts ancrés) ; encouragements en 1 tap ; Mission coopérative ; classement interne optionnel sur la **progression** |
| Encouragements (kudos) | **Garder** | 1 tap, prédéfinis, sans texte libre au début |
| Défis asynchrones | **Construire** | Même jeu de 5 items, appariés par cote ; score = justesse + calibration de la confiance ; **pas de chronomètre** |
| Distribution de la Situation du jour | **Construire** | Agrégats anonymes après réponse |
| Cartes de partage | **Transformer** | Capacité et jalons, sans spoiler, jamais quotidiennes par obligation |
| Fil d'activité | **Limiter** | Jalons uniquement, désactivé par défaut |
| Ligues publiques | **Opt-in, appariées** (§6.2) | — |
| Duels temps réel, salles d'étude en direct, chat libre | **Différer** | Coût de modération ; « study-with-me » sans gain prouvé **[EVIDENCE-BASED R§8]** |

**Exigences de sécurité (MUST) :** privé par défaut ; blocage, masquage, signalement ; aucun ajout à une Squad sans consentement ; aucun échec affiché à autrui ; jamais de localisation ; vues employeur / B2B agrégées sauf opt-in explicite ; mode mineurs ou âge minimum (Declared Age Range) avec fonctions sociales et IA cloud restreintes ; filtrage du contenu généré par les utilisateurs (App Review 1.2). **[INDUSTRY PATTERN R§8]**

### 6.5 Compétition intelligente
Le meilleur utilisateur ne doit **pas** être celui qui passe 4 heures par jour (les ligues de Duolingo ont triplé le nombre d'utilisateurs à ≥ 1 h/jour). **[INDUSTRY PATTERN R§7]**
| Dimension | Mécanisme CertiGo | Débutant | Expert |
|---|---|---|---|
| **Maîtrise** | Points de maîtrise plafonnés / jour | Gagne vite au début (concepts neufs) | Doit monter en profondeur |
| **Progression** | Gain relatif de la semaine (% vs sa propre base) | Avantage naturel | Doit progresser aussi |
| **Justesse et calibration** | Défis : justesse × calibration de la confiance | Juste et lucide = gagnant | Ne peut pas « bourrer » |
| **Régularité** | Semaines de Rythme ; « Pilier du territoire » (le plus de révisions à l'heure sur un territoire en 90 jours, à la Strava Local Legend) | Accessible | Accessible |
| **Compétence** | Cote Glicko-2 par région, **opt-in**, avec incertitude ; mode « pratique classée » | Apparié à son niveau | Apparié à son niveau |
| **Spécialisation** | Classements par territoire, entre amis / Squad | — | Valorise l'expertise |

### 6.6 Modèle d'IA — « colonne déterministe, voix ancrée, contrat d'effort »
- **Le moteur décide quoi** (maîtrise, espacement, fausses idées, prochaine activité : déterministe, explicable, côté serveur). **Le modèle de langage décide comment le dire**, à partir d'extraits validés. **L'apprenant fait toujours l'effort d'abord.** **[EVIDENCE-BASED R§9 : Kestin 2025, Bastani 2025, méta-analyses ITS]**
- **Moments IA (pas d'onglet de chat)** : après une erreur (*Expliquer mon erreur* → re-essai obligatoire sur un item jumeau) ; avant une révision (rappel ciblé d'une fausse idée) ; après une séance (bilan en 2 lignes) ; aux jalons d'examen (plan, débrief). **[EVIDENCE-BASED R§9 : Khanmigo peu utilisé en barre latérale ; gains au tentative suivante]**
- **Échelle d'indices** : coup de pouce → indice ciblé → étape partielle → explication travaillée → re-essai obligatoire ; plafond de 4 tours.
- **Capacités retenues** : Expliquer mon erreur · Indices gradués · Comparer deux concepts (attributs issus des extraits) · Analogie (optionnelle, avec « où l'analogie s'arrête ») · Plan d'étude (fourchettes, re-planification hebdo) · Débrief d'examen (au niveau des domaines uniquement, conforme NDA) · *Carte de mes fausses idées* · *Expliquer* (explain-it-back, texte ou voix, formatif) · Variantes d'items **hors ligne** (relues par un humain, calibrées avant de compter).
- **Ancrage** : uniquement des extraits validés avec identifiants ; vérification de support phrase par phrase ; calculs (CIDR, évaluation de politique) faits par du code ; sinon **abstention**. Affichage « Vérifié le [date] · source ».
- **Routage** : sur l'appareil (Foundation Models) pour reformuler, évaluer un explain-it-back par rubrique, expurger des secrets, repli hors ligne ; Private Cloud Compute (iOS 27, si éligible) pour les sessions longues ; petit modèle Azure OpenAI (existant) pour les explications canoniques ancrées ; grand modèle **hors ligne** pour l'auteur, jamais face à l'apprenant sans relecture.
- **Repli** : Azure ancré → PCC / sur l'appareil (mêmes extraits) → explication humaine déterministe → abstention avec lien vers la documentation officielle. Délai p95 > 2,5 s, consentement absent, moins de 13 ans ou appareil inéligible = niveau suivant automatiquement.
- **Ne jamais** : réponse avant tentative ; affirmation hors extraits ; contenu d'examen réel ou « dump » ; flatterie, culpabilisation, fausse empathie ; inférence d'émotion (interdite dans l'éducation dans l'UE) ; notation IA qui bloque une progression ; maîtrise qui monte sur une performance assistée ; envoi de données à un fournisseur tiers sans consentement nommé (App Review 5.1.2(i)). **[INDUSTRY PATTERN R§9]**
- **Mesures** : précision différée sans aide (vs groupe sans IA), récurrence des fausses idées à 14 jours, réponse révélée avant tentative ≈ 0, taux de support ≥ 98 %, tests de complaisance / dump / injection à 100 % (bloquants), latence p95, coût par apprenant actif.

---
## 7. Architecture d'apprentissage — le CertiGo Learning Model

### 7.1 Les 14 règles du modèle (toute fonctionnalité MUST en respecter au moins une et n'en violer aucune)
| # | Règle | Traduction produit | Preuve |
|---|---|---|---|
| L1 | **Récupérer avant de relire** | Chaque concept commence par une question ou une prédiction (pré-test), jamais par un paragraphe | [EVIDENCE-BASED R§5 : retrieval practice, pretesting] |
| L2 | **Espacer, puis espacer encore** | Planification FSRS par concept ; rappels différés ; « rappels successifs » pour ancrer | [EVIDENCE-BASED R§5 : spacing, successive relearning] |
| L3 | **Entrelacer pour discriminer** | Les révisions mélangent des concepts voisins (NSG / pare-feu / ASG) ; première exposition en bloc court | [EVIDENCE-BASED R§5 : interleaving] |
| L4 | **Feedback qui explique le pourquoi** | Immédiat en pratique, différé en examen blanc ; pourquoi la bonne réponse, pourquoi **chaque** mauvaise | [EVIDENCE-BASED R§5 ; R§10] |
| L5 | **Exemples travaillés, puis estompés** | Exemple étiqueté par sous-objectifs → item jumeau → item estompé → item autonome ; on saute l'exemple si l'apprenant réussit déjà (inversion d'expertise) | [EVIDENCE-BASED R§5, R§10] |
| L6 | **L'artefact d'abord, la surface variée** | Code, log, config, commande, schéma réalistes ; noms et services varient d'une révision à l'autre | [EVIDENCE-BASED R§10] |
| L7 | **Monter l'échelle** | Chaque concept progresse sur une échelle de profondeur (§7.4), pas seulement en mémoire | [EVIDENCE-BASED R§10] |
| L8 | **Nommer les fausses idées** | Distracteurs = erreurs documentées ; mémoire personnelle des fausses idées ; remédiation ciblée | [EVIDENCE-BASED R§5, R§10] |
| L9 | **Déclarer sa confiance** | Confiance (Sûr / Plutôt / Au hasard) sur une partie des items ; les erreurs commises avec certitude sont reprises (hypercorrection) | [EVIDENCE-BASED R§5 : métacognition, hypercorrection] |
| L10 | **Générer et expliquer** | Explain-it-back en une phrase (texte ou voix), prédictions, auto-explications | [EVIDENCE-BASED R§5, R§10] |
| L11 | **Une idée par carte** | Segmentation, signalisation, artefacts ≤ 25 lignes, divulgation progressive | [EVIDENCE-BASED R§5 : charge cognitive] |
| L12 | **Mots + images utiles** | Schémas natifs (jamais décoratifs) accompagnés du texte ; alternative textuelle complète | [EVIDENCE-BASED R§5 : double codage, multimédia] |
| L13 | **Difficulté désirable, pas décourageante** | Taux de réussite visé 70–85 % par séance ; ajustement automatique | [EVIDENCE-BASED R§5 : desirable difficulties] |
| L14 | **Sortir du téléphone au sommet** | À partir du niveau associé (AZ-104…), passage de relais vers un vrai lab (Mac / navigateur) | [EVIDENCE-BASED R§10 : transfert, apprentissage par la pratique] |

### 7.2 Les atomes
| Atome | Définition | Champs essentiels |
|---|---|---|
| **Concept** | Nœud de l'Atlas : une idée ou une compétence enseignable et testable | id, titre, région, territoire, **type** (déclaratif / procédural / diagnostic / conception), prérequis, voisins, fausses idées liées, objectifs d'examen (route, objectif, poids), **produits concernés** (identifiants du registre de marques, §15.11), sources datées, version |
| **Carte** | Unité d'explication | concept, sorte (*Question d'ouverture*, *Explication*, *Exemple travaillé* à sous-objectifs, *Schéma*, *Artefact commenté*, *À retenir*), texte, médias accessibles |
| **Item** | Un exercice | concept(s), **format** (§7.3), **échelon** (§7.4), difficulté, énoncé, artefact, options / jetons / emplacements, explications par option, étiquettes de fausse idée, sources, statut de revue (brouillon IA / relu / publié), version — **clé de correction côté serveur uniquement** |
| **Situation** | Mini-cas de 1 à 3 minutes | contexte, artefact(s), 1–3 décisions (items), révélation, tableau « Qui gère quoi ? » ou conséquences, *À retenir*, région, éligibilité *Situation du jour* |
| **Route** | Un objectif | type (certification / compétence), objectifs pondérés (blueprint officiel), format d'examen (durée, types d'items, consultation autorisée ou non), version du programme, liens officiels |
| **Fausse idée** | Erreur typique nommée | énoncé, pourquoi c'est faux, concept(s), items qui la détectent, remédiation |
| **Source** | Référence | URL, titre, éditeur, **date de vérification** |

**Règle de contenu :** original uniquement ; chaque item publié est relu par un humain ; l'IA rédige des brouillons et des variantes, ne publie jamais ; un item d'un examen réel ou paraphrasé d'un « dump » est un incident de conformité.

### 7.3 Catalogue des formats (natifs de la tech, 30 s – 3 min sur iPhone)
Priorités : **P1** = Phase 4 ; **P2** = après validation des P1 ; **P3** = plus tard.

| Format (nom produit) | Ce qui est entraîné | Interaction iPhone | Priorité |
|---|---|---|---|
| **Choisir** (QCM / multi + confiance) | Rappel, discrimination | Tap ; confiance en 1 tap | P1 |
| **Situation** (décision sur mini-cas, ex-Atelier de décision) | Jugement, application | Lecture + tap + révélation | P1 |
| **Prédire** (sortie d'une commande, d'un code, d'une requête KQL/SQL) | Lecture, modèle d'exécution | Tap sur une sortie candidate | P1 |
| **Trouver l'erreur** (taper la ligne fautive d'une config / d'un code / d'un schéma) | Revue, hygiène sécurité | Tap sur une ligne de l'artefact | P1 |
| **Ordonner** (runbook, Parsons 2D : YAML, Bicep, Terraform, Dockerfile, pipeline) | Procédure, structure | Tap-pour-placer + boutons d'indentation (glisser en option) | P1 |
| **Composer la commande** (jetons : `az`, `kubectl`, `git`, `docker`) | Composition, paramètres | Clavier de jetons, 1 ligne max | P1 |
| **Lire le log** (cause + prochaine vérification) | Lecture d'erreurs, diagnostic | Surlignage + choix | P2 |
| **Diagnostiquer** (triage d'incident : alerte → preuves → hypothèse → action → vérification) | Dépannage structuré | Cartes de preuves à révéler, chemin noté | P2 |
| **Compléter le schéma** (emplacements : sous-réseau, NSG, LB, private endpoint) | Modèle de système | Tap-pour-placer dans des emplacements | P2 |
| **Arbitrer** (décision d'architecture sous contraintes : coût, RTO/RPO, conformité) | Compromis | Choix + conséquences déterministes | P2 |
| **Expliquer** (une phrase, texte ou voix) | Abstraction, auto-explication | Saisie courte / dictée ; retour IA formatif | P2 |
| **Classer** (ex. responsabilités IaaS / PaaS / SaaS) | Catégorisation | Tap-pour-placer dans des colonnes | P2 |
| **Estimer** (coût, latence, taille) | Raisonnement quantitatif, calibration | Curseur avec bandes de tolérance | P3 |
| **Mini-cas** (un contexte, 3 items liés) | Intégration, format d'examen | Enchaînement | P3 |
| **Sprint de documentation** (trouver une limite dans Learn en 60 s — examens associés) | Consultation légale en examen | Lien externe + réponse | P3 |
| **Passage au lab** | Exécution réelle, transfert | Handoff / lien vers Mac | P3 |

Règles d'interaction : **tap > saisie > glisser** ; tout glisser a une alternative tap et VoiceOver ; artefacts ≤ 25 lignes, police à chasse fixe, zoom, retour à la ligne activable ; distracteurs = fausses idées documentées ; plusieurs ordres équivalents acceptés quand c'est vrai. **[EVIDENCE-BASED R§10]**

### 7.4 Progression d'un concept : Profondeur × Mémoire
Chaque concept a **deux dimensions**, toutes deux calculées côté serveur :

**Profondeur — l'échelle (5 échelons + 1 hors téléphone)**
| Échelon | Nom générique | Déclaratif | Procédural | Diagnostic | Conception |
|---|---|---|---|---|---|
| 1 | **Reconnaître** | Identifier la bonne définition | Lire / prédire une commande | Lire un log | Identifier les contraintes |
| 2 | **Rappeler** | Rappel sans indice | Ordonner les étapes | Localiser l'anomalie | Associer options et contraintes |
| 3 | **Appliquer** | Résoudre une *Situation* | Compléter / composer | Formuler une hypothèse | Comparer deux options |
| 4 | **Analyser** | Distinguer de concepts voisins | Corriger une erreur | Vérifier, corriger | Décider sous contraintes |
| 5 | **Expliquer** | Expliquer à quelqu'un (explain-it-back) | Expliquer pourquoi cet ordre | Rédiger un post-mortem d'une ligne | Justifier un compromis |
| (6) | **Pratiquer** (hors téléphone) | — | Exécuter en lab | Résoudre un vrai incident en lab | Revue d'architecture |

**Mémoire — l'état FSRS** : rétention prédite (la probabilité de se souvenir aujourd'hui).

**États affichés d'un concept**
| État | Règle (serveur) | Visuel Atlas |
|---|---|---|
| *Inconnu* | Jamais vu | Point creux, gris |
| *Découvert* | Vu, échelon 1 tenté | Point fin, couleur de région à 30 % |
| *En pratique* | ≥ 1 réussite, pas encore de rappel différé | Point plein, couleur à 60 % |
| *Ancré* | Critère initial atteint (récupération réussie lors de la séance d'apprentissage) **puis** ≥ 2 réapprentissages espacés réussis au 1er essai, sur 2 jours distincts, dont un ≥ 72 h après l'apprentissage | Point plein, couleur à 100 %, halo |
| *Maîtrisé* | ≥ 3 réapprentissages espacés réussis sur 3 jours distincts (critère de *successive relearning*) **et** échelon ≥ 4 réussi sur ≥ 2 items de surfaces différentes ; jamais une série réussie dans une même séance | Facette (glyphe prisme) + halo |
| Surimpression *S'estompe* | Rétention prédite < 80 % | Luminosité réduite (+ libellé) |
| Surimpression *Fausse idée* | Fausse idée détectée non corrigée | Petit marqueur ⚠︎ (+ libellé) |

Aucune information n'est portée **uniquement** par la couleur : chaque état a un glyphe et un libellé. **[DESIGN JUDGMENT + HIG R§11]**

### 7.5 La Séance — une seule architecture pour 5, 15 et 45 minutes
La séance est **composée par le serveur** (moteur de recommandation existant étendu) à partir des atomes, et **rendue par le client**. L'utilisateur choisit seulement la **durée** ; le contenu se compose.

| Durée | Nom | Composition type | Objectif |
|---|---|---|---|
| ≈ 5 min | **Express** | 6–10 rappels dus (entrelacés) **ou** moins + 1 *Situation* de transfert sur des concepts déjà vus → 1 re-test d'erreur commise avec certitude s'il y en a → 1 question d'ouverture du prochain concept (non notée) → *À retenir* ; **aucun nouveau concept complexe** | Réapprentissage et entretien : le meilleur usage de 5 minutes |
| ≈ 15 min | **Séance** | Question d'ouverture → 1 nouveau concept (explication → exemple travaillé → auto-explication → 3–4 items qui montent l'échelle) → 5–8 rappels espacés dont une **paire de contraste** (ex. NSG / pare-feu) → 1 *Situation* appliquée → *À retenir* | Apprendre un bloc cohérent |
| 30–45 min | **Plongée** | Un module de territoire : 2–4 concepts liés, exemples travaillés à sous-objectifs, *Diagnostiquer* ou *Arbitrer* en capstone, mini-contrôle mixte (≈ 10 items) ou examen blanc partiel, *Expliquer* final ; lecture éditoriale (ex-Lecture guidée) | Étude profonde, reprise possible en plusieurs fois |

Règles communes :
- **1 tap** depuis *Aujourd'hui* ; la durée proposée par défaut dépend de l'heure et de l'historique (modifiable).
- **Reprise contextuelle :** chaque carte est sauvegardée ; « Reprendre — 2 cartes restantes » pendant 24 h ; une *Plongée* se reprend sur plusieurs jours.
- **Pas de compte à rebours** en pratique (seulement en examen blanc) ; « Terminer maintenant » toujours disponible, sans perte.
- **Hors ligne :** les 2 prochaines séances sont pré-composées et mises en cache ; les réponses sont mises en file (idempotentes) et notées par le serveur à la reconnexion (feedback hors ligne : décision ouverte OD-3, §20.2).
- **Ajustement :** si le taux de réussite sort de 70–85 %, la séance suivante ajuste la difficulté ; jamais au milieu d'une carte.
- **Fin sur une réussite :** la dernière récupération d'une séance est choisie pour être réussissable (sans être triviale).
- **Plafond de révisions :** nombre quotidien de révisions plafonné et « dette de révision » lissée sur plusieurs jours ; intervalles FSRS ajustés à la date d'examen quand elle existe. **[EVIDENCE-BASED R§5]**
- **Hygiène des QCM :** quand c'est possible, la question s'affiche **avant** les options (un temps de réflexion) ; ≤ 3 distracteurs plausibles ; un distracteur choisi est re-testé plus tard sous forme de rappel. **[EVIDENCE-BASED R§5 : effet de suggestion négative des QCM]**

### 7.6 Le feedback (le moment du *Déclic*)
- **Pratique :** feedback **immédiat** (≤ 1 s perçu) : statut (symbole + mot + couleur) → explication de la bonne réponse → pourquoi l'option choisie est fausse → fausse idée nommée s'il y a lieu → *À retenir* → actions secondaires : *Voir la fiche*, *Expliquer autrement* (IA ancrée), *Signaler une erreur*.
- **Erreur commise avec certitude :** message dédié, sans jugement (« Tu étais sûr : ces erreurs-là se corrigent très bien — on y revient bientôt ») ; item jumeau plus loin dans la séance, puis re-test à ~2 jours et ~1 semaine (une erreur commise avec certitude a plus de chances de réapparaître). **[EVIDENCE-BASED R§5 : hypercorrection]**
- **Examen blanc :** aucun feedback pendant ; débrief complet à la fin. **[EVIDENCE-BASED R§5]**
- **Ton :** le mot « Faux » n'est jamais utilisé seul ; on écrit « Pas tout à fait » / « Presque » / « Correct ». **[DESIGN JUDGMENT]**

### 7.7 La Préparation (ex-Readiness Score) — honnête par construction
| Élément | Affichage | Règle |
|---|---|---|
| Par objectif d'examen | Couverture (concepts avec preuves) · Profondeur moyenne · Mémoire moyenne · Nombre de preuves | Pondéré par le poids officiel de l'objectif |
| Bande globale | *Preuves insuffisantes* · *Pas encore* · *En bonne voie* · *Prêt à tenter* · *Très prêt* | *Preuves insuffisantes* tant qu'il n'y a pas ≥ 1 examen blanc chronométré sur items **jamais vus** et une couverture minimale de chaque objectif ; *Prêt à tenter* exige un examen blanc réussi + couverture ≥ 85 % des objectifs pondérés |
| Incertitude | Barre d'incertitude qui se resserre avec les preuves ; « fondé sur 214 réponses, dont 38 rappels différés » | Jamais de chiffre précis avec peu de preuves |
| Ce qui manque | « 3 actions qui te rapprochent de *Prêt* » (impact = poids × déficit) | Actionnable en 1 tap |
| Prévision de date | « Au rythme actuel, *Prêt à tenter* vers le 10–20 déc. » (fourchette) | Affichée seulement si ≥ 3 semaines d'historique |
| Probabilité de réussite | **Masquée** jusqu'à calibration (≥ 200 résultats d'examen déclarés pour la route et la version du programme ; Brier, log loss, diagramme de fiabilité suivis en interne). Ensuite : fourchette + date (« 70–85 % si tu passes l'examen le 20 nov. ») | **[EVIDENCE-BASED / INDUSTRY PATTERN R§5 : NBME, NCLEX ; R§3 : The Outsiders, visualisation explicable]** |

La formule heuristique actuelle (100 × couverture^0,5 × maîtrise × récence^0,3) **MUST NOT** être affichée comme un pourcentage de réussite : elle double le modèle d'oubli FSRS, récompense la couverture partielle, gonfle la maîtrise par la répétition des mêmes items et ressemble à une probabilité sans en être une (R§12). Modèle cible *Préparation v2* : difficultés d'items calibrées (IRT/Elo) ; habileté par objectif avec incertitude, estimée sur les **premières tentatives d'items jamais vus** ; rétention FSRS projetée à la date d'examen ; a priori de population pour les objectifs sans preuve ; simulation de formulaires pondérés par le blueprint ; lien avec la réussite appris sur les résultats déclarés, par certification et par version. **[EVIDENCE-BASED + INDUSTRY PATTERN R§5]**

### 7.8 Fraîcheur et versions
- Chaque concept et chaque route portent une version et une date de vérification des sources.
- Quand un contenu *Ancré* par l'utilisateur change de façon significative (renommage de service, retrait, changement de limite), il reçoit une **Mise à jour de connaissance** (carte de 1 min dans la prochaine séance) et le concept passe en *S'estompe* jusqu'à révision. **[DESIGN JUDGMENT ; INDUSTRY PATTERN R§10 : examens Microsoft mis à jour chaque trimestre]**

### 7.9 Passage au lab
À partir des routes associées (AZ-104 et au-delà) et pour les compétences procédurales : bouton « Continuer sur Mac » (Handoff / lien universel) vers un exercice officiel (labs GitHub Microsoft, exercices Learn) ou partenaire ; achèvement déclaré puis, plus tard, vérifié par API. Les bacs à sable gratuits Microsoft Learn n'étant plus disponibles, CertiGo **MUST NOT** promettre un environnement Azure gratuit. **[COMPETITOR OBSERVATION R§10]**

---

## 8. Architecture de l'information et navigation

### 8.1 Structure cible
```
TabView (Liquid Glass, standard)
├── Aujourd'hui      (sun.max / sun.max.fill)
│   ├── Carte Séance (Express · Séance · Plongée)  → Séance [plein écran]
│   ├── Situation du jour                           → Situation [plein écran]
│   ├── Rythme de la semaine
│   ├── Mémoire (prévision)                         → Mémoire (détail)
│   ├── Objectif (route + Préparation)              → Objectif (détail) → Examen blanc [plein écran]
│   └── Ensemble (aperçu, si actif)                 → onglet Ensemble
├── Atlas            (map / map.fill)
│   ├── Carte / Liste (bascule)                     → Région → Territoire → Concept
│   ├── Filtres : Mon objectif · Tout · À raviver · Fausses idées
│   ├── Objectifs (routes)                          → Route → Objectif d'examen → Concepts
│   └── Explorer (catalogue complet)                → Route / Région
├── Ensemble         (person.2 / person.2.fill)
│   ├── Situation du jour : résultats de la communauté
│   ├── Squad                                       → Squad (objectif, membres, défis)
│   ├── Amis                                        → Profil ami (ce qu'il partage)
│   └── Défis                                       → Défi [plein écran]
├── Profil           (person.crop.circle / .fill)
│   ├── Passeport                                   → Partager
│   ├── Historique & calibration
│   ├── CertiGo Pro
│   └── Réglages → Rythme & rappels · Langue · Lecture & accessibilité · Sons & haptique ·
│                  Confidentialité & visibilité · Données hors ligne · Compte · Suppression du compte ·
│                  À propos des données & méthode · Aide
└── Recherche (rôle .search, iOS 26+ ; sinon champ de recherche dans Atlas)
```

### 8.2 Règles de navigation
- La tab bar **navigue, n'agit jamais** ; toujours visible hors séance plein écran ; libellés d'un mot ; symboles pleins à l'état sélectionné ; badges seulement pour un élément critique (ex. examen aujourd'hui). **[OFFICIAL APPLE HIG, R§11]**
- Une **action principale** par écran ; actions secondaires dans la barre d'outils (titre + symbole) ou un menu.
- **Plein écran** (focus) : Séance, Situation, Examen blanc, Défi, premier lancement. Pendant une séance, la tab bar disparaît ; un accessoire « Séance en cours » permet de revenir si l'utilisateur sort.
- **Sheets** (détentes medium/large) : fiche concept depuis une séance, réglages rapides, partage, CertiGo Pro (contextuel uniquement).
- **Push** : exploration hiérarchique (Atlas, Ensemble, Profil).
- **Coach** n'est plus une destination : ses capacités apparaissent là où elles servent (§12). **[EVIDENCE-BASED R§9 : l'IA sans garde-fous nuit à l'apprentissage ; DESIGN JUDGMENT]**
- **Adaptativité :** `TabView` adaptable en barre latérale sur iPad / iPhone Duo ; Atlas et fiche concept en deux colonnes quand la largeur le permet ; séance centrée à largeur de lecture.

### 8.3 Liens profonds (contrats à créer, additifs)
`certigo://today` · `certigo://session?length=express|seance|plongee` · `certigo://situation/today` · `certigo://atlas/concept/{id}` · `certigo://route/{id}` · `certigo://squad/{id}` · `certigo://exam/{routeId}` · liens universels `https://<domaine>/s/{situationId}` (partage) et `https://<domaine>/join/{squadCode}` (invitation). Les schémas existants (`certigo://auth`) sont conservés.

---

## 9. Parcours clés

### 9.1 Les 60 premières secondes (*time-to-value* < 60 s)
| Temps | Écran | Contenu | Pourquoi |
|---|---|---|---|
| 0–5 s | **Bienvenue** | Logo animé (réfraction brève) · « Une question. Une idée plus claire. » · une ligne : « Progresse en tech, chaque jour. » · choix : **Cloud · IA · Sécurité · Réseau · DevOps · Code · Données · Systèmes** + « Je prépare une certification » | Le choix d'intérêt donne l'autonomie et oriente la première Situation |
| 5–50 s | **Situation de découverte** | Une *Situation* réelle de 3 décisions adaptée au choix (débutant / intermédiaire selon la 1re réponse) ; confiance en 1 tap ; feedback immédiat et beau | Le « wow » arrive en faisant, pas en lisant **[INDUSTRY PATTERN R§3 : onboarding comme artisanat]** |
| 50–60 s | **Premier Déclic** | « Tu viens d'apprendre 3 choses » : 3 concepts s'allument dans un mini-Atlas · distribution « 41 % ont choisi comme toi » | Valeur + monde + communauté en un écran |
| 60–120 s | **Ton objectif** | « Que veux-tu ? » : *Préparer une certification* (code + date facultative) · *Progresser dans un domaine* · *Juste apprendre un peu chaque jour* ; **Rythme** : jours par semaine (3/4/5/7) ; **Quand ?** (« après le café », « dans les transports », heure) | Intention d'implémentation **[EVIDENCE-BASED R§6]** |
| ensuite | **Sauvegarder** | Sign in with Apple / passkey / Microsoft / Google (le compte vient **après** la valeur) ; mode invité possible | Pas de mur avant la valeur |
| ensuite | **Aujourd'hui** | La première séance est prête ; la demande d'autorisation de notifications vient **après** la première séance, au moment où l'utilisateur choisit son rappel | Permissions contextualisées **[OFFICIAL APPLE HIG]** |

**MUST NOT :** paywall, date de naissance, « comment nous avez-vous connus ? », écran de promesse, écran de réaction d'une mascotte avant la première Situation. (L'onboarding Flutter comptait 23 écrans et un paywall avant toute leçon.)

### 9.2 Les 7 premiers jours
| Jour | Ce que l'utilisateur découvre | Moment visé |
|---|---|---|
| **J0** | Situation de découverte, premier *Déclic*, objectif, rythme, première séance Express ou Séance | **WOW** : « c'est de la vraie tech, et c'est beau » |
| **J1** | Premiers **rappels différés** : « Tu te souviens de 4 sur 5 d'hier » ; *Situation du jour* introduite | **AHA** : « CertiGo sait comment j'apprends » |
| **J2** | Une **fausse idée détectée** et corrigée (« Tu confonds souvent NSG et pare-feu Azure — voici la différence ») | **AHA** personnel |
| **J3** | Premier concept *Ancré* (rappel ≥ 72 h) → célébration *Réfraction* niveau 2 ; proposition (non insistante) d'inviter un ami ou de créer une *Squad* | **MASTERY** |
| **J4–J6** | Une *Plongée* proposée ; widget proposé (« Ta Situation du jour sur l'écran d'accueil ») ; l'Atlas s'étend | Habitude |
| **J7** | **Bilan de la semaine** : *Avant / Maintenant* (les 3 questions du J0 reposées : « Lundi 1/3, aujourd'hui 3/3 »), concepts ancrés, fausses idées corrigées, semaine de *Rythme* tenue ; carte de capacité partageable | **« Je progresse vraiment »** |

### 9.3 Les 30 premiers jours — la valeur qui s'accumule
- **Semaine 2 :** l'Atlas montre un territoire presque complet ; *Mémoire* prévoit les concepts à raviver ; première *Mission* hebdomadaire choisie.
- **Semaine 3 :** pour les candidats, la *Préparation* sort de *Pas encore* avec une incertitude qui se resserre ; premier examen blanc proposé ; *Squad* : premier objectif coopératif atteint.
- **Semaine 4 :** **Rapport du mois** (style « Wrapped », sobre) : concepts ancrés, profondeur gagnée, calibration de la confiance, meilleure Situation, prochaine étape ; partage optionnel.
- **Pourquoi rester après 30 jours :** l'historique de mémoire (FSRS), le modèle de maîtrise, les fausses idées corrigées, l'Atlas, la Préparation calibrée, le graphe social et la personnalisation de l'IA rendent CertiGo **impossible à remplacer par un outil sans mémoire** (vidéo, chatbot, PDF). **[DESIGN JUDGMENT, R§16–17]**

### 9.4 Séance
Aujourd'hui → carte Séance (durée par défaut, composition visible : « 6 rappels · 1 nouveau concept : *Groupes de sécurité réseau* · 1 Situation ») → **Commencer** → cartes et items (barre de progression segmentée, bouton fermer = « Terminer et sauvegarder ») → feedback après chaque item → **Résultats** (ce qui a changé dans l'Atlas, *Déclics*, fausses idées corrigées, Rythme) → **Terminé** (retour à Aujourd'hui) ou « Encore 5 min ».

### 9.5 Situation du jour
Une Situation par région et par jour, identique pour tous les apprenants de cette région. Carte sur Aujourd'hui → plein écran → contexte + artefact → décision(s) + confiance → révélation → **distribution de la communauté** (après réponse uniquement) → explication → *À retenir* → **carte de partage sans spoiler** (grille de pastilles façon Wordle, région, difficulté, « 3/3 du premier coup ») → retour. L'historique des Situations est consultable dans Ensemble.

### 9.6 Objectif, Préparation, examen blanc, examen, débrief
Choisir une route (Atlas › Objectifs ou onboarding) → confirmation serveur → plan (date d'examen facultative, rythme) → progression par objectif → examen blanc (plein écran, minuteur avec option **temps majoré / sans limite**, Live Activity) → débrief par objectif, fausses idées, impact sur la Préparation → *Prêt à tenter* → le jour J : Live Activity « Examen aujourd'hui », révision légère uniquement → le lendemain : « Comment s'est passé ton examen ? » (réussi / pas cette fois / je préfère ne pas dire ; score facultatif) → débrief et célébration ou plan de reprise bienveillant → *Passeport* mis à jour → objectif suivant proposé.

### 9.7 Retour après une absence
Aucune notification de perte. À l'ouverture après ≥ 7 jours : « Bon retour. On reprend en douceur : 3 minutes pour raviver l'essentiel. » → séance de reprise (rappels prioritaires, difficulté abaissée) → le Rythme repart sur la semaine en cours (aucune série « perdue » affichée en rouge).

### 9.8 Rappels et notifications
- Choisis par l'utilisateur (jours, heure, contexte) ; **1 rappel maximum par jour** ; autorisation demandée après la première séance (provisoire possible).
- Niveaux : *Passive* pour les rappels, *Active* pour une Situation du jour terminée par un ami (si activé), *Time Sensitive* uniquement le jour de l'examen.
- Silence adaptatif : après 3 rappels ignorés, fréquence divisée par deux et proposition de changer l'horaire.
- Copie : bienveillante, concrète, jamais culpabilisante (exemples §15.9).

### 9.9 Hors ligne
Bandeau discret « Hors ligne — tes réponses seront synchronisées » ; séances en cache jouables ; Situation du jour téléchargée le matin si possible ; aucune perte de réponse ; conflits résolus côté serveur.

### 9.10 CertiGo Pro
Présenté **après** la première semaine ou au moment où l'utilisateur touche une capacité Pro (examen blanc complet, route complète, Plongée illimitée, débrief IA approfondi). Écran unique : ce qui est inclus, prix, essai, rappel avant facturation, restauration des achats, gestion via le système. **MUST NOT** : compte à rebours artificiel, fermeture difficile, culpabilisation.

### 9.11 Compte et données
Suppression du compte accessible en 2 niveaux depuis Profil (exigence App Store, existe déjà) ; export des données d'apprentissage ; visibilité sociale par défaut **privée** ; explication claire de l'usage de l'IA et des fournisseurs (Guideline 5.1.2(i)).

---
## 10. Expérience quotidienne — *Aujourd'hui*

### 10.1 Rôle
Répondre en **une seconde** à « Qu'est-ce que je fais maintenant ? » et le lancer en **un tap**. Aujourd'hui n'est ni un tableau de bord ni un fil : c'est un **plan du jour**.

### 10.2 Ordre des blocs (de haut en bas) et règles
| # | Bloc | Contenu | Règle |
|---|---|---|---|
| 1 | **En-tête** | Grand titre « Aujourd'hui » ; date ; accès Recherche (iOS < 26) | Aucune métrique de vanité |
| 2 | **Carte Séance** (héros) | Sélecteur *Express · Séance · Plongée* (durée par défaut intelligente) ; composition (« 6 rappels · 1 nouveau concept : *Peering de réseaux virtuels* · 1 Situation ») ; bouton **Commencer** | Seule action principale de l'écran ; « Reprendre (2 cartes) » remplace Commencer si une séance est en cours |
| 3 | **Situation du jour** | Région, titre court, difficulté, « 2 min » ; après réponse : votre résultat + « 41 % ont choisi comme toi » | Disparaît du haut une fois faite, reste consultable dans Ensemble |
| 4 | **Rythme** | Les 7 jours de la semaine (faits / repos / à venir), objectif « 3 sur 4 cette semaine », meilleur rythme | Jamais de rouge, jamais de compte à rebours |
| 5 | **Mémoire** | « 6 concepts prêts à être ravivés · ~3 min » + mini-prévision 7 jours | Formulation positive (pas « tu oublies ») |
| 6 | **Objectif** | Route (ex. AZ-900), bande de *Préparation*, date d'examen et « 3 actions pour progresser » | Si pas d'objectif : carte « Choisir un objectif » |
| 7 | **Ensemble** | Objectif de *Squad* ou encouragement reçu | Seulement si l'utilisateur a un ami ou une Squad |
| 8 | **Mot de la semaine** (IA) | 1 ligne factuelle issue du modèle (« Tu confonds souvent NSG et pare-feu : ta prochaine séance commence par là ») | Jamais émotionnel, jamais culpabilisant ; masquable |

### 10.3 Variantes d'état
| État de l'utilisateur | Ce qui change |
|---|---|
| Jour 0 (après le premier lancement) | Carte Séance pré-remplie ; bloc Mémoire masqué ; invitation à ajouter le widget après la 1re séance |
| Retour après ≥ 7 jours | Carte « Bon retour » avec séance de reprise en douceur ; Rythme repart sur la semaine courante |
| Semaine d'examen | Objectif monte en position 2 ; Plongée remplacée par « Examen blanc » ; pas de nouveau concept la veille |
| Jour J | Live Activity « Examen aujourd'hui » ; Aujourd'hui = révision légère + conseils pratiques (pièce d'identité, horaire) |
| Hors ligne | Bandeau discret ; séances en cache jouables ; Situation du jour si téléchargée |
| Pas d'objectif / curieux | Objectif remplacé par « Explorer une région » |
| Invité (sans compte) | Tout fonctionne ; incitation douce à sauvegarder après la 2e séance |

### 10.4 Surfaces hors de l'app (même plan du jour)
Widget *Aujourd'hui* (séance + Rythme), widget *Situation du jour*, widget interactif *Carte de révision* (répondre à un rappel depuis l'écran d'accueil), contrôle Centre de contrôle « Express 5 min », raccourci Siri « Fais-moi réviser le réseau ».

---

## 11. Expérience sociale — *Ensemble*

### 11.1 Rôle
Donner **de la compagnie et de la reconnaissance**, jamais de la pression. Ensemble a de la valeur **même sans amis** grâce à la communauté de la Situation du jour.

### 11.2 Contenu
| Bloc | Contenu | Sans amis |
|---|---|---|
| **Situation du jour — communauté** | Distribution anonyme des réponses, « meilleures explications » sélectionnées (plus tard), historique de vos Situations | Toujours présent |
| **Squad** | Objectif hebdomadaire commun (barre qui se remplit de contributions anonymisées par défaut), Mission coopérative, encouragements, défi interne optionnel | Carte « Créer ou rejoindre une Squad » (par lien, code, ou appariement par route et mois d'examen) |
| **Amis** | Ce que chacun choisit de partager : Rythme, jalons, Situations ; encourager en 1 tap ; lancer un Défi | Carte « Inviter un ami » (lien, QR) |
| **Défis** | Défis reçus / envoyés ; résultat = justesse + calibration | — |
| **Ligues de progression** (opt-in) | Votre groupe apparié, ±3 voisins, score de maîtrise plafonné | Masqué tant que non activé |

### 11.3 Contrôles de confidentialité (Réglages › Confidentialité & visibilité)
Profil : privé (défaut) / amis / Squad ; pseudonyme ; ce qui est partagé (Rythme, jalons, Situations, Passeport) ; participation aux ligues (non par défaut) ; découverte par code uniquement ; liste de blocage ; signalement. Aucune incitation à réduire la confidentialité. **[INDUSTRY PATTERN R§8]**

---

## 12. Expérience IA (surfaces concrètes)

| Moment | Surface | Déclencheur | Comportement | Repli |
|---|---|---|---|---|
| Après une erreur | Panneau de feedback → **Expliquer autrement** | Réponse incorrecte ou « Je ne sais pas » | Explication ancrée personnalisée par la fausse idée détectée → **re-essai obligatoire** sur un item jumeau | Explication humaine de l'item |
| Pendant un item multi-étapes | Bouton **Indice** | Après une première tentative | Échelle : coup de pouce → indice ciblé → étape partielle → explication travaillée ; 4 tours max | Indices auteur |
| Suivi d'explication | « **Pourquoi ?** » sous l'explication | Volontaire | Une question de suivi, réponse ancrée dans la fiche, 2 tours max, se termine par un item | Lien vers la fiche |
| Fiche concept | **Comparer avec…** | Volontaire | Tableau de contraste à partir des attributs validés des deux concepts | Tableau auteur |
| Fiche concept | **Analogie** (optionnelle) | Volontaire | Analogie + « où l'analogie s'arrête » | Masqué |
| Après une séance | **Bilan** (2 lignes) | Fin de séance | Faits : ce qui s'est ancré, la fausse idée à surveiller | Bilan déterministe |
| Objectif | **Mon plan** | Date d'examen fixée / chaque lundi | Plan hebdomadaire en fourchettes, re-planifié | Plan déterministe |
| Après un examen blanc | **Débrief** | Fin d'examen | Par objectif, fausses idées, 3 actions | Débrief déterministe |
| Après l'examen réel | **Débrief d'examen** | Déclaration du résultat | Auto-évaluation **par domaine uniquement** → re-plan ; refus poli de toute restitution de question | — |
| Profil / Atlas | **Carte de mes fausses idées** | Toujours | Fausses idées actives / corrigées, avec drills de réparation | — |
| Item *Expliquer* | Saisie / dictée | Item dédié | Retour formatif par rubrique (atomes de concept trouvés / manquants) ; **ne compte jamais pour la maîtrise** | Rubrique auteur |

Règles d'interface IA (MUST) : étiquette « IA · d'après la fiche *X* · vérifiée le *date* » ; texte de progression spécifique pendant la génération (« Je relis la fiche *Groupes de sécurité réseau*… ») ; pouce haut/bas facultatif et **Signaler** ; **consentement nommant le fournisseur** avant le premier appel cloud (App Review 5.1.2(i)) ; réglage « IA dans le cloud » (désactivé = sur l'appareil + déterministe) ; jamais d'avatar ni de prénom ; jamais de verdict renversé sous la pression sans nouvelle preuve. **[OFFICIAL APPLE HIG Generative AI ; INDUSTRY PATTERN R§9]**

---

## 13. Moments signature et célébrations

### 13.1 Échelle de célébration
| Niveau | Déclencheur | Visuel | Son | Haptique | Reduce Motion | Silencieux |
|---|---|---|---|---|---|---|
| **0** | Chaque réponse | Statut (symbole + mot + couleur), *Magic Replace* du symbole | Ton court (optionnel) | `.success` / `.selection` (réponse incorrecte : impact léger, pas `.error`) | Identique sans transition | Visuel seul |
| **1** | Séance terminée, Situation résolue | Résultats ; concepts qui changent d'état s'animent < 1 s | Motif court | `.success` | Fondu | Visuel seul |
| **2** | Concept *Ancré* ou *Maîtrisé*, fausse idée corrigée, semaine de Rythme tenue, objectif de Squad atteint | **Réfraction** dans la couleur de la région (≤ 1,2 s) | Motif *Déclic* | Haptique *Déclic* | Fondu + éclat statique | Visuel seul |
| **3** | Territoire complet, examen blanc réussi, *Prêt à tenter*, examen réussi | Plein écran : réfraction + carte de capacité partageable | Motif étendu | Motif étendu | Carte statique | Carte statique |

Règles : intensité ∝ rareté ; jamais deux célébrations simultanées ; jamais d'animation qui bloque la navigation > 1,2 s (touchable pour passer) ; **Mode Calme** plafonne au niveau 1 visuel.

### 13.2 Les cinq moments clés
| Moment | Définition CertiGo | Quand | Comment on le reconnaît |
|---|---|---|---|
| **WOW** | « C'est de la vraie tech, et c'est beau » | 60 premières secondes | La Situation de découverte avec un artefact réel, puis 3 concepts qui s'allument |
| **AHA** | « CertiGo sait comment j'apprends » | J1–J2 | Rappel différé réussi (« 4 sur 5 d'hier ») ; fausse idée nommée et corrigée |
| **MASTERY** | « Je le sais vraiment » | J3+ | Premier concept *Ancré*, puis *Maîtrisé* (réfraction) ; *Avant / Maintenant* au J7 |
| **SOCIAL** | « On progresse ensemble » | Semaine 2+ | Objectif de Squad atteint ; encouragement reçu ; même choix que 41 % des gens |
| **CELEBRATION** | « J'ai franchi un cap » | Jalons | Territoire complet, *Prêt à tenter*, examen réussi → Passeport + carte de capacité |

### 13.3 Le test « I love this app »
| Levier | Ce que CertiGo fait concrètement |
|---|---|
| Personnalité | Le pair compétent et bienveillant ; une pointe d'esprit dans les micro-textes, jamais aux dépens de l'apprenant |
| Surprise | Une Situation bonus rare et gratuite ; un récap mensuel qui montre quelque chose qu'on ignorait (« ta meilleure région : Identité ») |
| Micro-interactions | Taper une ligne d'artefact = surlignage + tic haptique ; jetons de commande qui s'emboîtent ; bascule Carte/Liste de l'Atlas fluide |
| Artisanat | Typographie du code soignée (SF Mono, numérotation, coloration accessible), états vides écrits, aucune icône approximative |
| Animation | Réfraction réservée aux vrais jalons ; transitions qui expliquent (le concept « monte » dans l'Atlas) |
| Rituel | Situation du jour ; bilan du dimanche ; récap mensuel ; sprint de décembre |
| Identité | Passeport ; Atlas personnel ; vocabulaire propre |
| Progrès | Profondeur × Mémoire visibles ; *Avant / Maintenant* |
| Personnalisation | Carte de mes fausses idées ; séance composée pour moi ; plan qui s'adapte |
| Lien social | Squad coopérative ; encouragements ; défis justes |
| Qualité du contenu | Situations réalistes, sources datées, mises à jour de connaissance, zéro « dump » |

---

## 14. Expérience iOS (« CertiGo on iOS »)

### 14.1 Obligations (MUST)
- Composants système : `TabView` (rôle Recherche sur iOS 26+), `NavigationStack`, toolbars, sheets, menus, `ContentUnavailableView` pour les états vides ; **Liquid Glass uniquement sur la couche navigation / contrôles**, jamais sur le contenu ; légibilité vérifiée avec Reduce Transparency, Increase Contrast et le curseur de transparence d'iOS 27. **[OFFICIAL APPLE R§11]**
- Dynamic Type jusqu'à AX5 (texte ≥ 200 %), SF Symbols, couleurs sémantiques, mode sombre complet, Increase Contrast, Reduce Motion, Differentiate Without Color, VoiceOver, Voice Control, Full Keyboard Access, cibles ≥ 44 × 44 pt.
- Widgets (WidgetKit) : *Aujourd'hui*, *Situation du jour*, *Carte de révision* interactive ; Écran verrouillé, StandBy, Smart Stack ; modes teinté / clair.
- App Intents : `StartSessionIntent(length)`, `OpenDailySituationIntent`, `ReviewTopicIntent(topic)`, `OpenConceptIntent` ; entités `ConceptEntity` et `RouteEntity` indexées dans Spotlight ; App Shortcuts en 8 langues.
- Notifications : autorisation contextualisée (provisoire possible), niveaux *Passive* / *Active*, *Time Sensitive* uniquement le jour d'examen, aucun push marketing sans opt-in.
- StoreKit 2 (`SubscriptionStoreView`), restauration, gestion système ; Sign in with Apple / passkeys (via la fédération Entra existante).
- Foundation Models avec repli non-IA systématique (disponibilité vérifiée à l'exécution, `contextSize` lu à l'exécution, conception pour 4 096 tokens).
- Accessibility Nutrition Labels déclarés honnêtement (VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion, Captions).
- Adaptativité : tailles de classe, marges, aucune largeur fixe ; iPad et iPhone Duo (barre latérale adaptable, deux colonnes Atlas / Concept).

### 14.2 Recommandé (SHOULD)
Live Activities (examen blanc chronométré, Plongée, jour d'examen) ; contrôle Centre de contrôle / bouton Action « Express 5 min » ; SpeechAnalyzer pour *Expliquer* à la voix (audio non conservé) ; Translation pour le glossaire bilingue (le contenu d'examen reste dans sa langue) ; Background Assets / tâche continue pour les packs hors ligne ; Private Cloud Compute (iOS 27) pour plans et débriefs longs si éligible ; Declared Age Range ; Writing Tools dans les notes (exclure le code) ; Apple Watch en phase 2 (rappels de 60 s).

### 14.3 Possible (MAY) et à éviter (AVOID)
- **MAY :** SharePlay (« Situation ensemble » en FaceTime), Visual Intelligence (pointer un message d'erreur → fiche), Screen Time API (bloc d'étude volontaire), App Clip pour jouer une Situation partagée sans installer (limites de taille à vérifier).
- **AVOID :** tab bar personnalisée ; verre derrière du texte courant ; Game Center / app Jeux comme couche sociale principale (éligibilité d'une app éducative non vérifiée, et contraire au progrès humain) ; Image Playground pour des schémas techniques ; Journaling Suggestions.

### 14.4 Cible de déploiement
Aujourd'hui iOS 17. iOS 26 équipait **79 % des iPhone** au 7 juin 2026 (données Apple citées par la presse) et la plupart des capacités ci-dessus exigent iOS 26+. **Recommandation :** passer à **iOS 26 minimum** à la prochaine version majeure (décision DR-002), d'ici là `#available` systématique. **[INDUSTRY PATTERN R§11]**

---
## 15. Langage visuel — « Cœur calme, expression méritée »

### 15.1 Douze principes
1. **Cœur calme, expression méritée** — les écrans d'étude restent silencieux ; l'expression suit l'échelle de célébration (§13).
2. **Le contenu est le héros** — situations, artefacts et explications ont l'espace et le contraste ; l'interface s'efface.
3. **La hiérarchie plutôt que l'ornement** — taille, graisse, couleur et contenant désignent la prochaine action.
4. **Un accent propre, parcimonieux** — l'*Indigo CertiGo* sur ~10 % de la surface (actions, progression) ; les **couleurs de région** pour la connaissance.
5. **Un système de symboles propre** — jamais d'icônes d'éditeurs comme marque.
6. **Une typographie « amicale sans être enfantine »** — polices système, Dynamic Type partout, mono pour le code, jamais de graisses fines.
7. **Un feedback multisensoriel, entièrement optionnel.**
8. **Le mouvement explique d'abord**, célèbre ensuite.
9. **La profondeur seulement là où il n'y a rien à lire.**
10. **Une voix adulte.**
11. **Des rituels et des récaps.**
12. **L'accessibilité comme attribut de marque.**
**[EVIDENCE-BASED / DESIGN JUDGMENT R§3]**

### 15.2 Couleurs (rôles sémantiques ; contrastes vérifiés par calcul WCAG)
**Neutres :** rôles mappés sur les couleurs système (adaptation automatique sombre / contraste) : `canvas` = systemGroupedBackground · `surface` = secondarySystemGroupedBackground · `surfaceRaised` = tertiarySystemGroupedBackground · `textPrimary` = label · `textSecondary` = secondaryLabel · `textTertiary` = tertiaryLabel (jamais pour une information essentielle) · `separator` = separator.

**Marque, feedback, régions** (texte et symboles ; ratios mesurés sur #F2F2F7 en clair, sur #2C2C2E en sombre — tous ≥ 4,5:1 ; variantes « HC » ≥ 7:1 pour Increase Contrast) :
| Rôle | Clair | Sombre | HC clair | HC sombre | Usage |
|---|---|---|---|---|---|
| `accent` (Indigo CertiGo) | #4338CA | #8E8CFF | #4338CA | #B4B2FF | Liens, sélection, progression |
| `accentFill` (fond de bouton principal, texte blanc) | #4338CA (7,9:1) | #5B52F0 (5,4:1) | #3A30B5 | #5B52F0 | Bouton principal uniquement |
| `positive` | #1A7F37 | #3FB950 | #135D28 | #6BCD79 | « Correct » (+ symbole + mot) |
| `negative` | #B42318 | #FF7B72 | #9D1F15 | #FF9F98 | « Pas tout à fait » (+ symbole + mot) |
| `caution` | #8A5A00 | #E3B341 | #704900 | #E3B341 | « Presque » / avertissement |
| `region.cloud` | #0A5FC2 | #5AA9FF | #0850A2 | #80BDFF | Cloud & architecture |
| `region.ai` | #7A35E8 | #B996FF | #6319D9 | #C7AAFF | IA |
| `region.data` | #0B6E87 | #3DD5F3 | #09596D | #3DD5F3 | Données |
| `region.security` | #C0263D | #FF7A8A | #9C1F32 | #FF9EA9 | Sécurité |
| `region.network` | #0B7268 | #3FD9C4 | #095B53 | #3FD9C4 | Réseau |
| `region.devops` | #B8430B | #FF9F5A | #8F3409 | #FFA25F | DevOps, conteneurs, IaC, Git |
| `region.code` | #8F5A00 | #F5C64A | #734800 | #F5C64A | Programmation |
| `region.systems` | #167A3B | #5BDB8A | #115E2D | #5BDB8A | Linux & systèmes |
Variantes `soft` (fonds de puces, halos) : même teinte à 12 % d'opacité en clair, 20 % en sombre ; jamais de texte en couleur de région sur un fond `soft` de la même région sans vérification.

**Artefacts (code, logs, configs)** : fond `surfaceArtifact` #F5F6F8 / #151517 ; texte #1D1D1F / #E6E6EA ; mots-clés #A0287A / #FF7AC6 ; chaînes #1F7A1F / #7EE787 ; commentaires #5E6470 / #9AA3AF ; nombres #9A4D00 / #FFB86B ; types #0B5FA8 / #79C0FF (tous ≥ 5:1) ; ligne signalée : fond #FDE7E9 / #4A1D22 + marqueur de marge + libellé VoiceOver.

**Règles :** la couleur n'est **jamais** le seul porteur d'information ; le bleu #0078D4 est **interdit** ; pas de dégradés sur les écrans d'étude (autorisés uniquement dans les célébrations de niveau ≥ 2, l'icône et les cartes de partage).

### 15.3 Typographie
| Style Prism | Base | Usage |
|---|---|---|
| `display` | SF Pro, `.largeTitle` agrandi via `@ScaledMetric` (base 40 pt), Bold | Chiffres héros, titres de célébration |
| `title1`–`title3` | Styles système | Titres d'écran et de section |
| `headline` / `body` / `callout` / `subheadline` / `footnote` / `caption` | Styles système | Texte d'interface |
| `editorial` | New York (`.serif`), `.body` | Lecture longue en *Plongée* (à valider par test de préférence) |
| `code` / `codeSmall` | SF Mono (`.monospaced`), `.body` / `.callout`, chiffres tabulaires | Artefacts |
| `numeric` | `.monospacedDigit()` | Compteurs, minuteurs |
Règles : Dynamic Type jusqu'à AX5 ; aux tailles d'accessibilité, les dispositions horizontales passent en vertical (`ViewThatFits` / `AnyLayout`) ; jamais de troncature d'énoncé ; artefacts avec retour à la ligne activable et défilement horizontal sinon ; aucune graisse Ultralight / Thin / Light ; Bold Text respecté. **[OFFICIAL APPLE R§11]**

### 15.4 Symboles
- **SF Symbols** pour toute l'interface (variantes pleines pour l'état sélectionné).
- **Glyphes CertiGo** (symboles personnalisés au format SF Symbols, graisses alignées, libellés d'accessibilité) : 8 glyphes de région · 5 glyphes d'état de concept (*Inconnu*, *Découvert*, *En pratique*, *Ancré*, *Maîtrisé* = facette) · glyphe *Fausse idée* · glyphe *Déclic* · glyphe de route.
- Animations de symboles (iOS 26+) : *Draw On* pour un jour de Rythme accompli, *Variable Draw* pour la profondeur d'un concept, *Magic Replace* pour un changement d'état.
- Les produits réels (Azure, Microsoft 365, GitHub, AWS…) sont représentés par leurs **icônes officielles**, non modifiées et toujours accompagnées de leur nom (§15.11). SF Symbols et glyphes CertiGo restent l'iconographie **de l'interface** ; une icône d'éditeur n'est jamais un bouton, un onglet ou un état.

### 15.5 Illustration
Aucun personnage (sauf test de la *Facette*, §5.4). Illustrations **géométriques abstraites** (facettes, lumière, réfraction) pour les états vides, l'accueil et les célébrations. Les **schémas techniques** sont dessinés nativement (formes SwiftUI / `Canvas`) à partir d'une spécification de données, avec description textuelle structurée ; chaque nœud qui représente un service réel porte son **icône officielle** et son nom, comme dans les schémas d'architecture des éditeurs (§15.11) ; jamais d'image générée par IA pour un schéma ; pas de photos d'illustration.

### 15.6 Espacement, grille, tailles
Échelle 4 pt : `xxs` 2 · `xs` 4 · `s` 8 · `m` 12 · `l` 16 · `xl` 20 · `xxl` 24 · `xxxl` 32 · `huge` 48 · `giant` 64. Marges d'écran : marges système (16–20 pt) ; padding de carte : 16 (`l`) ou 20 (`xl`) pour les cartes héros ; espacement entre sections : 24–32 ; largeur de lecture maximale ~ 672 pt sur grand écran ; cible tactile ≥ 44 × 44 pt ; bouton principal hauteur ≥ 50 pt.

### 15.7 Surfaces, matériaux, cartes
- **Contenu = surfaces opaques** (`surface`, `surfaceArtifact`). **Liquid Glass = navigation et contrôles** (tab bar, toolbars, accessoire « Séance en cours », bouton flottant Vérifier si nécessaire), variante *regular* derrière du texte, regroupée dans un `GlassEffectContainer`. **[OFFICIAL APPLE R§11]**
- **Rayons :** `s` 8 (puces) · `m` 12 (champs, lignes d'artefact signalées) · `l` 16 (cartes) · `xl` 24 (cartes héros, feuilles) · capsule (boutons secondaires, puces) — coins continus.
- **Élévation :** quasi nulle ; ombre douce uniquement pour la carte Séance héros en clair ; séparation par contraste de surface, pas par ombres.
- **Types de cartes :** *Standard* · *Héros* (Séance, Situation du jour) · *Artefact* · *Feedback* · *Situation* (contexte + artefact) · *Partage* (rendu image).

### 15.8 Mouvement
| Fonction | Exemple | Jeton | Reduce Motion |
|---|---|---|---|
| Orientation | Passage carte → feedback | `snappy` (ressort ~0,3 s, sans rebond) | Fondu 0,2 s |
| Feedback | Statut de réponse, sélection de ligne | `quick` (0,15 s) | Identique (opacité) |
| Continuité | Concept qui rejoint l'Atlas | `smooth` (~0,45 s) | Fondu |
| Célébration | Réfraction | `expressive` (keyframes ≤ 1,2 s) | Fondu + éclat statique |
Règles : pas d'animation sur les interactions fréquentes au-delà du feedback ; une animation à la fois ; aucune boucle infinie sur un écran au repos ; 60 i/s minimum (120 sur ProMotion) sur l'appareil de référence ; pas de parallaxe, de flou animé ni de rotation continue.

### 15.9 Haptique, son, copie des notifications
- **Haptique** : `.selection` (choix, ligne d'artefact), `.success` (correct, séance terminée), impact léger (incorrect — jamais `.error`, réservé aux erreurs système), `.warning` (actions destructives), motif *Déclic* (niveaux 2–3). Réglage « Haptique » dans l'app.
- **Son** : désactivable ; session audio *ambient* (respecte le mode silencieux) ; ton court de réponse, motif *Déclic*, motif étendu.
- **Notifications** (exemples validés) :
  - « Ta Situation du jour : un pod Kubernetes redémarre en boucle. 2 minutes ? »
  - « 6 concepts sont prêts à être ravivés. 3 minutes suffisent. »
  - « Ta Squad a atteint 80 % de son objectif de la semaine. »
  - « Examen AZ-900 aujourd'hui. Une révision légère, puis fais-toi confiance. »
  - Interdits : toute formule de perte, de culpabilité, d'absence d'un personnage, de compte à rebours.

### 15.10 États
| État | Règle | Exemple |
|---|---|---|
| Chargement | Squelette de la mise en page finale ; > 1 s : une astuce d'apprentissage | « Astuce : te tester te fait plus progresser que relire. » |
| Vide | Une ligne de valeur + une action (`ContentUnavailableView`) | « Ton Atlas commence ici. — Faire ma première Situation » |
| Erreur | Explique, ne gronde jamais, propose une action ; code technique masqué (copiable) | « Impossible de charger ta séance. Tes réponses sont en sécurité. — Réessayer » |
| Hors ligne | Bandeau discret + ce qui reste possible | « Hors ligne — 2 séances disponibles, tes réponses seront synchronisées. » |
| Invité | Tout fonctionne ; incitation douce à sauvegarder | « Sauvegarde ta progression en 1 tap. » |
| Fonction IA indisponible | Repli silencieux vers l'explication auteur ; mention discrète | « Explication de l'auteur » |

### 15.11 Icônes officielles des éditeurs — « le vrai symbole, jamais une imitation »
**Décision (fondateur, 22/10/2026 — ADR-016).** Quand CertiGo parle d'un produit réel, il montre **son vrai symbole** : les icônes Azure telles qu'elles apparaissent dans le portail et dans les schémas d'architecture Microsoft, les vraies icônes de Dynamics 365, de Microsoft Fabric ou de Microsoft Entra ID, les symboles officiels publiés par GitHub et, à mesure que l'*Atlas* s'étend, ceux d'AWS, de Google Cloud, de Kubernetes… — **toujours tels que l'éditeur les fournit, dans les usages qu'il autorise**. Ce que l'éditeur réserve à une licence (icônes Word, Excel ou Teams, logos d'entreprise) n'apparaît qu'après autorisation écrite.

**Pourquoi.**
- *Reconnaissance et transfert.* Les images sont mieux retenues que les mots seuls (effet de supériorité de l'image, double codage — Paivio ; Nelson, Reed & Walling 1976), et un indice présent à l'apprentissage aide le rappel quand il réapparaît (spécificité de l'encodage — Tulving & Thomson 1973 ; traitement approprié au transfert — Morris, Bransford & Franks 1977). **[EVIDENCE-BASED pour les principes]** Apprendre avec les symboles du portail, de la console et des schémas officiels prépare à les reconnaître au travail et dans les documents d'examen. **[DESIGN JUDGMENT pour l'application]**
- *Crédibilité et artisanat.* Une icône approximative signale l'amateurisme ; l'exactitude visuelle prolonge l'exactitude du contenu (« aucune icône approximative », §13). **[DESIGN JUDGMENT]**
- *Conformité.* Les éditeurs publient des kits officiels pour les schémas, les formations et la documentation ; les utiliser **non modifiés et dans ce périmètre** est ce qui rend l'usage légitime — à l'opposé des anciennes mascottes dérivées (§5.4). **[EVIDENCE-BASED — conditions officielles ; pas un avis juridique]**

**Règles produit.**
| Règle | Détail |
|---|---|
| Ce que l'on montre | Icônes de **produits et services** issues des **kits d'architecture officiels** (Azure, Power Platform, Dynamics 365, Fabric, Entra ; puis les kits équivalents des autres éditeurs) et icônes non-logo publiées sous licence libre (ex. Octicons de GitHub) |
| Ce que l'on ne montre pas sans autorisation écrite | **Icônes d'applications Microsoft 365** (Word, Excel, PowerPoint, Outlook, Teams, SharePoint, OneDrive…), symbole Windows, **logos d'entreprise** (Microsoft, GitHub…), captures d'écran de produits ; et toute icône hors du contenu pédagogique (*Atlas*, *Objectifs*, *Passeport*) |
| Ce que l'on ne montre jamais | **Badges et logos de certification** (une certification s'écrit en texte : code + intitulé officiel) ; imitations ou recréations d'icônes |
| Comment | Non modifiées (formes, couleurs, proportions), sur une plaque neutre, **toujours avec le nom officiel complet**, jamais teintées par l'accent ni par une couleur de région, jamais l'élément dominant de l'écran ; une icône ne représente que le produit pour lequel elle a été dessinée |
| Où | Schémas (chaque nœud qui représente un service réel), cartes *Apprendre*, *Situations*, explications, page *Concept*, glossaire ; *Atlas*, *Objectifs*, Recherche et *Passeport* dès qu'une autorisation écrite est enregistrée (repli d'ici là) |
| Où jamais | Icône de l'app, logo CertiGo, *Facette*, célébrations, écrans d'accueil et paywall, notifications, widgets, Live Activities, cartes de partage, page App Store (nom, icône, captures, aperçus), publicité |
| Quand l'éditeur ne permet pas un usage | Repli neutre CertiGo (glyphe de région + nom en texte) — **jamais une imitation** du logo ; les vrais symboles apparaissent automatiquement le jour où l'autorisation est enregistrée |
| Transparence | Écran « Marques et mentions légales » (mentions de marque, kits, versions, conditions) + phrase de non-affiliation |

**Coexistence avec Prism.** Deux registres visuels distincts : **l'interface** parle en SF Symbols et glyphes CertiGo (accent Indigo, couleurs de région) ; **le contenu** montre les produits réels avec leurs icônes officielles. La couleur de région habille le cadre (puce, halo, nœud d'*Atlas*), jamais l'icône. Une icône d'éditeur n'est jamais un bouton, un onglet ou un indicateur d'état. **[DESIGN JUDGMENT]**

**Spécification d'ingénierie :** Master Prompt §22A (sources officielles par éditeur, contextes autorisés appliqués automatiquement, manifeste de licences, garde-fous CI) ; inventaire en Phase 0 ; mise en œuvre à l'étape **2B**, puis dans chaque phase qui affiche un produit. Les cas non couverts par les conditions d'un éditeur sont tranchés par OD-11 / DR-010.

---

## 16. Écrans North Star

> Format : **Rôle · Anatomie (haut → bas) · Interactions · États · Accessibilité · Analytics · Critères (Given / When / Then)**. Les composants cités sont ceux de Prism (§18). **Règle transversale :** dans tous ces écrans, un produit réel nommé est accompagné de son icône officielle (`BrandLabel`, §15.11) dans les contextes autorisés par l'éditeur.

### NS-1 — Premier lancement (Bienvenue → Situation de découverte → Premier Déclic)
- **Rôle :** prouver en < 60 s que CertiGo mérite d'exister.
- **Anatomie :** icône animée (réfraction courte) · « Une question. Une idée plus claire. » · « Progresse en tech, chaque jour. » · grille de 8 `RegionChip` + « Je prépare une certification » · (écran suivant) `SituationCard` plein écran · `ArtifactView` · `ChoiceList` + `ConfidencePicker` · `FeedbackPanel` · (écran final) mini-Atlas avec 3 concepts qui s'allument + distribution communautaire + bouton « Continuer ».
- **Interactions :** 1 tap pour choisir la région ; 3 décisions ; aucun champ texte.
- **États :** hors ligne (Situation de découverte embarquée dans l'app) ; Reduce Motion (pas de réfraction).
- **Accessibilité :** tout le parcours au VoiceOver et en AX5 ; ordre de lecture : contexte → artefact → question → options.
- **Analytics :** `onboarding_started`, `region_selected`, `taste_item_answered`, `taste_completed{correct, duration}`, `first_declic_viewed`.
- **Critères :** *Given* une première ouverture, *when* l'utilisateur choisit « Réseau », *then* la première décision apparaît en ≤ 2 écrans et ≤ 10 s ; *Given* la Situation terminée, *then* le temps médian jusqu'au premier feedback est < 60 s en test utilisateur.

### NS-2 — Aujourd'hui
- **Rôle / anatomie :** voir §10.2 (`SessionHeroCard` avec `SessionLengthPicker`, `DailySituationCard`, `RhythmWeekView`, `MemoryForecastCard`, `ReadinessBandView` compact, `SquadGoalView` compact, `InsightLine`).
- **Interactions :** 1 tap = Commencer ; appui long sur la carte Séance = menu (changer de durée, voir la composition) ; tirer pour rafraîchir.
- **États :** §10.3.
- **Accessibilité :** chaque carte = un élément VoiceOver avec résumé (« Séance de 15 minutes : 6 rappels, 1 nouveau concept, 1 situation. Bouton Commencer. ») ; actions personnalisées pour les actions secondaires.
- **Analytics :** `today_viewed{state}`, `session_started{length, entry: today}`, `daily_situation_opened`.
- **Critères :** *Given* 6 révisions dues, *when* Aujourd'hui s'ouvre, *then* la composition indique « 6 rappels » et Commencer lance la séance en 1 tap ; *Given* AX5, *then* aucune carte n'est tronquée et la carte Séance reste en premier.

### NS-3 — Séance : carte d'apprentissage
- **Anatomie :** `SessionProgressHeader` (segments, Terminer) · `QuestionCard` d'ouverture **avant** l'explication · `ExplanationCard` (≤ 1 idée, signalisation) · `WorkedExampleView` (sous-objectifs étiquetés) · `DiagramView` si utile · bouton « Continuer » / « Je connais déjà » (test de saut).
- **Critères :** *Given* un apprenant qui réussit le test de saut, *then* l'exemple travaillé est remplacé par un item de niveau supérieur (inversion d'expertise).

### NS-4 — Séance : item sur artefact (*Trouver l'erreur*)
- **Anatomie :** contexte (1–2 lignes) · `ArtifactView` (numéros de ligne, coloration, zoom, retour à la ligne) · consigne « Touche la ligne qui pose problème » · `ConfidencePicker` · bouton **Vérifier** (zone du pouce).
- **Interactions :** tap sur une ligne = surlignage + `.selection` ; re-tap = désélection ; Vérifier actif seulement après sélection.
- **Accessibilité :** rotor VoiceOver « Lignes » ; chaque ligne annoncée « Ligne 7 : allow inbound port 3389 from any » ; action « Sélectionner cette ligne ».
- **Critères :** *Given* un artefact de 25 lignes en AX5, *then* toutes les lignes sont lisibles sans troncature ; *Given* VoiceOver, *then* l'item est réalisable sans geste de glisser.

### NS-5 — Feedback
- **Anatomie :** `FeedbackPanel` : statut (symbole + mot + couleur) · explication de la bonne réponse · « pourquoi ton choix » (spécifique à l'option) · fausse idée nommée (si détectée) · `TakeawayLine` · actions : *Expliquer autrement* (IA), *Pourquoi ?*, *Voir la fiche*, *Signaler* · bouton **Continuer**.
- **Variantes :** correct · pas tout à fait · erreur avec certitude (message dédié) · examen blanc (aucun feedback).
- **Critères :** *Given* une réponse soumise en ligne, *then* le feedback s'affiche en ≤ 1 s perçu (p95) ; *Given* une option fausse choisie, *then* l'explication de **cette** option est affichée.

### NS-6 — Résultats de séance
- **Anatomie :** titre (« Séance terminée ») · « Ce qui a changé » (concepts qui changent d'état, animés vers l'Atlas) · fausse idée corrigée · Rythme du jour accompli · prochaine étape (1 suggestion) · « Encore 5 min » / « Terminé ».
- **Critères :** *Given* un concept passé à *Ancré*, *then* une célébration de niveau 2 est jouée (ou sa variante Reduce Motion) et l'Atlas reflète l'état.

### NS-7 — Situation du jour
- **Anatomie :** région + date · contexte · artefact · 1–3 décisions + confiance · révélation · `CommunityDistributionChart` (après réponse) · explication · *À retenir* · `ShareCardRenderer` (grille sans spoiler) · lien vers l'historique.
- **Critères :** *Given* une réponse non encore donnée, *then* aucune statistique communautaire n'est visible ; *Given* un partage, *then* l'image ne contient ni la question ni la réponse.

### NS-8 — Atlas
- **Anatomie :** bascule **Carte / Liste** · filtres (Mon objectif · Tout · À raviver · Fausses idées) · `AtlasCanvas` (régions → territoires → concepts, zoom sémantique ; luminosité = mémoire ; glyphe = état ; anneau de territoire) · `AtlasList` (même information, structurée) · section Objectifs (routes) · Explorer.
- **Accessibilité :** la **Liste est l'équivalent complet** de la Carte et le mode par défaut avec VoiceOver ; la Carte n'est jamais le seul accès à une information.
- **Performance :** 60 i/s avec ≤ 500 nœuds visibles ; niveaux de détail ; pas d'animation au repos.
- **Critères :** *Given* le filtre « À raviver », *then* seuls les concepts dont la rétention prédite < 80 % sont montrés, avec un bouton « Raviver (3 min) ».

### NS-9 — Concept
- **Anatomie :** en-tête (région, nom, état, échelons `DepthLadderView`, mémoire) · « En une phrase » · explication · exemple travaillé · artefact(s) · schéma · fausses idées liées · *Comparer avec…* · concepts voisins · sources **datées** · « Pratiquer 1 min » · *Signaler une erreur*.
- **Critères :** *Given* un concept dont le contenu a changé depuis l'ancrage, *then* une bannière « Mise à jour de connaissance » propose un rafraîchissement d'1 min.

### NS-10 — Objectif & Préparation
- **Anatomie :** route (code, nom, version du programme, date d'examen) · `ReadinessBandView` (bande, incertitude, nombre de preuves) · `ObjectiveCoverageList` (par objectif officiel : poids, couverture, profondeur, mémoire) · « 3 actions pour te rapprocher de *Prêt* » · examens blancs · plan · liens officiels · « Comment s'est passé ton examen ? » (après la date).
- **Critères :** *Given* < 1 examen blanc sur items jamais vus, *then* la bande affiche *Preuves insuffisantes* et aucun pourcentage ; *Given* VoiceOver, *then* chaque objectif est annoncé avec poids et état.

### NS-11 — Examen blanc et débrief
- **Anatomie :** écran d'avant-examen (durée, format, option **temps majoré / sans limite**) · items sans feedback · navigation entre items, marquage · Live Activity (minuteur) · fin → débrief par objectif, fausses idées, impact sur la Préparation, 3 actions.
- **Critères :** *Given* l'option sans limite, *then* aucun minuteur n'est affiché ni annoncé.

### NS-12 — Ensemble (Squad)
- **Anatomie :** voir §11.2 ; `SquadGoalView` (barre coopérative), membres (monogrammes), `KudosButton`, Mission coopérative, défis.
- **Critères :** *Given* un nouveau compte, *then* le profil est privé et la participation aux ligues est désactivée.

### NS-13 — Profil & Passeport
- **Anatomie :** `PassportCard` (régions, concepts maîtrisés, routes, examens réussis déclarés) · Historique & calibration (« Ta confiance est bien calibrée à 82 % ») · Carte de mes fausses idées · CertiGo Pro · Réglages.
- **Règle :** le Passeport ne s'intitule jamais « certificat » et mentionne « preuves d'apprentissage CertiGo, pas une certification officielle ».

### NS-14 — Widgets et Live Activity
- **Widgets :** *Aujourd'hui* (petit / moyen : séance + Rythme) · *Situation du jour* (moyen) · *Carte de révision* interactive (moyen / grand : question → 3 boutons de réponse → feedback court ; la notation reste serveur, le widget affiche « Réponse enregistrée » puis le résultat à la prochaine actualisation si la politique DR-004 l'exige).
- **Live Activity :** examen blanc (temps restant, item n/N), Plongée (étape), jour d'examen.
- **Critères :** *Given* le widget *Carte de révision*, *when* l'utilisateur répond, *then* la réponse est mise en file sans ouvrir l'app.

---

## 17. Validation (à mener avant et pendant l'implémentation)

| # | Question | Méthode | Seuil de succès |
|---|---|---|---|
| V1 | Le premier lancement crée-t-il un WOW et une compréhension ? | Tests modérés (8–12 personnes par segment S1/S2/S3) sur prototype | ≥ 80 % expliquent CertiGo en une phrase ; médiane < 60 s jusqu'au 1er feedback |
| V2 | Les formats d'artefact sont-ils lisibles et utiles sur iPhone ? | Tests de tâches (AX défaut et AX3), mesure du temps et des erreurs | ≥ 90 % de réussite d'interaction ; utilité perçue ≥ 4/5 |
| V3 | Les formats apprennent-ils mieux que des QCM équivalents ? | Expérience : Parsons vs estompé vs correction, à J+7 sur une tâche de transfert ; *Diagnostiquer* vs QCM | Gain significatif ou équivalence à coût moindre |
| V4 | La Situation du jour devient-elle un rituel ? | Bêta TestFlight 4 semaines | ≥ 40 % des actifs hebdo la font ≥ 4 j/sem |
| V5 | Rythme hebdomadaire vs série quotidienne | A/B | Rétention W4 non inférieure **et** stress déclaré inférieur |
| V6 | La Préparation est-elle honnête ? | Collecte des résultats d'examen (opt-in, incitée) | Brier / fiabilité suivis ; écart prévu-observé < 10 pts avant d'afficher une probabilité |
| V7 | L'IA aide-t-elle à apprendre ? | A/B contre groupe sans IA sur items différés sans aide | Non-infériorité minimale ; réponse avant tentative ≈ 0 |
| V8 | Personnage C vs D | Test de préférence + crédibilité perçue (adultes) | C retenu seulement s'il gagne sans perte de crédibilité |
| V9 | Accessibilité réelle | Sessions avec 3–5 utilisateurs VoiceOver / basse vision | 100 % des tâches courantes réalisables |
| V10 | Disposition à payer | Van Westendorp + test de paywall contextuel | Fourchette de prix validée par segment |
| V11 | Nom de marque | Recherche d'antériorité + test de confusion (Certingo) | Avis juridique favorable |

Principe : chaque test A/B est jugé sur l'apprentissage **et** sur les garde-fous (§2.3), jamais sur le DAU seul ; porte éthique avant tout test touchant aux notifications ou à la motivation. **[INDUSTRY PATTERN R§7 : rapport FTC sur l'expérimentation]**

---

## 18. Prism — design system natif

### 18.1 Statut et périmètre
Prism (ex-package Flutter `prism_ui`, « néon doux ») est **refondu en module Swift natif** : `apps/apple/CertigoKit/Sources/Prism`. Il est **l'unique source** de couleurs, typographie, espacements, rayons, matériaux, mouvement, haptique, son et composants visuels. L'ancien Prism Flutter est une archive de référence, **non portée**.

### 18.2 Architecture
```
Prism/
├─ Tokens/        PrismColor · PrismTypography · PrismSpacing · PrismRadius · PrismSize
│                 PrismMaterial · PrismElevation · PrismMotion · PrismHaptics · PrismSound
├─ Foundation/    PrismText · PrismIcon (SF Symbols + glyphes CertiGo) · PrismButtonStyle
│                 PrismCard · PrismSection · PrismRow · PrismChip · PrismBadge
│                 PrismProgressBar · PrismProgressRing · PrismSegmentedControl
├─ Learning/      SessionProgressHeader · SessionLengthPicker · QuestionCard · ExplanationCard
│                 WorkedExampleView · DiagramView · ArtifactView · ChoiceList · ConfidencePicker
│                 TokenComposer · OrderList · SlotBoard · EstimateSlider · ExplainInput
│                 FeedbackPanel · ResponsibilityMatrix · TakeawayLine · HintLadderView
├─ Progress/      MasteryGlyph · DepthLadderView · MemoryForecastChart · ReadinessBandView
│                 ObjectiveCoverageList · RhythmWeekView · AtlasCanvas · AtlasList
│                 RegionChip · RouteBadge · PassportCard
├─ Social/        AvatarMonogram · KudosButton · SquadGoalView · ChallengeCard
│                 CommunityDistributionChart
├─ States/        PrismEmptyState · PrismErrorState · PrismOfflineBanner · PrismSkeleton
│                 PrismToast · PrismCelebration (niveaux 0–3) · ShareCardRenderer
├─ Brand/        BrandIcon · BrandLabel · BrandFallbackMark · BrandNoticesView
│                 (données : module BrandAssets — registre, manifeste, icônes officielles ; §15.11)
├─ Accessibility/ adaptations AX (layouts), rotors, actions personnalisées, annonces
└─ Gallery/       PrismGallery (Debug uniquement)
Tests/PrismTests/ contrastes WCAG · snapshots · lint des tokens
```

### 18.3 Règles d'API
- Les tokens sont des **rôles sémantiques** (`PrismColor.region(.network)`, `PrismSpacing.l`), jamais des valeurs.
- Les variantes (sombre, Increase Contrast, Reduce Motion, Reduce Transparency, Dynamic Type) sont résolues **dans Prism** via l'environnement, jamais dans les écrans.
- Chaque composant : `#Preview` (nominal, vide, chargement, erreur, AX3, sombre), snapshot, test d'accessibilité, documentation (but, variantes, do/don't) dans la galerie.
- Un élément entre dans Prism s'il est utilisé ≥ 2 fois **ou** s'il appartient à un écran North Star.
- Le test de contraste calcule les ratios WCAG de chaque paire texte / fond (clair, sombre, HC) et **échoue** sous 4,5:1 (texte) ou 3:1 (non-texte).

### 18.4 Gouvernance
Versionnement interne (MAJEUR.MINEUR.CORRECTIF) ; `Prism/CHANGELOG.md` ; tout nouveau composant ou token passe par une entrée du journal des décisions ; dépréciation en deux versions ; aucune modification de token sans captures avant / après.

---

## 19. Lexique

| Terme | Définition |
|---|---|
| **Situation** | Mini-cas réel (contexte + artefact + 1–3 décisions + explication + à retenir), 1 à 3 min |
| **Situation du jour** | La Situation commune à tous les apprenants d'une région, ce jour-là |
| **Artefact** | Objet technique réaliste : code, log, configuration, sortie de commande, schéma, facture |
| **Atlas** | Carte personnelle des connaissances : régions → territoires → concepts |
| **Région** | Grand domaine (Cloud, IA, Données, Sécurité, Réseau, DevOps, Code, Systèmes) |
| **Territoire** | Sous-domaine cohérent d'une région (ex. Identité, Réseau virtuel) |
| **Concept** | Nœud enseignable et testable de l'Atlas |
| **Route** | Objectif (certification ou compétence) tracé sur l'Atlas, avec ses objectifs officiels pondérés |
| **Échelon** | Niveau de profondeur d'un concept : Reconnaître · Rappeler · Appliquer · Analyser · Expliquer (· Pratiquer) |
| **Découvert / En pratique / Ancré / Maîtrisé** | États d'un concept (§7.4) |
| **S'estompe** | Rétention prédite < 80 % |
| **Fausse idée** | Erreur typique nommée, détectée par les distracteurs |
| **Déclic** | Moment signature : fausse idée corrigée ou concept ancré (réfraction + motif + haptique) |
| **Express / Séance / Plongée** | Séances de ~5, ~15, 30–45 min |
| **Rythme** | Objectif de jours d'apprentissage par semaine, avec jours de repos |
| **Squad** | Groupe d'étude de 3 à 8 personnes avec un objectif hebdomadaire commun |
| **Défi** | Duel asynchrone noté sur la justesse et la calibration |
| **Mission** | Objectif hebdomadaire lié à une compétence (≤ 3) |
| **Préparation** | Estimation honnête de la préparation à un examen (bandes, incertitude, preuves) |
| **Passeport** | Preuves d'apprentissage CertiGo partageables (pas une certification) |
| **Mise à jour de connaissance** | Rafraîchissement d'1 min quand un contenu ancré change |

---

## 20. Journal des décisions

### 20.1 Décisions prises (v1.0, complétées en v1.1)
| ID | Décision | Étiquette |
|---|---|---|
| ADR-001 | L'unité d'apprentissage est la *Situation* sur artefact ; thèse « artefacts et décisions » | EVIDENCE-BASED + EXPERIMENTAL BET |
| ADR-002 | Direction produit D « L'Atlas vivant » (A + B + C) | DESIGN JUDGMENT |
| ADR-003 | Navigation : Aujourd'hui · Atlas · Ensemble · Profil (+ Recherche) ; Coach retiré comme onglet | DESIGN JUDGMENT + EVIDENCE-BASED |
| ADR-004 | Séance unique 5 / 15 / 30–45 min composée par le serveur | EVIDENCE-BASED |
| ADR-005 | Progression Profondeur × Mémoire ; *Ancré* / *Maîtrisé* selon le *successive relearning* | EVIDENCE-BASED |
| ADR-006 | Readiness 0–100 remplacé par la *Préparation* ; probabilité masquée jusqu'à calibration | EVIDENCE-BASED |
| ADR-007 | Rythme hebdomadaire primaire ; série quotidienne optionnelle | EVIDENCE-BASED |
| ADR-008 | Suppression UI des gemmes, de la boutique, de la réparation payante, des ligues XP publiques, des messages de perte | EVIDENCE-BASED + INDUSTRY PATTERN (réglementation) |
| ADR-009 | Compétition opt-in, appariée, plafonnée ; social coopératif et privé par défaut | EVIDENCE-BASED |
| ADR-010 | IA : colonne déterministe, voix ancrée, contrat d'effort ; pas de chat libre | EVIDENCE-BASED |
| ADR-011 | Pas de mascotte (option D) ; glyphe compagnon (C) à tester ; retrait des mascottes dérivées d'icônes Azure et du #0078D4 (les icônes officielles non modifiées restent utilisées pour désigner les produits, ADR-016) | EVIDENCE-BASED + DESIGN JUDGMENT |
| ADR-012 | Personnalité « Cœur calme, expression méritée » ; échelle de célébration 0–3 ; Mode Calme | EVIDENCE-BASED |
| ADR-013 | Liquid Glass réservé à la navigation et aux contrôles | OFFICIAL APPLE |
| ADR-014 | Palette : accent Indigo CertiGo + 8 couleurs de région, contrastes vérifiés | DESIGN JUDGMENT (vérifié par calcul) |
| ADR-015 | Contenu original, relu par un humain, sources datées ; IA rédactrice jamais éditrice | INDUSTRY PATTERN + EVIDENCE-BASED |
| ADR-016 | **Icônes officielles des éditeurs** (v1.1, décision du fondateur du 22/10/2026) : chaque produit réel est représenté par son icône officielle non modifiée, avec son nom, dans les contextes autorisés par l'éditeur (contenu pédagogique d'abord) ; jamais comme marque CertiGo ; icônes d'applications Microsoft 365 et logos d'entreprise seulement sur autorisation écrite ; jamais de badge de certification ; repli neutre sinon | DÉCISION DU FONDATEUR + EVIDENCE-BASED (conditions officielles) + DESIGN JUDGMENT |

### 20.2 Décisions ouvertes (à trancher par le propriétaire)
| ID | Question | Recommandation |
|---|---|---|
| OD-1 | Conflit de nom avec *Certingo* | Recherche d'antériorité et avis juridique avant tout investissement de marque |
| OD-2 | Cible iOS 26 minimum | Oui, à la prochaine version majeure |
| OD-3 | Feedback hors ligne (clé de correction locale pour les items de pratique ?) | Feedback hors ligne **provisoire** seulement pour des items marqués par le serveur, re-notés à la synchronisation ; rien de compétitif ne compte avant re-notation |
| OD-4 | Personnage C (*Facette*) | Prototype + test V8 |
| OD-5 | Âge minimum / mode mineurs | 16+ au lancement, Declared Age Range |
| OD-6 | Prix et périmètre exact de Pro | Test V10 |
| OD-7 | Outil d'analytics et consentement | Pipeline propre via le backend existant (`events`), consentement explicite UE |
| OD-8 | Sort de l'app Flutter | Gel immédiat, archivage après la Phase 11 |
| OD-9 | App Clip pour la Situation partagée | Après validation de V4 |
| OD-10 | Calendrier B2B (Squads d'entreprise, Multiseat) | Après preuve de rétention B2C |
| OD-11 | Éditeurs dont les conditions ne couvrent pas clairement un contexte (catalogue, widgets…) ou qui exigent une licence (logos d'entreprise, badges) | Repli neutre par défaut ; demandes d'autorisation groupées préparées par l'agent, envoyées par le propriétaire ; avis juridique avant le lancement public |

---

## 21. Plan d'implémentation (résumé)
La transformation est exécutée par l'agent de développement selon `03_MASTER_IMPLEMENTATION_PROMPT.md`, en 12 phases réversibles plus l'étape **2B** : **0** audit + baseline (lecture seule) · **1** fondations Prism (+ découpage du monolithe, flags, tests d'architecture) · **2** composants · **2B** icônes officielles des éditeurs (bibliothèque, manifeste de licences, `BrandLabel`) · **3** Aujourd'hui et nouvelle navigation · **4** expérience d'apprentissage (lecteur de séance, formats P1) · **5** feedback, résultats, Situation du jour, examen blanc · **6** Atlas, Concept, Mémoire, Préparation, Passeport · **7** gamification au service de l'apprentissage (Rythme, jalons, Missions, célébrations ; retraits UI) · **8** social (Squads, amis, défis, ligues opt-in) · **9** IA contextuelle · **10** écrans restants et surfaces système (premier lancement, Pro, widgets, Live Activities, App Intents) · **11** durcissement accessibilité, performance, visuel. Chaque phase se termine par les 7 portes (build, tests, validation visuelle, accessibilité, performance, rapport, point de contrôle) et une validation du propriétaire.
**Distinction :** les *décisions ouvertes* (OD-n, §20.2) appartiennent au propriétaire ; les *Decision Requests* (DR-n) sont instruites par l'agent pendant l'implémentation (Master Prompt §37). Correspondances : OD-2 ↔ DR-002 · OD-3 ↔ DR-004 · OD-7 ↔ DR-008 · OD-8 ↔ DR-003 · OD-11 ↔ DR-010.
