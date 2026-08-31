# Politique de sécurité — Certigo

La sécurité de Certigo et de ses utilisateurs est une priorité. Ce document
explique comment signaler une vulnérabilité et ce que couvre notre périmètre.

## Signaler une vulnérabilité

**Merci de ne pas ouvrir d'issue publique pour un problème de sécurité.**

Privilégiez l'un de ces canaux privés :

1. **GitHub Security Advisories** — onglet *Security* du dépôt →
   *Report a vulnerability* (recommandé).
2. À défaut, contactez l'équipe en privé (e-mail de sécurité du projet).

Merci d'inclure, si possible :

- une description du problème et de son impact ;
- les étapes de reproduction (ou un PoC) ;
- les versions / composants concernés (mobile, API, infra) ;
- toute atténuation envisagée.

### Engagements de réponse (cible)

| Étape | Délai cible |
|---|---|
| Accusé de réception | 3 jours ouvrés |
| Évaluation initiale & sévérité | 7 jours ouvrés |
| Correctif ou plan d'atténuation | selon sévérité (critique : au plus vite) |

Nous suivons une **divulgation coordonnée** : merci de nous laisser un délai
raisonnable de correction avant toute publication.

## Périmètre

Composants concernés :

- **Mobile** — app Flutter (`apps/`, `packages/`).
- **API** — Azure Functions .NET 8 (`backend/`), authentification Entra.
- **Infrastructure** — templates Bicep (`infra/`).
- **Outillage de contenu** (`tools/`).

Exemples **dans** le périmètre : contournement d'authentification/autorisation,
fuite de données utilisateur, injection, falsification du score de quiz côté
serveur, exposition de secrets, élévation de privilèges.

Exemples **hors** périmètre : ingénierie sociale, déni de service volumétrique,
rapports automatisés sans impact démontré.

## Bonnes pratiques appliquées

- Authentification par **JWT Entra** validé côté API ; `userId` toujours issu du
  jeton, jamais du corps de requête.
- **Identités managées** pour l'accès à Cosmos DB et Key Vault — pas de secrets
  applicatifs en clair.
- Notation des quiz **autoritative côté serveur** (clé de correction non exposée).
- Releases de contenu lues depuis des versions Blob WORM par une identité
  `Storage Blob Data Reader`; aucune URL arbitraire ni package HTTP n'est accepté.
- Questions/corrigés séparés dans des containers Blob et Cosmos distincts.
  L'import valide tout le canal public contre une deny-list anti-fuite avant
  mutation et après projection.
- Import, promotion et rollback exigent l'app role Entra
  `Content.Release.Admin` et une précondition ETag; aucune Function key.
- Analyse continue bloquante sur runners Azure : **CodeQL** (SAST), **OSV**
  (dépendances NuGet/csproj, npm et pub), **Checkov** (IaC), et posture cloud via
  **Microsoft Defender for Cloud**. CodeQL transmet son SARIF à Code Scanning et
  publie aussi une synthèse locale ; OSV et Checkov publient leurs résultats
  structurés non secrets dans les logs immutables et le résumé du job, sans dépendre
  du quota d'artefacts. Les contrôleurs et configurations CodeQL, OSV, Checkov
  et project-state sont toujours exécutés depuis le SHA immuable de base, séparément
  des sources de PR analysées. Les scans pouvant interpréter les fichiers de la PR
  restent protégés par l'environnement `pr-ci`.
- `.github/dependabot.yml` propose uniquement des mises à jour de versions ; ce
  service n'est pas une gate de sécurité.

## Contenu de certification

Certigo n'est ni affilié ni approuvé par Microsoft et **ne reproduit aucun
contenu d'examen réel**. Tout signalement à ce sujet doit être adressé en privé.
