# CERTIGO TOP-10-WORTHY REPORT
### Discover what CertiGo should become — recherche produit, design et apprentissage

> **Version :** 1.1 — 22/10/2026 (v1.1 : les vrais symboles des éditeurs — §3.5, §14, annexe C) · **Commanditaire :** Gabriel Chambaud · **Statut :** phase A (découverte) terminée ; ce rapport fonde la *CertiGo Product & Experience Bible* (phase B).
> **Question centrale :** *What would CertiGo need to become one of the most loved, useful, effective and distinctive technology-learning apps on iPhone?*
> **Question ultime :** *Si l'on créait CertiGo aujourd'hui pour en faire l'un des meilleurs produits au monde pour apprendre la technologie sur iPhone, que construirait-on ?* — puis seulement : *comment transformer le CertiGo actuel sans casser ce qui fonctionne ?*

### Méthode
- **Sept fils de recherche** (plus un huitième en v1.1 : icônes et logos officiels des éditeurs) menés en parallèle (≈ 400 sources consultées, dont une majorité de sources primaires) : R1 marché et benchmark · R2 barre de qualité Apple et iOS · R3 science de l'apprentissage, micro-learning et préparation fiable · R4 gamification, habitudes, social, compétition · R5 IA au service de l'apprentissage · R6 apprentissage spécifique à la tech · R7 références design et personnalité de marque. Les mémos complets (en anglais, avec toutes les sources) sont fournis en annexe (`annexes/R1…R7`).
- **Audit de l'existant** à partir de preuves datées : instantané du dépôt (06/07/2026 : Flutter + backend .NET + contenu), journaux de build Xcode de l'app native (14/10 et 22/10/2026), enregistrements d'écran (19/10 et 22/10/2026), trace Instruments de lancement (19/10/2026), fichier d'icône, audits, blueprint d'architecture et étude de monétisation de juillet 2026.
- **Limites :** aucun accès au dépôt natif complet ni à des données d'usage réelles ; la mission de redesign antérieure et le fichier `certigo-figma-ai-prompt.txt` n'étaient pas accessibles ; les classements App Store sont des instantanés du 22/10/2026 ; plusieurs études 2025–2026 sur l'IA sont des documents de travail.

### Discipline de preuve
Chaque conclusion importante porte une étiquette — jamais confondues :
| Étiquette | Signification |
|---|---|
| **EVIDENCE-BASED** | Méta-analyse, essai contrôlé, étude évaluée par les pairs, rapport technique officiel |
| **INDUSTRY PATTERN** | Données d'entreprise, règles de plateformes, réglementation, pratiques établies |
| **COMPETITOR OBSERVATION** | Comportement documenté d'un produit concurrent |
| **DESIGN JUDGMENT** | Jugement de conception argumenté |
| **EXPERIMENTAL BET** | Pari à valider avant ou pendant l'implémentation |
Les recommandations majeures sont reprises dans le **registre de preuves** (annexe C) avec **SOURCE · EVIDENCE · CONFIDENCE · CERTIGO IMPLICATION**.

---

## 1. Executive conclusion

**1. CertiGo a des fondations rares, mais pas encore un produit.** L'architecture de confiance est remarquable (notation autoritative côté serveur, clé de correction jamais exposée, anti-triche, contenu as code avec sources datées, refus des « dumps », suppression de compte, hors-ligne idempotent, 8 langues d'interface) et l'app SwiftUI native démarre sainement (rendu de la première frame ~64 ms sur simulateur). Mais l'expérience livrée aujourd'hui est une **démonstration** : deux situations fictives, un discours omniprésent sur ce que l'app n'est pas (« fictif », « aucun verdict », « pas un corrigé publié »), un feedback en trois temps, un onglet Coach sans rôle clair. Le contenu existant est **mince et monotone** (146 leçons, **145 items sur 146 sont des QCM**, une question par leçon). L'héritage Flutter a copié les mécaniques les **moins défendables** de Duolingo (gemmes, réparation payante de série, 10 ligues XP, notifications culpabilisantes, mascottes dérivées d'icônes Azure, onboarding de 23 écrans avec paywall avant la première leçon). **Score actuel : 3,3 / 10 en moyenne sur 26 dimensions** (11 dimensions ≤ 2) ; cible : **8,2**. (Annexe A.)

**2. Le marché laisse une place réelle.** Aucune app d'apprentissage de la tech n'apparaît dans les classements Education par revenus (top 25 US, top 30 France, instantanés du 22/10/2026) ; la niche certification iOS est fragmentée et peu notée ; aucune app iOS Microsoft Learn n'a été identifiée et ses bacs à sable gratuits semblent retirés ; la pratique technique réelle vit sur ordinateur ; aucune des ~150 distinctions Apple Design Award 2023–2026 ne concerne la préparation aux certifications IT. La demande est structurelle (compétences IA, réseau / cybersécurité et littératie technologique en tête du WEF ; 84 % des professionnels IT prévoient une nouvelle certification sous 12 mois). **[INDUSTRY PATTERN / COMPETITOR OBSERVATION]**

**3. Ce que CertiGo doit devenir : *la pratique quotidienne du jugement technique*.** Duolingo a fait du mot l'unité d'apprentissage ; en tech, l'unité est **l'artefact et la décision** (lire un log, prédire une commande, toucher la mauvaise ligne d'une config, diagnostiquer, arbitrer). La science le soutient : la lecture et le traçage précèdent l'écriture, les problèmes de Parsons et les exemples erronés sont efficaces et adaptés au tactile, le dépannage structuré double les pannes résolues, la récupération espacée et le *successive relearning* produisent une mémoire durable. **Positionnement : « Duolingo vous apprend à lire et dire des mots. CertiGo vous apprend à lire des systèmes et à agir dessus. »** **[EVIDENCE-BASED → EXPERIMENTAL BET]**

**4. La magie recommandée est une combinaison :** la ***Situation du jour*** (un rituel fini et partageable, une situation réelle par région et par jour), l'***Atlas*** (la carte vivante de ce que l'on sait : profondeur × mémoire, les certifications devenant des routes) et le ***Déclic*** (le moment signature quand une fausse idée est corrigée ou qu'un concept s'ancre). Autour : une ***Préparation*** honnête qui montre son incertitude, une ***Séance*** unique de 5 / 15 / 45 minutes, un ***Rythme*** hebdomadaire sans peur, des ***Squads*** coopératives, une **IA contextuelle et ancrée** (pas un onglet de chat), une personnalité **« Cœur calme, expression méritée »** et une **accessibilité de référence** (code, logs et schémas pleinement utilisables au VoiceOver et en AX5 — la voie la plus crédible vers une reconnaissance Apple, catégorie Inclusivity).

**5. Ce qu'il faut arrêter.** Gemmes et boutique ; réparation payante de série ; ligues XP publiques (elles ont triplé chez Duolingo le nombre d'utilisateurs à ≥ 1 h/jour) ; messages de perte ; mascottes dérivées d'icônes Azure et bleu #0078D4 (conditions d'usage Microsoft, affiliation implicite — les icônes officielles, elles, sont adoptées **telles quelles** pour désigner les produits, §3.5) ; onglet Coach ; onboarding long et paywall avant la valeur ; Readiness 0–100 présenté comme une probabilité ; avertissements de démo dans chaque écran. **[EVIDENCE-BASED / INDUSTRY PATTERN]**

**6. Ce qu'il faut construire d'abord** (10 paris, §25) : formats natifs de la tech, Séance adaptative, Situation du jour, Atlas, Préparation v2, moteur de fausses idées, Rythme, Squads, fraîcheur des connaissances, surfaces iOS (widgets, Live Activities, App Intents). S'y ajoute, à la demande du fondateur, une exigence de crédibilité transversale : **les vrais symboles des éditeurs** — chaque produit cité affiche son icône officielle, non modifiée, avec son nom, partout où l'éditeur le permet (§3.5).

**7. Les risques majeurs** sont le **coût et la qualité du contenu** (les formats sur artefacts coûtent plus cher à écrire que des QCM), la **dispersion** d'un fondateur seul, l'**exactitude de l'IA** sur des sujets qui changent chaque mois, la **calibration** de la Préparation faute de résultats d'examen, et un **conflit de nom** avec *Certingo* (certingo.app), concurrent direct au nom presque identique. **[COMPETITOR OBSERVATION / DESIGN JUDGMENT]**

**8. Décision recommandée :** adopter la direction **« L'Atlas vivant »** (Bible §3.4), valider les 11 hypothèses critiques (§28), puis exécuter la transformation progressive décrite dans le Master Implementation Prompt, en commençant par une **Phase 0 d'audit en lecture seule**.

**9. La question centrale, décomposée.**
| Sous-question | Ce qui la détermine (preuve) | Réponse CertiGo |
|---|---|---|
| Est-elle **téléchargée** ? | Visibilité éditoriale (accessibilité, localisation, design), bouche-à-oreille, référencement | Pitch éditorial Inclusivity + Delight ; Situation partageable ; Accessibility Nutrition Labels ; 8 langues |
| Est-elle **comprise** ? | Une idée lisible en une phrase (lauréats ADA) | « Une situation tech par jour, en 2 minutes » |
| Produit-elle un **premier WOW** ? | Time-to-value, faire plutôt que lire | Situation de découverte en < 60 s, premier Déclic |
| **Fait-elle réellement apprendre** ? | Récupération espacée, feedback, formats de transfert | Learning Model §19, métrique WDL |
| Est-elle **agréable 5 minutes** ? | Rituel fini, micro-interactions, zéro friction | Express, Situation du jour, haptique |
| Reste-t-elle **utile 45 minutes** ? | Profondeur, exemples travaillés, capstones | Plongée, Diagnostiquer, Arbitrer, examen blanc |
| Donne-t-elle envie de **revenir demain** ? | Indices, rituel, valeur visible, sans peur | Aujourd'hui, Rythme, Situation du jour, widget |
| Reste-t-elle **utile après des mois** ? | Valeur cumulée, progression en profondeur | Atlas, routes successives, fraîcheur, renouvellement |
| Crée-t-elle un **attachement** ? | Compétence visible, identité, personnalisation | Passeport, Carte des fausses idées, Déclic |
| Donne-t-elle envie **d'inviter** ? | Coopération, objectifs communs | Squads |
| Donne-t-elle envie de **partager une réussite** ? | Cartes de capacité, sans spoiler | Partages de Situation et de jalons |
| Donne-t-elle envie de **payer** ? | Valeur de résultat, gratuité généreuse, confiance de facturation | Pro = profondeur et résultats, essai honnête |
| Obtient-elle de **bonnes notes** ? | Absence de frustration (paywall, rareté, culpabilité), qualité du contenu | Zéro dark pattern, contenu relu et daté |
| Semble-t-elle **premium** ? | Retenue, cohérence, artisanat | Cœur calme, Prism, typographie du code |
| Semble-t-elle **profondément iOS** ? | Composants système, surfaces hors app | Liquid Glass (navigation), widgets, Live Activities, Intents |
| Reste-t-elle **accessible** ? | Toutes tâches courantes avec chaque fonction d'accessibilité | Artefacts accessibles, AX5, audits par phase |
| **Se différencie**-t-elle ? | Unité d'apprentissage propre, douve de données | Artefacts & décisions ; Atlas ; Préparation calibrée |
| Construit-elle une **marque mémorable** ? | Signature sensorielle, vocabulaire, voix | Réfraction, Déclic, lexique, pair bienveillant |

**10. Réponse à la question ultime.**
*Si l'on créait CertiGo aujourd'hui*, on construirait **une pratique quotidienne du jugement technique sur iPhone** : une situation réelle par jour, des artefacts à lire et des décisions à prendre, une mémoire qui ancre ce qui est appris, une carte honnête de ce que l'on sait, une IA qui explique après l'effort à partir de sources vérifiées, une communauté qui coopère, et une exigence d'accessibilité et d'artisanat iOS de niveau Apple Design Award — sans monnaie, sans peur, sans mascotte, sans « dump ».
*Pour transformer le CertiGo actuel sans casser ce qui fonctionne* : préserver l'architecture de confiance (notation serveur, intégrité, hors ligne, contenu as code, suppression de compte, langues) ; transformer l'Atelier de décision en *Situation* ; exposer les moteurs existants (FSRS, maîtrise, fausses idées) dans Aujourd'hui et l'Atlas ; retirer de l'interface, derrière des flags, les mécaniques héritées ; bâtir Prism avant de toucher aux écrans ; avancer en 12 phases réversibles, chacune prouvée par ses tests.

---

## 2. Market analysis

### 2.1 Le leader : Duolingo (données déclarées par l'entreprise)
| Période | DAU | MAU | DAU/MAU | Abonnés payants | Chiffre d'affaires |
|---|---|---|---|---|---|
| T2 2025 | 47,7 M | 128,3 M | 37 % | 10,9 M | 252,3 M$ |
| T3 2025 | 50,5 M | 135,3 M | 37 % | 11,5 M | 271,7 M$ |
| Exercice 2025 | — | — | — | 12,2 M (T4) | 1 037,6 M$ (+39 %) |
| T1 2026 | 56,5 M | n.v. | — | 12,5 M | 292,0 M$ |
| T2 2026 | 58,7 M (+23 %) | 140,6 M | 42 % | 12,7 M | 298,5 M$ |
**[INDUSTRY PATTERN — lettres aux actionnaires, confiance haute ; DAU/MAU calculé]**

