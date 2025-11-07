# Post-deployment script to add Playwright connection to AI Foundry
# Uses Entra ID authentication (no manual tokens required)
#
# Prerequisites:
# - Azure CLI logged in
# - Contributor/Owner role on Playwright workspace (already assigned in Bicep)
# - AI Foundry hub and Playwright workspace deployed

Write-Host "Adding Playwright connection to AI Foundry..." -ForegroundColor Cyan

# Get parameters from environment or azd
$resourceGroup = if ($env:AZURE_RESOURCE_GROUP_NAME) { $env:AZURE_RESOURCE_GROUP_NAME } else { azd env get-value AZURE_RESOURCE_GROUP_NAME }
$subscriptionId = if ($env:AZURE_SUBSCRIPTION_ID) { $env:AZURE_SUBSCRIPTION_ID } else { az account show --query id -o tsv }
$location = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { azd env get-value AZURE_LOCATION }

# Get AI Foundry hub name
$aiFoundryName = az cognitiveservices account list `
  --resource-group $resourceGroup `
  --query "[?kind=='AIServices'].name | [0]" `
  --output tsv

if ([string]::IsNullOrEmpty($aiFoundryName)) {
  Write-Error "AI Foundry hub not found in resource group $resourceGroup"
  exit 1
}

Write-Host "Found AI Foundry hub: $aiFoundryName" -ForegroundColor Green

# Get Playwright workspace details
$playwrightWorkspace = az resource list `
  --resource-group $resourceGroup `
  --resource-type "Microsoft.LoadTestService/playwrightWorkspaces" `
  --query "[0]" `
  --output json | ConvertFrom-Json

if ($null -eq $playwrightWorkspace) {
  Write-Error "Playwright workspace not found in resource group $resourceGroup"
  exit 1
}

$playwrightWorkspaceName = $playwrightWorkspace.name
$playwrightWorkspaceId = $playwrightWorkspace.id
$playwrightLocation = $playwrightWorkspace.location

Write-Host "Found Playwright workspace: $playwrightWorkspaceName in $playwrightLocation" -ForegroundColor Green

# Construct workspace endpoint
$playwrightEndpoint = "wss://$playwrightLocation.api.playwright.microsoft.com/playwrightworkspaces/$playwrightWorkspaceName/browsers"

Write-Host "Playwright endpoint: $playwrightEndpoint"

# Get Entra ID access token
Write-Host "Getting Entra ID access token..."
$accessToken = az account get-access-token --resource https://management.azure.com --query accessToken -o tsv

# Create connection using REST API
Write-Host "Creating Playwright connection in AI Foundry..."

$connectionApiUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/$aiFoundryName/connections/Playwright?api-version=2025-04-01-preview"

$connectionPayload = @{
  properties = @{
    category = "Serverless"
    target = $playwrightEndpoint
    authType = "ApiKey"
    isSharedToAll = $true
    credentials = @{
      key = $accessToken
    }
    metadata = @{
      Type = "Playwright"
      ApiType = "Azure"
      ApiVersion = "2024-07-01-preview"
      ResourceId = $playwrightWorkspaceId
    }
  }
} | ConvertTo-Json -Depth 10

# Make REST API call
$headers = @{
  "Authorization" = "Bearer $accessToken"
  "Content-Type" = "application/json"
}

try {
  $response = Invoke-RestMethod -Method Put -Uri $connectionApiUrl -Headers $headers -Body $connectionPayload

  Write-Host "✓ Playwright connection created successfully!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Connection details:"
  Write-Host "  Name: Playwright"
  Write-Host "  Target: $playwrightEndpoint"
  Write-Host "  Auth: Entra ID (via access token)"
  Write-Host "  Workspace: $playwrightWorkspaceName"
}
catch {
  Write-Error "Failed to create Playwright connection: $_"
  Write-Error $_.Exception.Response
  exit 1
}
