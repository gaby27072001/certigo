// ============================================================================
// Azure Communication Services — Email (transactional).
// Provisions an Email Communication Service with an Azure-managed domain and a
// linked Communication Services resource, so the backend can send the
// email-verification message. Outputs the endpoint, a ready-to-use sender
// address (DoNotReply@<azure-managed-domain>), and a connection string.
//
// NOTE: not wired for automatic sending until the Function App consumes the
// outputs (main.bicep passes them as app settings). ACS resources are global.
// For a branded sender, switch the domain to CustomerManaged and verify DNS.
// ============================================================================

@description('Base name used to derive the ACS resource names. Lowercase, no spaces.')
param name string

@description('Data residency for the Communication + Email services (e.g. Europe, United States).')
param dataLocation string = 'Europe'

param tags object = {}

// Email Communication Service — holds the sending domain(s).
resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: 'acsemail-${name}'
  location: 'global'
  tags: tags
  properties: {
    dataLocation: dataLocation
  }
}

// Azure-managed sending domain (no DNS setup required). Provides a domain of the
// form <guid>.azurecomm.net and the default DoNotReply mailbox. The resource name
// MUST be exactly 'AzureManagedDomain' for domainManagement = 'AzureManaged'.
resource managedDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: 'AzureManagedDomain'
  location: 'global'
  tags: tags
  properties: {
    domainManagement: 'AzureManaged'
    userEngagementTracking: 'Disabled'
  }
}

// Communication Services resource that actually sends, linked to the domain above.
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: 'acs-${name}'
  location: 'global'
  tags: tags
  properties: {
    dataLocation: dataLocation
    linkedDomains: [
      managedDomain.id
    ]
  }
}

@description('Data-plane endpoint of the Communication Services resource.')
output endpoint string = 'https://${communicationService.properties.hostName}'

@description('Default no-reply sender address on the Azure-managed domain.')
output senderAddress string = 'DoNotReply@${managedDomain.properties.fromSenderDomain}'

@description('Primary connection string (used when managed-identity email is not configured).')
@secure()
output connectionString string = communicationService.listKeys().primaryConnectionString

@description('Communication Services resource name (for optional role assignments).')
output communicationServiceName string = communicationService.name
