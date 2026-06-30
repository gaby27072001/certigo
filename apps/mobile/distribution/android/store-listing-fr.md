# Fiche Google Play — Certigo (modèle FR)

> Modèle de fiche Play Store. Les valeurs marquées `TODO` doivent être confirmées
> avant la publication. Aucune de ces valeurs n'est un secret ; les secrets de
> signature/publication sont gérés via GitHub Actions (voir `docs/RELEASE_MOBILE.md`).

| Champ | Valeur |
|---|---|
| Nom de l'application | **Certigo** |
| applicationId / package | `com.certigo.mobileapp` ⚠️ NON modifiable après le 1er upload |
| Catégorie | Éducation |
| Adresse e-mail de contact | TODO (ex : `support@certigo.app`) |
| Site web | `https://gchambaud_microsoft.github.io/Certigo/` |
| Politique de confidentialité (URL) | `https://gchambaud_microsoft.github.io/Certigo/privacy-policy/` |

## Description courte (≤ 80 caractères)
Le Duolingo des certifications IT — formez-vous, entraînez-vous, réussissez.

## Description complète (≤ 4000 caractères)
Certigo est LA plateforme de référence pour apprendre, s'entraîner et décrocher ses certifications IT.

🏆 Le Duolingo du monde tech
Oubliez les cours interminables et les PDF ennuyeux. Certigo transforme votre préparation aux certifications en une expérience engageante, progressive et addictive — quelques minutes par jour suffisent pour progresser vraiment.

📚 Toutes les certifications IT au même endroit
Cloud : AWS, Azure, Google Cloud
Réseau : Cisco CCNA, CompTIA Network+
Sécurité : CompTIA Security+, certifications Cybersec
DevOps, IA, Data et bien plus encore…
Un seul endroit pour tout votre parcours IT professionnel.

🎯 Une méthode qui fonctionne
Concept → Exemple concret → Quiz → Révision adaptative par répétition espacée. Vous apprenez, vous pratiquez, vous mémorisez — exactement ce qu'il faut pour réussir le jour J.

🎮 Apprenez en jouant
XP, niveaux, streak quotidien, badges de progression — sans cœurs ni vies. Votre Readiness Score (0–100) vous indique en temps réel si vous êtes prêt à passer votre examen.

⚠️ Certigo est une plateforme indépendante, non affiliée ni approuvée par Microsoft, Amazon, Cisco, CompTIA ou tout autre organisme de certification. Toutes les leçons et questions sont originales.

## Conformité (à vérifier dans la console Play)
- **Politique de confidentialité** : URL publique en place via GitHub Pages (`/privacy-policy/`). Migration ultérieure possible vers `https://certigo.app/privacy-policy/` en conservant le même chemin.
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
