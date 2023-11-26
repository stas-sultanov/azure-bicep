/* Copyright © 2023 Stas Sultanov */

metadata author = {
	githubUrl: 'https://github.com/stas-sultanov'
	name: 'Stas Sultanov'
	profileUrl: 'https://www.linkedin.com/in/stas-sultanov'
}

/* scope */

targetScope = 'resourceGroup'

/* parameters */

@description('Name of the Cdn/profiles resource.')
param Cdn_profiles__name string

@description('Name of the Network/dnsZones resource.')
param Network_dnsZones__name string

@description('Time to live of the custom CNAME record in seconds.')
@maxValue(86400)
@minValue(1)
param cnameRecordTTL int = 3600

@description('Name of the resource.')
param name string

@description('Tags to put on the resources.')
param tags object

@description('Time to live of the validation TXT record in seconds.')
@maxValue(86400)
@minValue(1)
param validationRecordTTL int = 3600

/* variables */

var cdn_profiles_customDomains__hostName = '${name}.${Network_dnsZones_.name}'

var cdn_profiles_customDomains__name = '${name}-${replace(Network_dnsZones_.name, '.', '-')}'

var network_dnsZones_txt_Validation_name = '_dnsauth.${name}'

/* existing resources */

resource Cdn_profiles_ 'Microsoft.Cdn/profiles@2023-05-01' existing = {
	name: Cdn_profiles__name
}

resource Network_dnsZones_ 'Microsoft.Network/dnsZones@2018-05-01' existing = {
	name: Network_dnsZones__name
}

/* resources */

// https://learn.microsoft.com/azure/templates/microsoft.cdn/profiles/afdendpoints
resource Cdn_profiles_afdEndpoints_ 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
	location: 'global'
	name: name
	parent: Cdn_profiles_
	properties: {
		autoGeneratedDomainNameLabelScope: 'ResourceGroupReuse'
	}
	tags: tags
}

// https://learn.microsoft.com/azure/templates/microsoft.cdn/profiles/customdomains
resource Cdn_profiles_customDomains_ 'Microsoft.Cdn/profiles/customDomains@2023-05-01' = {
	name: cdn_profiles_customDomains__name
	parent: Cdn_profiles_
	properties: {
		azureDnsZone: {
			id: Network_dnsZones_.id
		}
		hostName: cdn_profiles_customDomains__hostName
		tlsSettings: {
			certificateType: 'ManagedCertificate'
			minimumTlsVersion: 'TLS12'
		}
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.network/dnszones/cname
resource Network_dnsZones_cname_ 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
	name: name
	parent: Network_dnsZones_
	properties: {
		CNAMERecord: {
			cname: Cdn_profiles_afdEndpoints_.properties.hostName
		}
		TTL: cnameRecordTTL
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.network/dnszones/txt
resource Network_dnsZones_txt_Validation 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
	name: network_dnsZones_txt_Validation_name
	parent: Network_dnsZones_
	properties: {
		TTL: validationRecordTTL
		TXTRecords: [
			{
				value: [
					Cdn_profiles_customDomains_.properties.validationProperties.validationToken
				]
			}
		]
	}
}

/* outputs */

output Cdn_profiles_afdEndpoints__id string = Cdn_profiles_afdEndpoints_.id

output Cdn_profiles_customDomains__id string = Cdn_profiles_customDomains_.id

output Network_dnsZones_cname__id string = Network_dnsZones_cname_.id

output Network_dnsZones_txt_Validation_id string = Network_dnsZones_txt_Validation.id
