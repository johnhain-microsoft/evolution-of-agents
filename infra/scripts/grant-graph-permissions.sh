#!/bin/bash
# Post-deployment script to grant Microsoft Graph API permissions to Logic App
# Grants Calendars.Read and Calendars.ReadWrite permissions to system-assigned managed identity
#
# Prerequisites:
# - Azure CLI logged in with permissions to grant API permissions
# - Logic App deployed with system-assigned managed identity

set -e

echo "Granting Microsoft Graph API permissions to Logic App..."

# Get Logic App details from environment
RESOURCE_GROUP="${LOGIC_APP_RESOURCE_GROUP:-$(azd env get-value LOGIC_APP_RESOURCE_GROUP)}"
LOGIC_APP_NAME="${LOGIC_APP_NAME:-$(azd env get-value LOGIC_APP_NAME)}"

if [ -z "$LOGIC_APP_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo "Error: Logic App name or resource group not found in environment"
    exit 1
fi

echo "Logic App: $LOGIC_APP_NAME in $RESOURCE_GROUP"

# Get Logic App's system-assigned managed identity principal ID
PRINCIPAL_ID=$(az functionapp identity show \
    --name "$LOGIC_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query principalId \
    --output tsv)

if [ -z "$PRINCIPAL_ID" ]; then
    echo "Error: Failed to get Logic App managed identity principal ID"
    exit 1
fi

echo "Logic App Principal ID: $PRINCIPAL_ID"

# Microsoft Graph Service Principal ID (well-known)
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"

# Graph API Permission IDs
CALENDARS_READ_ID="798ee544-9d2d-430c-a058-570e29e34338"       # Calendars.Read
CALENDARS_READ_WRITE_ID="ef54d2bf-783f-4e0f-bca1-3210c0444d99" # Calendars.ReadWrite

echo "Granting Calendars.Read and Calendars.ReadWrite permissions..."

# Get Graph service principal object ID
GRAPH_SP_ID=$(az ad sp list --filter "appId eq '$GRAPH_APP_ID'" --query "[0].id" --output tsv)

if [ -z "$GRAPH_SP_ID" ]; then
    echo "Error: Failed to get Microsoft Graph service principal ID"
    exit 1
fi

# Grant Calendars.Read permission
if az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$GRAPH_SP_ID/appRoleAssignedTo" \
    --body "{\"principalId\":\"$PRINCIPAL_ID\",\"resourceId\":\"$GRAPH_SP_ID\",\"appRoleId\":\"$CALENDARS_READ_ID\"}" \
    --headers "Content-Type=application/json" > /dev/null 2>&1; then
    echo "✓ Granted Calendars.Read permission"
else
    echo "Warning: Calendars.Read permission may already be assigned or failed to grant"
fi

# Grant Calendars.ReadWrite permission
if az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$GRAPH_SP_ID/appRoleAssignedTo" \
    --body "{\"principalId\":\"$PRINCIPAL_ID\",\"resourceId\":\"$GRAPH_SP_ID\",\"appRoleId\":\"$CALENDARS_READ_WRITE_ID\"}" \
    --headers "Content-Type=application/json" > /dev/null 2>&1; then
    echo "✓ Granted Calendars.ReadWrite permission"
else
    echo "Warning: Calendars.ReadWrite permission may already be assigned or failed to grant"
fi

echo "Graph API permissions granted successfully!"
echo "Note: It may take a few minutes for permissions to propagate."
