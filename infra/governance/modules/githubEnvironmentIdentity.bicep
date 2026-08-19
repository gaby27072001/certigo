targetScope = 'resourceGroup'

@description('User-assigned managed identity name.')
param identityName string

@description('Azure region for the managed identity.')
param location string

@description('GitHub repository owner.')
param githubRepositoryOwner string

@description('GitHub repository name.')
param githubRepositoryName string

@description('Protected GitHub Environment used as the sole federated subject.')
param githubEnvironmentName string

param tags object = {}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

resource githubEnvironmentCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
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
output federatedSubject string = githubEnvironmentCredential.properties.subject
output principalId string = identity.properties.principalId
output resourceId string = identity.id
