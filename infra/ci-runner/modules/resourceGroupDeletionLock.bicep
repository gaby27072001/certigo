// ============================================================================
// Certigo — verrou de suppression sur `rg-certigo-ci`
//
// POURQUOI. Plusieurs templates distincts ciblent ce resource group
// (`infra/ci-runner/network.bicep`, `runner.bicep`, `pilot.bicep`, le module
// `sharedPrivateDns.bicep` déployé par `infra/main.bicep`, et désormais
// `auto-recovery.bicep`). Un déploiement en **mode Complete** lancé depuis
// n'importe lequel d'entre eux supprimerait toute ressource absente de CE
// template — y compris les cinq zones DNS privées partagées, dont
// `privatelink.blob.core.windows.net`.
//
// CE QUE CELA PROTÈGE RÉELLEMENT — vérifié dans Azure, pas supposé :
//   * Les 4 enregistrements A de la zone blob pointent vers les comptes de
//     stockage `dev`, `staging`, `prod` **et** `content`. Détruire la zone
//     casse les quatre, pas seulement le contenu.
//   * L'enregistrement `stcertigocntz3wqbdww -> 10.42.1.5` est géré par Azure
//     via le `dnsZoneGroup` du private endpoint `pe-stcertigocntz3wqbdww-blob`,
//     lequel réside dans `rg-certigo-content` — donc HORS de portée d'un
//     déploiement Complete ciblant `rg-certigo-ci`. C'est bien la ZONE qui est
//     exposée, pas l'endpoint ni l'enregistrement pris isolément.
//   * Les instances `vmss-certigo-runner-zonal_be505fa1` et `_f55d176e`
//     portent des enregistrements de runner GitHub recréés à la main. Détruire
//     une instance perd son enregistrement et supprime le pool trusted.
//
// POURQUOI UN VERROU PLUTÔT QUE DE LA DOCUMENTATION. La règle « jamais de mode
// Complete ici » n'était portée que par un runbook. Un runbook *signale*, il
// n'*empêche* pas. `CanNotDelete` transforme une destruction silencieuse en
// échec de déploiement immédiat et lisible.
//
// EFFET DE BORD ASSUMÉ. Le verrou est hérité par les ressources enfants. La
// suppression du private endpoint de contenu, qui entraînerait la suppression
// de son enregistrement A dans la zone verrouillée, échouera tant que le
// verrou est en place. C'est le comportement recherché : une suppression
// délibérée doit passer par une levée délibérée du verrou.
// ============================================================================
targetScope = 'resourceGroup'

@description('Nom du verrou de suppression appliqué au resource group.')
@minLength(1)
param lockName string = 'certigo-ci-cannot-delete'

resource deletionLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: lockName
  properties: {
    level: 'CanNotDelete'
    notes: 'Protege les zones DNS privees partagees (dev/staging/prod/content) et les instances de runner trusted dont les enregistrements GitHub ont ete restaures manuellement. Un deploiement en mode Complete cible sur ce resource group les supprimerait. Lever ce verrou explicitement avant toute suppression voulue.'
  }
}

output lockId string = deletionLock.id
output lockName string = deletionLock.name
