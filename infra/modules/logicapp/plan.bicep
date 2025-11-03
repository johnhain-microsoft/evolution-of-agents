@description('The location used for all deployed resources')
param location string

@description('Tags that will be applied to all resources')
param tags object = {}

param name string

@description('Log Analytics workspace Resource ID')
param logAnalyticsWorkspaceResourceId string

// Logic App Plan
module logicappplan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'logicappplan'
  params: {
    name: name
    location: location
    skuName: 'WS1'
    kind: 'elastic'
    skuCapacity: 1
    reserved: false
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceResourceId
      }
    ]
    
  }
}

// Outputs for use by other modules
@description('Service Bus Name')
output logicAppPlanName string = logicappplan.outputs.name

@description('Service Bus Resource ID')
output logicAppPlanResourceId string = logicappplan.outputs.resourceId
