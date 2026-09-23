// Reprise automatique des runners CI. `alertEmail` n'est pas versionné : il est
// injecté au déploiement depuis la variable non secrète ALERT_EMAIL, comme pour
// les autres alertes du dépôt (voir infra/params/staging.bicepparam).
using '../ci-runner/auto-recovery.bicep'

param resourceGroupName = 'rg-certigo-ci'
param location = 'westeurope'

// Les six instances exactes (2 trusted + 4 PR) désallouées chaque nuit.
// L'appartenance est bidirectionnelle et testée : chaque instance de
// `inventory.managedRunnerBindings` doit figurer ici, et réciproquement (voir
// « every managed runner is restarted after the nightly teardown » dans
// infra/tests/least-privilege.test.mjs). Une instance absente d'ici ne redémarre
// pas après le teardown ; une instance absente du contrôleur y est classée
// `unclassifiedVirtualMachines` et bloque le plan.
//
// 2026-09-23 : `bbf83c5c` et `a14700a3` (provisioningState Failed, runners 28/30
// désenregistrés) faisaient échouer chaque run depuis le 2026-09-12 pendant que les
// quatre runners PR réels restaient éteints. Ils sont désormais interdits dans
// `inventory.forbiddenVirtualMachines`, ce qui interdit aussi de les rallumer.
param virtualMachineNames = [
  'vmss-certigo-runner-zonal_f55d176e'
  'vmss-certigo-runner-zonal_be505fa1'
  'vmss-certigo-pr-pilot-z1_5275ea21'
  'vmss-certigo-pr-pilot-z1_94bad106'
  'vmss-certigo-pr-pilot-z1_1a6deaa2'
  'vmss-certigo-pr-pilot-z1_6e3abce4'
]

// 01:30 UTC : strictement après la fenêtre de teardown 00:46-00:49 UTC, avec
// ~41 minutes de marge pour ne pas courir contre elle.
param scheduleHourUtc = 1
param scheduleMinuteUtc = 30

param deployResourceGroupDeletionLock = true
