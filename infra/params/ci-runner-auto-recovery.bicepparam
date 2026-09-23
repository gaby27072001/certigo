// Reprise automatique des runners CI. `alertEmail` n'est pas versionné : il est
// injecté au déploiement depuis la variable non secrète ALERT_EMAIL, comme pour
// les autres alertes du dépôt (voir infra/params/staging.bicepparam).
using '../ci-runner/auto-recovery.bicep'

param resourceGroupName = 'rg-certigo-ci'
param location = 'westeurope'

// Aucune liste d'instances ici, volontairement. Depuis le 2026-09-23 la reprise énumère à
// chaque run les instances des scale sets déclarés par défaut dans auto-recovery.bicep
// (`scaleSets`, unique exemplaire : ne pas le redéclarer ici) et exclut celles de
// `inventory.forbiddenVirtualMachines` et `inventory.externalVirtualMachines` de
// infra/ci-runner/capacity-controller.config.json.
//
// Pourquoi : du 2026-09-12 au 2026-09-23 la liste figée visait `bbf83c5c` et `a14700a3`
// (provisioningState Failed) et ignorait les quatre instances PR de remplacement créées le
// 2026-09-14 ; 12 runs consécutifs ont échoué et la CI PR restait éteinte chaque matin.
// Une instance remplacée ou ajoutée est désormais rallumée sans aucune modification ici ;
// seule une instance RETIRÉE doit être inscrite dans `forbiddenVirtualMachines`.

// 01:30 UTC : strictement après la fenêtre de teardown 00:46-00:49 UTC, avec
// ~41 minutes de marge pour ne pas courir contre elle.
param scheduleHourUtc = 1
param scheduleMinuteUtc = 30

param deployResourceGroupDeletionLock = true
