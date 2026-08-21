using '../governance/main.bicep'

param location = 'westeurope'
param identityResourceGroupName = 'rg-certigo-ci'
param contentResourceGroupName = 'rg-certigo-content'
param ciVnetName = 'vnet-certigo-ci'
param ciRunnerSubnetName = 'snet-runners'
param blobPrivateDnsZoneName = 'privatelink.blob.core.windows.net'
param githubRepositoryOwner = 'gchambaud_microsoft'
param githubRepositoryName = 'Certigo'
param contentRepositoryOwner = 'gchambaud_microsoft'
param contentRepositoryName = 'certigo-content'
param contentInfrastructurePlanIdentityName = 'id-certigo-content-infra-plan'
param contentInfrastructurePlanEnvironmentName = 'azure-content-infra-plan'
param privilegedAssignmentPolicyEffect = 'Audit'

// Subscription-wide security controls move here only during a separate,
// PIM-approved admin deployment. Existing assignments/plans remain live.
param manageMcsbPolicyAssignment = false
param manageDefenderPlans = false
param enableDefenderPlans = false
