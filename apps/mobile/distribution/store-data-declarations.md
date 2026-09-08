# Déclarations de données — faits implémentés

Ce document prépare la saisie manuelle dans Play Console et App Store Connect.
Il ne prouve pas que les consoles ont été mises à jour.

| Catégorie | Collectée/transmise | Finalité réelle |
|---|---|---|
| Identifiant utilisateur | Oui | authentification, compte, synchronisation |
| Adresse e-mail | Oui pour les comptes e-mail ; fournie au broker pour les comptes fédérés | authentification et e-mails transactionnels |
| Nom d’affichage / pseudo | Oui | profil et fonctions sociales |
| Activité dans l’app | Oui : progression, réponses, scores, tentatives | apprentissage et notation serveur |
| Relations sociales | Oui lorsque l’utilisateur ajoute un ami | liste d’amis et classement |
| Diagnostics | Oui : corrélation, codes d’erreur, latence backend | sécurité et fiabilité |
| Année de naissance onboarding | Stockage local SharedPreferences dans l’implémentation actuelle | personnalisation locale |
| Localisation précise, contacts, santé, paiements réels | Non implémentés dans le code actuel | sans objet |

Les données réseau sont transportées via HTTPS. Le compte et les données
associées peuvent être supprimés dans l’app. La page externe à déclarer sur
Google Play est :

`https://www.certigo-app.com/account-deletion/`

Cette URL est écrite en clair, et non sous forme de variable, parce que ce
document est recopié à la main dans la console Play. `docs/PUBLIC_DOMAIN_MIGRATION.md`
fait autorité ; le `www` y est obligatoire, la racine ne pouvant pas servir la page.

Avant soumission en production, le responsable de publication doit comparer ces
faits au binaire exact et aux SDK réellement activés ; aucune réponse de console
n’est automatisée par ce dépôt.
