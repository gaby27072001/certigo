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
et des environnements couverts. Les templates runner déclarent séparément les
valeurs CI non personnelles ; chaque valeur obligatoire est un paramètre Bicep
distinct, donc aucun appelant ne peut remplacer le contrat par un objet partiel.
Les templates effectuent une fusion additive : les tags supplémentaires sont
conservés et, en cas de collision, le contrat obligatoire prévaut :

```bicep
var effectiveTags = union(existingTags, requiredTags)
```

Les valeurs restent des paramètres des templates consommateurs. Elles ne doivent
contenir ni adresse personnelle, ni nom de personne, ni valeur temporaire telle
que `TBD`, `unknown`, `none` ou `n/a`.

## Périmètre et ordre d'intégration

La PR de normalisation doit rester isolée des brouillons qui modifient déjà les
points de composition :

1. #301 fournit désormais le contrat et le validateur FinOps en lecture seule ;
2. stabiliser #290 pour le stockage de contenu et #302 pour le moindre privilège
   (#296 et #303 sont déjà intégrés) ;
3. rebaser la PR de tags, puis résoudre uniquement les ajouts de paramètres ;
4. appliquer `union(existingTags, requiredTags)` dans `infra/main.bicep` avec
   `env` déjà existant et des paramètres non personnels pour `owner`, `product`,
   `managedBy` et `costCenter` ;
5. transmettre l'objet résultant aux modules applicatifs existants sans modifier
   leurs noms, SKU, réseau, identités ou attributions RBAC ;
6. appliquer le même contrat au point de composition de #290, sans ajouter de
   `tags` aux sous-ressources qui ne les prennent pas en charge ;
7. ajouter le test `infra/tests/azure-tag-contract.test.mjs` à `ci-infra.yml`
   seulement après consolidation des quatre PR qui modifient déjà ce workflow.

Les templates runner `network.bicep` et `runner.bicep` appliquent déjà ce contrat.
Les sous-réseaux, associations, diagnostics, attributions de rôles et autres
types sans propriété `tags` restent inchangés.

Le disque OS est créé implicitement par la VM et son nom live n'est pas déclaré
dans le template actuel. Il reste hors de cette première adoption : inventer ou
fixer son nom dans cette PR risquerait un remplacement. Après inventaire, une
étape séparée pourra appliquer uniquement `Microsoft.Resources/tags` à son ID
existant, sans redéclarer ni renommer le disque.

## Validation statique

Depuis la racine, avec les versions épinglées par la CI :

```bash
BICEP_BIN=bicep CHECKOV_BIN=checkov bash infra/validate-tags.sh
```

Le validateur compile les deux templates runner, vérifie la présence des cinq
tags, la conservation des tags de provenance et les invariants de nom/SKU, puis
exécute Checkov sur `infra`. Il ne contacte pas Azure.

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
