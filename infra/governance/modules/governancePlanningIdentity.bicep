targetScope = 'resourceGroup'

param identityName string
param location string
param githubRepositoryOwner string
param githubRepositoryName string
param githubEnvironmentName string
param tags object

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

resource credential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  parent: identity
  name: 'github-${githubEnvironmentName}'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubRepositoryOwner}/${githubRepositoryName}:environment:${githubEnvironmentName}'
  }
}

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
output resourceId string = identity.id
output subject string = credential.properties.subject
