// Office 365 API Connection for Logic Apps Standard
param location string = resourceGroup().location
param connectionName string
param managedIdentityId string

// Office 365 Outlook managed API reference
resource office365ManagedApi 'Microsoft.Web/locations/managedApis@2016-06-01' existing = {
  name: '${location}/office365'
}

// Create Office 365 connection using managed identity
resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: connectionName
  location: location
  kind: 'V2'
  properties: {
    displayName: 'Office 365 Connection'
    api: {
      id: office365ManagedApi.id
    }
    parameterValueType: 'Alternative'
    alternativeParameterValues: {}
    customParameterValues: {}
  }
}

// Output connection details
output connectionId string = office365Connection.id
output connectionName string = office365Connection.name
output connectionRuntimeUrl string = office365Connection.properties.connectionRuntimeUrl
