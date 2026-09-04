targetScope = 'subscription'

@description('Azure region for deployment identities and policy assignments.')
param location string = 'westeurope'

@description('Dedicated resource group created or adopted for governance identities.')
param identityResourceGroupName string = 'rg-certigo-identities'

@description('Existing resource group that owns shared CI networking.')
param ciResourceGroupName string = 'rg-certigo-ci'

@description('Dedicated resource group created or adopted for immutable content resources.')
param contentResourceGroupName string = 'rg-certigo-content'

@description('GitHub repository owner.')
param githubRepositoryOwner string = 'gchambaud_microsoft'

@description('GitHub repository name.')
param githubRepositoryName string = 'Certigo'

@description('GitHub repository owner for immutable content publication identities.')
param contentRepositoryOwner string = 'gchambaud_microsoft'

@description('GitHub repository for immutable content publication identities.')
param contentRepositoryName string = 'certigo-content'

@description('Dedicated managed identity used only by the content infrastructure planning workflow.')
param contentInfrastructurePlanIdentityName string = 'id-certigo-content-infra-plan'

@description('Protected GitHub Environment trusted by the content infrastructure planning identity.')
param contentInfrastructurePlanEnvironmentName string = 'azure-content-infra-plan'

@description('Application environments receiving isolated deployment identities.')
param environments array = [
  {
    name: 'dev'
    resourceGroupName: 'rg-certigo-dev'
  }
  {
    name: 'staging'
    resourceGroupName: 'rg-certigo-staging'
  }
  {
    name: 'prod'
    resourceGroupName: 'rg-certigo-prod'
  }
]

var identityTags = {
  product: 'Certigo'
  managedBy: 'bicep'
  purpose: 'github-oidc-deployment'
}

var contentTags = {
  product: 'Certigo'
  workload: 'immutable-content'
  managedBy: 'bicep'
}

var descriptorEnvironmentName = 'azure-content-release'
var publicEnvironmentName = 'azure-content-public'
var privateEnvironmentName = 'azure-content-answer-key'
var descriptorPublisherIdentityName = 'id-certigo-content-release'
var publicPublisherIdentityName = 'id-certigo-content-public'
var privatePublisherIdentityName = 'id-certigo-content-answer-key'
var readerIdentityName = 'id-certigo-content-reader'

var environmentResourceGroupIds = [
  for environment in environments: subscriptionResourceId(
    'Microsoft.Resources/resourceGroups',
    environment.resourceGroupName
  )
]

var privilegedRoleDefinitionIds = [
  subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
  )
  subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  )
  subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator
  )
  subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168' // Role Based Access Control Administrator
  )
]

resource contentResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: contentResourceGroupName
  location: location
  tags: contentTags
}

resource identityResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: identityResourceGroupName
  location: location
  tags: identityTags
}

resource subscriptionDeploymentLauncher 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-subscription-deployment-launcher')
  properties: {
    roleName: 'Certigo Subscription Deployment Launcher ${take(uniqueString(subscription().id), 6)}'
    description: 'Runs subscription what-if/deployments and reads exact governance evidence inputs; cannot manage resources or RBAC.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/deployments/read'
          'Microsoft.Resources/deployments/operations/read'
          'Microsoft.Resources/deployments/write'
          'Microsoft.Resources/deployments/validate/action'
          'Microsoft.Resources/deployments/whatIf/action'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Authorization/policyAssignments/read'
          'Microsoft.Authorization/policyDefinitions/read'
          'Microsoft.Authorization/roleAssignments/read'
          'Microsoft.Authorization/roleDefinitions/read'
          'Microsoft.ManagedIdentity/userAssignedIdentities/read'
          'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource runtimeRoleAssignmentWriter 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-runtime-role-assignment-writer')
  properties: {
    roleName: 'Certigo Runtime Role Assignment Writer ${take(uniqueString(subscription().id), 6)}'
    description: 'Creates role assignments without delete; each assignment adds a condition that limits role definitions and principal type.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Authorization/roleAssignments/read'
          'Microsoft.Authorization/roleAssignments/write'
          'Microsoft.Authorization/roleDefinitions/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: environmentResourceGroupIds
  }
}

resource sharedNetworkDeploymentRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-shared-network-deployment')
  properties: {
    roleName: 'Certigo Shared Network Deployment ${take(uniqueString(subscription().id), 6)}'
    description: 'Updates only shared private DNS and VNet peerings; has no Compute, Key Vault, or general Contributor actions.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/deployments/read'
          'Microsoft.Resources/deployments/write'
          'Microsoft.Resources/deployments/validate/action'
          'Microsoft.Resources/deployments/whatIf/action'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read'
          'Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write'
          'Microsoft.Network/privateDnsZones/read'
          'Microsoft.Network/privateDnsZones/write'
          'Microsoft.Network/privateDnsZones/join/action'
          'Microsoft.Network/privateDnsZones/virtualNetworkLinks/read'
          'Microsoft.Network/privateDnsZones/virtualNetworkLinks/write'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscriptionResourceId('Microsoft.Resources/resourceGroups', ciResourceGroupName)
    ]
  }
}