Leçons pour CertiGo :
| Constat | Étiquette | Implication |
|---|---|---|
| Duolingo reconnaît que **la friction ajoutée a ralenti la croissance** et investit > 50 M$ de revenus non perçus dans l'expérience gratuite ; la rétention des utilisateurs actuels atteint 84 % | INDUSTRY PATTERN, haute | Ne jamais bloquer la boucle quotidienne ; monétiser la profondeur |
| Le mémo « AI-first » (remplacer des contractuels par l'IA) a déclenché un boycott ; le système *Energy* (remplaçant les cœurs) divise ; une publicité affichée dans une Live Activity a été rejetée | INDUSTRY PATTERN / COMPETITOR OBSERVATION | Parler d'IA uniquement comme bénéfice d'apprentissage vérifié ; aucune ressource rare qui freine la pratique ; Live Activities réservées aux vraies séances |
| 20 500 unités de cours publiées au T1 2026 (contre 1 800 / trimestre en 2024), une vérification de maîtrise en fin d'unité | COMPETITOR OBSERVATION, haute | Le contenu généré est devenu banal : la différence se fait sur le **contrôle qualité** et la maîtrise |
| *Duolingo Score* relié à LinkedIn ; échecs et maths en croissance ; objectif 100 M DAU en 2028 ; aucun signe d'entrée sur la tech | COMPETITOR OBSERVATION | Relier la Préparation à un résultat externe ; surveiller une éventuelle entrée de Duolingo |

### 2.2 La demande
| Signal | Étiquette | Implication |
|---|---|---|
| WEF 2025 : IA & big data, réseaux & cybersécurité, littératie technologique = 3 compétences à plus forte croissance | INDUSTRY PATTERN, haute | Priorités : IA, sécurité, cloud |
| Pearson VUE 2025 (~24 000 professionnels IT) : 84 % prévoient une autre certification sous 12 mois ; 32 % augmentés après certification | INDUSTRY PATTERN, moyenne (éditeur d'examens) | Parcours multi-certifications ; valeur vie client d'abonnement |
| Skillsoft : 65 % déclarent des lacunes ; **91 % des responsables estiment que les employés surestiment leurs compétences** | INDUSTRY PATTERN, moyenne | Une Préparation **calibrée** répond à un vrai problème d'acheteur (B2B plus tard) |
| ISC2 2025 : les compétences priment sur les effectifs ; IA et sécurité cloud en tête | INDUSTRY PATTERN | Routes SC-900 → SC-200 / AZ-500 |
| Microsoft : Learn consultable pendant les examens associés / experts (pas Fundamentals) ; renouvellement annuel gratuit ; Fundamentals sans expiration ; Applied Skills en lab ; **AI-901 a remplacé AI-900** (retrait au 30/06/2026 selon une source tierce) ; ~99 $ / 165 $ par examen | INDUSTRY PATTERN, haute | Fraîcheur = douve ; « mode renouvellement » ; exercices de consultation documentaire ; abonnement < un échec à repasser |

### 2.3 Qui gagne la catégorie Education (instantanés du 22/10/2026)
- **US Top Grossing :** Duolingo, PictureThis, ClassDojo, Learna, Quizlet, Toca Boca World, Lingokids, Pimsleur, Simply Piano, Solid Starts. **FR Top Grossing :** Duolingo, Ornikar, Babbel, Loora, PictureThis, May, Simply Piano, Speak, Praktika, Baobab ; **AnkiMobile n° 1 des apps payantes en France**.
- **Aucune app d'apprentissage de la tech** dans les classements par revenus (top 25 US, top 30 France) ; seul titre tech repéré : « Learn Git Step by Step » (n° 29 des apps payantes en France). Les couloirs en croissance : tuteurs de conversation IA, aide aux devoirs IA, micro-learning quotidien (Imprint, Headway). Ordre de grandeur (modélisé, confiance faible) : un top 10 US Education ≈ 0,9 M$ / mois. **[COMPETITOR OBSERVATION, moyenne]**
- **Implication :** une place dans le Top 10 exige une proposition **large** (« progresser en tech, chaque jour ») — les certifications seules ne suffisent pas.
- Les choix éditoriaux d'Apple 2025 favorisent le calme, l'artisanat, l'accessibilité et les fonctions natives (Tiimo, Strava, CapWords, Speechify). **[OFFICIAL APPLE]**

### 2.4 Les assistants IA et les autres alternatives
| Alternative | Mouvement 2024–2026 | Limite pour la tech / les certifications |
|---|---|---|
| ChatGPT (Study Mode, juil. 2025 ; ~700 M d'utilisateurs hebdo) | Questions guidées | Optionnel, contournable ; pas de programme d'examen, de planification ni de préparation calibrée |
| Gemini Guided Learning (août 2025), Claude Learning mode (avr. 2025), NotebookLM (fiches et quiz, sept. 2025) | Pédagogie intégrée | Généralistes ; pas de boucle d'habitude ; qualité dépendante des sources |
| Microsoft Learn | Modules, XP, badges, évaluations d'entraînement ; Ask Learn et AI Skills Navigator (préversions) | **Aucune app iOS identifiée** ; très textuel ; entraînements jugés plus faciles que l'examen |
| Coursera + Udemy (fusion close le 11/05/2026, 290 M d'apprenants) ; *Ollie* (micro-learning, juin 2026, réservé à Coursera Plus) | Valide le micro-learning gamifié | Contenus longs ; pas calibrés sur la difficulté d'examen |
| YouTube, blogs, Reddit, documentation | Abondance | Passifs : pas de récupération, pas d'espacement |
**[INDUSTRY PATTERN / COMPETITOR OBSERVATION]**
Essais contrôlés : un accès libre à GPT-4 améliore la pratique mais **réduit de 17 %** la performance sans aide ; un tuteur structuré peut **doubler** les gains d'apprentissage. **[EVIDENCE-BASED, haute]** → Les apprenants utiliseront l'IA de toute façon : l'intégrer, sous contrat d'effort.

### 2.5 La niche certification IT sur iOS
| App | Positionnement | Modèle | Note |
|---|---|---|---|
| Pocket Prep | 25 000+ questions, examens blancs, « Question du jour » ; CompTIA, ISC2, Cisco, ISACA ; **pas de Microsoft trouvé** | 20,99 $/mois ; 124,99 $/an ; garantie de réussite | 4,8★ (5 K) |
| **Azure Mastery** | 32 examens Microsoft, 12,9 K questions, prédiction de préparation sur l'appareil, Apple Watch, compagnon « Aura » | Pro + à vie | Peu de notes — **rival le plus proche sur Microsoft** |
| **Certingo** (web) | 112 certifications, ~79 K questions, ES/EN, répétition espacée | Pass par certification dès 9,99 $ | **Nom quasi identique** |
| CertiG33k | FSRS / SM-2, simulateur ; « pas d'animaux mignons » | 9,99 $/mois | n.v. |
| Certo | « 100 % original, aucune fuite », hors ligne, sans compte | Achats uniques | Récent |
| CertForge, CertiHub | Banques de questions | Divers | Très peu de notes ; CertForge vend encore AI-900, retiré |
| ExamTopics (web) | « Dumps » reconstruits | ~80 $/mois | Trustpilot 1,8 |
**[COMPETITOR OBSERVATION, moyenne]**
Constats : la niche est **fragmentée et concurrence sur le nombre de questions** ; Microsoft **exclut** les candidats et **révoque** les certifications en cas de fraude (y compris assistance d'IA) ; les banques d'entraînement sont souvent jugées plus faciles que l'examen. **[INDUSTRY PATTERN, haute]** → Promesse explicite : *original, cité, à jour, jamais de dump* ; calibration publiée quand les données existeront.

### 2.6 Implications de marché
1. Le Top 10 Education se gagne avec une **proposition grand public** et une **qualité de référence**, pas avec un catalogue de questions.
2. Le coin d'entrée reste la **certification** (intention claire, résultat mesurable, disposition à payer), à condition de la présenter comme une **route sur un Atlas** plus large.
3. Les douves crédibles sont **la calibration, la fraîcheur, la pratique sur artefacts, la confiance** — pas « l'IA », devenue commune.

---

## 3. Apple quality analysis

### 3.1 Ce que récompensent les Apple Design Awards (formulations d'Apple)
| Catégorie | Ce qu'Apple dit récompenser |
|---|---|
| Delight and Fun | des expériences mémorables, engageantes et satisfaisantes, enrichies par les technologies Apple |
| Inclusivity | une excellente expérience pour tous, quels que soient les origines, capacités et langues |
| Innovation | un usage nouveau des technologies Apple qui distingue l'app dans son genre |
| Interaction | des interfaces intuitives et des contrôles sans effort, parfaitement adaptés à la plateforme |
| Social Impact | améliorer des vies de manière significative et éclairer des enjeux cruciaux |
| Visuals and Graphics | des images superbes, des interfaces finement dessinées, des animations de qualité |
**[EVIDENCE : source officielle Apple — confiance haute]**

### 3.2 Les apps d'apprentissage et de progression primées 2023–2026
| App | Distinction | Raison donnée par Apple | Leçon pour CertiGo |
|---|---|---|---|
| Duolingo | ADA 2023 Delight and Fun ; finaliste Social Impact | personnages délicieux, gamification amusante | La gamification gagne par le charme, pas par la pression |
| CapWords | ADA 2025 Delight and Fun | une idée simple et « révolutionnaire » ; un son réel par carte ; Apple note que le Delight « n'est pas toujours facile » dans une app éducative | Un moment magique unique ; une micro-animation masque la latence de l'IA |
| Speechify | ADA 2025 Inclusivity | conçue avec l'accessibilité en son cœur | Un mode audio |
| Guitar Wiz | ADA 2026 Inclusivity | développeur solo, SwiftUI ; VoiceOver, Dynamic Type, Increase Contrast, Differentiate Without Color | La profondeur d'accessibilité bat la taille d'équipe |
| Gentler Streak | ADA 2024 Social Impact | progression mesurée contre soi-même, pas contre les autres | Le progrès humain bat la pression du classement |
| The Outsiders | Finaliste Interaction 2026 | un « Training Readiness Score » en « belle visualisation de données » | La Préparation doit être belle **et** explicable |
| CellWalk | Finaliste Visuals 2025, vitrine Foundation Models | explications ancrées par appel d'outils, adaptées au niveau | Modèle du tuteur ancré |
| Tiimo | App iPhone de l'année 2025 | planificateur visuel, IA « bien implémentée » | IA utile et discrète |
| DailyArt, NYT Games, EF Hello | Cultural Impact 2024 | rituel quotidien, apprentissage systématique | Le rituel quotidien est reconnu |
**[OFFICIAL APPLE SOURCE — confiance haute ; détail : annexe R2]**

**Constat clé :** sur ~150 distinctions ADA 2023–2026, **aucune app de préparation aux certifications IT** n'apparaît. C'est un espace libre — et un avertissement : la distinction se gagnera par l'artisanat et l'inclusion, pas par la catégorie. **[INDUSTRY PATTERN — inférence, confiance moyenne]**

### 3.3 Ce qui distingue une app de niveau ADA
1. Une idée lisible immédiatement · 2. Un moment physique signature (son, haptique, animation porteurs de sens) · 3. Une accessibilité nommée réglage par réglage · 4. Un usage précoce et exemplaire des technologies récentes (Liquid Glass cité pour Moonlitt et Tide Guide en 2026 ; Foundation Models chez 4 finalistes 2026) · 5. Une présence hors de l'app (widgets, Live Activities, App Intents) · 6. Une motivation humaine · 7. La retenue · 8. Une IA ancrée et respectueuse de la vie privée · 9. Un onboarding traité comme un artisanat · 10. SwiftUI natif. **[OFFICIAL APPLE / INDUSTRY PATTERN — confiance moyenne sur la synthèse]**
Contre-évidences : les jurys favorisent les paris stratégiques d'Apple (visionOS) ; Nielsen Norman Group documente des pertes de lisibilité avec Liquid Glass ; une « IA tutrice » seule n'est plus différenciante. **[INDUSTRY PATTERN]**

### 3.4 « Si CertiGo était finaliste d'un Apple Design Award, pourquoi Apple le choisirait-il ? »
Réponse sérieuse (pas « parce que c'est beau ») :
| Dimension | Réponse CertiGo |
|---|---|
| **Concept produit remarquable** | La technologie apprise par ses **artefacts et ses décisions** : une situation réelle par jour, en 2 minutes, sur iPhone — là où la pratique technique vit aujourd'hui sur ordinateur |
| **Interaction distinctive** | « Toucher la ligne fautive » d'un log ou d'une config vivante ; composer une commande au pouce avec des jetons ; répondre à une carte de révision depuis un widget interactif |
| **Innovation d'apprentissage mémorable** | L'*Atlas* Profondeur × Mémoire ; les fausses idées nommées et réparées ; une *Préparation* qui montre son incertitude |
| **Technologies Apple pertinentes** | WidgetKit interactif, Live Activities (examen blanc), App Intents / Spotlight / Siri, Foundation Models ancrés sur l'appareil, SpeechAnalyzer (explain-it-back), Liquid Glass limité à la navigation, Accessibility Nutrition Labels |
| **Identité visuelle reconnaissable** | Lumière et réfraction : un accent indigo, 8 couleurs de région, le *Déclic* |
| **Attention aux détails** | Typographie du code, états vides écrits, haptique au sens documenté, chaque célébration en 3 variantes |
| **Qualité d'accessibilité requise** | Code, logs et schémas **entièrement** utilisables au VoiceOver et en AX5 ; aucun verdict porté par la couleur ; temps majoré en examen blanc ; 8 langues — catégorie visée n° 1 : **Inclusivity** |
**[DESIGN JUDGMENT fondé sur les sources Apple — EXPERIMENTAL BET : à mériter, pas à revendiquer]**

### 3.5 Références du fondateur, expressivité et personnages : ce que dit la recherche
- **L'expressivité aide quand elle sert la hiérarchie.** Google (Material 3 Expressive, 46 études, > 18 000 participants) : éléments clés repérés jusqu'à 4× plus vite ; une étude CHI 2026 (n = 48) : fixation 33 % plus rapide, tâches 20 % plus rapides ; mais « une minorité importante » préfère des versions plus calmes, et l'expressivité ne convient pas à tout (exemple d'une interface bancaire). Une app d'examen à enjeu est plus proche de la banque que du lecteur de musique. **[EVIDENCE-BASED — haute]**
- **L'esthétique aide la tolérance aux petits défauts, pas aux grands** (effet esthétique-utilisabilité, NN/g) ; la crédibilité perçue dépend fortement du « look », mais l'apparence trop « léchée » suscite aussi la méfiance (Stanford). **[EVIDENCE-BASED — moyenne]**
- **Personnages :** effet faible des agents pédagogiques (méta-analyses : petit effet, plus fort chez les enfants ; ~0,20 global) ; la mignonnerie peut faire paraître une marque incompétente ; Duolingo a construit Duo pendant une décennie ; Brilliant a pourtant adopté une mascotte (Koji, 2024) et ses apprenants ont demandé un personnage plutôt qu'un bouton IA générique. **[EVIDENCE-BASED moyenne / COMPETITOR OBSERVATION]** → pas de mascotte par défaut, test d'un glyphe abstrait (à la manière de Yorhart, Gentler Streak, ADA 2024).
- **Icônes Azure :** licenciées pour des schémas, formations et documentations ; interdiction de les modifier ou de les utiliser pour représenter son produit ; #0078D4 est la couleur primaire par défaut de Fluent UI. **[EVIDENCE-BASED — textes officiels ; pas un avis juridique]** → les mascottes **dérivées** sont retirées ; les icônes **officielles non modifiées** sont, elles, adoptées pour désigner les produits (décision du fondateur, v1.1).
- **Les vrais symboles des éditeurs (ajout v1.1, à la demande du fondateur).** Objectif : chaque produit cité apparaît avec son vrai symbole — celui du portail Azure, de la console AWS, des schémas officiels. La recherche complémentaire (annexes R8a, R8b ; 17 éditeurs, sources du 22/10/2026) montre que c'est **possible, mais pas partout ni pour tout** :
  - **Microsoft publie des kits officiels** (Azure V24 de juillet 2026, Power Platform, Dynamics 365, Fabric, Entra) qu'il autorise « in architectural diagrams, training materials, or documentation », non modifiés, sans représenter son propre produit. Mais ses règles de marque réservent par ailleurs les icônes de produits à une licence expresse, et sa page sur le contenu protégé exclut les icônes « in software applications » → **confirmation écrite à demander** avant le lancement public. **[EVIDENCE-BASED — textes officiels ; lecture : DESIGN JUDGMENT ; pas un avis juridique]**
  - **Icônes d'applications Microsoft 365** (Word, Excel, PowerPoint, Teams…), symbole Windows, logos GitHub : **licence ou autorisation écrite** requise ; les Octicons de GitHub (hors logos) sont sous licence MIT. **[EVIDENCE-BASED]**
  - **Autres éditeurs :** AWS limite ses icônes aux schémas d'architecture ; Google Cloud autorise ses icônes dans les schémas et les supports pédagogiques ; les icônes communautaires Kubernetes (Apache-2.0 / CC-BY-4.0), les icônes de topologie Cisco (« use them freely, but you may not alter them »), le logo Python (usage nominatif) et Tux (avec crédit) sont utilisables dans les leçons ; Docker et HashiCorp limitent l'usage éducatif aux **noms**, pas aux logos ; Red Hat, CompTIA et ISC2 interdisent leurs logos aux formations tierces (Red Hat : jusqu'aux identifiants d'examen). **[EVIDENCE-BASED]**
  - **Badges de certification : jamais.** Ils sont réservés aux titulaires ou aux partenaires agréés chez tous les éditeurs étudiés ; AWS interdit même toute image qui leur ressemble. **[EVIDENCE-BASED]**
  - **Agrégateurs** (Simple Icons, Devicon) : pas une source acceptable — redessins monochromes, aucun droit de marque, plusieurs marques retirées à la demande des éditeurs. **[EVIDENCE-BASED]**
  - **Apple** exige les droits sur tout ce qui figure dans l'icône, les captures et les aperçus (2.3.9), interdit la marque d'un autre dans l'icône ou le nom de l'app (4.1) et le contenu protégé sans autorisation (5.2.1) ; App Review peut demander les preuves. **[EVIDENCE-BASED — officiel Apple]**
  - **Pourquoi c'est utile pour apprendre :** les images sont mieux retenues que les mots (supériorité de l'image, double codage) et un indice présent à l'apprentissage aide le rappel quand il réapparaît (spécificité de l'encodage) — apprendre avec les symboles du portail et des schémas officiels aide à les reconnaître au travail. **[EVIDENCE-BASED pour les principes ; DESIGN JUDGMENT pour l'application]**
  - **Décision v1.1 :** trois niveaux (autorisé dans le contenu pédagogique · sur autorisation écrite · interdit), contextes appliqués automatiquement par le code, repli neutre, manifeste de licences, garde-fous CI et interrupteur de retrait par éditeur — les vrais symboles apparaissent d'eux-mêmes dès qu'une autorisation est enregistrée (Bible §15.11, Master Prompt §22A, étape 2B). **[DESIGN JUDGMENT]**
- **Les références du fondateur partagent une grammaire** — contenu héros, système signature unique, mouvement qui explique avant de célébrer, moments forts rares, voix aussi importante que le visuel — **mais divergent** sur l'endroit où vit la personnalité (personnage chez Duolingo, contenu chez Apple Music, DailyArt, Coursera). **[DESIGN JUDGMENT — haute]**

**Préférences visuelles du fondateur, transformées en hypothèses et validées :**
| Préférence | Besoins utilisateurs | Contraintes pédagogiques | iOS | Accessibilité | Performance | Verdict / règle |
|---|---|---|---|---|---|---|
| Interfaces épurées | ✅ réduit la charge | ✅ cohérence, signalisation | ✅ | ✅ | ✅ | **Valider** : une action principale par écran |
| Forte hiérarchie | ✅ repérage 4× plus rapide | ✅ signalisation | ✅ styles système | ✅ si Dynamic Type | ✅ | **Valider** |
| Symboles | ✅ | ⚠️ jamais seuls | ✅ SF Symbols | ✅ avec libellés | ✅ | **Valider** avec mots |
| Couleurs bien placées | ✅ | ✅ sens = région / statut | ✅ sémantiques | ⚠️ jamais seules, contrastes | ✅ | **Valider** : accent ~10 %, régions pour la connaissance |
| Micro-interactions | ✅ délice | ✅ feedback | ✅ haptique système | ✅ si optionnelles | ✅ | **Valider** |
| Animations | ⚠️ minorité « calme » | ⚠️ distraction pendant l'effort | ✅ | ⚠️ Reduce Motion | ⚠️ coût | **Conditionner** : rares, expliquent, 3 variantes |
| Espaces généreux | ✅ | ✅ | ✅ | ⚠️ AX5 réduit l'espace | ✅ | **Valider** avec mise en page adaptative |
| Grands visuels très expressifs | ⚠️ | ❌ pendant l'étude (détails séduisants) | ✅ | ⚠️ | ⚠️ | **Restreindre** aux jalons, accueil, partages |
| Simplicité | ✅ | ✅ | ✅ | ✅ | ✅ | **Valider** |
| Interfaces « vivantes » | ✅ | ⚠️ | ✅ | ⚠️ | ⚠️ | **Conditionner** : vivant aux transitions, calme à l'effort |
| Contenu mis en valeur | ✅ | ✅ | ✅ | ✅ | ✅ | **Valider** : artefacts héros |
| Sentiment premium | ✅ confiance | ✅ | ✅ | ✅ si retenue | ⚠️ verre / 3D coûteux | **Valider** par la retenue, pas par l'effet |
**[EVIDENCE-BASED + DESIGN JUDGMENT — annexe R7]**

---

## 4. Education-app benchmark

### 4.1 Matrice produit (synthèse ; profils complets en annexe R1)
| Produit | Proposition / cible | Boucle quotidienne & format | Progression & motivation | Social / compétition | IA | Moat |
|---|---|---|---|---|---|---|
| **Duolingo** | Langues (+ maths, musique, échecs), grand public | Chemin + 3 quêtes ; leçons 3–5 min ; *Energy* | XP, série, gemmes, ligues, Score | Ligues, amis, quêtes entre amis | Video Call, contenu généré | Marque, pile d'habitudes, A/B permanent |
| **Brilliant** | Maths, CS, données — jeunes pros | 1 concept / 3 problèmes par jour ; série avec charges | XP, ligues de 30 | Ligues | **Koji** (mai 2026) : ne donne jamais la réponse | Moteur de leçons interactives |
| **Speak** | Parler une langue | Plan perso, conversation | Série (sauvegarde 48 h), ligues opt-out | Ligues opt-out | Tuteur avec mémoire | Volume de parole |
| **Khan Academy / Khanmigo** | Pratique de maîtrise gratuite | Série hebdo ; missions | Points, badges | Faible | Khanmigo socratique (peu utilisé) | Contenu gratuit de confiance |
| **Quizlet** | Fiches à partir de tout | « Study Bites », Learn, tests | Faible | Faible | Q-Chat retiré (2025) | Contenu des utilisateurs |
| **Anki** | Répétition espacée (FSRS) | Révisions dues | Aucune (choix) | Decks partagés | — | Algorithme, communauté |
| **Elevate** | Entraînement cérébral adulte | Séance du jour 3–5 jeux | Score EPQ, ligues opt-out | Ligues | — | Jeux soignés, un score |
| **CapWords** | Langues par l'image | Capturer → sticker → réviser | Légère | — | Conversation (v2) | **Moment natif délicieux** (ADA 2025) |
| **Imprint / Headway** | Micro-learning visuel / résumés | Chapitre ≤ 2 min / résumé 15 min | Série, quiz | — | — | Artisanat visuel / habitude audio |
| **Mimo** | Code débutant | Leçons + éditeur ; Live Activity d'objectif | XP, classement sans opt-out, série | Classement | Tuteur | Boucle de code la plus native iPhone |
| **Sololearn** | Code gratuit + Q&R | Leçons ; 5 cœurs | Ligues planètes | Communauté | Kodie (payant) | Catalogue, communauté |
| **Codecademy (Go)** | École de code web | Compagnon fiches | Série | — | Assistant | Parcours carrière |
| **DataCamp** | Données & IA | 250 XP / jour | Série + gels | — | Tuteur | Catalogue entreprise |
| **Boot.dev** | Backend / DevOps façon RPG | Exercices web | XP, ligues, boss | Guildes | Boots socratique | Couche de jeu la plus profonde |
| **TryHackMe (Pulse)** | Cybersécurité en labs | Labs web ; Pulse = fiches / quiz | 7 ligues, gels, Capability Score | Ligues | Echo | Labs sans installation |
| **KodeKloud** | DevOps / Kubernetes | Labs desktop ; app iOS 2025 | — | — | Live Assist | Labs sur vrais clusters |
| **Coursera (+ Ollie)** | Diplômes et certificats de marque | Cours longs ; Ollie micro | Points, séries, badges (Ollie) | Classements (Ollie) | Coach | Marques de certificats |
| **Microsoft Learn** | Formation officielle | Modules, quiz | XP, badges | — | Ask Learn (préversion) | Émetteur des certifications |
| **AWS Skill Builder** | Formation officielle AWS | Cours ; **Cloud Quest** (jeu 3D, IA) | Badges, tournois | Tournois | Conversations clients IA | Labs officiels |
| **Pocket Prep** | Banques de questions | Question du jour, Quick 10, points faibles | Série | Comparaison | Tuteur (web) | Ampleur, simplicité |
| **NYT Games** (référence) | Rituel quotidien | Un puzzle par jour | Séries, statistiques | Classement d'amis | — | Rituel rare et partageable |
| **Strava** (référence) | Réseau social sportif | Activités | Segments, *Local Legend* | Kudos, clubs | — | Graphe social |

### 4.2 Matrice expérience et modèle économique
| Produit | Onboarding / time-to-value | Identité (typo, couleur, motion, haptique) | iOS & hors ligne | Prix | Note US | Plaintes fréquentes |
|---|---|---|---|---|---|---|
| Duolingo | Leçon très tôt ; placement | Personnages Rive, couleurs vives, sons, haptique composée | Widgets, Live Activities | Super 9,99–12,99 $/mois | 4,7 (5,5 M) | *Energy* punitive, « AI slop », publicité en Live Activity |
| Brilliant | Quiz d'intérêt | Visuels interactifs soignés | Widget ; pas de hors ligne | Jusqu'à ~192 $/an avec tuteur | 4,7 (33 K) | Prix, cours retirés |
| Speak | Quiz → plan, essai 7 j | Sobre | — | 17,99 $/mois | 4,8 (63 K) | Prix, reconnaissance vocale |
| Khan Academy | Immédiat | Institutionnel | Vidéos hors ligne | Gratuit (Khanmigo 4 $/mois) | 4,6 | App < web |
| Quizlet | Immédiat | Utilitaire | Fiches hors ligne | 35,99–44,99 $/an | 4,8 (1,1 M) | Modes passés derrière le paywall |
| Anki | Lent | Minimal | Complet | 24,99 $ une fois | 4,0 | Interface confuse |
| Elevate | Test initial | Très soigné | Widgets | 26,99–44,99 $/an | 4,8 | Prélèvements inattendus |
| CapWords | Immédiat (caméra) | Sons réels, Liquid Glass | Camera Control | — | 4,7 | Phrases trop difficiles |
| Imprint / Headway | Paywall tôt | Illustration / audio | Widgets, Watch, hors ligne (Headway) | 99,99 $/an ; 12,99–89,99 $ | 4,8 / 4,6 | **Résiliation difficile** (Trustpilot 1,7 / 3,9) |
| Mimo | Rapide | Coloré | Live Activities ; pas de hors ligne | ~40–100 $/an | 4,8 | Minuteurs, superficiel |
| Sololearn | Rapide | Ludique | — | 70–120 $/an | 4,8 | Cœurs = payer pour apprendre |
| TryHackMe Pulse | — | Sombre « hacker » | — | 16,99 €/mois | 3,9 (14) | Progression perdue, contenu déplacé vers MAX |
| Pocket Prep | Choix d'examen | Utilitaire | — | 124,99 $/an | 4,8 (5 K) | Plus facile que l'examen |
| NYT Games | Immédiat | Typographie éditoriale | Widgets | 50 $/an | 4,8 | Extension du paywall |
**[COMPETITOR OBSERVATION — instantanés App Store US du 22/10/2026 ; détails et sources : annexe R1]**

### 4.3 Ce que les meilleures apps font toutes bien
1. Une **unité quotidienne de 1–5 minutes** avec des séries **indulgentes** (charges, gels, sauvegarde 48 h, *Streak Revival*).
2. Des **ligues hebdomadaires d'~30 personnes** — désormais avec **opt-out** chez les nouveaux entrants.
3. **Un nombre de compétence** partageable (Duolingo Score, EPQ, Capability Score) — mais jamais calibré publiquement.
4. **Des tuteurs IA qui retiennent la réponse** (Koji, Khanmigo, Boots, Echo).
5. **Un personnage ou un délice artisanal** (Duo, Koji ; CapWords) — dans les entretiens de Brilliant, des apprenants ont demandé un personnage plutôt qu'un bouton IA générique.
6. **Les surfaces iOS comme crochets d'habitude** (widgets, Live Activities, Watch) — et leur usage publicitaire se retourne contre l'app.
7. **Maîtrise et révision espacée intégrées.**
**[COMPETITOR OBSERVATION, haute]**

### 4.4 Ce que le marché fait mal pour la tech → voir les listes obligatoires du §14.

---

## 5. Learning-science findings

### 5.1 Principe par principe
| Principe | Qualité de preuve | Conditions d'application | Pertinence tech | Traduction UX | Risque de mauvaise application |
|---|---|---|---|---|---|
| **Active recall / Retrieval practice** | **Élevée** — test vs relecture g = 0,50 (Rowland 2014, 159 effets) ; en classe g = 0,50 (Yang 2021, 48 478 élèves) | Plus fort avec récupération effortful + feedback ; succès final nécessaire | Termes, ports, options CLI, sémantique des politiques, « pourquoi » | Question avant les options ; cloze ; jetons ; chaque unité finit par une récupération | QCM seul = reconnaissance ; mémoriser la banque |
| **Spaced repetition** | **Élevée** — espacé vs massé g = 0,74 (Latimier 2021) ; écart optimal ∝ délai jusqu'au test (Cepeda 2008) | L'écart doit dépendre de la date d'examen | Limites, terminologie, commandes | FSRS ajusté à la date d'examen ; plafond quotidien ; reprise dans de nouveaux scénarios | Pile de révisions → abandon ; espacer la même carte entraîne la carte |
| **Interleaving** | **Moyenne** — g = 0,42 (Brunmair & Richter 2019) ; défavorable pour du vocabulaire | Catégories proches, items variés, après une première exposition en bloc | Forte : « quel service / protocole / contrôle ? » | Paires de contraste (NSG / pare-feu) ; bloquer le nouveau, entrelacer les révisions | Mélanger des sujets sans rapport ; ressenti « plus dur » |
| **Testing effect** (examens blancs) | **Élevée** — g = 0,61 (Adesope 2017) ; transfert d = 0,40 (Pan & Rickard 2018) | Congruence de format, récupération élaborée | Items scénarisés = cible du transfert | Examens blancs comme événements d'apprentissage avec débrief ; surfaces variées | Inflation par répétition des mêmes items |
| **Feedback** | **Élevée, hétérogène** — d = 0,48 (Wisniewski 2020) ; > ⅓ des interventions dégradent (Kluger & DeNisi 1996) | Centré tâche / processus, pas l'ego | Pourquoi chaque distracteur échoue | Réponse → pourquoi → pourquoi ton choix tentait → règle en 1 ligne | Louanges, classement présenté comme feedback, murs de texte |
| **Mastery learning** | **Moyenne (ancienne)** — effets positifs (Kulik 1990), plus forts pour les plus faibles | Vérifications **différées** fiables | Chaînes de prérequis (sous-réseaux → VNet) | « Maîtrisé » après récupérations réussies sur plusieurs séances ; portes souples | « Maîtrise » dans une même séance ; portes dures → abandon |
| **Cognitive load** | **Moyenne-élevée** — principes multimédias (Noetel 2022, 1 189 études) : contiguïté, signalisation | Interactivité des éléments × connaissances préalables | Schémas, JSON/YAML, flux de paquets | Une idée par écran ; étiquettes sur les schémas ; révélation progressive du code | Sur-simplifier |
| **Chunking / segmenting** | **Moyenne** — gains petits à moyens (Rey 2019) | Segments signifiants, au rythme de l'apprenant | Découper par fonction (routage, identité) | Segments 30–90 s + carte de concepts qui les relie | Sur-fragmentation → faits isolés |
| **Worked examples** | **Élevée (novices)** — g = 0,48 (Barbieri 2023) ; aide utile aux novices d = 0,505, nuisible aux experts d = −0,428 (Tetzlaff 2025) | Tâches bien structurées ; estomper | Séquences CLI, évaluation IAM, CIDR | Exemple → complétion → autonome ; test de saut | Garder les experts dans les exemples |
| **Generation effect** | **Moyenne** — d ≈ 0,40 (Bertsch 2007) | Génération atteignable et vérifiée | Prédire une sortie, compléter une config | Prédire puis révéler | Générations fausses non vérifiées |
| **Elaboration / self-explanation** | **Moyenne** — g = 0,55 (Bisra 2018) | Connaissances préalables | « Pourquoi ce NACL bloque-t-il le retour ? » | Choix d'explication + texte libre occasionnel (IA formative) | Charge de saisie ; explications fausses non corrigées |
| **Dual coding / multimedia** | **Moyenne** — modalité, cohérence, segmentation, signalisation ; « styles d'apprentissage » non fondés | Le visuel doit structurer | Topologies, flux de requêtes | Schéma + texte court ; surlignage au toucher | Images décoratives, schémas illisibles |
| **Metacognition** | **Moyenne-élevée** — jugements différés plus justes (g = 0,93) ; 72 % croient le massé meilleur alors que l'espacé gagne pour 90 % | Les jugements immédiats suivent la fluidité | La familiarité avec une banque crée la surconfiance | Confiance sur une partie des items ; « tu le sais toujours ? » le lendemain ; calibration personnelle | Demander la confiance partout |
| **Desirable difficulties** | **Moyenne** (cadre) ; composantes élevées | Surmontables avec feedback | Scénarios variés, tests différés | Expliquer « difficile = efficace » ; montrer ensuite les gains | Difficulté gratuite → abandon |
**[EVIDENCE-BASED — détail et DOI : annexe R3]**

### 5.2 Phénomènes complémentaires décisifs
- **Successive relearning** (élevée) : critère initial (≈ 3 rappels corrects) **puis** 3 réapprentissages espacés sur des jours différents ; gains ≥ 10 % sur un examen à enjeu (Janes 2020). → définition de *Maîtrisé*.
- **Pretesting** (moyenne) : poser la question avant d'enseigner aide si la réponse est étudiée ensuite. → *question d'ouverture*.
- **Hypercorrection** (moyenne-élevée) : les erreurs commises avec certitude se corrigent mieux… mais réapparaissent plus. → re-test à ~2 jours et ~1 semaine.
- **Suggestion négative des QCM** (élevée) : lire des leurres crée de « fausses connaissances » (Roediger & Marsh 2005) ; le feedback la réduit. → expliquer chaque leurre, ≤ 3 leurres plausibles, question avant options.
- **Inversion d'expertise** (élevée) et **productive failure** (g = 0,36, pour le conceptuel). → guidage adaptatif.
- **Deliberate practice** : 4 % de la variance en éducation, < 1 % dans les métiers (Macnamara 2014). → les drills sont nécessaires mais pas suffisants : passage au lab.
- **FSRS** : meilleur que SM-2 pour 99,6 % des utilisateurs selon le benchmark des mainteneurs (non évalué par les pairs) ; AUC ≈ 0,70 → prédire un rappel individuel reste difficile. → FSRS par défaut, honnêteté sur l'incertitude. **[INDUSTRY PATTERN / EVIDENCE-BASED — confiance moyenne]**

### 5.3 Micro-learning : ce que dit (et ne dit pas) la preuve
- Le mobile aide en moyenne (0,52, Sung 2016) mais la preuve **spécifique au micro-learning est faible** (pas de définition commune de la durée). La valeur vient de la **récupération et de l'espacement** contenus dans les unités courtes, pas de la brièveté elle-même. **[EVIDENCE-BASED — confiance faible à moyenne]**
- Aucune étude ne fixe une durée optimale ; les chunks se définissent **par le sens**, pas en secondes.
- **5 minutes = idéal pour réapprendre, faible pour un premier apprentissage complexe.** → *Express* sans nouveau concept complexe ; nouveautés en *Séance* et *Plongée*.
- Interruptions : la reprise coûte ; un **indice d'objectif** (« Tu choisissais entre NAT Gateway et point de terminaison ») l'atténue.
- Lecture sur écran : plus fragile pour du texte informatif long, chronométré et à défilement (g = −0,21) ; pas de différence significative sur appareil tenu en main (−0,12). → *Plongée* au rythme de l'apprenant, peu de défilement.
- Sommeil : bénéfice de consolidation (g = 0,44 ; 0,28 après correction de biais).
**Conclusion :** une **seule architecture d'atomes** (30–120 s, un concept, reprenables, étiquetés objectif / format / difficulté) composée sous un budget de temps sert les trois usages : **Express** (réapprendre), **Séance** (apprendre un bloc cohérent), **Plongée** (intégrer, transférer, mesurer). **[EVIDENCE-BASED + DESIGN JUDGMENT]**

### 5.4 Le Readiness Score actuel n'est pas encore crédible
Formule actuelle : 100 × couverture^0,5 × maîtrise × récence^0,3 (récence = e^(−j/30)).
- `récence^0,3` = e^(−j/100) : ×0,74 après 30 jours, **en double** du modèle d'oubli FSRS.
- `√couverture` **récompense la couverture partielle** (25 % → ×0,50 ; 50 % → ×0,71).
- La maîtrise mesurée sur des items pratiqués est **gonflée** par la répétition et la reconnaissance (re-test : +0,26 ET).
- Un 0–100 se lit comme un pourcentage ou une probabilité **sans être ni l'un ni l'autre** (exemple : couverture 0,5, maîtrise 0,8, étudié il y a 7 jours → 52,7, sans signification définie ; 720/1000 ≠ 72 %).
- Les produits sérieux (NBME, NCLEX) affichent **une fourchette, une fenêtre de validité et un critère d'arrêt à 95 %**. Aucune étude publique de validité prédictive n'existe pour les tests d'entraînement IT.
→ **Préparation v2** (Bible §7.7) : IRT / Elo, habileté par objectif avec incertitude sur **items jamais vus**, rétention projetée à la date d'examen, a priori pour les objectifs sans preuve, simulation de formulaires, lien avec la réussite appris sur des résultats déclarés ; « Preuves insuffisantes » tant que le minimum n'est pas atteint. **[EVIDENCE-BASED + INDUSTRY PATTERN — confiance moyenne]**

---

## 6. Habit and retention findings
- **Une habitude prend du temps et tolère les ratés** : médiane 66 jours (18–254) ; un jour manqué n'affecte pas matériellement la formation (Lally 2010) ; des mois pour le sport (Buyalskaya 2023, > 12 M observations). **[EVIDENCE-BASED — élevée]**
- **La flexibilité bat la rigidité** : incitations à fenêtre fixe < flexibles ; objectifs avec « réserve d'urgence » = meilleure persévérance après un raté. **[EVIDENCE-BASED — élevée]**
- **Récompenser le retour** : la meilleure intervention de la mégaétude Milkman 2021 (61 293 personnes) récompensait le retour après une séance manquée ; seules 8 % des interventions gardaient un effet après la fin du programme ; les experts n'ont pas su prédire les gagnants. **[EVIDENCE-BASED — élevée]** → *Rythme* hebdomadaire, jours de repos, retour célébré, tests A/B.
- **Intentions d'implémentation** : d = 0,65 (94 tests), mais effets divisés par ~10 à grande échelle (247 MOOC). → les combiner à des indices passifs (widget). **[EVIDENCE-BASED — élevée]**
- **Rappels vs dépendance** : compter sur les rappels soutient la répétition mais freine l'automatisation, contrairement aux indices liés à un événement existant ; effet d'une notification : +3,9 % d'engagement sur 24 h ; les désinscriptions sont quasi définitives → « protéger le canal ». **[EVIDENCE-BASED moyenne / INDUSTRY PATTERN]**
- **Briser une série nuit** : mettre en avant une série cassée réduit l'engagement ultérieur, moins si la réparation est possible (Silverman & Barasch 2023). **[EVIDENCE-BASED — élevée]**
- **Duolingo** : découpler la série de l'objectif XP (+3,3 % de rétention J14), gels, « amulette » du week-end, animations de jalons — chacun quelques points ; la *Streak Revival* de juin 2026 a fait revenir 15,4 M de séries. **[INDUSTRY PATTERN — données propriétaires]**
**Différencier rappel et dépendance :** l'utilisateur doit revenir parce que « je veux continuer à apprendre » → indices choisis, contenu attendu (Situation du jour), valeur accumulée (Atlas), et **jamais** la peur de perdre.

---

## 7. Gamification findings

### 7.1 Ce que dit la preuve
- Effet **réel mais modeste** : g ≈ 0,25–0,5 ; seul l'effet cognitif résiste aux sous-ensembles rigoureux (Sailer & Homner 2020 : cognitif 0,49, motivationnel 0,36, comportemental 0,25) ; motivation intrinsèque +0,26, compétence perçue +0,28, **appartenance +1,78** (Li 2024). **[EVIDENCE-BASED — élevée]**
- **L'effet s'estompe** quand la couche de jeu s'arrête (0,42 → 0,15 au suivi). **[EVIDENCE-BASED]**
- **Récompenses attendues et contingentes** → baisse de la motivation intrinsèque (d −0,28 à −0,40) ; **feedback informatif** → hausse. **[EVIDENCE-BASED — élevée]**
- **Contre-exemple adulte** : classement + badges → motivation, satisfaction et notes **plus basses** (Hanus & Fox 2015, n = 80). **[EVIDENCE-BASED — moyenne]**
- **Ligues Duolingo** : +17 % de temps d'apprentissage mais **×3 d'utilisateurs à ≥ 1 h/jour** — exactement le « champion de 4 heures par jour » que le fondateur refuse. **[INDUSTRY PATTERN]**
- **Réglementation convergente** : DSA art. 25 (interfaces manipulatrices), lignes directrices UE sur les mineurs qui **nomment les séries**, Digital Fairness Act attendu mi-novembre 2026, règles Apple (monnaies achetées non expirables, probabilités affichées) ; le *confirmshaming* (culpabiliser pour faire agir) est un dark pattern répertorié ; le rapport de la FTC voit dans l'expérimentation manipulatrice à grande échelle « un signal de dark patterns ». **[INDUSTRY PATTERN — élevée]**

### 7.2 Mécanique par mécanique
| Mécanique | Bénéfice apprentissage | Bénéfice motivation | Bénéfice rétention | Risque | Risque de dark pattern | Fit CertiGo |
|---|---|---|---|---|---|---|
| Série (streak) | Faible (présence) | Moyen | Élevé | Anxiété, abandon après rupture | Moyen-élevé si cadrée par la perte | **Transformer** en Rythme hebdo |
| XP | Faible-moyen si pondéré qualité | Moyen | Moyen | Farming, course aux minutes | Moyen | **Cacher** (points de maîtrise internes) |
| Objectif quotidien | Moyen | Moyen | Moyen | Devient une barrière | Faible | **Garder minimal** |
| Ligues hebdo XP | Faible | Haut pour le haut / négatif pour le bas | Élevé | Récompense les heures | Moyen | **Transformer** (opt-in, appariées) |
| Classements globaux | Faible | ± | Faible | Abandon | Moyen | **Supprimer** |
| Quêtes | Moyen si liées à la compétence | Moyen | Moyen | Corvées | Faible | **Missions** (≤ 3) |
| Succès | Faible-moyen | Moyen | Moyen | Inflation | Faible | **Maîtrise uniquement** |
| Monnaie virtuelle | — | Faible | Moyen | Masque le prix | Élevé si achetée | **Supprimer** |
| Boutique / réparation payante | — | Faible | Moyen court terme | Monétise l'anxiété | Élevé | **Supprimer** |
| Récompenses variables | — | Moyen | Moyen | Machine à sous | Élevé si payant | **Petites, gratuites, rares** |
| Célébrations | Faible-moyen (feedback) | Moyen | Moyen | Habituation | Faible | **Garder, informatives** |
| Personnages | Faible | Moyen | Moyen | Infantilisant, distrait | Moyen (culpabilité) | **Aucun** (test d'un glyphe) |
| Barres de progression | Moyen | Moyen | Moyen | Départs lents nuisibles | Faible | **Garder, rapides au début** |
| Jalons | Faible | Moyen | Moyen | Nombres arbitraires | Faible | **Jalons de maîtrise** |
| Comparaison sociale | Faible | ± | ± | Découragement | Moyen | **Relative, opt-in** |
| Aversion à la perte | — | Élevé court terme | Moyen | Anxiété | Élevé | **Supprimer** |
| Déclencheurs de retour | — | Moyen | Faible + | Fatigue, dépendance | Moyen-élevé | **Peu, choisis** |
| Saisons / battle pass | Faible | Moyen (nouveau départ) | Moyen | FOMO | Élevé si payant | **Saisons rares, pas de pass** |
**[EVIDENCE-BASED / INDUSTRY PATTERN — annexe R4]**

### 7.3 Autres modèles plus adaptés à la tech
Cotes Glicko/Elo (Lichess, éducation : « simple, robuste, efficace ») ; points dégressifs pour le contenu répété (TryHackMe : « Learning beats grinding ») ; rang compté sur la 1re réussite (Codewars) ; suppression du classement global d'Advent of Code en 2025 (beaucoup concluaient « être de moins bons programmeurs ») ; GitHub a retiré ses compteurs de série dès 2016 ; *Local Legend* Strava (régularité, sans vitesse) ; Apple Fitness (≤ 600 pts/jour relatifs à ses propres objectifs, pause jusqu'à 90 jours) ; NYT Games (« notre étoile du nord n'est pas les minutes »). **[COMPETITOR OBSERVATION — élevée]**

### 7.4 « Professional Duolingo » : le point d'équilibre
Le bon nom de l'équilibre n'est pas « Duolingo pro » mais **« jeu au service de la compétence »** (*gameful design* : restructurer les défis de l'activité elle-même plutôt qu'ajouter des points ; *meaningful gamification* : réflexion, exposition, choix, information, jeu, engagement). Formule recommandée pour CertiGo : **« Sérieux dans le fond, joyeux dans la forme »** — fini par conception, des chiffres qui ont du sens pour un employeur, de l'humour dans les micro-textes jamais aux dépens de l'apprenant, le délice réservé aux jalons, un respect visible du temps de l'apprenant (NYT Games, Strava, Apple Fitness, Monzo, GitHub). **[EVIDENCE-BASED moyenne + COMPETITOR OBSERVATION]**

---

## 8. Social learning findings
- **Coopération > compétition** : apprentissage coopératif et tutorat entre pairs positifs (méta-analyses) ; l'interaction sociale module l'effet comportemental de la gamification ; « fiction + compétition *avec* collaboration » est la combinaison la plus efficace. **[EVIDENCE-BASED — moyenne à élevée]**
- **Co-présence passive sans gain** : le « study-with-me » n'a pas fait mieux qu'étudier seul (n = 60). **[EVIDENCE-BASED — faible]**
- **Comparaison** : l'exposition à l'excellence inatteignable fait abandonner (Rogers & Feller, MOOC, N = 5 740) ; les moins actifs entraînent leurs amis plus actifs, pas l'inverse (1,1 M de coureurs) ; la compétition doit être opt-in (73 % des hommes vs 35 % des femmes de même niveau choisissent un tournoi). **[EVIDENCE-BASED — élevée]**
- **Friends / Friend Streak Duolingo** : +22 % de probabilité de leçon quotidienne (corrélationnel). **[INDUSTRY PATTERN — faible]**

| Fonction proposée | Apprentissage | Motivation | Rétention | Appartenance | Verdict |
|---|---|---|---|---|---|
| Friends | ○ | ● | ● | ● | Garder (pseudonymes, pas d'import de contacts) |
| **Study Squads** | ● (coopération) | ● | ● | ●● | **Construire (cœur)** |
| Study Together / Study Rooms | ○ | ○ | ○ | ● | Différer (pas de gain prouvé, modération) |
| Challenges (asynchrones) | ● (récupération) | ● | ● | ● | Construire, appariés, sans chrono |
| Knowledge Battles (temps réel) | ○ (vitesse > compréhension) | ●● | ● | ● | Différer, mode casual |
| Private Leagues | ○ | ● | ● | ● | Opt-in (amis / Squad) |
| Public Leagues | ○ | ± | ● | ○ | Opt-in, appariées par cote seulement |
| Team Goals / Team Streaks | ○ | ● | ● | ●● | Construire, hebdomadaires |
| Peer Encouragement | ○ | ● | ● | ● | Garder (1 tap) |
| Activity feed | ○ | ± | ○ | ● | Jalons seulement, désactivé par défaut |
| Share Cards | ○ | ● | ○ | ● | Capacité, sans spoiler |
| Community Challenges | ○ | ● | ● | ● | Dans les temps forts saisonniers |
(● = apport ; ●● = apport fort ; ○ = faible ou non démontré ; ± = ambivalent) **[EVIDENCE-BASED + DESIGN JUDGMENT]**

### 8.1 Compétition intelligente
Classements fondés sur : **maîtrise** (points plafonnés), **progression** (gain relatif à sa propre base), **justesse et calibration** (défis), **régularité** (semaines de Rythme, « Pilier du territoire » façon Local Legend), **performance en défi**, **croissance hebdomadaire**, **spécialisation** (par territoire) ; appariement par cote Glicko-2 et par route ; pas de relégation les 4 premières semaines ; ±3 voisins visibles ; jamais de classement absolu global. Les débutants gagnent sur la progression, les experts sur la profondeur et la spécialisation. **[EVIDENCE-BASED + COMPETITOR OBSERVATION]**

### 8.2 Exigences de confidentialité et de sécurité
Contenu généré par les utilisateurs : filtrage, signalement, blocage, contact publié (App Review 1.2) ; lignes directrices UE sur les mineurs : comptes privés par défaut, blocage et sourdine, aucun ajout à un groupe sans consentement, désactivation des mécaniques de type « série » pour les mineurs ; ne jamais pousser vers moins de confidentialité ; ne jamais exposer de localisation (affaire de la carte de chaleur Strava) ; pour CertiGo : pseudonymes, visibilité des classements désactivée par défaut, aucun échec affiché à autrui, vues employeur agrégées sauf opt-in, âge minimum ou mode mineurs. **[INDUSTRY PATTERN — haute]**

---

## 9. AI learning findings
- **Le design bat l'accès** : tuteur structuré avec solutions expertes → gains **0,73–1,3 ET** en moins de temps (Kestin 2025, RCT, Harvard) ; accès libre à GPT-4 → +48 % en pratique mais **−17 % à l'examen sans aide**, risque largement neutralisé par un tuteur à garde-fous (Bastani 2025, PNAS, ~1 000 élèves). **[EVIDENCE-BASED — élevée]**
- **Une boîte de chat à côté est peu utilisée** : Khanmigo +0,06–0,08 ET/an, comparable à Khan Academy sans IA ; la contrainte est l'engagement ; l'IA aide surtout **juste après une erreur** (NBER 2026, documents de travail). Quizlet a retiré son Q-Chat socratique. **[EVIDENCE-BASED moyenne / COMPETITOR OBSERVATION]**
- **Le cœur adaptatif ne demande pas de LLM** : systèmes tuteurs intelligents d = 0,76 vs tutorat humain 0,79 (VanLehn 2011). **[EVIDENCE-BASED — élevée]**
- **La justesse technique est le risque n° 1** : 52 % des réponses de ChatGPT à des questions de programmation contenaient des erreurs, ignorées 39 % du temps par les utilisateurs ; GPT-4 : 19 % de Terraform AWS correct ; outils RAG juridiques : 17–33 % d'hallucinations ; et les services changent (Azure AD → Microsoft Entra ID). **[EVIDENCE-BASED — élevée, modèles 2023–2024]**
- **Paresse métacognitive** : performance immédiate ↑, transfert et connaissance ✗ (Fan 2025) ; confiance dans l'IA ↔ moins de pensée critique (Lee, CHI 2025). **[EVIDENCE-BASED — moyenne]**
- **Ce qui devient possible (et pas cher)** : une explication ancrée coûte < 0,001 $ sur un petit modèle (estimation) ; inférence sur l'appareil gratuite ; Private Cloud Compute iOS 27 (32 K de contexte) sans coût d'API sous 2 M de téléchargements ; brouillons d'items en secondes au lieu d'~1 h d'expert (mais discrimination plus faible : 0,24 vs 0,36 → relecture et calibration obligatoires). **[INDUSTRY PATTERN / EVIDENCE-BASED moyenne]**
- **Lignes rouges** : pas de réponse avant tentative ; aucun item d'examen réel (CompTIA : ≥ 12 mois d'exclusion et retrait de certification pour les « dumps ») ; pas d'inférence d'émotion (interdite dans l'éducation dans l'UE depuis février 2025) ; ni flatterie ni culpabilité ; pas de notation IA opaque qui bloque ; consentement nommant le fournisseur (App Review 5.1.2(i), novembre 2025) ; AI Act : obligation d'information depuis le 2 août 2026, usages éducatifs « à haut risque » (Annexe III) au 2 décembre 2027 → garder l'IA **formative**. **[INDUSTRY PATTERN — élevée]**

**Ce que l'IA peut faire dans CertiGo qui était impossible ou trop cher :** une explication personnalisée **par fausse idée** pour chaque erreur ; des variantes isomorphes d'items vérifiés ; des simulations d'incident où un moteur détient la vérité et l'IA ne fait que narrer ; l'évaluation formative d'une explication orale (explain-it-back) sur l'appareil ; des tableaux de contraste entre concepts à partir d'extraits ; un plan d'étude qui se réécrit chaque semaine ; une veille de fraîcheur (diff de la documentation officielle). **Ce que l'IA ne doit pas faire :** être un onglet de chat, donner la réponse avant l'effort, affirmer hors des sources, toucher au contenu d'examen, jouer un personnage qui « s'ennuie de vous », noter ce qui compte. **[EVIDENCE-BASED + DESIGN JUDGMENT — annexe R5]**

---

## 10. Tech-learning-specific findings
- **Les compétences forment une hiérarchie** : lire / tracer précède et prédit écrire (Lister 2004 ; Lopez 2008) ; enseigner les compétences de façon incrémentale améliore la réussite (Xie 2019). **[EVIDENCE-BASED — élevée]**
- **Les formats adaptés au téléphone sont aussi les plus efficaces** : problèmes de Parsons = même apprentissage en moins de temps (Ericson 2017) ; Parsons estompés = transfert comparable à l'écriture (Weinman 2021) ; étiquettes de sous-objectifs = moins d'échecs (Margulieux 2020) ; exemples erronés = meilleure rétention différée (d = 0,33) bien que moins appréciés ; stratégie de dépannage structurée = **2× plus de pannes résolues** (Schaafstal 2000). **[EVIDENCE-BASED — moyenne à élevée]**
- **Plafond de transfert du téléphone** : Parsons standard sans transfert (pilote) ; tuteur mobile plus utile aux avancés qu'aux novices ; tutoriels qui n'enseignent pas le transfert. → estomper et **sortir vers un lab**. **[EVIDENCE-BASED — moyenne]**
- **Saisie sur iPhone** : le clavier masque la moitié de l'écran ; Parsons « bien adaptés au tactile » → **tap > saisie > glisser**, jetons, ≤ 1 ligne de saisie, artefacts ≤ 25 lignes. **[EVIDENCE-BASED — moyenne]**
- **Les examens deviennent pratiques** : examens Microsoft associés avec labs possibles et consultation limitée de Microsoft Learn (pas en Fundamentals) ; Applied Skills 100 % lab ; CompTIA PBQ simulés ; AWS ajoute ordonnancement, appariement, études de cas ; Microsoft : 120–140 h d'étude typiques pour un examen de rôle ; renouvellements annuels gratuits. **[INDUSTRY PATTERN — élevée]**
- **Concurrence scindée** : apps mobiles = syntaxe ou fiches « compagnon » (Mimo, Enki, Codecademy Go, TryHackMe Pulse) ; pratique réelle = ordinateur (SadServers, KodeKloud, OverTheWire, Google Skills, AWS Cloud Quest) ; bacs à sable Microsoft Learn apparemment retirés ; Grasshopper (Google) fermé en 2023. **Aucun produit mobile natif de raisonnement diagnostique sur des artefacts réalistes n'a été trouvé.** **[COMPETITOR OBSERVATION — moyenne]**

### 10.1 « What is the Duolingo-like experience for tech that doesn't yet exist? »
**Réponse :** une pratique quotidienne où **le vocabulaire est fait d'artefacts et de décisions** — lire un log, prédire une commande, toucher la mauvaise ligne d'une config, diagnostiquer un incident, arbitrer une architecture — sur une **échelle** qui monte de *Reconnaître* à *Expliquer*, espacée par une mémoire qui sait ce que vous savez, et qui **sort vers un vrai lab** au sommet. Duolingo vous apprend à lire et dire des mots ; CertiGo vous apprend à **lire des systèmes et à agir dessus**.
Trois concepts candidats (la recherche R6) et leur intégration :
| Concept | Rôle dans CertiGo |
|---|---|
| *Artifact Tree* (fluence sur artefacts par technologie) | → l'**échelle de profondeur** de chaque concept de l'Atlas |
| *Incident Mode* (3 minutes d'astreinte : alerte → preuves → hypothèse → action → vérification) | → format **Diagnostiquer** et une partie des *Situations du jour* |
| *Architect's Desk* (décider sous contraintes et voir les conséquences) | → format **Arbitrer**, capstone hebdomadaire en *Plongée* (évolution de l'Atelier de décision actuel) |
**[EVIDENCE-BASED + COMPETITOR OBSERVATION → EXPERIMENTAL BET à valider (Bible §17, V3)]**

---

## 11. iOS opportunity analysis
| Capacité | Valeur pour CertiGo | Effort | Reco |
|---|---|---|---|
| Liquid Glass (navigation) + icône Icon Composer | Natif, légibilité contrôlée | S–M | MUST |
| Widgets (interactifs, Écran verrouillé, StandBy) | Situation du jour, carte de révision répondable, Rythme | M | MUST |
| App Intents, Spotlight, Siri (iOS 27 : schémas d'entités) | « Fais-moi réviser le réseau », concepts dans Spotlight | M–L | MUST (raccourcis, entités) / SHOULD (schémas Siri) |
| Foundation Models sur l'appareil | Reformulation ancrée, rubriques d'explain-it-back, hors ligne | M–L | MUST avec repli |
| Private Cloud Compute (iOS 27) | Plans et débriefs longs sans coût d'API (petits développeurs) | M | SHOULD |
| Live Activities / Dynamic Island | Examen blanc, Plongée, jour J | M | SHOULD |
| Contrôles du Centre de contrôle / bouton Action | « Express 5 min » | S | SHOULD |
| SpeechAnalyzer | Explain-it-back à la voix | M | SHOULD |
| Translation | Glossaire bilingue | S | SHOULD |
| StoreKit 2 (+ Multiseat iOS 27) | Pro, offres, sièges d'équipe plus tard | M | MUST / SHOULD |
| Sign in with Apple, passkeys | Inscription en un geste | S–M | MUST |
| Background Assets / tâche continue | Packs hors ligne | M | SHOULD |
| Declared Age Range | Restreindre social et IA cloud pour les mineurs | S–M | SHOULD |
| SharePlay, Visual Intelligence, Screen Time | Niches | M–L | MAY |
| Game Center / app Jeux, Journaling Suggestions, Image Playground (schémas) | Inadaptés | — | AVOID |
**Cible de déploiement :** iOS 26 sur 79 % des iPhone au 7 juin 2026 ; la plupart des capacités exigent iOS 26+ → **iOS 26 minimum à la prochaine version majeure**. iPhone Duo (pliable, sept. 2026) impose une mise en page adaptative. **[OFFICIAL APPLE / INDUSTRY PATTERN — annexe R2]**

### 11.1 Accessibilité = qualité
L'accessibilité est le **premier levier de distinction** atteignable (catégorie Inclusivity), une exigence App Store croissante (**Accessibility Nutrition Labels**, déclarables seulement si *toutes* les tâches courantes sont réalisables ; obligatoires « avec le temps » ; pris en compte dans la recherche App Store) et un marché (développeurs aveugles et malvoyants mal servis par les apps de code). Exigences : Dynamic Type jusqu'à AX5 (texte ≥ 200 %), VoiceOver (artefacts ligne à ligne, schémas décrits), Voice Control (libellés visibles = libellés d'accessibilité), Differentiate Without Color, Increase Contrast (variantes ≥ 7:1), Reduce Motion et Reduce Transparency, cibles ≥ 44 pt, sous-titres et transcriptions, alternatives à tout geste, temps majoré en examen blanc. **[OFFICIAL APPLE — élevée]**

---
## 12. CertiGo current-state audit

### 12.1 Deux réalités à ne pas confondre
| Réalité | Ce qui existe | Statut |
|---|---|---|
| **App iOS native** (octobre 2026) | SwiftUI, Swift 6, iOS 17 min. ; `CertigoNative` + package `CertigoKit` (`CertigoDomain`, `CertigoData`, `CertigoAppleFileIO`) + MSAL ; 4 onglets (Apprendre, Coach, Communauté, Profil) ; mode Démo ; 8 langues | **Client cible**, encore au stade de pilote |
| **App Flutter** (juillet 2026) | 15–18 fonctionnalités, Prism « néon doux », gamification complète, onboarding de 23 écrans | **Héritage** : mémoire fonctionnelle, à ne pas porter |
| **Backend .NET + contenu** | ~29 endpoints, 8 conteneurs Cosmos, moteurs FSRS / maîtrise / readiness / recommandation / fausses idées / intégrité ; 146 leçons YAML ; > 400 tests | **Actif à préserver** |
*(À re-vérifier en Phase 0 : le dépôt natif complet n'a pas été lu, seulement ses journaux de build et ses écrans.)*

### 12.2 Forces à préserver
| Force | Preuve | Pourquoi c'est précieux |
|---|---|---|
| Architecture de confiance (notation serveur, clé jamais exposée, anti-triche, idempotence) | README, ETAT_DU_PROJET, audit juillet | Condition d'une Préparation crédible et d'une compétition juste |
| Contenu as code, schémas, validateur, **sources datées**, refus des dumps | `content/`, pilote « Sources vérifiées le 2026-10-14 » | Base de la fraîcheur et de la marque de confiance |
| L'**Atelier de décision** (situation → choix → « Qui gère quoi ? » → à retenir) | Enregistrements du 19/10 et du 22/10 | Graine du format *Situation*, rare sur le marché |
| Moteurs : FSRS, maîtrise, mémoire des fausses idées, recommandation | `Certigo.Domain` (Tutor, Progress, Readiness, Recommendation) | Le « modèle de l'apprenant » est la future douve |
| Hors ligne, protection des fichiers, Keychain, suppression de compte | Fichiers `CertigoData` | Prérequis App Store et confiance |
| Internationalisation (8 langues d'interface) | Enregistrement du 22/10 | Atout Inclusivity et marchés |
| Lancement sain | Rendu de la première frame ~64 ms ; état actif ~0,95 s après le début de la trace (simulateur) | Base de performance |

### 12.3 Faiblesses observées
**Produit et expérience (app native)**
- La première minute est consacrée à expliquer **ce que l'app n'est pas** (« Objectifs, réponses et explications sont fictifs », « Aucun verdict, score ou gain », « Ce n'est pas une connexion de production »), avec une section **Développement / connecteur API de test** visible.
- Le feedback demande **trois temps** (« Envoyer la réponse » → « En attente » → « Simuler l'explication ») : le moment d'apprentissage le plus important est retardé. **[EVIDENCE-BASED R§5 : le feedback est l'ingrédient actif]**
- L'organisation suit le **catalogue** (codes, familles, catégories, « 7 / 39 ») plutôt que l'apprenant ; aucun plan du jour ; aucun rituel.
- L'onglet **Coach** n'a pas de rôle clair et pousse vers le modèle « IA = chat ». **[EVIDENCE-BASED R§9]**
- Densité de texte élevée, hiérarchie plate (listes groupées système + un seul accent indigo saturé), aucun mouvement, aucune gamification visible.

**Apprentissage et contenu**
- **145 items sur 146 sont des QCM**, 1 question par leçon, 2 blocs de code au total : le schéma (8 formats) est riche, le contenu ne l'utilise pas.
- Ordre des leçons « accroche → concept → exemple → code → vérification → récap » : **la lecture précède la récupération**, qui n'arrive qu'à la fin. **[EVIDENCE-BASED R§5 : retrieval first, pretesting]**
- 5 parcours de 12 leçons + 84 parcours « catalogue » à 1 leçon : **largeur sans profondeur**.
- **Readiness 0–100** heuristique, non calibré, lisible à tort comme un pourcentage de réussite (§5.4).

**Gamification héritée (Flutter)**
- Copie des mécaniques de Duolingo les moins défendables : gemmes, boutique, **gel / réparation de série payants**, 10 ligues XP (Bronze → Obsidienne), succès de volume (« Trésorier : gagner N gemmes »), saisons mensuelles.
- Notifications **culpabilisantes** : « Ne casse pas ta série ! 🔥 … Sentinel compte sur toi », « Ta flamme va s'éteindre », « Pip s'ennuie un peu » — à côté de formulations bienveillantes (« Chaque expert a fait des pauses ») qui montrent la bonne voie. **[EVIDENCE-BASED / INDUSTRY PATTERN R§7 : DSA art. 25, confirmshaming]**
- Onboarding de **23 écrans** (année de naissance, attribution, « promesse », réactions de mascotte…) avec **paywall avant toute leçon**.

**Marque**
- 7 mascottes = **icônes Azure « cutifiées »** (Azure, Functions, Cosmos DB, Defender, Bicep, AI Foundry, Blob) : hors des conditions d'usage Microsoft et ancrage mono-éditeur ; art jamais livré (dossier vide).
- Couleur primaire héritée **#0078D4** = couleur par défaut de Fluent UI (Microsoft).
- Icône actuelle : « C » hexagonal en verre indigo + étincelle — cohérente, mais l'étincelle est le symbole générique de « l'IA ».

**Technique**
- **Build du 22/10/2026 en échec** : `@Environment(\.accessibilityContrast)` (clé inexistante) dans `NativeCertificationCrest`.
- `CertigoNativeApp.swift` ≥ 3 683 lignes : monolithe ; **aucun design system natif** (Prism n'existe qu'en Flutter) → risque maximal de dérive visuelle en vibe coding.
- Aucune extension iOS observée (widgets, Live Activities, App Intents) ; cible iOS 17.

### 12.4 Observations écran par écran (app native)
| Écran | Observé | Problème | Direction |
|---|---|---|---|
| Accueil « Certigo » | Carte héros « Une question. Une idée plus claire. », « Découvrir la démo », avertissements, connecteur de test | La promesse est bonne, la première action n'apprend rien | Garder la promesse ; Situation de découverte en < 60 s |
| Apprendre › Mon apprentissage | Bandeau « Démo · données fictives », état vide « Votre prochain objectif » | Méta-texte, pas de plan | Écran *Aujourd'hui* |
| Apprendre › Explorer | Catalogue de 39 certifications, filtres par codes | Orienté catalogue | *Atlas* + Objectifs |
| Atelier de décision | Situation → 3 options → envoi → attente → explication → « Qui gère quoi ? » | Feedback retardé, aucun artefact technique | Format *Situation* (feedback ≤ 1 s, artefact, confiance) |
| Lecture guidée | Pilote « Assistants IA responsables », 18 min, sources datées, étapes numérotées | Lecture longue sans récupération intercalée | *Plongée* (lecture segmentée + items) |
| Profil / Réglages | Aperçu, Progression & historique, langue, accessibilité « suit les réglages système », suppression de compte | Base saine | *Profil* + *Passeport* |
| Coach, Communauté | Onglets présents (contenu non observé) | Rôles flous | IA contextuelle ; *Ensemble* |

### 12.5 Synthèse chiffrée
Score moyen **3,3 / 10** sur les 26 dimensions du framework (annexe A) ; points forts : **Performance (7)**, **Confiance (7)**, **Hors ligne (6)** ; 11 dimensions à 2 ou moins (expérience de première session, boucle quotidienne, social, collaboration, marque, mouvement, haptique, communauté, partage, bouche-à-oreille, rétention).

---

## 13. User-value gaps

| Job to be done | Ce que l'utilisateur attend | Ce que CertiGo offre aujourd'hui | Écart |
|---|---|---|---|
| Quotidien (« j'ai 5 minutes ») | Savoir quoi faire, en 1 tap, et que ce soit utile | Démo, catalogue | **Critique** : pas de plan, pas de séance, pas de rituel |
| Objectif (« je vise une certification ») | Une route, un plan, une préparation honnête | Choix d'objectif confirmé serveur, plan de préparation, readiness non calibré | **Fort** : honnêteté et visibilité de la préparation |
| Clarté (« je n'ai pas compris ») | Une explication qui part de mon erreur | Explication générique, différée | **Fort** |
| Mémoire (« je ne veux pas oublier ») | Des rappels au bon moment, visibles | FSRS côté serveur, « Révision recommandée » | **Moyen** : le moteur existe, l'expérience non |
| Profondeur (« je veux savoir faire ») | Pratiquer sur de vrais artefacts | QCM uniquement | **Critique** |
| Preuve (« je progresse ? ») | Voir ses progrès, les montrer | Historique de démo | **Fort** |
| Fraîcheur (« la tech change ») | Être prévenu quand mon savoir devient faux | Sources datées (pilote) | **Moyen** : la graine existe |
| Ensemble (« pas seul ») | Compagnie sans pression | Onglet Communauté, amis (backend) | **Fort** |
| Confiance (« pas de piège ») | Pas de dump, pas de piège à l'abonnement, pas de culpabilité | Forte côté données ; notifications culpabilisantes et paywall précoce dans l'héritage | **Moyen** |

---

## 14. Missing features — et les cinq listes obligatoires

# FEATURES CERTIGO HAS BUT SHOULD NOT PRIORITIZE
| Fonction existante | Décision | Raison | Étiquette |
|---|---|---|---|
| Gemmes et boutique | Retirer de l'UI | Monnaie sans valeur d'apprentissage ; risque de dark pattern ; règles Apple / UE | EVIDENCE-BASED + INDUSTRY PATTERN |
| Gel / réparation de série payants | Supprimer | Monétise l'anxiété ; remplacé par un rattrapage gratuit | EVIDENCE-BASED |
| 10 ligues XP hebdomadaires | Remplacer par des ligues de progression opt-in | Récompensent les heures ; découragent le bas du classement | EVIDENCE-BASED |
| XP et niveaux affichés | Cacher (points de maîtrise internes) | Mesurent l'activité, pas l'apprentissage | EVIDENCE-BASED |
| Succès de volume | Remplacer par des jalons de maîtrise | Inflation, sens nul | EVIDENCE-BASED |
| Saisons mensuelles | 4 temps forts par an, coopératifs | Fatigue, FOMO | EVIDENCE-BASED |
| Mascottes Azure | Supprimer | Conditions d'usage Microsoft ; infantilisation | EVIDENCE-BASED |
| Onglet Coach (chat) | Supprimer comme onglet | IA en barre latérale peu utilisée ; risque de béquille | EVIDENCE-BASED |
| Onboarding 23 écrans + paywall | Remplacer | Time-to-value | INDUSTRY PATTERN |
| 84 parcours « catalogue » à 1 leçon | Masquer tant qu'ils ne sont pas réels | Largeur sans profondeur = promesse non tenue | DESIGN JUDGMENT |
| Connecteur de test, mode Démo dans l'UI de production | Retirer des builds de production | Confusion, perte de confiance | DESIGN JUDGMENT |
| Carte de partage quotidienne | Transformer (capacité, sans obligation) | Partager l'activité ne fait pas venir | INDUSTRY PATTERN |

# FEATURES CERTIGO HAS AND SHOULD DOUBLE DOWN ON
| Fonction | Comment l'amplifier |
|---|---|
| Atelier de décision | Devient *Situation* : artefacts, confiance, feedback immédiat, Situation du jour |
| Moteur FSRS + maîtrise | Devient visible : Mémoire, Atlas, *Ancré / Maîtrisé* (successive relearning), plafond quotidien, date d'examen |
| Mémoire des fausses idées | *Carte de mes fausses idées*, distracteurs diagnostiques, « Expliquer mon erreur » |
| Tuteur ancré + repli déterministe | IA contextuelle, citée, à contrat d'effort, sur l'appareil quand possible |
| Notation autoritative + intégrité | Préparation crédible ; compétition juste |
| Contenu as code + sources datées | Fraîcheur, Mises à jour de connaissance, marque de confiance |
| Lecture guidée | *Plongée* segmentée avec récupération intercalée |
| Plan de préparation / révision recommandée | Composition de la Séance ; Mon plan |
| Packs hors ligne | Séances en cache, Situation du jour téléchargée |
| 8 langues | Inclusivity ; glossaire bilingue |
| SwiftUI natif | Liquid Glass, widgets, Live Activities, App Intents |

# FEATURES CERTIGO IS MISSING
1. **Formats natifs de la tech** : `ArtifactView`, Trouver l'erreur, Prédire, Ordonner (Parsons), Composer la commande, Lire le log, Diagnostiquer, Compléter le schéma, Arbitrer, Expliquer, Classer, Estimer.
2. **Aujourd'hui** (plan du jour) et **Séance adaptative** 5 / 15 / 45.
3. **Situation du jour** + distribution communautaire + partage sans spoiler.
4. **Atlas** (Profondeur × Mémoire) + **fiches Concept** + **Mémoire** (prévision).
5. **Confiance déclarée** et calibration personnelle.
6. **Préparation v2**, examens blancs avec débrief, déclaration des résultats d'examen.
7. **Rythme hebdomadaire** avec repos et retour célébré.
8. **Squads**, encouragements, défis justes, ligues opt-in appariées.
9. **Passeport** et cartes de capacité.
10. **Mises à jour de connaissance**, mode renouvellement Microsoft, exercices de consultation documentaire (examens associés).
11. **Surfaces iOS** : widgets (dont carte de révision interactive), Live Activities, App Intents / Spotlight / Siri, Centre de contrôle.
12. **Premier lancement** en < 60 s, paywall équitable (StoreKit 2) **après** la valeur.
13. **Prism natif**, flags de fonctionnalité, analytics d'apprentissage, passage au lab.
14. **Les vrais symboles des éditeurs** *(ajout v1.1, décision du fondateur)* : bibliothèque d'icônes officielles (kits Azure, Power Platform, Dynamics 365, Fabric et Entra, puis ceux d'AWS, de Google Cloud, de Kubernetes… ; icônes Word / Excel / Teams et logos GitHub seulement sur autorisation écrite) non modifiées, tracées (source, version, conditions, empreinte) et affichées avec le nom officiel partout où l'éditeur le permet ; mentions de marque et non-affiliation.

# FEATURES THE MARKET DOES POORLY
1. **Pratique concrète sur mobile** : labs sur ordinateur, apps mobiles « compagnons ». **[COMPETITOR OBSERVATION, haute]**
2. **Calibration** : entraînements jugés plus faciles que l'examen ; aucune donnée publique préparation → réussite.
3. **Fraîcheur** : examens qui changent (AI-900 → AI-901), apps qui vendent des examens retirés.
4. **Rareté punitive** : cœurs, clés, énergie qui freinent la pratique au moment de l'erreur.
5. **Interaction superficielle** : textes à trous, QCM de rappel, peu de « décider comme un admin ».
6. **Confiance de facturation** : résiliation difficile (Imprint, Headway, Codecademy, Coursera, Elevate).
7. **Collaboration** : compétition partout, coopération nulle part.
8. **Accessibilité du contenu technique** : code et schémas rarement utilisables au VoiceOver. **[DESIGN JUDGMENT — non mesuré systématiquement]**
9. **Exactitude de l'IA** sur des sujets techniques qui changent.
10. **Transfert vers le travail réel** : « tutorial hell ».

# FEATURES CERTIGO COULD UNIQUELY OWN
1. **La Situation sur artefact** comme unité d'apprentissage mobile (avec Diagnostiquer et Arbitrer). **[EXPERIMENTAL BET, fondé sur EVIDENCE-BASED]**
2. **L'Atlas Profondeur × Mémoire** à travers les certifications : un concept partagé par AZ-900, AI-901 et SC-900 n'est appris et révisé qu'une fois.
3. **La Préparation calibrée et publiée** (courbes prévu vs observé dès que les données le permettent).
4. **La carte des fausses idées** construite sur des erreurs réellement observées (les LLM devinent mal les fausses idées des apprenants).
5. **Les Mises à jour de connaissance** (fraîcheur comme fonctionnalité).
6. **Les artefacts techniques entièrement accessibles** (VoiceOver ligne à ligne, schémas décrits, AX5).
7. **Les spécificités Microsoft** : consultation documentaire chronométrée (examens associés), mode renouvellement annuel, préparation aux Applied Skills via Arbitrer / Diagnostiquer + passage au lab.
8. **La marque de confiance** : original, cité, daté, sans dump, sans piège de facturation, sans culpabilité.

---

## 15. Features to simplify / remove

| Élément | Action | Détail | Étiquette |
|---|---|---|---|
| Navigation 4 onglets actuelle | Simplifier | Aujourd'hui · Atlas · Ensemble · Profil (+ Recherche) ; Coach dissous dans le contexte | DESIGN JUDGMENT + EVIDENCE-BASED |
| Méta-texte de démo / provenance | Regrouper | Une page « À propos des données & méthode » + un badge discret ; mode Invité avec contenu public réel | DESIGN JUDGMENT |
| Feedback en 3 temps | Fusionner | Vérifier → feedback complet ≤ 1 s | EVIDENCE-BASED |
| Readiness 0–100 | Remplacer | Bandes + incertitude + preuves ; probabilité après calibration | EVIDENCE-BASED |
| Gamification Momentum | Réduire à l'essentiel | Rythme, jalons de maîtrise, ≤ 3 Missions, célébrations 0–3 | EVIDENCE-BASED |
| Ligue / classements | Rendre opt-in, apparier, plafonner | Ligues de progression, cote Glicko-2 | EVIDENCE-BASED |
| Onboarding | Raccourcir | 60 s de valeur, puis objectif, rythme, compte | INDUSTRY PATTERN |
| Catalogue des 89 certifications | Recentrer | Afficher d'abord les routes **réellement complètes** ; le reste en « bientôt » | DESIGN JUDGMENT |
| Effets de verre (héritage Prism Flutter) | Restreindre | Liquid Glass sur la navigation uniquement | OFFICIAL APPLE |
| Personnages | Retirer | Symboles, mouvement, son, voix (test d'un glyphe abstrait) | EVIDENCE-BASED |
| Notifications | Réduire et réécrire | ≤ 1 / jour, choisies, bienveillantes, arrêt après 3 ignorées | EVIDENCE-BASED |

---

## 16. Strategic differentiation

| Acteur | Fort sur | Faible sur | Ce que CertiGo fait autrement |
|---|---|---|---|
| Duolingo, Mimo, Sololearn | Habitude, plaisir | Profondeur, transfert, sujets tech pro | Situations sur artefacts, profondeur, ton adulte |
| Pocket Prep, banques de questions, dumps | Volume, entraînement à l'examen | Apprentissage, explication, honnêteté, légalité | Explications par option, fausses idées, Préparation calibrée, contenu original |
| Microsoft Learn, Coursera / Udemy | Contenu officiel, certificats | Passivité, mobile, mémoire | Pratique quotidienne mobile, révision espacée, couche « pratique & habitude » au-dessus de Learn |
| Labs (KodeKloud, TryHackMe, SadServers, Cloud Quest) | Pratique réelle | Ordinateur, temps, coût | 2 minutes sur iPhone, puis passage au lab |
| Assistants IA (ChatGPT Study Mode, Gemini, Claude, NotebookLM) | Explication à la demande | Mémoire de l'apprenant, structure, exactitude vérifiée, contrat d'effort | Modèle de l'apprenant, contenu vérifié, effort d'abord |
| Anki | Algorithme | Création de cartes, enseignement, plaisir | Contenu prêt, enseignement, rituel |

**Positionnement :** *la pratique quotidienne du jugement technique* — assez courte pour un trajet, assez profonde pour compter, assez honnête pour s'y fier, assez native pour être un plaisir. **[DESIGN JUDGMENT fondé sur R1, R6]**

---

## 17. Potential moat

### 17.1 « Pourquoi CertiGo alors que j'ai déjà… ? » (l'interface plus belle n'est pas une réponse)
| Alternative | Réponse fondée |
|---|---|
| **YouTube, blogs, Reddit, documentation** | Regarder et lire sont des techniques à faible utilité ; la récupération et l'espacement à forte utilité (Dunlosky 2013). CertiGo **fait récupérer, au bon moment**, sur des situations réalistes. **[EVIDENCE-BASED]** |
| **ChatGPT et assistants** | L'accès libre améliore la pratique mais **réduit la performance sans aide** ; les modes étude sont optionnels. CertiGo **sait ce que vous savez** (mémoire, profondeur, fausses idées), impose l'effort avant l'aide, cite des sources vérifiées et datées. **[EVIDENCE-BASED]** |
| **Microsoft Learn** | Canonique et gratuit, mais sans app iOS identifiée, textuel, sans planification. CertiGo est la **couche de pratique et d'habitude** au-dessus de Learn, qu'il cite. **[COMPETITOR OBSERVATION]** |
| **Coursera / Udemy** | Cours longs et passifs ; Ollie réservé aux abonnés Plus. CertiGo = pratique quotidienne et transfert. |
| **Duolingo** | Pas de piste tech ; mécaniques de jeu conçues pour des mots. CertiGo = la même facilité, appliquée aux systèmes. |
| **Anki** | Même classe d'algorithme (FSRS), mais il faut écrire ses cartes et rien n'est enseigné. CertiGo apporte le contenu, l'enseignement, la profondeur. |
| **Dumps (ExamTopics)** | Exclusion et révocation des certifications par Microsoft / CompTIA. CertiGo est l'alternative légale et efficace. **[INDUSTRY PATTERN]** |
| **Non établi** | Aucune preuve publique qu'une app dédiée augmente le taux de réussite face à ces alternatives : **CertiGo doit produire cette preuve** (cohortes, A/B, calibration). |

### 17.2 Les couches de la douve (par ordre de construction)
1. **Le modèle de l'apprenant** — mémoire, profondeur, fausses idées, calibration : plus on l'utilise, plus il est précis, et il ne se transporte pas vers un chatbot sans mémoire. *(Court terme.)*
2. **La bibliothèque de Situations et la taxonomie des fausses idées** — formats sur artefacts, distracteurs issus d'erreurs réelles, items calibrés (IRT / Elo). *(Moyen terme ; coûteux à copier.)*
3. **La donnée de calibration** — résultats d'examen déclarés reliés aux preuves : seule base d'une Préparation honnête. *(Moyen terme ; effet de réseau de données.)*
4. **Le rituel et le graphe social** — Situation du jour, Squads. *(Moyen terme.)*
5. **La confiance et la fraîcheur** — pipeline de mises à jour, sources datées, zéro dump. *(Continu.)*
6. **L'artisanat natif et l'accessibilité** — difficile à égaler pour des concurrents multiplateformes. *(Continu.)*
**Honnêteté :** au démarrage, la seule douve réelle est **la vitesse et la qualité d'exécution** ; les douves de données exigent de l'échelle. **[DESIGN JUDGMENT]**

---
## 18. Proposed product model
**Direction retenue : « L'Atlas vivant »** — la colonne vertébrale d'un *Intelligent Learning OS* (modèle d'apprentissage, honnêteté, calme), le rituel et la joie d'un *Professional Duolingo* purgé de ses dark patterns, et le monde d'un *Living Tech World* rendu utile (l'Atlas, la fraîcheur, des temps forts rares). Les trois directions et leur comparaison détaillée (philosophie, boucle, home, apprentissage, progression, social, IA, identité, forces, faiblesses, risques, audience, différenciation, fit iOS, potentiel) figurent dans la Bible §3.
| Élément | Proposition |
|---|---|
| Vision | *Become better at technology, every day.* |
| Positionnement | La pratique quotidienne du jugement technique ; « lire des systèmes et agir dessus » |
| Cibles | S1 candidats certification (cœur), S2 praticiens à jour, S3 curieux ; S4 équipes plus tard |
| Boucles | Apprentissage · Quotidienne · Maîtrise · Objectif / carrière (cœur) ; Sociale · Découverte · Fraîcheur · Acquisition (secondaires) |
| Modèle de contenu | Concept · Carte · Item · Situation · Route · Fausse idée · Source (original, relu par un humain, daté) |
| Rétention | Intrinsèque d'abord (compétence, autonomie, appartenance), habitude saine, retour sans honte, valeur cumulée |
| Monétisation | Gratuit généreux (Situation du jour, Express, révisions, Atlas, Squads) ; **Pro** = profondeur et résultats (routes complètes, Plongée, examens blancs, Préparation détaillée, IA approfondie, hors ligne complet) ; jamais de pub dans l'apprentissage, ni de paywall avant la valeur, ni de rareté punitive |
**[DESIGN JUDGMENT fondé sur §2–§11]**

## 19. Proposed learning model
Quatorze règles (Bible §7.1) dont les plus structurantes : **récupérer avant de relire** · **espacer** (FSRS ajusté à la date d'examen, plafond quotidien) · **entrelacer** les concepts confondables · **feedback qui explique le pourquoi** de chaque option · **exemples travaillés puis estompés** (inversion d'expertise) · **artefact d'abord, surface variée** · **échelle de profondeur** Reconnaître → Rappeler → Appliquer → Analyser → Expliquer (→ Pratiquer en lab) · **fausses idées nommées** · **confiance déclarée** (hypercorrection) · **générer et expliquer** · **une idée par carte** · **difficulté désirable** (70–85 % de réussite) · **sortir vers le lab** au sommet.
États d'un concept : *Découvert → En pratique → Ancré* (2 réapprentissages espacés réussis) *→ Maîtrisé* (3 réapprentissages espacés + échelon ≥ 4 sur 2 surfaces). Séance unique 5 / 15 / 45 composée par le serveur. Préparation v2 calibrée. **[EVIDENCE-BASED]**

## 20. Proposed daily loop
**Signal** (heure et contexte choisis, widget, Situation du jour) → **Aujourd'hui** (un plan, une action) → **Séance** (Express / Séance / Plongée) → **Feedback** (Déclic) → **Résultats** (l'Atlas change, le Rythme avance) → **Indice pour demain** (aperçu de la prochaine Situation, question d'ouverture). Un jour compte dès une séance Express ; aucune perte, aucun compte à rebours ; ≤ 1 notification par jour. **[EVIDENCE-BASED + DESIGN JUDGMENT]**

## 21. Proposed social loop
**Situation du jour** → réponse → **distribution de la communauté** → **partage sans spoiler** → un ami joue → comparaison du **raisonnement** (pas du rang) → **objectif hebdomadaire de Squad** → **encouragement** → retour. Compétition seulement **opt-in, appariée et plafonnée** (ligues de progression, cote Glicko-2, défis notés sur justesse × calibration). Privé par défaut ; pas de chat libre au lancement. **[EVIDENCE-BASED]**

## 22. Proposed progression model
Deux axes par concept — **Profondeur** (échelons) et **Mémoire** (rétention prédite) — agrégés en territoires, régions et routes ; *Préparation* par route ; *Passeport* par personne ; **Rythme** hebdomadaire pour la régularité ; **jalons de maîtrise** rares ; **cote** de compétence par région uniquement en mode classé. **Supprimés :** XP visible, niveaux génériques, couronnes, ligues aux minutes. **[EVIDENCE-BASED]**

## 23. Proposed AI model
**« Colonne déterministe, voix ancrée, contrat d'effort »** : le moteur décide quoi (maîtrise, espacement, fausses idées, prochaine activité) ; le modèle de langage décide comment le dire, uniquement à partir d'extraits validés et datés, avec vérification de support et abstention ; l'apprenant fait l'effort d'abord. IA **aux moments utiles** (après une erreur, avant une révision, après une séance, aux jalons d'examen) — **jamais en onglet de chat**. Routage : sur l'appareil (Foundation Models) → Private Cloud Compute (iOS 27, si éligible) → petit modèle Azure OpenAI existant → explication auteur → abstention. Consentement nommant le fournisseur ; pas d'inférence d'émotion ; IA formative uniquement. **[EVIDENCE-BASED + INDUSTRY PATTERN]**

## 24. Proposed brand personality
**« Cœur calme, expression méritée »** (précision de l'*Expressive Minimalism* du fondateur) : calme pendant l'effort, vivant aux transitions, expressif aux jalons, intensité proportionnelle à la rareté, **Mode Calme** disponible. **Voix :** le pair compétent et bienveillant (précis, chaleureux, une pointe d'esprit, jamais culpabilisant ni infantile). **Signature :** lumière et réfraction (*Prism*), accent **Indigo CertiGo**, 8 couleurs de région, le **Déclic** (visuel + motif sonore + haptique), vocabulaire propre (Situation, Atlas, Ancré, Rythme, Squad, Passeport). **Pas de mascotte** (option D), test d'un glyphe compagnon abstrait (option C). Retrait des mascottes dérivées d'icônes Azure et du #0078D4 ; les produits réels gardent leurs **icônes officielles non modifiées** (jamais la marque CertiGo). Alerte de marque : *Certingo*. **[EVIDENCE-BASED + DESIGN JUDGMENT]**

---

## 25. Top 10 product bets
| # | Pari | Hypothèse | Étiquette / confiance | Mesure de succès |
|---|---|---|---|---|
| 1 | **Formats natifs de la tech** (Situation, Trouver l'erreur, Prédire, Ordonner, Composer, Diagnostiquer, Arbitrer) | Pratiquer sur artefacts transfère mieux que des QCM équivalents | EVIDENCE-BASED → EXPERIMENTAL BET · moyenne | Transfert à J+7 (V3) ; utilité perçue |
| 2 | **Séance adaptative 5 / 15 / 45** | Une architecture d'atomes sert les trois usages sans compromis | EVIDENCE-BASED · moyenne | Séances complétées ; gains durables / minute |
| 3 | **Situation du jour** | Un rituel fini et partageable crée une habitude sans peur | COMPETITOR OBSERVATION → BET · moyenne | ≥ 40 % des actifs hebdo ≥ 4 j/sem (V4) |
| 4 | **Atlas Profondeur × Mémoire** | Voir sa connaissance grandir et s'estomper motive et guide | DESIGN JUDGMENT → BET · moyenne | Usage du filtre « À raviver » ; rétention W4 |
| 5 | **Préparation v2** | L'honnêteté (incertitude, preuves) crée la confiance et le bouche-à-oreille | EVIDENCE-BASED · moyenne | Brier / fiabilité ; NPS des candidats |
| 6 | **Fausses idées + Expliquer mon erreur** | Une explication fondée sur *ma* fausse idée corrige mieux | EVIDENCE-BASED · moyenne-haute | Récurrence à 14 jours ↓ |
| 7 | **Rythme hebdomadaire** | La flexibilité retient autant que la série, avec moins de stress | EVIDENCE-BASED · haute | Non-infériorité W4 + stress ↓ (V5) |
| 8 | **Squads coopératives** | L'appartenance augmente la régularité | EVIDENCE-BASED · moyenne | Objectifs de Squad atteints ; rétention des membres |
| 9 | **Fraîcheur** (Mises à jour, renouvellement, consultation documentaire) | La tech change : être à jour est une valeur et une douve | INDUSTRY PATTERN → BET · moyenne | Taux d'items obsolètes ; usage du mode renouvellement |
| 10 | **Présence iOS + accessibilité de référence** | Widgets interactifs, Live Activities, Intents et artefacts accessibles augmentent l'usage et la reconnaissance Apple | OFFICIAL APPLE + BET · moyenne | Part des séances lancées hors app ; labels d'accessibilité ; mise en avant éditoriale |

## 26. Top 10 experience principles
1. **L'apprentissage d'abord** — toute mécanique cite la règle d'apprentissage qu'elle sert, sinon elle n'existe pas.
2. **Un tap vers le progrès** — ouvrir l'app mène à la meilleure activité en un geste.
3. **L'effort avant l'aide** — tentative, puis indice, puis explication.
4. **Cœur calme, expression méritée** — le calme pour l'effort, l'éclat pour les jalons.
5. **Le contenu est le héros** — des artefacts lisibles, beaux, accessibles.
6. **Honnête par construction** — incertitude visible, IA étiquetée, aucun faux progrès.
7. **Respect de la personne** — ni peur ni culpabilité ; le repos fait partie de l'apprentissage.
8. **Célébrer la maîtrise, pas l'activité.**
9. **Natif et inclusif** — Dynamic Type, VoiceOver, Reduce Motion sont des critères d'acceptation, pas des options.
10. **Un seul système** — Prism, sans composant ponctuel ni valeur brute.

## 27. Top risks
| # | Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Coût et qualité du contenu sur artefacts (fondateur seul) | Haute | Critique | Gabarits par format, IA rédactrice + relecture humaine, périmètre étroit (4 routes Fundamentals + 2 régions transverses), statistiques d'items |
| 2 | Dispersion (trop de fonctionnalités) | Haute | Élevé | Listes REMOVE, phases, flags, critères d'acceptation |
| 3 | Erreur d'IA virale sur un service cloud | Moyenne | Critique | Ancrage, vérification de support, abstention, fraîcheur, bouton Signaler, tests bloquants |
| 4 | Préparation mal calibrée → candidats qui échouent | Moyenne | Élevé | Bandes sans probabilité avant calibration, collecte incitée des résultats, A/B « réservation prématurée » |
| 5 | Conflit de marque *Certingo* | Moyenne | Élevé | Recherche d'antériorité, avis juridique, plan B de nom |
| 6 | Retrait des mécaniques de perte → baisse du DAU | Moyenne | Moyen | A/B sur rétention W4 / 90 j et apprentissage ; rattrapage gratuit |
| 7 | Plafond de transfert du téléphone (« superficiel ») | Moyenne | Élevé | Échelle de profondeur, passage au lab, mesure du transfert différé |
| 8 | Démarrage à froid social | Haute | Moyen | Valeur sans amis (communauté de la Situation du jour), Squads appariées |
| 9 | Réglementation (DSA, Digital Fairness Act, AI Act, COPPA) | Moyenne | Moyen | Pas de dark patterns, IA formative, mode mineurs, consentements |
| 10 | Dérive du vibe coding (styles par écran, logique déplacée) | Haute | Élevé | Prism, tests d'architecture, portes de phase, Decision Requests |
| 11 | Changement d'examens / de règles Microsoft | Haute | Moyen | Versions de routes, diff de la documentation officielle, mises à jour |
| 12 | Dépendance à Apple (Foundation Models, PCC) | Moyenne | Faible-moyen | Routage agnostique, replis |

## 28. What must be tested before implementation
| Priorité | Test | Avant la phase | Référence |
|---|---|---|---|
| P0 | Premier lancement (WOW, compréhension, < 60 s) — prototype | 3 | Bible §17 V1 |
| P0 | Lisibilité et utilité des formats sur artefacts (AX défaut / AX3) | 4 | V2 |
| P0 | Recherche d'antériorité et avis sur le nom | Tout investissement de marque | V11 |
| P1 | Formats vs QCM sur transfert différé | 5 | V3 |
| P1 | Accessibilité réelle avec utilisateurs VoiceOver / basse vision | 4 puis 11 | V9 |
| P1 | Personnage C vs D | 7 | V8 |
| P1 | Disposition à payer et placement du paywall | 10 | V10 |
| P2 | Rituel Situation du jour (bêta 4 semaines) | 8 | V4 |
| P2 | Rythme hebdo vs série quotidienne (A/B) | 7 | V5 |
| P2 | IA vs sans IA sur items différés sans aide | 9 | V7 |
| Continu | Calibration de la Préparation (résultats déclarés) | 6 → | V6 |
Toute expérimentation touchant à la motivation ou aux notifications passe une **porte éthique** (le rapport FTC voit dans l'expérimentation manipulatrice à grande échelle « un signal de dark patterns »). **[INDUSTRY PATTERN]**

---
## Annexe A — APP STORE TOP-10-WORTHY FRAMEWORK et scorecard

> Échelle : **3/10** = présent mais faible ; **6/10** = correct, au niveau du marché ; **9–10/10** = référence de la catégorie. Position actuelle = app native d'octobre 2026, en tenant compte des capacités backend non exposées. Cible = fin de la transformation (Phase 11).

| # | Dimension | 3/10 | 6/10 | 9–10/10 | CertiGo actuel | Écart | Changements nécessaires | Cible |
|---|---|---|---|---|---|---|---|---|
| 1 | Product usefulness | Une fonction utile, sans plan | Couvre un besoin clair (prépa) | Indispensable au quotidien et pour un objectif | **3** — démo, 2 situations fictives | Pas de valeur quotidienne réelle | Aujourd'hui, Séance, routes réelles, Situation du jour | 8 |
| 2 | Learning effectiveness | Lecture + QCM | Récupération + espacement | Récupération espacée, formats de transfert, maîtrise différée mesurée | **4** — moteurs FSRS, mais 145/146 QCM | Formats, ordre récupération-d'abord, mesures différées | Formats natifs, *successive relearning*, métriques WDL | 9 |
| 3 | First-session experience | Formulaires, paywall | Leçon rapide | « Wow » en < 60 s, sans compte | **2** — démo + avertissements ; héritage : 23 écrans + paywall | Pas de valeur avant 60 s | Situation de découverte, compte après la valeur | 9 |
| 4 | Daily habit loop | Rappels génériques | Série + objectif | Rituel fini + plan du jour + indices passifs, sans peur | **2** | Aucune boucle native | Aujourd'hui, Situation du jour, Rythme, widgets | 8 |
| 5 | Retention | Non mesurée | D30 dans la moyenne | Rétention durable fondée sur la valeur cumulée | **2** — non mesurable | Pas de boucle ni de valeur cumulée | Atlas, Mémoire, Squads, Préparation | 8 |
| 6 | Content quality | Questions isolées | Couverture correcte, explications | Situations réalistes, explications par option, sources datées, fraîcheur | **5** — original, sourcé, mais mince | Profondeur et formats | Gabarits de formats, relecture, mises à jour | 9 |
| 7 | Personalization | Aucune | Révisions adaptatives | Séance composée pour moi, fausses idées, plan | **3** — moteurs invisibles | Exposition | Séance, Expliquer mon erreur, Carte des fausses idées | 8 |
| 8 | Gamification | Points sans sens | Série, XP, ligues | Jeu au service de la maîtrise, sans dark pattern | **3** — héritage copié, mal aligné | Mécaniques de perte | Rythme, jalons, Missions, célébrations 0–3 | 8 |
| 9 | Social experience | Partage isolé | Amis, classement | Coopération, appartenance, privé par défaut | **2** | Rien de vivant | Squads, encouragements, communauté de la Situation | 7 |
| 10 | Collaboration | Aucune | Quêtes entre amis | Objectifs d'équipe qui font apprendre | **1** | Absente | Squads, Missions coopératives | 7 |
| 11 | Competition | Classement global XP | Ligues | Opt-in, apparié, plafonné, sur maîtrise et progression | **3** — 10 ligues XP (backend) | Récompense les heures | Ligues de progression, Glicko-2, défis justes | 7 |
| 12 | AI usefulness | Chatbot générique | Explications à la demande | IA contextuelle, ancrée, à contrat d'effort, mesurée | **3** — tuteur conçu, non validé live | Usage, ancrage visible | Moments IA, repli, évaluations | 8 |
| 13 | Visual identity | Gabarit système | Cohérent | Reconnaissable en une capture | **3** — sobre, un accent | Pas de langage propre | Prism, Réfraction, couleurs de région | 8 |
| 14 | Brand distinctiveness | Nom seul | Ton cohérent | Promesse, voix, vocabulaire, signature sensorielle | **2** — mascottes Azure, #0078D4 | Ancrage tiers, conflit de nom | Voix, Déclic, vocabulaire, décision de nom | 8 |
| 15 | Interaction quality | Fonctionnel | Fluide | Gestes signature, zéro friction, adapté au pouce | **4** — natif, mais feedback en 3 temps | Friction aux moments clés | Vérifier → feedback, artefacts tactiles | 9 |
| 16 | Motion | Aucun / gratuit | Transitions propres | Mouvement qui explique, célébrations rares, Reduce Motion | **2** | Absent | Jetons PrismMotion, échelle 0–3 | 8 |
| 17 | Haptics | Aucune | Système | Vocabulaire haptique signifiant + signature | **2** (non vérifié natif) | Absente | `sensoryFeedback`, motif Déclic | 8 |
| 18 | Accessibility | Partielle | Dynamic Type + VoiceOver de base | Toutes tâches en AX5, VoiceOver, Voice Control ; artefacts accessibles ; labels App Store | **5** — composants système, bug de contraste | Artefacts, audits, labels | Exigences §11.1, audits par phase | 9 |
| 19 | Performance | Lent | Correct | Instantané, fluide à 120 i/s, frugal | **7** — lancement sain | Écrans lourds non mesurés | Budgets, mesures par phase | 9 |
| 20 | iOS integration | Aucune | Widgets | Widgets interactifs, Live Activities, Intents, Spotlight, FM | **3** | Rien hors de l'app | Phase 10 + Today widget | 9 |
| 21 | Trust | Douteux | Correct | Transparence totale, aucune manipulation | **7** — architecture solide | Méta-texte anxiogène, héritage culpabilisant | Copie, méthode publiée, zéro dark pattern | 9 |
| 22 | Monetization fairness | Paywall précoce, pièges | Freemium classique | Gratuit généreux, Pro pour la profondeur, résiliation simple | **5** — paywall pré-valeur (héritage) | Placement | Pro après la valeur, StoreKit 2 | 9 |
| 23 | Offline / resilience | Aucun | Contenu en cache | Séances complètes hors ligne, synchro sans perte | **6** — packs, file idempotente | Séances complètes | Pré-composition de 2 séances | 9 |
| 24 | Community potential | Aucun | Amis | Rituels collectifs, Squads, temps forts | **2** | Absent | Situation du jour, Squads, sprint annuel | 7 |
| 25 | Shareability | Capture d'écran | Carte de partage | Cartes de capacité sans spoiler, désirables | **2** | Rien à partager | Cartes Situation / jalons / Passeport | 8 |
| 26 | Word of mouth | Aucun | Satisfaction | « Il faut que tu essaies » | **2** | Pas de moment racontable | Déclic, Situation du jour, honnêteté | 8 |
| | **Moyenne** | | | | **3,3** | | | **8,2** |
*(Moyennes calculées : 3,27 et 8,23.)*

---

## Annexe B — Verdict sur les hypothèses du fondateur

| Hypothèse | Verdict | Ce qu'elle devient | Pourquoi |
|---|---|---|---|
| Readiness Score | **Transformer** | *Préparation* (bandes, incertitude, preuves ; probabilité après calibration) | La formule actuelle double l'oubli, récompense la couverture partielle et ressemble à une probabilité **[EVIDENCE-BASED]** |
| Streak | **Transformer** | *Rythme* hebdomadaire ; série quotidienne optionnelle | Flexibilité et retour récompensé > peur de perdre **[EVIDENCE-BASED]** |
| XP | **Cacher** | Points de maîtrise internes | L'XP mesure l'activité **[EVIDENCE-BASED]** |
| Gems | **Supprimer** | — | Monnaie sans apprentissage, risque réglementaire **[INDUSTRY PATTERN]** |
| Shop | **Supprimer** | (Plus tard : cosmétiques gagnés) | Monétise l'anxiété **[EVIDENCE-BASED]** |
| Leagues | **Transformer** | Ligues de progression opt-in, appariées, plafonnées | Les ligues XP fabriquent des champions de 4 h/jour **[INDUSTRY PATTERN]** |
| Friends | **Garder** | Privés par défaut, pseudonymes | Relatedness g = 1,78 **[EVIDENCE-BASED]** |
| Quests | **Transformer** | ≤ 3 *Missions* liées à des compétences, dont 1 coopérative | Corvées sinon |
| Seasons | **Transformer** | ≤ 4 temps forts / an, coopératifs ; sprint de décembre | Nouveau départ oui, battle pass non |
| Learning paths | **Transformer** | *Routes* sur l'Atlas, adaptatives | Un chemin linéaire contredit la révision espacée |
| AI Tutor | **Transformer** | IA contextuelle, ancrée, à contrat d'effort ; pas d'onglet | Chat latéral peu utilisé ; accès libre nuit **[EVIDENCE-BASED]** |
| Microlearning | **Garder, préciser** | Séance 5 / 15 / 45 sur une architecture d'atomes | 5 min = réapprendre, pas apprendre du complexe **[EVIDENCE-BASED]** |
| Daily Challenge | **Garder, élever** | *Situation du jour* (artefact + décision + communauté) | Rituel fini, utile, partageable |
| Social competition | **Transformer** | Coopération d'abord ; compétition opt-in et juste | **[EVIDENCE-BASED]** |
| *Expressive Minimalism* | **Valider et préciser** | « Cœur calme, expression méritée » + Mode Calme | Expression par la hiérarchie, intensité ∝ rareté **[EVIDENCE-BASED]** |
| Références (Apple Music, Airbnb, Duolingo, DailyArt, Coursera, Kartable, Lovable) | **Compatibles sous conditions** | Personnalité dans le contenu et les symboles, pas dans un personnage | Duolingo (maximaliste, personnage) et Apple Music (retenue, contenu) **ne fonctionnent pas ensemble tels quels** |
| Mascotte | **Non** (test d'un glyphe abstrait) | Symboles, Déclic, voix | Effets d'agents pédagogiques faibles chez l'adulte ; risque d'image incompétente ; Azure = hors licence |
| « CertiGo a trop de choses » | **Oui** | 4 onglets, une action par écran, mécaniques réduites | 15+ fonctionnalités Flutter pour un contenu à 1 question par leçon |
| « Certaines mécaniques Duolingo ne conviennent pas » | **Oui** | Copier la **bienveillance** de Duolingo, pas ses ligues aux minutes ni sa culpabilisation | Les gains documentés de Duolingo viennent de la réduction des frictions |
| « Certaines fonctionnalités sont trop visibles » | **Oui** | Le catalogue de 89 certifications, la ligue, le Coach | Reléguées ou supprimées |

---

## Annexe C — Registre de preuves (recommandations majeures)

| # | Recommandation | SOURCE | EVIDENCE | CONFIDENCE | CERTIGO IMPLICATION |
|---|---|---|---|---|---|
| 1 | Récupération avant relecture | Rowland 2014 ; Yang 2021 ; Adesope 2017 | Méta-analyses, g ≈ 0,50–0,61 | Haute | Question d'ouverture, items à chaque carte |
| 2 | Espacement et successive relearning | Latimier 2021 ; Cepeda 2008 ; Rawson & Dunlosky 2011 ; Janes 2020 | Méta-analyses, essais en classe | Haute | FSRS + définition d'*Ancré / Maîtrisé* |
| 3 | Entrelacer les concepts confondables | Brunmair & Richter 2019 | Méta-analyse g = 0,42 (pas pour le vocabulaire) | Moyenne | Paires de contraste en révision |
| 4 | Feedback explicatif par option | Wisniewski 2020 ; Butler & Roediger 2008 | Méta-analyse d = 0,48 ; expériences | Haute | Panneau de feedback, ≤ 3 leurres |
| 5 | Exemples travaillés puis estompés | Barbieri 2023 ; Tetzlaff 2025 | Méta-analyses | Haute (novices) | Test de saut, estompage |
| 6 | Formats sur artefacts (Parsons, exemples erronés, dépannage structuré) | Ericson 2017 ; Weinman 2021 ; McLaren 2016 ; Schaafstal 2000 | Études contrôlées | Moyenne-haute | Catalogue de formats P1/P2 |
| 7 | Passage au lab au sommet | Koedinger 2015 ; Macnamara 2014 | Corrélationnel ; méta-analyse | Moyenne | Bouton « Continuer sur Mac » |
| 8 | Préparation honnête, calibrée | NBME / NCLEX ; Hausknecht 2007 ; Dunlosky & Rawson 2012 | Pratiques d'évaluation ; méta-analyse | Moyenne | Bandes, incertitude, collecte des résultats |
| 9 | Rythme flexible, retour récompensé | Lally 2010 ; Milkman 2021 ; Beshears 2021 | Études longitudinales, mégaétude | Haute | Rythme hebdo, rattrapage gratuit |
| 10 | Pas de messages de perte | Silverman & Barasch 2023 ; DSA art. 25 ; lignes directrices UE mineurs | Expériences ; réglementation | Haute | Réécriture des notifications |
| 11 | Compétition opt-in et appariée | Rogers & Feller 2016 ; Niederle & Vesterlund 2007 ; Pelánek 2016 | Expériences de terrain | Haute | Ligues de progression, Glicko-2 |
| 12 | Social coopératif | Sailer & Homner 2020 ; Li 2024 ; Kyndt 2013 | Méta-analyses | Moyenne-haute | Squads |
| 13 | Gamification modeste, fondée sur le feedback | Sailer & Homner 2020 ; Deci 1999 ; Hanus & Fox 2015 | Méta-analyses ; étude adulte | Haute | Jeu au service de la maîtrise |
| 14 | IA structurée, ancrée, après effort | Kestin 2025 ; Bastani 2025 ; VanLehn 2011 | RCT ; méta-analyse | Haute | Moments IA, contrat d'effort |
| 15 | Pas d'onglet de chat | Oreopoulos & Low 2026 ; retrait de Q-Chat | Documents de travail ; observation | Moyenne | Coach dissous |
| 16 | Ancrage et abstention | Kabir 2024 ; IaC-Eval 2024 ; Magesh 2025 | Études évaluées | Haute | Vérification de support, repli |
| 17 | Consentement fournisseur IA | App Review 5.1.2(i) (nov. 2025) ; AI Act | Règles | Haute | Écran de consentement |
| 18 | Pas de mascotte infantilisante | Schroeder 2013 ; Castro-Alonso 2021 ; Frontiers 2026 | Méta-analyses ; étude | Moyenne | Option D + test C |
| 19 | Retrait des mascottes dérivées d'icônes Azure et du #0078D4 | Conditions d'usage Microsoft ; Fluent UI | Textes officiels | Haute (pas un avis juridique) | Nouvelle palette, symboles propres |
| 20 | « Cœur calme, expression méritée » | Google M3 Expressive (46 études) ; HIG Motion ; NN/g | Recherche industrielle ; guide officiel | Moyenne-haute | Échelle de célébration, Mode Calme |
| 21 | Liquid Glass sur la navigation uniquement | HIG Materials ; NN/g | Guide officiel | Haute | Règle Prism |
| 22 | Accessibilité de référence | HIG Accessibility ; Accessibility Nutrition Labels ; lauréats Inclusivity | Officiel | Haute | Artefacts accessibles, audits |
| 23 | Widgets, Live Activities, App Intents | Lauréats ADA (Flighty, Mela, Lumy) ; WWDC26 | Officiel / observation | Haute | Phase 10 + widget Aujourd'hui |
| 24 | iOS 26 minimum | Adoption 79 % (juin 2026) | Données Apple via presse | Moyenne-haute | DR-002 |
| 25 | Positionnement large, coin d'entrée certification | Classements Education ; Pearson VUE ; WEF | Observation ; enquêtes | Moyenne | Atlas + routes |
| 26 | Promesse « original, sans dump » | Politiques Microsoft et CompTIA | Règles officielles | Haute | Marque de confiance |
| 27 | Conflit de nom *Certingo* | certingo.app | Observation | Moyenne | Recherche d'antériorité |
| 28 | Les vrais symboles des éditeurs : icônes officielles non modifiées, dans les usages autorisés (v1.1) | Conditions des kits Microsoft (Azure, Power Platform, Dynamics 365, Fabric, Entra) ; règles de marque Microsoft, Microsoft 365, Windows, GitHub ; AWS, Google Cloud, CNCF / Linux Foundation, Cisco, PSF, Docker, HashiCorp, Red Hat, CompTIA, ISC2 ; App Store Review Guidelines 2.3.7, 2.3.9, 4.1, 5.2 ; Paivio (double codage) ; Tulving & Thomson 1973 | Textes officiels ; recherche fondamentale en mémoire | Haute (règles publiées) · Moyenne (portée exacte dans une app payante, à confirmer par écrit) | Étape 2B, `BrandLabel`, contextes, manifeste, DR-010 / OD-11 |

---

## Annexe D — Sources et annexes de recherche
Les mémos de recherche (en anglais) accompagnent ce rapport dans le dossier `annexes/` : **R1** marché et benchmark (≈ 60 sources), **R2** Apple et iOS (55 sources, ~80 % officielles Apple), **R3** science de l'apprentissage (58 sources, ~45 évaluées par les pairs), **R4** gamification et social (77 sources), **R5** IA (52 sources), **R6** apprentissage de la tech (~60 sources), **R7** design et marque (71 sources) ; **R8a** et **R8b** (v1.1) icônes et logos officiels des éditeurs (Microsoft, GitHub, Apple ; AWS, Google Cloud, CNCF et autres). Chaque mémo contient ses URL, ses niveaux de confiance, ses contradictions et un pré-mortem.

Sources internes : instantané du dépôt Certigo (06/07/2026) — `README.md`, `docs/ETAT_DU_PROJET.md`, `AUDIT_Certigo.md`, `content/`, `backend/src/Certigo.Domain` ; journaux de build `CertigoNative` (14/10 et 22/10/2026) ; enregistrements d'écran (19/10, 22/10/2026) ; trace Instruments (19/10/2026) ; `Certigo.icon` ; *Certigo Enterprise Architecture Blueprint 2026–2030* ; *Stratégie exhaustive de monétisation pour Certigo* ; *Opportunity Analysis: a "Duolingo for IT & Enterprise Learning"*.

Sources externes principales (sélection) : Apple Newsroom et developer.apple.com (ADA 2023–2026, App Store Awards 2023–2025, HIG, WWDC26) ; Duolingo (lettres aux actionnaires T3 2025–T2 2026, blog, Settles & Meeder 2016, Yancey & Settles 2020) ; Dunlosky 2013 ; Rowland 2014 ; Adesope 2017 ; Yang 2021 ; Latimier 2021 ; Brunmair & Richter 2019 ; Pan & Rickard 2018 ; Wisniewski 2020 ; Barbieri 2023 ; Tetzlaff 2025 ; Rawson & Dunlosky 2011 ; Sinha & Kapur 2021 ; Macnamara 2014 ; Sailer & Homner 2020 ; Li, Hew & Du 2024 ; Deci, Koestner & Ryan 1999 ; Milkman 2021 ; Lally 2010 ; Silverman & Barasch 2023 ; Rogers & Feller 2016 ; Kestin 2025 ; Bastani 2025 ; VanLehn 2011 ; Kabir 2024 ; Lister 2004 ; Lopez 2008 ; Ericson 2017 ; Weinman 2021 ; Margulieux 2020 ; Schaafstal 2000 ; McLaren 2016 ; Microsoft Learn (examens, renouvellement, Applied Skills, politiques) ; CompTIA ; AWS ; WEF 2025 ; Pearson VUE 2025 ; Skillsoft ; ISC2 ; Google Design (Material 3 Expressive) ; NN/g ; conditions d'usage des icônes Azure ; Fluent UI.
