# Suppression de compte — Certigo

Dernière mise à jour : 19 août 2026

## Depuis l’application

Dans Certigo, ouvrez **Profil > Mon compte > Supprimer le compte**. L’application
demande une confirmation explicite et une authentification récente avant
d’enregistrer la demande.

La suppression retire les données actives associées au compte : profil,
progression, tentatives, événements d’apprentissage, économie virtuelle,
classements, relations sociales et identifiants de connexion gérés par Certigo.
Ces données actives sont supprimées immédiatement après la vérification et
l’exécution de la demande. La session locale et la file de synchronisation hors
ligne sont effacées uniquement après confirmation du serveur.

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