resource contentPublisherRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: 'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de'
  properties: {
    roleName: 'Certigo Immutable Content Publisher ${take(uniqueString(subscription().id), 6)}'
    description: 'Creates and verifies immutable content blobs without delete or immutability-policy mutation.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read'
        ]
        notActions: []
        // Create-and-verify only. `blobs/write` cannot overwrite because the
        // publisher always uploads with `--overwrite false` onto containers that
        // have version-level immutability enabled. `blobs/delete` is deliberately
        // absent so a publisher can never remove or truncate a published release.
        dataActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'
        ]
        notDataActions: []
      }
    ]
    assignableScopes: [
      contentResourceGroup.id
    ]
  }
}

resource contentInfrastructurePlanExecutorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-content-infrastructure-plan-executor')
  properties: {
    roleName: 'Certigo Content Infrastructure Plan Executor ${take(uniqueString(subscription().id), 6)}'
    description: 'Runs resource-group what-if for the dedicated content stack without delete, resource-group, or role-definition permissions.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/deployments/read'
          'Microsoft.Resources/deployments/write'
          'Microsoft.Resources/deployments/validate/action'
          'Microsoft.Resources/deployments/whatIf/action'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.Storage/storageAccounts/write'
          'Microsoft.Storage/storageAccounts/blobServices/read'
          'Microsoft.Storage/storageAccounts/blobServices/write'
          'Microsoft.Storage/storageAccounts/blobServices/containers/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/write'
          'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/write'
          'Microsoft.Storage/storageAccounts/managementPolicies/read'
          'Microsoft.Storage/storageAccounts/managementPolicies/write'
          'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action'
          'Microsoft.ManagedIdentity/userAssignedIdentities/read'
          'Microsoft.Network/privateEndpoints/read'
          'Microsoft.Network/privateEndpoints/write'
          'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read'
          'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write'
          'Microsoft.Authorization/roleAssignments/read'
          'Microsoft.Authorization/roleAssignments/write'
          'Microsoft.Authorization/roleDefinitions/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      contentResourceGroup.id
    ]
  }
}

resource contentInfrastructurePlanExternalJoinRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-content-infrastructure-plan-external-join')
  properties: {
    roleName: 'Certigo Content Infrastructure Plan External Join ${take(uniqueString(subscription().id), 6)}'
    description: 'Reads and joins only the exact trusted subnet and private DNS zone through resource-scoped assignments.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Network/virtualNetworks/subnets/join/action'
          'Microsoft.Network/privateDnsZones/read'
          'Microsoft.Network/privateDnsZones/join/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscriptionResourceId('Microsoft.Resources/resourceGroups', ciResourceGroupName)
    ]
  }
}

module deploymentIdentities 'modules/githubEnvironmentIdentity.bicep' = [
  for environment in environments: {
    scope: identityResourceGroup
    name: 'identity-${environment.name}'
    params: {
      githubEnvironmentName: environment.name
      githubRepositoryName: githubRepositoryName
      githubRepositoryOwner: githubRepositoryOwner
      identityName: 'id-certigo-deploy-${environment.name}'
      location: location
      tags: union(identityTags, {
        environment: environment.name
      })
    }
  }
]

module contentInfrastructurePlanIdentity 'modules/githubEnvironmentIdentity.bicep' = {
  scope: identityResourceGroup
  name: 'identity-content-infra-plan'
  params: {
    githubEnvironmentName: contentInfrastructurePlanEnvironmentName
    githubRepositoryName: githubRepositoryName
    githubRepositoryOwner: githubRepositoryOwner
    identityName: contentInfrastructurePlanIdentityName
    location: location
    tags: union(identityTags, {
      purpose: 'content-infrastructure-plan'
    })
  }
}

module descriptorPublisherIdentity '../modules/contentIdentity.bicep' = {
  scope: identityResourceGroup
  name: 'content-release-publisher-identity'
  params: {
    githubEnvironmentName: descriptorEnvironmentName
    githubRepositoryName: contentRepositoryName
    githubRepositoryOwner: contentRepositoryOwner
    identityName: descriptorPublisherIdentityName
    location: location
    tags: contentTags
  }
}

module publicPublisherIdentity '../modules/contentIdentity.bicep' = {
  scope: identityResourceGroup
  name: 'content-public-publisher-identity'
  params: {
    githubEnvironmentName: publicEnvironmentName
    githubRepositoryName: contentRepositoryName
    githubRepositoryOwner: contentRepositoryOwner
    identityName: publicPublisherIdentityName
    location: location
    tags: contentTags
  }
}

