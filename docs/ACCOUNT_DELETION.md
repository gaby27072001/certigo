# Suppression de compte

## Contrat livré

| Surface | Comportement |
|---|---|
| Mobile | `Profil > Mon compte > Supprimer le compte`, conséquences explicites, case de confirmation, ré-authentification, progression, reprise et confirmation finale |
| API | `GET /api/account/deletion` et `POST /api/account/deletion`, utilisateur dérivé du JWT |
| Web public | `/account-deletion/`, demande par messagerie sans formulaire ni collecte par GitHub Pages |
| Persistance | état `account-deletion` durable dans `attempts`, partitionnée par SHA-256 de l’identifiant de compte |
| Blocage | toute API hors suppression répond `423` dès qu’une demande durable existe |
| Audit | identifiant de demande aléatoire, événement, étape, code d’échec et horodatage ; aucun nom, e-mail, identifiant de compte ou jeton |
| Activation | `ACCOUNT_DELETION_ENABLED=false` par défaut ; activation interdite avant succès du gate Cosmos destructif |

## Preuve et ré-authentification

La première demande exige un `auth_time` de moins de 10 minutes. Un compte
e-mail doit ressaisir son mot de passe. Un compte fédéré relance OIDC avec
`prompt=login` et `max_age=0`. L’ID token de preuve est validé côté serveur et
doit porter le même sujet que le bearer token. Une reprise d’une demande déjà
persistée n’impose pas une nouvelle ré-authentification.

## Ordre de suppression et reprise

Les étapes sont idempotentes et enregistrées après chaque succès :

1. relations d’amitié et entrées de classement ;
2. progression, tentatives, examens et événements d’apprentissage ;
3. opérations d’économie virtuelle et achats en gemmes ;
4. profil, puis seconde réconciliation des relations sociales pour fermer les
   créations concurrentes ;
5. credential e-mail local ou identité cliente Entra External ID.
6. réconciliation finale de toutes les partitions utilisateur ; chaque writer
   Cosmos acquiert atomiquement un lease avant mutation, publie le session token
   du conteneur écrit, puis la suppression attend zéro lease et rejoue ses sweeps
   avec ces tokens avant de passer à `completed`.

Un échec conserve les étapes terminées, un code non personnel, un compteur et
la prochaine échéance de retry. Le client n’efface jamais sa session ni sa file
hors ligne avant le statut serveur `completed`.

Pour les comptes e-mail, supprimer le credential empêche immédiatement tout
nouveau refresh token. Le tombstone 423 bloque les access tokens déjà émis
jusqu’à leur expiration. Pour les comptes fédérés, l’API supprime l’objet
utilisateur Entra via Microsoft Graph après `revokeSignInSessions` ; `404` est
traité comme un succès idempotent.

## Conservation et anonymisation

| Donnée | Action | Résidu |
|---|---|---|
| Données actives Cosmos liées au compte | suppression immédiate après vérification et exécution | aucun document utilisateur actif |
| État de suppression | sujet en clair retiré à l’achèvement | hash SHA-256, request ID, étapes, codes, dates |
| Tombstone | TTL Cosmos | 30 jours |
| Sauvegarde Cosmos production | expiration par rotation PITR | 30 jours maximum |
| Journaux de suppression | événements structurés sans identité | 90 jours |
| Données locales | effacement après confirmation serveur | aucun jeton, préférence ou travail hors ligne Certigo |

Une restauration Cosmos doit exécuter la réconciliation des suppressions avant
de remettre les données restaurées en service. Le tombstone ne doit pas être
restauré isolément de son historique.

## État des prérequis externes

Les prérequis suivants sont accomplis :

- le client confidentiel Graph dédié est créé ;
- les permissions d’application minimales Microsoft Graph
  `User.RevokeSessions.All` et `User.ReadWrite.All` sont consenties par un
  administrateur ;
- le secret `ENTRA_GRAPH_CLIENT_SECRET` et les variables
  `ENTRA_GRAPH_TENANT_ID`, `ENTRA_GRAPH_CLIENT_ID` et
  `ENTRA_REAUTH_AUDIENCE` sont configurés dans les GitHub Environments
  `staging` et `prod`, sans valeur dans le dépôt ;
- Sign in with Apple est activé sur l’App ID mobile ; le Service ID Certigo
  CIAM est associé au domaine et à la return URL ; Apple est activé dans
  `susi_certigo` et le bouton est visible.

`User.Read`, visible uniquement sous « Autres autorisations accordées », n’est
ni configurée ni utilisée par Certigo. Son nettoyage est une tâche distincte.

