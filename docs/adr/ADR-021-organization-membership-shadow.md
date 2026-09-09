# ADR-021 — Organization/Membership : activation du runtime `shadow`

| Champ | Valeur |
|---|---|
| **ADR** | 021 |
| **Statut** | Accepté — runtime `off\|shadow` |
| **Date** | 2026-09-03 |
| **Activation runtime** | `off` (défaut, tous environnements) ; `shadow` ajoute uniquement une observation read-only en tâche de fond |
| **Contrat** | `docs/contracts/organization-membership/v1` (1.1.0 → 1.2.0) |
| **Dépend de** | [ADR-015](./ADR-015-organization-membership.md) — non modifié par cette décision |
| **Numérotation** | `019` et `020` étaient déjà pris au moment de la rédaction (voir note dans [`ADR-020-immutable-content-storage.md`](./ADR-020-immutable-content-storage.md) : `019` abandonné suite à collision avec `ADR-019-runtime-content-releases.md`, committé en parallèle sur `wp-p2-04`). `021` est le premier numéro libre confirmé. |

> Cette décision livre uniquement la prochaine phase annoncée par ADR-015 : un runtime `shadow`
> **sans aucun endpoint d'écriture ni de lecture utilisateur**. La surface HTTP V1 reste
> strictement 404 avant authentification, dans `off` comme dans `shadow`. Le legacy reste
> entièrement autoritaire. Aucun environnement n'active `shadow` par cette PR — les paramètres
> Bicep par défaut restent `off` partout ; seule la valeur `@allowed` est élargie pour permettre
> une décision manuelle et séparée plus tard.

## Contexte

ADR-015 a livré le contrat et le domaine Organization/Membership avec un runtime strictement
`off` : `ORGANIZATION_MEMBERSHIP_V1` ne pouvait prendre aucune autre valeur sans faire échouer le
démarrage. Sa section « Conséquences et prochaine phase » réserve explicitement la suite : un
runtime `shadow` qui observe (memberships projetées, RU Cosmos, conflits d'idempotence, volumétrie
des équipes, seuil du batch d'offboarding) sans exposer d'endpoint d'écriture, une activation
`read`/`write` étant hors périmètre et exigeant son propre ADR.

Le seul autre runtime `off|shadow` du dépôt est `PersonLinkedIdentityFeatureMode` (ADR-014). Son
`Parse()` (off/shadow insensible à la casse, rejet strict de toute autre valeur) sert de gabarit
direct pour le parsing introduit ici. Sa différence structurelle importante : Person/LinkedIdentity
n'a jamais gaté de route HTTP — son mode `shadow` ne fait qu'ajouter un décorateur de repository
sur du trafic legacy déjà vivant. Organization/Membership, à l'inverse, gate déjà
`OrganizationFunctions`/`OrganizationFeatureMiddleware` sur ce même flag. Ajouter naïvement
`Shadow` à l'énumération sans revoir la garde aurait donc déverrouillé silencieusement les routes.

Une seconde contrainte a façonné cette décision : `IOrganizationOffboardingRecoveryWorker`
(livré par ADR-015 avec le domaine, jamais câblé à un timer) mute et supprime des documents
(`PurgeOffboardingAsync`). Le câbler à un timer déclenché par `shadow` aurait fait tourner du code
mutant en tâche de fond — inacceptable pour un runtime dont l'ADR précédent exige explicitement
« sans endpoint d'écriture utilisateur ».

## Décision

### 1. `ORGANIZATION_MEMBERSHIP_V1` accepte `off` (défaut) et `shadow`

`OrganizationFeatureMode` gagne une valeur `Shadow`. `OrganizationFeatureOptions.Parse` accepte
`off`/`shadow` insensible à la casse (vide ou absent → `off`) et lève `InvalidOperationException`
pour toute autre valeur — parité stricte avec `PersonLinkedIdentityOptions.Parse`.

### 2. La surface HTTP reste bloquée dans `off` **et** dans `shadow`

`OrganizationFeatureOptions` expose `HttpSurfaceEnabled`, `false` pour les deux valeurs actuelles.
`OrganizationFeatureMiddleware` et `OrganizationFunctions.EnsureAvailable()` gardent désormais sur
`!HttpSurfaceEnabled` plutôt que sur `Mode == Off`. Seul un futur mode `read`/`write` — qui exigera
son propre ADR, comme le réserve ADR-015 — mettrait cette propriété à `true`. Testé par des
`[Theory]` paramétrés sur `off` et `shadow` : chaque route retourne 404 avant authentification et
avant tout accès service, dans les deux modes.

### 3. Une voie d'observation strictement read-only, séparée par construction

`shadow` active un unique comportement automatique : un timer `OrganizationShadowObservationFunctions`
qui, une fois par cycle (`ORGANIZATION_SHADOW_OBSERVATION_SCHEDULE`, même cadence que le recovery
Enterprise Learning Metrics), observe deux signaux :

- le nombre d'offboardings incomplets (`ListIncompleteOffboardingsAsync`, requête Cosmos déjà
  existante et déjà read-only, plafonnée à 100) — sert de proxy au « seuil du batch d'offboarding »
  sans jamais déclencher la purge elle-même ;
