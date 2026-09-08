# Politique de confidentialité — Certigo

Dernière mise à jour : 19 août 2026

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
  naissance saisie pendant l’onboarding. Ces préférences locales ne sont pas
  toutes envoyées au serveur.

Certigo ne demande pas de pièce d’identité pour utiliser le flux normal de
suppression de compte.

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
- Application Insights pour la télémétrie technique du backend.

Les communications réseau de production utilisent HTTPS. Les secrets
d’authentification et mots de passe en clair ne sont pas journalisés.

## Conservation et suppression

Les données actives sont conservées tant que le compte existe. L’utilisateur
peut lancer la suppression depuis **Profil > Mon compte > Supprimer le compte**,
ou utiliser la page publique :

https://www.certigo-app.com/account-deletion/

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