Le CD valide le jeu Graph complet, injecte le secret uniquement dans un paramètre
Bicep `@secure`, puis Bicep crée une nouvelle version
`ENTRA-GRAPH-CLIENT-SECRET` dans le Key Vault de l’environnement. Seule son URI
versionnée est écrite dans `ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI` ; l’identité
managée de la Function App lit la valeur au runtime. Aucune saisie manuelle dans
Key Vault ou dans les app settings n’est requise. Le compte humain n’a donc pas
besoin d’accès à l’abonnement Certigo.

Sans les trois variables et le secret, le déploiement staging/production
échoue avant Azure. En `dev`, le CD les ignore, ne crée aucun secret Graph et
l’étape d’identité externe reste indisponible plutôt que de produire un faux
succès.

Le backend reste fail-closed avec `ACCOUNT_DELETION_ENABLED=false`. Le paramètre
ne pourra être activé dans l’IaC qu’après succès explicite du test d’intégration
Cosmos de suppression ; un test skippé ou non exécuté ne satisfait pas ce gate.
Tant que le flag reste faux, Bicep ne crée pas le secret Graph dans Key Vault et
n’émet aucun des quatre app settings Graph/ré-authentification de suppression.
La PR d’activation devra aussi fournir
`ENTRA_GRAPH_CLIENT_SECRET_EXPIRES_ON` comme timestamp UTC futur ; cette
expiration est appliquée au secret Key Vault et contrôlée par Checkov.

### Gate d’intégration Cosmos

Le workflow trusted `test-account-deletion-cosmos.yml`, chargé uniquement depuis
`main` par un `repository_dispatch` manuel sans payload, autorise uniquement un
émulateur Docker local sur runner éphémère. Il génère une clé aléatoire pour le
run, crée une base unique et supprime le conteneur en `finally`. Il n’utilise
aucune identité Azure, aucun rôle data-plane et aucune donnée live.

Déclenchement opérateur, après présence du workflow sur `main` :

```powershell
'{"event_type":"test-account-deletion-cosmos","client_payload":{}}' |
  gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input -
```

### Validation Apple restante après déploiement

Effectuer un test réel avec un compte Apple sacrifiable : créer la connexion via
`susi_certigo`, supprimer le compte dans Certigo, puis vérifier que
l’association Apple n’existe plus ou est révoquée. C’est la seule validation
Apple encore ouverte pour ce flux.

Les actions humaines non liées à ce câblage restent :

1. Enregistrer
   `https://gchambaud_microsoft.github.io/Certigo/account-deletion/` dans le champ
   URL de suppression du compte de Play Console après publication de la page.

Cette PR ne renseigne aucune valeur de production et ne publie aucune page. Les
promotions Bicep, le test Apple réel, le dispatch GitHub Pages et les déclarations
des consoles store restent des actions humaines avant soumission.

Le contact public approuvé est `gabriel.chambaud@icloud.com`. La politique
approuvée ne demande aucune pièce d’identité.

## Exigences officielles consultées le 18 août 2026

- Apple, [App Store Review Guidelines 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/) :
  une app qui crée des comptes doit permettre leur suppression dans l’app.
- Apple, [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/) :
  ré-authentification permise, délai permis s’il est annoncé, confirmation
  d’achèvement, suppression des données non légalement requises et révocation
  Sign in with Apple.
- Google Play, [Personal and sensitive user data — Account Deletion Requirement](https://support.google.com/googleplay/android-developer/answer/10144311) :
  voie facilement accessible dans et hors de l’app, données associées supprimées,
  désactivation simple insuffisante.
- Google Play, [Data deletion on Google Play](https://support.google.com/googleplay/android-developer/answer/13327111) :
  URL web fonctionnelle enregistrée dans Play Console et utilisable après
  désinstallation.
- Google, [Designing your account deletion experience](https://android-developers.googleblog.com/2024/03/designing-your-account-deletion-experience-google-play.html) :
  conséquences avant confirmation et état final explicite.
- Microsoft Graph, [Delete a user](https://learn.microsoft.com/graph/api/user-delete?view=graph-rest-1.0) :
  permission d’application `User.ReadWrite.All`, réponse idempotente gérée côté
  Certigo.
- Microsoft Graph, [Revoke sign-in sessions](https://learn.microsoft.com/graph/api/user-revokesigninsessions?view=graph-rest-1.0) :
  invalidation des refresh tokens et cookies de session avec la permission
  d’application `User.RevokeSessions.All` ; un court délai de propagation est
  documenté par Microsoft.
