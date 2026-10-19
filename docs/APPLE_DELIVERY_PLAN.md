# Plan de realisation et gates Apple

Mise a jour : 19 octobre 2026. Ce plan distingue preparation source,
integration et comportement observe. Une option inscrite ici n'est pas une
fonctionnalite deja livree.

## Ce qui exige macOS, et ce qui ne l'exige pas

Le Mac personnel n'est pas necessaire pour ecrire du Swift ou gerer le portail.
En revanche, les SDK Apple et Xcode exigent macOS : une machine macOS distante
pourrait effectuer une compilation, sans remplacer les essais sur appareil.
Ne pas acheter ou configurer un service distant implicitement.

| Travail | Sans Mac | Preuve Apple indispensable |
| --- | --- | --- |
| Domaines, contrats, etats, coordination et tests Swift Foundation | Implementation et tests Linux avec toolchain compatible | Integration des adaptateurs Apple distincte |
| SwiftUI, localisation, semantique d'accessibilite | Source et controles statiques preparables | Compilation SDK, rendu et interactions dans Xcode/appareil |
| VoiceOver, grandes tailles, clavier, Switch Control, Voice Control | Criteres et corrections source preparables | Taches reelles sur les configurations et appareils cibles |
| MSAL, Keychain, scenes, callbacks | Contrats et configuration publique preparables | Initialisation, cache, retour navigateur, connexion et deconnexion sur Apple |
| iPad, widgets, App Intents et Live Activities | Contrats, routage et sources preparables | Compilation des extensions, etats locked/stale/logout et integrations systeme |
| Apple Developer / App Store Connect | Consultation et reglages web possibles ici | Pas de Mac requis pour le portail ; signature/archive requises pour un build |
| Certificats et profils | Inspection web possible ; ne pas regenerer par precaution | Verification locale des cles, profils et signature du build sur macOS |
| Archive et TestFlight | Textes, captures prevues, criteres, confidentialite preparables | Archive signee et inspection des bundles ; installation et essai reels |
| Contenus, backend et contrats wire | Travail autonome possible selon les decisions produit | Consommation native a observer ; pas de remplacement par un test de schema |

Les tests Linux ne compilent pas SwiftUI/UIKit/Security/MSAL. Une verification
statique d'accessibilite ne prouve ni le rendu ni la navigation assistee.

## Ordre de livraison

| Lot | Resultat | Dependances et critere de sortie |
| --- | --- | --- |
| Q0 - Coeur reel | Connexion, profil, catalogue, contenu et progression | Compte de test dedie, API et choix de consommation des lecons ; parcours reels observes, aucun verdict invente |
| Q1 - Inclusion | Lisibilite, accessibilite, coherence visuelle et comprehension | Conception parallele a Q0 ; toutes les taches courantes utilisables avec les configurations retenues |
| Q2 - Fiabilite | Reprise, hors ligne, isolation compte et synchronisation | Stores/outbox existants, autorite serveur preservee ; pas de perte, doublon ou attribution au mauvais compte |
| Q3 - iPad et langues | Fenetres, clavier/pointeur, localisation | Q0-Q2 ; parcours utilisables aux tailles et langues ciblees, contenu disponible explicite |
| Q4 - Acces systeme | Liens universels, Spotlight, App Intents/Siri/Raccourcis et partage | Routage et session fiables ; liens absents/invalides, droits et deconnexion geres |
| Q5 - Regularite | Rappels facultatifs, widget, calendrier et aides TipKit | Donnees reelles persistees ; choix respectes, aucune fuite sur ecran verrouille, pas de relance abusive |
| Q6 - Beta et decouverte | Candidate TestFlight et fiche App Store fidele | Q0-Q3 et extensions retenues ; signature, confidentialite et publication sont des gates distinctes |
| Q7 - Options | IA, Watch, education, monetisation, gamification et anti-distraction | Usage, risques, maintenance et autorisations approuves avant implementation ; ne bloquent pas toutes la beta |

Azure reste la source de verite des comptes, corrections et progressions.
CloudKit n'est pas ajoute comme seconde verite. Le pilote editorial n'est pas
un contrat de cours connecte : le choix lecteur local FR non certifiant versus
contrat API reste une decision distincte.

## Acceptation inclusion et reglages

- VoiceOver : noms, titres, ordre, regroupements, selection, correction et
  changements d'etat ; lecture braille selon les configurations disponibles.
- Texte : Dynamic Type, texte en gras et agrandissement au moins 200 % sur les
  parcours iPhone/iPad, sans masquer une reponse ou une action.
- Interaction : Voice Control, Switch Control, clavier et alternative aux
  gestes precis, drag et appui long ; focus coherent.
- Apparence : systeme/clair/sombre, contraste, couleur jamais seule porteuse
  d'information, Reduce Motion et Reduce Transparency respectes.
