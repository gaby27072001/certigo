# Adoption des tags Azure

Ce runbook décrit l'adoption progressive du contrat FinOps défini par la PR
[#301](https://github.com/gchambaud_microsoft/Certigo/pull/301). Il ne constitue
ni une autorisation de déploiement, ni une preuve d'état du live.

## Contrat

Chaque groupe de ressources et chaque ressource Azure compatible avec les tags
doit exposer cinq valeurs non vides :

| Tag | Valeur attendue |
| --- | --- |
| `owner` | équipe ou service non personnel, par exemple `certigo-platform` |
| `product` | `Certigo` |
| `env` | `ci`, `dev`, `staging` ou `prod` |
| `managedBy` | `bicep` |
| `costCenter` | identifiant d'allocation non personnel, par exemple `engineering` |

`infra/finops/scopes.json`, fusionné avec #301, reste la source canonique des clés
et des environnements couverts. Les templates applicatifs et runner déclarent des
valeurs non personnelles ; chaque valeur obligatoire est un paramètre Bicep
distinct ou, pour l'application, réutilise le paramètre `env` existant. Aucun
appelant ne peut remplacer le contrat par un objet partiel. Les templates
effectuent une fusion additive : les tags supplémentaires sont conservés et, en
cas de collision, le contrat obligatoire prévaut :

```bicep
var effectiveTags = union(existingTags, requiredTags)
```

Les valeurs restent des paramètres des templates consommateurs. Elles ne doivent
contenir ni adresse personnelle, ni nom de personne, ni valeur temporaire telle
que `TBD`, `unknown`, `none` ou `n/a`.

## Périmètre intégré

Après intégration de #302, `infra/main.bicep`, `network.bicep` et `runner.bicep`
appliquent le contrat sans modifier les noms, SKU, réseaux, identités ou
attributions RBAC. Les modules applicatifs reçoivent l'objet fusionné. Les
ressources du hub partagées dans `rg-certigo-ci` conservent `env=ci`, même
lorsqu'elles sont composées depuis staging ou production.

Les groupes de ressources restent `existing` dans le déploiement applicatif :
leurs tags relèvent du bootstrap administrateur, pas de l'identité de déploiement
au moindre privilège. Les sous-réseaux, associations, diagnostics, attributions
de rôles et autres types sans propriété `tags` restent inchangés.

Le disque OS est créé implicitement par la VM et son nom live n'est pas déclaré
dans le template actuel. Il reste hors de cette première adoption : inventer ou
fixer son nom dans cette PR risquerait un remplacement. Après inventaire, une
étape séparée pourra appliquer uniquement `Microsoft.Resources/tags` à son ID
existant, sans redéclarer ni renommer le disque.

## Validation statique

Depuis la racine, avec les versions épinglées par la CI :

```bash
BICEP_BIN=bicep bash infra/validate.sh
checkov --directory infra --framework bicep --compact --quiet \
  --config-file .checkov.yaml
```

Le validateur principal compile les templates et paramètres, puis vérifie la
présence des cinq tags dans les compositions applicative et runner, la
conservation des tags de provenance et les invariants de nom/SKU/RBAC. La gate
de sécurité exécute Checkov séparément sur `infra`. Aucun de ces contrôles ne
contacte Azure.

## Adoption live ultérieure

L'adoption live est une opération séparée, sous ticket de changement et après
fusion des dépendances. L'opérateur doit :

1. exécuter le validateur statique et le vérificateur en lecture seule de #301 ;
2. capturer l'inventaire actuel des tags pour ne perdre aucune clé métier ;
3. exécuter uniquement un `what-if` incrémentiel sur chaque périmètre ;
4. refuser toute proposition `Delete`, `Create` d'une ressource existante,
   remplacement, renommage, changement de SKU, réseau, identité ou RBAC ;
5. n'accepter que des mises à jour de la propriété `tags`, avec conservation des
   clés hors contrat ;
6. faire approuver explicitement le résultat avant toute commande de création.

Cette PR n'exécute aucun `what-if` ni déploiement live. Les commandes et critères
d'exploitation généraux restent dans
[`AZURE_IAC_OPERATIONS.md`](AZURE_IAC_OPERATIONS.md).

Références :

- [Utiliser les étiquettes pour organiser les ressources Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources)
- [Fonction d'objet `union` dans Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-object#union)
