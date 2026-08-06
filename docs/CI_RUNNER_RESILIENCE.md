# Résilience des runners GitHub Actions

## Objectif et architecture

Les workflows Linux ciblent un **pool** et jamais une machine précise. Par défaut, le
pool est sélectionné avec les labels :

```json
["self-hosted", "Linux", "X64", "certigo-ci"]
```

Au moins deux runners en ligne doivent partager ces labels. GitHub Actions attribue
alors chaque job à n'importe quelle instance disponible : l'arrêt d'une VM ne bloque
plus la CI. Les protections existantes restent inchangées :

- les PR de fork ne peuvent pas exécuter de code sur les runners persistants ;
- les PR internes restent soumises à l'environnement `pr-ci` ;
- les déploiements et releases conservent leurs environnements (`dev`, `staging`,
  `prod`, `beta`, `github-pages`) et leurs approbations ;
- le chemin hébergé par GitHub est désactivé par défaut conformément à la politique EMU.

## Variables du dépôt

Configurer dans **Settings > Secrets and variables > Actions > Variables** :

| Variable | Valeur normale | Usage |
|---|---|---|
| `MAIN_CRITICAL_RUNNER_LABELS` | `["self-hosted","Linux","X64","certigo-ci"]` | Push `main`, schedules, déploiements et releases |
| `PR_RUNNER_LABELS` | `["self-hosted","Linux","X64","certigo-ci"]` | PR internes |
| `CI_GITHUB_HOSTED_FALLBACK` | `false` | Repli d'urgence global, seulement après exception EMU |

`BACKEND_CI_FALLBACK` reste reconnu par `ci-backend` et `ci-cortex-parity` pour
compatibilité. Il doit être retiré après migration vers `CI_GITHUB_HOSTED_FALLBACK`.

La release Android reste volontairement sur le pool self-hosted redondé. Elle peut
utiliser l'identité managée Azure du runner pour lire Key Vault, capacité absente d'un
runner GitHub-hosted.

## Actions d'infrastructure externes

Ces opérations modifient Azure ou GitHub et ne peuvent pas être prouvées par un commit :

1. Inventorier les runners et les VM :

   ```bash
   az vm list -g rg-certigo-ci -o table
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | {name,status,busy,labels:[.labels[].name]}'
   ```

2. Provisionner au moins une seconde VM, un VMSS ou un Runner Scale Set ARC dans
   `snet-runners`. Chaque instance doit avoir l'accès NAT décrit dans
   `infra/ci-runner/README.md`.
3. Installer les prérequis des workflows, enregistrer chaque runner avec le label
   commun `certigo-ci`, et attribuer la même identité managée lorsque le runner doit
   exécuter `release-android`.
4. Vérifier qu'au moins deux runners en ligne partagent tous les labels du pool :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '[.runners[] | select(.status == "online") | select(any(.labels[]; .name == "certigo-ci"))] | length'
   ```

   La valeur attendue est `2` ou plus.

Conserver comme preuve la sortie des deux inventaires, les noms des runners, leurs
labels, la date et l'URL du drill décrit ci-dessous.

## Drill de perte d'un runner

Le workflow manuel `Runner resilience drill` ne checkout aucun code et ne lit aucun
secret. Pour prouver le failover self-hosted :

1. Relever les deux runners en ligne.
2. Arrêter ou désactiver un seul runner et noter son nom exact.
3. Déclencher le workflow :

   ```bash
   gh workflow run runner-resilience-drill.yml \
     -f mode=self-hosted-failover \
     -f expected_offline_runner=<RUNNER_ARRETE>
   ```

4. Vérifier que le job termine sur un autre runner :

   ```bash
   gh run list --workflow runner-resilience-drill.yml --limit 1
   gh run watch <RUN_ID>
   ```

5. Réactiver le runner arrêté et confirmer que les deux instances sont `online`.

Le drill échoue si le runner exécutant porte le nom déclaré indisponible ou si le job
n'est pas exécuté sur un runner self-hosted. L'attente en file n'est pas limitée par
`timeout-minutes` ; l'absence de démarrage reste donc une preuve opérationnelle d'un
pool insuffisant et doit être interrompue manuellement.

## Repli hébergé et contrainte EMU

Ne jamais positionner `CI_GITHUB_HOSTED_FALLBACK=true` tant que l'organisation EMU
interdit les runners GitHub-hosted. Une fois une exception explicite accordée :

1. lancer `Runner resilience drill` avec `mode=github-hosted-break-glass` ;
2. vérifier que le résumé indique `Environment = github-hosted` ;
3. positionner `CI_GITHUB_HOSTED_FALLBACK=true` uniquement pendant l'incident ;
4. relancer les workflows critiques ;
5. remettre la variable à `false` dès que le pool self-hosted est rétabli.

Le fork-guard et les environments restent évalués même en mode hébergé. Si aucune
exception EMU n'est accordée, le second runner self-hosted est le seul mécanisme de
failover supporté.

## Rollback

Remettre `CI_GITHUB_HOSTED_FALLBACK=false`, restaurer les deux variables de labels avec
le JSON par défaut, puis réactiver les runners. Ne supprimer une VM ou un enregistrement
GitHub qu'après avoir confirmé qu'au moins deux autres runners compatibles sont en ligne.
