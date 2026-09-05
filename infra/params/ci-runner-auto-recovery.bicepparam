// Reprise automatique des runners CI. `alertEmail` n'est pas versionné : il est
// injecté au déploiement depuis la variable non secrète ALERT_EMAIL, comme pour
// les autres alertes du dépôt (voir infra/params/staging.bicepparam).
using '../ci-runner/auto-recovery.bicep'

param resourceGroupName = 'rg-certigo-ci'
param location = 'westeurope'

// Les trois instances exactes du VMSS Flexible désallouées chaque nuit.
// Toute instance ajoutée ici doit également figurer dans
// infra/ci-runner/capacity-controller.config.json, sans quoi le contrôleur de
// capacité la classe en `unclassifiedVirtualMachines` et bloque le plan.
param virtualMachineNames = [
  'vmss-certigo-runner-zonal_f55d176e'
  'vmss-certigo-runner-zonal_be505fa1'
  'vmss-certigo-pr-pilot-z1_bbf83c5c'
]

// 01:30 UTC : strictement après la fenêtre de teardown 00:46-00:49 UTC, avec
// ~41 minutes de marge pour ne pas courir contre elle.
param scheduleHourUtc = 1
param scheduleMinuteUtc = 30

param deployResourceGroupDeletionLock = true