- la volumétrie des appartenances d'équipe (`CountTeamMembershipsAsync`, nouvelle requête `TOP`
  plafonnée à 10 000 — une borne inférieure au coût RU prévisible, pas un agrégat `COUNT` non
  borné sur tout le conteneur — également read-only). Le résultat est un
  `TeamMembershipVolumetryObservation(TeamMembershipCountLowerBound, Capped)` : le nom du champ et
  l'indicateur `Capped` empêchent tout consommateur (télémétrie incluse) de le lire comme un total
  exact — `Capped=true` signale explicitement que le vrai compte peut être supérieur à la borne.

Ce timer dépend uniquement d'une nouvelle interface étroite, `IOrganizationShadowObservationReader`
(exactement ces deux méthodes). Il ne reçoit ni `IOrganizationRepository` complet, ni
`IOrganizationOffboardingRecoveryWorker` : il lui est **structurellement impossible** — pas
seulement interdit par convention — d'appeler une méthode de création, remplacement ou suppression.
`IOrganizationRepository` étend cette interface, donc `CosmosOrganizationRepository` la satisfait
automatiquement ; aucun second type de repository n'est introduit.

Ce timer est un no-op strict tant que `Mode != Shadow` (donc en particulier en `Off`, la valeur par
défaut de tous les environnements).

