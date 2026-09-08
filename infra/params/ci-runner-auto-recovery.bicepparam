// Reprise automatique des runners CI. `alertEmail` n'est pas versionné : il est
// injecté au déploiement depuis la variable non secrète ALERT_EMAIL, comme pour
// les autres alertes du dépôt (voir infra/params/staging.bicepparam).
using '../ci-runner/auto-recovery.bicep'

param resourceGroupName = 'rg-certigo-ci'
param location = 'westeurope'

// Les quatre instances exactes du VMSS Flexible désallouées chaque nuit.
// L'appartenance est bidirectionnelle et testée : chaque instance de
// `inventory.managedRunnerBindings` doit figurer ici, et réciproquement (voir
// « every managed runner is restarted after the nightly teardown » dans
// infra/tests/least-privilege.test.mjs). Une instance absente d'ici ne redémarre
// pas après le teardown ; une instance absente du contrôleur y est classée
// `unclassifiedVirtualMachines` et bloque le plan.
param virtualMachineNames = [
  'vmss-certigo-runner-zonal_f55d176e'
  'vmss-certigo-runner-zonal_be505fa1'
  'vmss-certigo-pr-pilot-z1_bbf83c5c'
  'vmss-certigo-pr-pilot-z1_a14700a3'
]

// 01:30 UTC : strictement après la fenêtre de teardown 00:46-00:49 UTC, avec
// ~41 minutes de marge pour ne pas courir contre elle.
param scheduleHourUtc = 1
param scheduleMinuteUtc = 30

param deployResourceGroupDeletionLock = true
