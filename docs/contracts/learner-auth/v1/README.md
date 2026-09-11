# Contrat Learner Authentication V1

**Version :** `1.0.0`

**Statut :** surface livree, conforme au code a la date de mesure ci-dessous.

Ce repertoire decrit les sept routes e-mail/mot de passe anonymes :

- `openapi.json` decrit les operations, les corps de requete et les invariants de
  confidentialite ;
- la garde vit dans
  `backend/tests/Certigo.Api.Tests/ApiSurfaceContractTests.cs`.

## Pourquoi un domaine separe

Ces routes sont les **seules** de l'API que `JwtAuthMiddleware` sert sans jeton porteur.
Elles portent donc une posture de securite differente de toute autre surface : un
`security: []` global plutot qu'un `bearerAuth`. Les melanger au parcours authentifie
obligerait a un document a deux postures, ou la valeur par defaut ne dirait plus rien.

Le decoupage suit la frontiere reelle, pas le decoupage des fichiers de fonctions :
`AuthFunctions.cs` contient exactement ces sept routes, et `JwtAuthMiddleware.AnonymousPaths`
en contient dix — les trois sondes `/health*` restent hors contrat, inscrites dans
`docs/contracts/deferred-routes.json`.

## Le piege que ce contrat documente

`AuthorizationLevel.Anonymous` apparait sur **toutes** les fonctions de cette API, y
compris celles qui exigent un jeton. Lire cet attribut pour deduire l'authentification
donne une reponse fausse pour environ neuf routes sur dix. La seule autorite est la liste
`AnonymousPaths` de `JwtAuthMiddleware`, et `ApiSurfaceContractTests` compare le contrat a
cette liste dans les deux sens.

## Invariants gardes

| Invariant | Ou il est verifie |
|---|---|
| Ces sept operations sont anonymes cote middleware | `ApiSurfaceContractTests.Contracted_anonymity_matches_the_authentication_middleware` |
| Aucune n'est absente du backend | `ApiSurfaceContractTests.Every_contracted_operation_exists_in_the_backend` |
| `resend-verification` et `request-password-reset` repondent a l'identique qu'un compte existe ou non | `x-certigo-privacy.accountEnumerationPossible: false` ; comportement dans `AuthFunctions.cs` |
| `login` ne distingue jamais e-mail inconnu et mot de passe faux | reponse `401` decrite sans corps discriminant |

## Formes de reponse

`verify-email` est suivie depuis un navigateur et rend du **HTML**, pas du JSON.
`reset-password` est appelee depuis le client mobile et rend du **JSON**. Cette asymetrie
est intentionnelle et fait partie du contrat.

## Mesure

Les sept operations correspondaient une a une aux routes declarees par
`AuthFunctions.cs` le **2026-09-11**, verifie par reflexion sur les attributs
`HttpTrigger` (et non par lecture de texte) dans `ApiSurfaceContractTests`.
