using '../governance/bootstrap-planning-identity.bicep'

param location = 'westeurope'
param identityResourceGroupName = 'rg-certigo-identities'
param identityName = 'id-certigo-governance-phase-b1a-plan'
param githubRepositoryOwner = 'gchambaud_microsoft'
param githubRepositoryName = 'Certigo'
param githubEnvironmentName = 'azure-governance-bootstrap-phase-b'
