# Profil de release Alpha privée

La fondation Alpha est une couche additive au contenu mobile versionné. Elle ne
retire aucun écran, modèle, provider ou test de l'application complète. Une
capacité conserve le même point d'intégration lorsqu'elle passe de `off` à
`upcoming`, puis à `enabled`.

## Configuration

`CERTIGO_RELEASE_PROFILE` est obligatoire au démarrage mobile :

| Valeur | Usage |
|---|---|
| `private-alpha` | Alpha privée, limitée par contrat UX à cinq comptes test pré-provisionnés |
| `full` | Comportement complet existant, toutes les capacités activées |

Une valeur absente ou inconnue résout le profil `fail-closed`. Le bootstrap
affiche alors l'erreur de configuration avant l'orientation, les notifications,
le stockage local, la connectivité ou les services réseau.

Les profils sont définis dans `packages/core/lib/src/release_profile.dart` et
injectés par Riverpod. Aucun identifiant, e-mail, tenant Entra, secret ou valeur
Azure n'est contenu dans ce contrat.

## Alpha Core obligatoire

Ces capacités doivent toutes être `enabled` dans `private-alpha`. La validation
du profil échoue si une entrée manque ou vaut `off`/`upcoming`.

| Capacité | Alpha | Full | Surface conservée |
|---|---:|---:|---|
| Authentification des comptes test | Enabled | Enabled | Connexion et restauration de session |
| Catalogue de certifications | Enabled | Enabled | Bibliothèque complète |
| Parcours | Enabled | Enabled | Parcours et domaines |
| Leçons | Enabled | Enabled | Lecture et exercices |
| Quiz et correction | Enabled | Enabled | Soumission, correction et récompenses |
| Progression, readiness et XP | Enabled | Enabled | Accueil, profil et indicateurs |
| Cache, offline et retry | Enabled | Enabled | Cache de leçons et file idempotente |
| Contenu versionné | Enabled | Enabled | Synchronisation et rollback du contenu public |

Les recommandations adaptatives, succès, saisons, quêtes, boutique, examen blanc
et rappels d'étude restent également activés : ils existent déjà et ne sont pas
présentés artificiellement comme inachevés, sans pour autant élargir l'invariant
minimal Alpha Core.

## Upcoming

Les points d'accès utiles à la compréhension du produit restent à leur
emplacement futur. Ils sont visibles, contrastés, libellés `Bientôt`, annoncés
`indisponible, bientôt` par le lecteur d'écran, et ne portent aucun callback,
navigation, haptique ou démarrage de service.

| Capacité non-core | Alpha | Full |
|---|---:|---:|
| Ligue | Upcoming | Enabled |
| Amis | Upcoming | Enabled |
| Partage social | Upcoming | Enabled |
| Tuteur IA | Upcoming | Enabled |
| Suppression de compte | Upcoming | Enabled* |

`*` Le profil `full` déclare la suppression de compte activée, mais le kill
switch opérationnel existant `ACCOUNT_DELETION_ENABLED` reste fail-closed. Tant
que le gate Cosmos destructif n'a pas réussi, l'état runtime effectif reste
`off`, y compris avec le profil `full`.

## Enabled later

Ces capacités restent `off` dans l'Alpha. Elles n'ont pas de promesse
interactive tant que leur contrat produit ou opérationnel n'est pas prêt.

| Capacité | Alpha | Full | Motif Alpha |
|---|---:|---:|---|
| Inscription publique | Off | Enabled | Cinq comptes test attribués, sans libre-service |
| Expérience manager | Off | Enabled | Hors coeur apprenant |
| Gestion d'organisation | Off | Enabled | Hors coeur apprenant |
| SSO/SCIM entreprise | Off | Enabled | Contrat entreprise futur |
| Intégration Viva | Off | Enabled | Intégration future |
| Contenu privé entreprise | Off | Enabled | Isolation de données future |
| Acquis portables | Off | Enabled | Portabilité future |
| Universal Links | Off | Enabled | Activation plateforme future |

## Garde-fous

- Les routes profondes d'une capacité non activée redirigent avant la
  construction de l'écran vers une surface générique sans données.
- Les repositories et services non activés lèvent
  `CapabilityUnavailableException` avant de construire leur dépendance réseau,
  stockage ou permission.
- L'inscription publique est absente du formulaire Alpha et le flux progressif
  est gardé. La connexion explique d'utiliser le compte test attribué.
- `Alpha privée` et la limite de cinq testeurs apparaissent discrètement dans la
  section Application du profil.
- Le profil `full` garde toutes les capacités `enabled`; les chemins existants
  restent inchangés.

## Dépendances futures

1. Le backend devra faire respecter l'admission de cinq comptes
   pré-provisionnés. La présente limite est uniquement un contrat UX.
2. Les valeurs Entra et API de l'Alpha devront être injectées hors du dépôt.
3. Le gate destructif de suppression de compte devra être validé avant son
   activation.
4. Les associations Universal Links devront être déployées avant activation.
5. Les fonctions entreprise et le tuteur IA nécessitent leurs contrats de
   données, sécurité et exploitation propres.
6. Une PR supérieure dédiée réalisera l'audit et le polish visuel des écrans
   Alpha Core; cette fondation fournit seulement les surfaces stables.
7. Avant d'activer un artefact officiel, chaque commande de build mobile devra
   injecter explicitement `CERTIGO_RELEASE_PROFILE=private-alpha` ou `full`.
   Les workflows et configurations de release ne sont volontairement pas
   modifiés dans cette PR; en leur absence, l'application reste fail-closed.

Cette PR ne modifie ni backend, ni Azure, ni DNS, ni store, ni workflow, ni
runner, ni environnement de déploiement.