- Cognition : consignes courtes, actions stables, sessions courtes et mode
  d'entrainement sans pression temporelle ; examen blanc chronometre distinct.
  Evaluer Assistive Access sans pretendre qu'il adapte automatiquement l'app.
- Audio : lecture optionnelle avec pause/vitesse/langue, coexistence VoiceOver ;
  sous-titres/transcriptions et audiodescription selon les medias proposes.
- Reglages : suivre le systeme par defaut ; sons/vibrations separes, rappels
  et plages de tranquillite, UI et langue du contenu distinctes, Wi-Fi et
  espace des telechargements, compte et confidentialite.
- Ne pas afficher d'interrupteurs inoperants pour des fonctions seulement prevues.

Les audits automatises aident a trouver des defauts ; l'acceptation exige aussi
des essais manuels des parcours, idealement avec des personnes aux besoins varies.

## Integrations a preparer apres le coeur

- App Intents, recherche Spotlight et liens universels partagent le routage
  authentifie. Retirer les index prives apres changement de compte/deconnexion.
- WidgetKit montre une progression reelle et une reprise valide ; tester donnees
  anciennes, ecran verrouille et absence de compte.
- Controles systeme et bouton Action : reutiliser les memes actions, sur appareils
  compatibles. ActivityKit uniquement pour une activite temporaire volontaire.
- Notifications locales pour les rappels simples ; APNs seulement si besoin
  serveur demontre. EventKit/EventKitUI avec action volontaire et acces minimal.
- TipKit pour une fonction non evidente, pas comme publicite ou tutoriel force.
- Filtres de concentration pour adapter Certigo ; bloquer d'autres apps est un
  autre produit, pas un droit accorde par un filtre.
- Handoff ne synchronise pas seul les donnees. Hors ligne et transferts conservent
  les garanties d'owner, d'idempotence et de correction serveur.
- Translation garde l'original et ne remplace pas une correction validee.
  Localiser aussi pluriels, dates, nombres et droite-a-gauche si necessaire.
- Mesurer lancement, blocages et energie avec outils Apple/MetricKit selon besoins.
  BackgroundTasks ne garantit pas une execution a une heure exacte.

## Options a decider, pas a activer toutes

| Option | Condition |
| --- | --- |
| Apple Intelligence/Foundation Models | Disponibilite materiel/OS/langues/provider, confidentialite, evaluation et repli sans IA ; pas de correction certifiante generee implicitement |
| Face ID/Touch ID | Protection locale utile avec repli ; ne remplace pas CIAM |
| StoreKit et partage familial | Offre payante decidee, droits serveur/restauration/remboursement/expiration definis, produits eligibles |
| Sign in with Apple / passkeys | Exigences App Review applicables et compatibilite CIAM a instruire ; aucune fusion par email |
| Watch | Usage court utile, maintenance justifiee, anciens owners/retards/doublons/unpair geres |
| ClassKit/Schoolwork, Shared iPad, MDM et School Manager | Public institutionnel confirme, isolation eleves et partage prive explicites |
| Game Center | Benefice pedagogique, participation facultative et confidentialite |
| FamilyControls/ManagedSettings/DeviceActivity | Anti-distraction volontaire, autorisation utilisateur et entitlement de distribution Apple |
| TV/visionOS | Usage propre demontre apres coeur stable, pas de portage automatique |

## Portail et distribution : minimiser les modifications

Les reglages d'accessibilite, couleurs et Dynamic Type ne sont pas des capacites
a cocher sur l'App ID. Ne pas activer iCloud, APNs, App Groups ou Sign in with Apple
avant une integration qui les necessite.

L'identite de developpement `com.certigo.native.dev` n'est pas l'identite installee
`com.certigo.mobileapp`. Une absence d'App ID explicite de developpement n'est pas
en soi une raison de modifier l'identite de production ou les profils locaux.
Ne pas regenerer de certificat, creer de cle, revoquer de profil ou changer la
signature sans besoin concret et autorisation correspondante.

Preparer fiche et captures localisees, pages produit personnalisees et optimisation
de fiche selon les contenus disponibles. Les In-App Events doivent etre de vrais
evenements eligibles, pas des taches quotidiennes. Demander des avis sans recompense
ni filtrage des avis negatifs. Les labels d'accessibilite doivent correspondre a
toutes les taches courantes sur chaque plateforme declaree.

## References

- [Accessibilite](https://developer.apple.com/documentation/accessibility)
- [Criteres des labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)
- [App Intents](https://developer.apple.com/documentation/appintents)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [Education](https://developer.apple.com/education/)
- [Family Controls](https://developer.apple.com/documentation/familycontrols)
- [Pages produit](https://developer.apple.com/app-store/custom-product-pages/)
- [CIAM local](../apps/apple/CIAM_LOCAL_DEVELOPMENT.md)
- [Manifeste de confidentialite](../apps/apple/PRIVACY_MANIFEST.md)
