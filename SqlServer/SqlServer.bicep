﻿/* Copyright © 2023 Stas Sultanov */

metadata author = {
	githubUrl: 'https://github.com/stas-sultanov'
	name: 'Stas Sultanov'
	profileUrl: 'https://www.linkedin.com/in/stas-sultanov'
}

/* imports */

import { ManagedServiceIdentity } from './../types.bicep'

/* types */

type EntraPrincipalType = 'Application' | 'Group' | 'User'

type EntraPrincipal = {
	@description('Name of the principal within the Entra tenant.')
	name: string

	@description('ObjectId of the principal within the Entra tenant.')
	objectId: string

	@description('Id of the Entra tenant.')
	tenantId: string?

	@description('Type of the principal within the Entra tenant.')
	type: EntraPrincipalType
}

/* parameters */

@description('Id of the OperationalInsights/Workspace resource.')
param OperationalInsights_workspaces__id string

@description('Administrator principal.')
param adminPrincipal EntraPrincipal

@description('Managed Service Identity.')
param identity ManagedServiceIdentity

@description('Location to deploy the resource.')
param location string = resourceGroup().location

@description('Name of the resource.')
param name string

@description('Define if access from Public Network is allowed.')
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Disabled'

@description('Common tags to put on the resource.')
param tags object

/* variables */

var operationalInsights_workspaces__id_split = split(
	OperationalInsights_workspaces__id,
	'/'
)

/* existing resources */

resource OperationalInsights_workspaces_ 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
	name: operationalInsights_workspaces__id_split[8]
	scope: resourceGroup(operationalInsights_workspaces__id_split[4])
}

/* resources */

// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource Insights_diagnosticSettings_ 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
	name: 'Log Analytics'
	properties: {
		logAnalyticsDestinationType: 'Dedicated'
		logs: [
			{
				category: 'SQLSecurityAuditEvents'
				enabled: true
			}
		]
		workspaceId: OperationalInsights_workspaces_.id
	}
	scope: Sql_servers_databases__master
}

// https://learn.microsoft.com/azure/templates/microsoft.sql/servers
resource Sql_servers_ 'Microsoft.Sql/servers@2023-02-01-preview' = {
	identity: identity
	location: location
	name: name
	properties: {
		administrators: {
			administratorType: 'ActiveDirectory'
			azureADOnlyAuthentication: true
			login: adminPrincipal.name
			principalType: adminPrincipal.type
			sid: adminPrincipal.objectId
			tenantId: contains(adminPrincipal, 'tenantId') ? adminPrincipal.tenantId : subscription().tenantId
		}
		minimalTlsVersion: '1.2'
		publicNetworkAccess: publicNetworkAccess
	}
	tags: tags
}

// https://learn.microsoft.com/azure/templates/microsoft.sql/servers/auditingsettings
resource Sql_servers_auditingSettings__Default 'Microsoft.Sql/servers/auditingSettings@2021-11-01' = {
	name: 'default'
	parent: Sql_servers_
	properties: {
		isAzureMonitorTargetEnabled: true
		state: 'Enabled'
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.sql/servers/connectionpolicies
resource Sql_servers_connectionPolicies__default 'Microsoft.Sql/servers/connectionPolicies@2021-11-01' = {
	name: 'default'
	parent: Sql_servers_
	properties: {
		connectionType: 'Default'
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.sql/servers/databases
resource Sql_servers_databases__master 'Microsoft.Sql/servers/databases@2021-11-01' = {
	location: location
	name: 'master'
	parent: Sql_servers_
	properties: {}
}

// https://learn.microsoft.com/azure/templates/microsoft.sql/servers/firewallrules
resource Sql_servers_firewallRules__AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
	name: 'AllowAllWindowsAzureIps'
	parent: Sql_servers_
	properties: {
		endIpAddress: '0.0.0.0'
		startIpAddress: '0.0.0.0'
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.sql/servers/firewallrules
resource Sql_servers_firewallRules__AllowPublicNetworkAccess 'Microsoft.Sql/servers/firewallRules@2021-11-01' = if (publicNetworkAccess == 'Enabled') {
	name: 'AllowPublicNetworkAccess'
	parent: Sql_servers_
	properties: {
		endIpAddress: '255.255.255.255'
		startIpAddress: '0.0.0.0'
	}
}

/* outputs */

output fullyQualifiedDomainName string = Sql_servers_.properties.fullyQualifiedDomainName

output identity object = Sql_servers_.identity

output id string = Sql_servers_.id
