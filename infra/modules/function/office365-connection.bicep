// Office 365 API Connection for Logic Apps Standard
param location string = resourceGroup().location
param connectionName string
param logicAppPrincipalId string

// Create Office 365 connection using managed identity
// Note: The connection is created but OAuth consent may be required on first use
// CRITICAL: kind 'V2' is required for connectionRuntimeUrl to be available
resource office365Connection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: connectionName
  location: location
  kind: 'V2'
  properties: {
    displayName: 'Office 365 Connection'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
}

// Access Policy - grants Logic App access to the API connection
resource accessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: guid(office365Connection.id, logicAppPrincipalId)
  parent: office365Connection
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}

// Output connection details
output connectionId string = office365Connection.id
output connectionName string = office365Connection.name
// connectionRuntimeUrl is available with kind: 'V2' and API version 2018-07-01-preview
output connectionRuntimeUrl string = reference(office365Connection.id, '2018-07-01-preview', 'full').properties.connectionRuntimeUrl
