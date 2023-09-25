metadata author = {
	githubUrl: 'https://github.com/stas-sultanov'
	name: 'Stas Sultanov'
	profileUrl: 'https://www.linkedin.com/in/stas-sultanov'
}

/* parameters */

@description('Id of the Storage/storageAccounts resource.')
param Storage_storageAccounts__id string

@description('Location to deploy the resource.')
param location string = resourceGroup().location

@description('Name of the resource.')
param name string

@description('Number of days to keep the logs. -1 for unlimited retention.')
@minValue(-1)
@maxValue(730)
param retentionInDays int = 30

@description('Number of days to keep the logs. -1 for unlimited retention.')
@allowed([ 'CapacityReservation', 'LACluster', 'PerGB2018' ])
param sku string = 'PerGB2018'

@description('Tags to put on the resource.')
param tags object = {}

/* variables */

var storage_StorageAccounts__id_split = split(Storage_storageAccounts__id, '/')

/* existing resources */

resource Storage_storageAccounts_ 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
	name: storage_StorageAccounts__id_split[8]
	scope: resourceGroup(storage_StorageAccounts__id_split[4])
}

/* resources */

// resource info:
// https://learn.microsoft.com/azure/templates/microsoft.operationalinsights/workspaces
resource OperationalInsights_workspaces_ 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
	name: name
	location: location
	tags: tags
	properties: {
		sku: {
			name: sku
		}
		features: {
			disableLocalAuth: true
		}
		retentionInDays: retentionInDays
		publicNetworkAccessForIngestion: 'Disabled'
	}
}

// resource info:
// https://learn.microsoft.com/azure/templates/microsoft.operationalinsights/workspaces/linkedstorageaccounts
resource OperationalInsights_workspaces_linkedStorageAccounts_Alerts 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2020-08-01' = {
	parent: OperationalInsights_workspaces_
	name: 'Alerts'
	properties: {
		storageAccountIds: [ Storage_storageAccounts_.id ]
	}
}

// resource info:
// https://learn.microsoft.com/azure/templates/microsoft.operationalinsights/workspaces/linkedstorageaccounts
resource OperationalInsights_workspaces_linkedStorageAccounts_CustomLogs 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2020-08-01' = {
	parent: OperationalInsights_workspaces_
	name: 'CustomLogs'
	properties: {
		storageAccountIds: [ Storage_storageAccounts_.id ]
	}
}

// resource info:
// https://learn.microsoft.com/azure/templates/microsoft.operationalinsights/workspaces/linkedstorageaccounts
resource OperationalInsights_workspace_linkedStorageAccounts_Query 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2020-08-01' = {
	parent: OperationalInsights_workspaces_
	name: 'Query'
	properties: {
		storageAccountIds: [ Storage_storageAccounts_.id ]
	}
}

// resource info:
// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings 
resource Insights_diagnosticSettings_ 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
	scope: OperationalInsights_workspaces_
	name: 'Storage'
	properties: {
		storageAccountId: Storage_storageAccounts_.id
		logs: [
			{
				category: 'Audit'
				enabled: true
			}
		]
		metrics: [
			{
				timeGrain: 'PT1M'
				enabled: true
			}
		]
	}
}

/* outputs */

output resourceId string = OperationalInsights_workspaces_.id