module privatePublisherIdentity '../modules/contentIdentity.bicep' = {
  scope: identityResourceGroup
  name: 'content-private-publisher-identity'
  params: {
    githubEnvironmentName: privateEnvironmentName
    githubRepositoryName: contentRepositoryName
    githubRepositoryOwner: contentRepositoryOwner
    identityName: privatePublisherIdentityName
    location: location
    tags: contentTags
  }
}

module contentReaderIdentity '../modules/contentReaderIdentity.bicep' = {
  scope: identityResourceGroup
  name: 'content-reader-identity'
  params: {
    identityName: readerIdentityName
    location: location
    tags: contentTags
  }
}

resource privilegedCiAssignmentPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: guid(subscription().id, 'certigo-privileged-ci-role-assignments')
  properties: {
    description: 'Audits or denies subscription-scoped privileged built-in roles assigned to service principals.'
    displayName: 'Certigo: restrict privileged CI role assignments at subscription scope'
    metadata: {
      category: 'Authorization'
      version: '1.0.0'
    }
    mode: 'All'
    parameters: {
      effect: {
        type: 'String'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
        metadata: {
          displayName: 'Effect'
          description: 'Keep Audit until historical assignments are removed and exemptions are approved.'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Authorization/roleAssignments'
          }
          {
            field: 'Microsoft.Authorization/roleAssignments/principalType'
            equals: 'ServicePrincipal'
          }
          {
            field: 'Microsoft.Authorization/roleAssignments/scope'
            equals: subscription().id
          }
          {
            field: 'Microsoft.Authorization/roleAssignments/roleDefinitionId'
            in: privilegedRoleDefinitionIds
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
    policyType: 'Custom'
  }
}

output phaseA object = {
  schemaVersion: 2
  subscriptionId: subscription().subscriptionId
  tenantId: tenant().tenantId
  contentResourceGroupId: contentResourceGroup.id
  identityResourceGroupId: identityResourceGroup.id
  identities: {
    contentAnswerKey: {
      clientId: privatePublisherIdentity.outputs.clientId
      name: privatePublisherIdentityName
      principalId: privatePublisherIdentity.outputs.principalId
      resourceId: privatePublisherIdentity.outputs.resourceId
    }
    contentInfrastructurePlan: {
      clientId: contentInfrastructurePlanIdentity.outputs.clientId
      federatedSubject: contentInfrastructurePlanIdentity.outputs.federatedSubject
      name: contentInfrastructurePlanIdentityName
      principalId: contentInfrastructurePlanIdentity.outputs.principalId
      resourceId: contentInfrastructurePlanIdentity.outputs.resourceId
    }
    contentPublic: {
      clientId: publicPublisherIdentity.outputs.clientId
      name: publicPublisherIdentityName
      principalId: publicPublisherIdentity.outputs.principalId
      resourceId: publicPublisherIdentity.outputs.resourceId
    }
    contentReader: {
      clientId: contentReaderIdentity.outputs.clientId
      name: readerIdentityName
      principalId: contentReaderIdentity.outputs.principalId
      resourceId: contentReaderIdentity.outputs.resourceId
    }
    contentRelease: {
      clientId: descriptorPublisherIdentity.outputs.clientId
      name: descriptorPublisherIdentityName
      principalId: descriptorPublisherIdentity.outputs.principalId
      resourceId: descriptorPublisherIdentity.outputs.resourceId
    }
    deployDev: {
      clientId: deploymentIdentities[0].outputs.clientId
      federatedSubject: deploymentIdentities[0].outputs.federatedSubject
      name: 'id-certigo-deploy-dev'
      principalId: deploymentIdentities[0].outputs.principalId
      resourceId: deploymentIdentities[0].outputs.resourceId
    }
    deployProd: {
      clientId: deploymentIdentities[2].outputs.clientId
      federatedSubject: deploymentIdentities[2].outputs.federatedSubject
      name: 'id-certigo-deploy-prod'
      principalId: deploymentIdentities[2].outputs.principalId
      resourceId: deploymentIdentities[2].outputs.resourceId
    }
    deployStaging: {
      clientId: deploymentIdentities[1].outputs.clientId
      federatedSubject: deploymentIdentities[1].outputs.federatedSubject
      name: 'id-certigo-deploy-staging'
      principalId: deploymentIdentities[1].outputs.principalId
      resourceId: deploymentIdentities[1].outputs.resourceId
    }
  }
  policyDefinitionId: privilegedCiAssignmentPolicy.id
  roleDefinitionIds: {
    contentInfrastructurePlanExecutor: contentInfrastructurePlanExecutorRole.id
    contentInfrastructurePlanExternalJoin: contentInfrastructurePlanExternalJoinRole.id
    contentPublisher: contentPublisherRole.id
    runtimeRoleAssignmentWriter: runtimeRoleAssignmentWriter.id
    sharedNetworkDeployment: sharedNetworkDeploymentRole.id
    subscriptionDeploymentLauncher: subscriptionDeploymentLauncher.id
  }
}
