/* Copyright © 2023 Stas Sultanov */

metadata author = {
	githubUrl: 'https://github.com/stas-sultanov'
	name: 'Stas Sultanov'
	profileUrl: 'https://www.linkedin.com/in/stas-sultanov'
}

/* scope */

targetScope = 'resourceGroup'

/* types */

@export()
type OriginGroupSettings = {
	@minValue(1)
	@maxValue(255)
	@description('The number of seconds between health probes.')
	healthProbeIntervalInSeconds: int

	@description('The path relative to the origin that is used to determine the health of the origin.')
	healthProbePath: string

	@description('The unique name of the Origin Group within the CDN profile.')
	name: string
}

@export()
type OriginSettings = {
	@description('The host header value sent to the origin with each request. If you leave this blank, the request hostname determines this value. Azure Front Door origins, such as Web Apps, Blob Storage, and Cloud Services require this host header value to match the origin hostname by default. This overrides the host header defined at Endpoint.')
	hostHeader: string

	@description('The address of the origin. Domain names, IPv4 addresses, and IPv6 addresses are supported. This should be unique across all origins in an endpoint.')
	hostName: string

	@description('The unique name of the Origin within the CDN profile.')
	name: string
}

@export()
type RouteSettings = {
	@description('The unique name of the Route within the CDN profile.')
	name: string

	@description('A  path on the Origin to retrieve content from, e.g. contoso.cloudapp.net/originpath.')
	originPath: string

	@description('The route patterns of the rule.')
	patternsToMatch: string[]
}

/* parameters */

@description('Id of the Cdn/profiles/afdEndpoints resource.')
param Cdn_profiles_afdEndpoints__id string

@description('Id of the Cdn/profiles/customDomains resource.')
param Cdn_profiles_customDomains__id string

@description('Origin group settings.')
param originGroup OriginGroupSettings

@description('Origin settings withing the origin group.')
param origin OriginSettings

@description('Route settings.')
param route RouteSettings

/* variables */

var cdn_profiles_afdEndpoints__id_split = split(Cdn_profiles_afdEndpoints__id, '/')

var cdn_profiles_customDomains__id_split = split(Cdn_profiles_customDomains__id, '/')

/* existing resources */

resource Cdn_profiles_ 'Microsoft.Cdn/profiles@2023-05-01' existing = {
	name: cdn_profiles_afdEndpoints__id_split[8]
}

resource Cdn_profiles_afdEndpoints_ 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' existing = {
	name: cdn_profiles_afdEndpoints__id_split[10]
	parent: Cdn_profiles_
}

resource Cdn_profiles_customDomains_ 'Microsoft.Cdn/profiles/customDomains@2023-05-01' existing = {
	name: cdn_profiles_customDomains__id_split[10]
	parent: Cdn_profiles_
}

/* resources */

// https://learn.microsoft.com/azure/templates/microsoft.cdn/profiles/afdendpoints/routes
resource Cdn_profiles_afdEndpoints_routes_ 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
	dependsOn: [
		Cdn_profiles_originGroups_origins_
	]
	name: route.name
	parent: Cdn_profiles_afdEndpoints_
	properties: {
		cacheConfiguration: {
			queryStringCachingBehavior: 'IgnoreQueryString'
		}
		customDomains: [
			{
				id: Cdn_profiles_customDomains_.id
			}
		]
		originGroup: {
			id: Cdn_profiles_originGroups_.id
		}
		originPath: route.originPath
		supportedProtocols: [
			'Https'
		]
		patternsToMatch: route.patternsToMatch
		forwardingProtocol: 'HttpOnly'
		linkToDefaultDomain: 'Disabled'
		httpsRedirect: 'Enabled'
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.cdn/profiles/origingroups
resource Cdn_profiles_originGroups_ 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
	name: originGroup.name
	parent: Cdn_profiles_
	properties: {
		healthProbeSettings: {
			probeIntervalInSeconds: originGroup.healthProbeIntervalInSeconds
			probePath: originGroup.healthProbePath
			probeProtocol: 'Http'
			probeRequestType: 'GET'
		}
		loadBalancingSettings: {
			additionalLatencyInMilliseconds: 50
			sampleSize: 4
			successfulSamplesRequired: 3
		}
	}
}

// https://learn.microsoft.com/azure/templates/microsoft.cdn/profiles/origingroups/origins
resource Cdn_profiles_originGroups_origins_ 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
	name: origin.name
	parent: Cdn_profiles_originGroups_
	properties: {
		hostName: origin.hostName
		httpPort: 80
		httpsPort: 443
		originHostHeader: origin.hostHeader
		priority: 1
		weight: 1000
	}
}

/* outputs */

output Cdn_profiles_afdEndpoints_routes__id string = Cdn_profiles_afdEndpoints_routes_.id

output Cdn_profiles_originGroups__id string = Cdn_profiles_originGroups_.id

output Cdn_profiles_originGroups_origins__id string = Cdn_profiles_originGroups_origins_.id
