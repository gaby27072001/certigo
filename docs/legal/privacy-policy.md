# Politique de confidentialité — Certigo

Dernière mise à jour : 20 octobre 2026

Cette politique distingue l’application Apple native **CertigoNative**
(`com.certigo.mobileapp`) et le client Flutter historique. Les fonctions
disponibles dépendent de la version installée ; un mode de démonstration ne
représente pas un compte connecté ni une progression synchronisée.

## Données traitées

Certigo traite les données nécessaires au fonctionnement du compte et du
service :

- identifiant de compte, nom d’affichage, pseudo et, pour les comptes créés par
  e-mail, adresse e-mail et empreinte cryptographique du mot de passe ;
- progression, réponses et résultats de quiz, tentatives d’examen, séries,
  récompenses virtuelles, préférences d’apprentissage et relations d’amitié ;
- données techniques de requête et de diagnostic, notamment des identifiants de
  corrélation non personnels, codes d’erreur et horodatages ;
- préférences et données hors ligne stockées sur l’appareil, dont l’année de
  naissance saisie pendant l’onboarding du client Flutter. Ces préférences
  locales ne sont pas toutes envoyées au serveur.

Dans le client Apple natif connecté, Microsoft Entra External ID (CIAM), via
la bibliothèque Microsoft Authentication Library (MSAL), authentifie le compte.
Certigo utilise l’identifiant de ce compte pour lui associer ses résultats et
sa progression côté serveur. Les jetons d’authentification sont conservés dans
le trousseau sécurisé du système, pas dans les préférences ordinaires.
La consultation d’un historique synchronisé ne transmet pas les brouillons
non envoyés : ils restent propres à l’appareil.

Certigo ne demande pas de pièce d’identité pour utiliser le flux normal de
suppression de compte.

## Stockage sur l’appareil Apple

Le téléchargement des packs publics de questions est volontaire. Ces packs
ne contiennent pas les clés de correction privées du serveur. Les brouillons
et les réponses en attente de synchronisation restent stockés localement,
séparés par compte et par service API. Une réponse mise en attente ne constitue
pas une correction confirmée ni une attribution de points : le serveur fait
autorité lors de la synchronisation.

Les fichiers d’activité, de soumission et de contenu utilisent la protection
iOS `NSFileProtectionCompleteUntilFirstUserAuthentication` : ils sont
inaccessibles avant le premier déverrouillage suivant le redémarrage, puis
peuvent rester accessibles lorsque l’appareil est reverrouillé. Ce mécanisme
n’est pas la protection `NSFileProtectionComplete`.
Les préférences propres à l’application utilisent `UserDefaults` ; le motif
d’accès déclaré à Apple pour ce stockage est `CA92.1`.

## Finalités

Ces données servent à authentifier le compte, synchroniser la progression,
noter les exercices côté serveur, calculer les fonctionnalités de progression
et de jeu, permettre les fonctions sociales choisies, sécuriser le service et
diagnostiquer les erreurs.

## Prestataires et transmission

Les données ne sont pas vendues. Elles peuvent être traitées par les services
techniques nécessaires au produit :

- Microsoft Azure et Azure Cosmos DB pour l’hébergement et les données actives ;
- Microsoft Entra External ID et, lorsque l’utilisateur le choisit, le
  fournisseur d’identité fédéré Microsoft, Google ou Apple ;
- Azure Communication Services pour les e-mails transactionnels lorsqu’il est
  configuré ;
- Application Insights pour la télémétrie technique du backend ;
- Sentry pour les erreurs et crashs techniques du client Flutter, lorsqu’il
  est configuré dans cette version. Les rapports sont limités au type d’erreur,
  à une pile nettoyée, à la version de
  l’application et aux caractéristiques techniques nécessaires au diagnostic
  et à la symbolication. L’identifiant de compte, l’e-mail, les tokens, les
  corps de requête et l’adresse IP brute ne sont pas collectés à cette fin.
  L’enregistrement de session, le tracing, le profiling, les captures d’écran
  et la hiérarchie visuelle sont désactivés.

Le client Apple natif n’intègre pas Sentry ni de SDK publicitaire ou de suivi
inter-applications. Cette absence ne signifie pas qu’aucune donnée ne quitte
l’appareil : l’authentification Microsoft, les requêtes d’apprentissage et les
diagnostics techniques du backend nécessitent les traitements décrits ici.
Le manifeste de confidentialité de l’application et celui de MSAL ont des
périmètres distincts ; les déclarations du SDK ne doivent pas être confondues
avec les données effectivement utilisées par Certigo.

Les communications réseau de production utilisent HTTPS. Les secrets
d’authentification et mots de passe en clair ne sont pas journalisés.

## Conservation et suppression

Les données actives sont conservées tant que le compte existe. L’utilisateur
peut lancer la suppression depuis la rubrique de compte de sa version de
l’application lorsqu’elle propose **Supprimer le compte**, ou utiliser la page
publique, qui reste accessible sans l’application :

https://www.certigo-app.com/account-deletion/

La suppression est distincte d’une déconnexion et exige une confirmation
explicite ainsi qu’une authentification récente. Pour le parcours Microsoft
natif, une nouvelle authentification interactive doit fournir la preuve
d’authentification récente exigée par le serveur (fenêtre de dix minutes).
La simple présence d’un jeton non expiré ne suffit pas.
Les données locales du compte et du service concernés sont purgées après
confirmation de l’achèvement côté serveur ; une erreur ou une demande encore
en cours ne doit pas être présentée comme une suppression achevée.

Le flux supprime les données actives associées au compte et les identifiants
gérés par Certigo immédiatement après la vérification et l’exécution de la
demande. Un reçu pseudonymisé, sans adresse e-mail, nom ni identifiant de compte
en clair, est conservé pendant 30 jours pour reprendre une opération interrompue
et prouver son achèvement.

En production, les sauvegardes continues Cosmos DB ont une fenêtre de
récupération maximale de 30 jours. Une sauvegarde n’est pas utilisée pour
réactiver un compte supprimé ; les copies résiduelles expirent avec cette
rotation. Une restauration opérationnelle doit réappliquer les suppressions
enregistrées avant remise en service.

Les journaux techniques de suppression ne contiennent aucune identité, adresse
e-mail ni identifiant de compte. Ils sont conservés pendant 90 jours.

Microsoft Entra conserve un objet utilisateur supprimé dans ses éléments
supprimés pendant sa fenêtre de récupération documentée de 30 jours, avant
suppression définitive. Cet objet n’autorise plus l’accès à Certigo.

La suppression du compte Certigo ne supprime pas le compte Microsoft, Google ou
Apple personnel de l’utilisateur. Pour un compte fédéré, l’identité cliente
Certigo hébergée dans Entra External ID est supprimée.

## Contact

Pour toute question ou demande sans accès à l’application :
gabriel.chambaud@icloud.com
