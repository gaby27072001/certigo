# Suppression de compte — Certigo

Dernière mise à jour : 20 octobre 2026

## Depuis l’application

Dans les versions de Certigo proposant la suppression dans l’application,
ouvrez la rubrique de compte du profil, puis **Supprimer le compte**.
Cette action est distincte de **Se déconnecter**. L’application demande une
confirmation explicite et une authentification récente avant d’enregistrer la
demande. Si votre version ne propose pas encore ce parcours, utilisez la voie
sans application ci-dessous.

Pour le client Apple natif connecté avec Microsoft Entra CIAM via MSAL,
le parcours de suppression doit demander une ré-authentification interactive.
Le serveur vérifie une preuve d’authentification dans une fenêtre de dix minutes ;
un jeton simplement encore valide ne remplace pas cette preuve.

La suppression retire les données actives associées au compte : profil,
progression, tentatives, événements d’apprentissage, économie virtuelle,
classements, relations sociales et identifiants de connexion gérés par Certigo.
Ces données actives sont supprimées immédiatement après la vérification et
l’exécution de la demande. La session locale et la file de synchronisation hors
ligne du compte et du service concernés sont effacées uniquement après
confirmation de l’achèvement par le serveur. Cela comprend les identifiants
locaux, l’activité, les brouillons et les soumissions en attente de ce compte.
Une erreur ou un état « en cours » ne confirme pas l’achèvement : consultez
l’état de la demande ou réessayez sans changer de compte.

Le mode démo ne possède pas de compte serveur à supprimer. Le connecteur
manuel de développement ne remplace pas la ré-authentification Microsoft
requise en production.

## Sans l’application

Envoyez une demande à
[gabriel.chambaud@icloud.com](mailto:gabriel.chambaud@icloud.com?subject=Suppression%20de%20compte%20Certigo)
depuis l’adresse associée au compte, avec pour objet
**Suppression de compte Certigo**. N’envoyez jamais de mot de passe, de jeton,
de pièce d’identité ou de contenu de cours.

Certigo demandera une vérification proportionnée avant d’exécuter la
suppression. Cette voie reste disponible après désinstallation de l’application.
Le site ne collecte ni ne stocke les données saisies : le bouton ouvre le client
de messagerie de l’utilisateur.

## Données techniques résiduelles

Le reçu pseudonymisé de suppression contient seulement un identifiant de
demande aléatoire, des états d’étapes, des codes d’échec non personnels et des
horodatages. Il expire automatiquement après 30 jours.

En production, les sauvegardes Cosmos DB suivent la fenêtre technique
`Continuous30Days`. Elles ne sont pas utilisées pour restaurer un compte
supprimé et les copies résiduelles expirent au plus tard après 30 jours.

Les journaux techniques de suppression ne contiennent aucune identité, adresse
e-mail ni identifiant de compte. Ils sont conservés pendant 90 jours.
