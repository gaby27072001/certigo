using '../governance/main.bicep'

param location = 'westeurope'
param identityResourceGroupName = 'rg-certigo-ci'
param githubRepositoryOwner = 'gchambaud_microsoft'
param githubRepositoryName = 'Certigo'
param privilegedAssignmentPolicyEffect = 'Audit'

// Subscription-wide security controls move here only during a separate,
// PIM-approved admin deployment. Existing assignments/plans remain live.
param manageMcsbPolicyAssignment = false
param manageDefenderPlans = false
param enableDefenderPlans = false
