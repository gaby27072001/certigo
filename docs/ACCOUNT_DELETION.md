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

Le gate historique `test-account-deletion-cosmos.yml` est retiré de
`.github/workflows/` : il ciblait le pool `certigo-trusted` et ne constitue pas
une preuve d’isolement suffisante. Il reste archivé dans
`.github/workflows-disabled/`. Son remplacement one-shot est disponible dans
`.github/workflows/post-merge-cosmos-account-deletion.yml`.

Le validateur trusted accepte uniquement les trois états atomiques de migration :
A avec le legacy seul actif, B avec les deux workflows archivés, et C avec le
one-shot seul actif et le legacy archivé. Le dépôt est en C depuis cette PR
d'activation ; tout état partiel ou mixte est rejeté.

L'ensemble actif de chaque état est épinglé dans le manifeste versionné
`.github/scripts/workflow-semantic-manifest.json`. Les empreintes SHA-256 portent
sur le chemin canonique et l'arbre YAML décodé, avec clés triées, chaînes NFC et
commentaires ignorés. Le parseur rejette les clés dupliquées, alias, merge keys,
anchors, tags et clés dynamiques. Le validateur charge toujours le manifeste du
contrôle trusted, jamais celui du checkout de PR : une PR ne peut donc pas
s'auto-approuver en modifiant simultanément un workflow et son empreinte.

La commande manuelle
`node .github/scripts/generate-workflow-semantic-manifest.mjs --write` est réservée
à une revue explicite de baseline. Le validateur ne l'appelle jamais. Une rotation
de baseline doit être fusionnée comme contrôle trusted avant la modification
sémantique correspondante ; `--check` vérifie ensuite que la génération revue est
reproductible.

Cette PR d’activation ne provisionne aucune ressource et ne lance aucun test :
elle déplace le one-shot sous `.github/workflows/` tandis que la variable
`CERTIGO_COSMOS_EMULATOR_ENABLED` demeure non définie ou `false`. Le workflow
reste donc bloqué tant qu’elle n’est pas explicitement égale à `true`. Le test
post-merge requiert ensuite une VM jetable sans identité managée, le label exclusif
`certigo-cosmos-emulator`, un checkout vérifié de `main`, puis un unique
`workflow_dispatch` avec la variable temporairement à `true`. Les prérequis,
permissions, bornes et preuves de destruction sont détaillés dans
`docs/runbooks/COSMOS_EMULATOR_RUNNER.md`.

### Validation Apple restante après déploiement

Effectuer un test réel avec un compte Apple sacrifiable : créer la connexion via
`susi_certigo`, supprimer le compte dans Certigo, puis vérifier que
l’association Apple n’existe plus ou est révoquée. C’est la seule validation
Apple encore ouverte pour ce flux.

L'URL publique de suppression de compte reste volontairement non configurée.
Elle ne peut être publiée ou inscrite dans Play Console qu'après satisfaction du
contrat fail-closed décrit dans
[`PUBLIC_DOMAIN_MIGRATION.md`](./PUBLIC_DOMAIN_MIGRATION.md). Une URL GitHub
Pages n'est pas un fallback implicite : sa possession, sa stabilité et sa
compatibilité stores doivent être prouvées comme pour toute autre origine.

Cette PR ne renseigne aucune valeur de production et ne publie aucune page. Les
actions humaines post-acquisition sont regroupées dans le guide de migration.

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
