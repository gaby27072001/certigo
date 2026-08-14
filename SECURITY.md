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
- Analyse continue bloquante sur runners Azure : **CodeQL** (SAST), **OSV** et
  **NuGet** (dépendances), **Checkov** (IaC), et posture cloud via
  **Microsoft Defender for Cloud**. Les SARIF/logs sont conservés comme artefacts.
- `.github/dependabot.yml` propose uniquement des mises à jour de versions ; ce
  service n'est pas une gate de sécurité.

## Contenu de certification

Certigo n'est ni affilié ni approuvé par Microsoft et **ne reproduit aucun
contenu d'examen réel**. Tout signalement à ce sujet doit être adressé en privé.
