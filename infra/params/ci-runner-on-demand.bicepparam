// Runners CI à la demande : réveil sur webhook `workflow_job` et désallocation des VM dont
// l'OS s'est arrêté. Aucune valeur secrète ici : l'URL signée du déclencheur n'est jamais
// versionnée (infra/ci-runner/register-wake-webhooks.ps1 la lit et la pose côté GitHub).
//
// Pools, labels de réveil, périodes calmes et plages GitHub : infra/ci-runner/on-demand.config.json.
// Dépôts et exclusions d'instances : infra/ci-runner/capacity-controller.config.json.
// Ne pas les redéclarer ici : une seconde copie pourrait diverger.
using '../ci-runner/on-demand.bicep'

param resourceGroupName = 'rg-certigo-ci'
param location = 'westeurope'
