# Fiche Google Play — Certigo (modèle FR)

> Modèle de fiche Play Store. Les valeurs marquées `TODO` doivent être confirmées
> avant la publication. Aucune de ces valeurs n'est un secret ; les secrets de
> signature/publication sont gérés via GitHub Actions (voir `docs/RELEASE_MOBILE.md`).

| Champ | Valeur |
|---|---|
| Nom de l'application | **Certigo** |
| applicationId / package | `law.certigo` ⚠️ NON modifiable après le 1er upload |
| Catégorie | Éducation |
| Adresse e-mail de contact | TODO (ex : `support@certigo.app`) |
| Site web | TODO |
| Politique de confidentialité (URL) | **TODO obligatoire** (exigée par Play même en test interne) |

## Description courte (≤ 80 caractères)
Maîtrisez vos certifications Microsoft par micro-leçons premium.

## Description complète (≤ 4000 caractères)
Certigo vous prépare aux certifications Microsoft (AZ-900, AZ-104, AI-900,
DP-900, SC-900) avec une pédagogie courte et efficace : concept → exemple
appliqué → vérification de compréhension → révision adaptative (répétition
espacée). Suivez votre progression grâce au Readiness Score (0–100) et restez
motivé avec XP, niveaux, streak et badges — sans cœurs ni vies.

⚠️ Certigo n'est ni affilié, ni approuvé par Microsoft. Aucun contenu
d'examen réel n'est reproduit : toutes les leçons et tous les items sont
originaux.

## Conformité (à vérifier dans la console Play)
- **Politique de confidentialité** : URL publique obligatoire. TODO.
- **Section "Sécurité des données"** : déclarer les données collectées. La bêta
  stocke des préférences locales (`shared_preferences`) et appelle l'API
  Certigo authentifiée (Entra External ID). TODO : compléter le formulaire.
- **Classification du contenu** : remplir le questionnaire (IARC). Attendu : Tout public.
- **Public cible & contenu** : hors « familles/enfants ».
- **targetSdk** : actuellement 34 (défaut Flutter 3.24). TODO : suivre l'exigence
  Play en vigueur et bumper si nécessaire avant la production.

## Ressources graphiques (TODO avant publication)
- Icône 512×512 (PNG 32 bits). Actuellement : icône Flutter par défaut → TODO marque.
- Image de présentation (feature graphic) 1024×500.
- 2 à 8 captures d'écran téléphone.
