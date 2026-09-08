# Connecteur Viva Learning - runbook NO-GO

> **Statut : feature `off`, contrats fixture-only, toute interaction tenant ou
> Microsoft 365 live est interdite.**

## Garde-fous actifs

- `VIVA_LEARNING_V1` est absent ou vaut `off`; toute autre valeur fait echouer le
  demarrage.
- Les endpoints sous
  `/api/v1/organizations/{organizationId}/integrations/viva-learning` renvoient
  `404` avant authentification et avant tout acces service.
- Aucun client Graph, credential, secret, identifiant de tenant ou domaine reel
  n'est configure.
- Le catalogue est charge depuis des fixtures JSON embarquees. Les seules URLs
  acceptees utilisent une origine HTTPS racine sous `.invalid`.
- Tant que le feature est `off`, `PUBLIC_WEB_ORIGIN` n'est pas consomme et
  l'origine forcee reste `https://links-disabled.invalid/`.
- Le mapper fixture rejette toute origine routable, HTTP, avec port, chemin,
  query ou fragment.

Configuration locale attendue :

```powershell
$env:VIVA_LEARNING_V1 = "off"
$env:PUBLIC_WEB_ORIGIN = "https://catalog.invalid/"
```

## Frontieres d'autorisation

| Operation | Identite abstraite | Permission contractuelle |
|---|---|---|
| Enregistrer le provider | administrateur delegue | `LearningProvider.ReadWrite` |
| Publier le catalogue | workload application | `LearningContent.ReadWrite.All` |
| Lire les assignations | utilisateur delegue | `LearningAssignedCourse.Read.All` |
| Synchroniser la progression | workload application | `LearningAssignedCourse.ReadWrite.All` |

Ces permissions sont des contrats de test, pas une instruction de consentement.
L'abstraction de consentement est scopee par `organizationId` et
`enterpriseTenantId`. Le cache ne manipule que des enveloppes chiffrees
(`keyId`, algorithme, ciphertext, nonce, tag, expiration). Les jetons delegues
sont en plus cloisonnes par un sujet d'entreprise opaque; les jetons application
n'ont aucun sujet utilisateur. Aucune implementation de stockage ni acquisition
de jeton n'est fournie.

## Isolation et donnees personnelles

- Le mapping `learningContent` derive un namespace stable et irreversible de
  l'organisation. Un meme contenu mappe dans deux organisations produit deux
  `externalId` differents.
- Les identifiants d'entreprise, consentements et jetons ne sont jamais relies
  par e-mail, nom ou `preferred_username`.
- Aucune donnee Viva ne rejoint `Person`, les acquis personnels, la mastery, la
  readiness, les recompenses ou la progression Certigo.
- Aucun endpoint n'accepte d'identite d'organisation ou de personne depuis un
  payload client.

## Conditions de sortie

Le verdict reste **NO-GO** tant qu'un lot distinct n'a pas apporte, avec revue
humaine et ADR :

1. un tenant non-production dedie et licencie;
2. la validation officielle des permissions exactes;
3. une implementation de consentement administrateur et de revocation;
4. un cache chiffre avec gestion et rotation de cles;
5. une origine publique controlee, prouvee et distincte des fixtures;
6. une politique de retention, audit et suppression des donnees entreprise;
7. des tests d'integration autorises et un protocole de nettoyage.

Aucune commande Azure, Microsoft 365, Graph, GitHub Actions ou de deploiement ne
fait partie de ce runbook.