`IOrganizationOffboardingRecoveryWorker` (le seul composant mutant lié à l'offboarding) **reste
totalement non câblé à un timer, dans tous les modes**, dans cette décision. Il demeure accessible
uniquement par les tests (unitaires + Cosmos-emulator opt-in), exactement comme depuis ADR-015.
Câbler son exécution réelle — décider quand/où purger en tâche de fond — est explicitement réservé
à un futur ADR `read`/`write`.

Note documentée sans correctif : `EnterpriseLearningRecoveryFunctions` (feature indépendante,
ADR-016) n'invoque ce même worker que si `ENTERPRISE_LEARNING_METRICS_V1 != off`, valeur que ce
flag ne peut jamais prendre aujourd'hui — ce chemin reste donc du code mort, avant et après cette
PR. Ce couplage n'est pas corrigé ici : le faire n'était pas nécessaire (aucune voie mutante n'est
de toute façon câblée par cette décision) et l'éviter réduit le risque et le périmètre du
changement. Une correction éventuelle accompagnera le futur ADR `read`/`write`.

### 4. Télémétrie sans PII

Un nouveau puits `IOrganizationTelemetry` / `ApplicationInsightsOrganizationTelemetry` (gabarit
strict de `IPersonLinkedIdentityTelemetry` / `ApplicationInsightsPersonLinkedIdentityTelemetry`)
enregistre des dimensions bornées uniquement : opération, résultat, RU Cosmos (`RequestCharge`),
un compte et l'indicateur `Capped` — jamais un id d'organisation, de personne, une équipe, un
e-mail ou un nom. Aucun champ de télémétrie ne transporte `organizationId`, brut ou haché ; si un
futur incrément avait besoin d'une dimension par tenant, elle devrait rester un hash borné et
non-réversible, jamais l'id brut. Deux catégories d'événements :

- **Observation live** (la seule à s'exécuter automatiquement en `shadow`) : RU et compte des deux
  requêtes de la section précédente.
- **Instrumentation additive sur les chemins mutants existants** (`CreateOrganizationAsync`,
  `CreateInvitationAsync`, `AcceptInvitationAsync`, `CreateTeamAsync`, `AddTeamMemberAsync`,
  `OffboardAsync`) : RU (`response.RequestCharge`, déjà calculé, capturé additivement sans changer
  le flux de contrôle) et conflits d'idempotence (`Created`/`Replayed`/`Conflict`, déjà distingués
  par `OrganizationCreateStatus`/`OrganizationIdempotencyConflictException` existants). **Ces
  chemins restent accessibles uniquement par les tests** (unitaires + Cosmos-emulator opt-in) :
  la surface HTTP qui les exposerait reste 404 dans tous les modes (point 2). Cette instrumentation
  pré-valide la plomberie de télémétrie avant une future activation `read`/`write`, sans jamais
  s'exécuter en tâche de fond.

### 5. Bicep

`@allowed` pour `organizationMembershipV1` passe de `['off']` à `['off', 'shadow']` dans
`functionApp.bicep` et `main.bicep` ; le défaut reste `'off'`. Un réglage
`ORGANIZATION_SHADOW_OBSERVATION_SCHEDULE` est ajouté en dur dans les appsettings (même patron que
`ENTERPRISE_LEARNING_RECOVERY_SCHEDULE`, qui est lui aussi codé en dur et non paramétré). Les trois
fichiers `infra/params/{dev,staging,prod}.bicepparam` ne sont pas modifiés : aucun ne surcharge
`organizationMembershipV1`, qui reste donc résolu à `off` dans les trois environnements. Aucune
ressource live n'est modifiée ou activée par cette PR.

> **Note correctrice — 2026-09-09 : cadence portée de `0 */5 * * * *` à `0 */15 * * * *`.**
> Les mentions « même cadence que le recovery Enterprise Learning Metrics » (§3) et le patron
> décrit ci-dessus restent exacts — les deux réglages bougent ensemble — mais la valeur n'est
> plus cinq minutes.
>
> **Motif.** Les deux timers sortent immédiatement (`off` partout), mais réveillent l'hôte
> Functions à chaque déclenchement. Mesuré le 2026-09-09 sur `func-certigo-dev` : 1 558
> démarrages d'hôte en 7 jours, contre 129 sur staging et 131 sur prod — deux environnements
> identiques dont le build déployé ne contient pas encore ces timers. La modale des écarts entre
> démarrages consécutifs vaut 300 s (n=375), soit exactement la cadence. Ces démarrages émettent
> environ 58 Ko de traces chacun et représentent 87,8 % de tout `AppTraces` sur dev, où ils
> masqueraient une véritable tempête de redémarrages. Le coût financier, lui, est négligeable et
> ne justifie rien : l'ingestion imputable vaut environ 0,4 Go/mois et le compute reste dans
> l'octroi gratuit du plan Flex Consumption.
>
> **Pourquoi quinze minutes et pas une heure.** Ces fonctions étant inertes, la cadence choisie
> aujourd'hui ne pourra être validée par aucune exécution réelle avant l'activation : la valeur
> retenue doit survivre à cet état futur plutôt qu'optimiser l'état présent. ADR-016 borne la
> cadence du recovery par un lease de claim de deux minutes et une expiration d'intent d'une
> heure ; quinze minutes laissent quatre tentatives de reprise dans cette fenêtre. Une cadence
> horaire tombe pile sur la borne d'expiration et une cadence quotidienne la dépasse : toutes
> deux casseraient la garantie de reprise sans erreur visible, et seulement une fois
> `ENTERPRISE_LEARNING_METRICS_V1` activé. Cette contrainte est désormais écrite à côté de la
> valeur dans `infra/modules/functionApp.bicep`, et non dans ce seul document.
>
> Aucun déclencheur ni aucune fonction n'est retiré ; aucun environnement n'est activé.

## Preuve — aucune donnée utilisateur créée, modifiée ou supprimée en `shadow`

1. **Structurelle** : `OrganizationShadowObservationFunctions` ne peut pas être compilé avec un
   appel à une méthode mutante — son constructeur ne connaît que
   `IOrganizationShadowObservationReader`, qui n'expose que deux méthodes de lecture. Le test dédié
   (`OrganizationShadowObservationFunctionsTests`) utilise un double qui n'implémente que cette
   interface : il n'existe littéralement aucune méthode de mutation à appeler par erreur.
2. `IOrganizationOffboardingRecoveryWorker` n'est référencé par aucun nouveau timer/Function de
   cette PR.
3. Tests paramétrés `off`/`shadow` prouvant le 404 avant authentification et avant accès service,
   pour chaque route Organization.
4. Tests unitaires du sink de télémétrie vérifiant l'ensemble exact des clés de dimensions (aucun
   id, e-mail ou nom).
5. Suite complète du backend verte (812 tests exécutés, 0 échec, 12 ignorés — les tests
   Cosmos-emulator opt-in, gated par `CERTIGO_COSMOS_TESTS=1`, jamais exécutés contre un compte
   Azure réel).
6. `bicep build`/`build-params` verts sur les trois fichiers de paramètres : aucun environnement ne
   bascule, `organizationMembershipV1` reste résolu à `off` partout.
7. Le seul chemin qui crée ou mute réellement des documents Cosmos Organization reste les tests
   d'intégration opt-in contre l'émulateur local éphémère — mécanisme inchangé depuis ADR-015.

## Conséquences et prochaine phase

Une activation `read` ou `write` — endpoints utilisateur réellement accessibles, câblage du
recovery worker mutant, décision sur le couplage `EnterpriseLearningRecoveryFunctions` — reste hors
périmètre et exigera son propre ADR et ses propres gates, comme le prévoyait déjà ADR-015. Aucun
environnement (dev/staging/prod) n'est activé sur `shadow` par cette décision ; l'activation réelle
reste une décision manuelle et séparée.
