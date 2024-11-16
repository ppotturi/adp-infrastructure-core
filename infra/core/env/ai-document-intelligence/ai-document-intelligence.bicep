@description('Required. The parameter object for the virtual network. The object must contain the name, resourceGroup and subnetPrivateEndpoints values.')
param vnet object

@description('Required. The parameter object for AI Document Intelligence. The object must contain the name and sku values.')
param aiDocumentIntelligence object

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. Environment name.')
param environment string

@description('Optional. Date in the format yyyyMMdd-HHmmss.')
param deploymentDate string = utcNow('yyyyMMdd-HHmmss')

@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')

var customTags = {
  Location: location
  CreatedDate: createdDate
  Environment: environment
}

var defaultTags = union(json(loadTextContent('../../../common/default-tags.json')), customTags)

var documentIntelligenceTags = {
  Name: aiDocumentIntelligence.name
  Purpose: 'AI Document Intelligence'
  Tier: 'Shared'
}

module documentIntelligenceResource 'br/avm:cognitive-services/account:0.8.0' = {
  name: 'ai-document-intelligence-${deploymentDate}'
  params: {
    kind: 'FormRecognizer'
    name: aiDocumentIntelligence.name
    publicNetworkAccess: 'Disabled'
    location: location
    sku: aiDocumentIntelligence.sku
    customSubDomainName: aiDocumentIntelligence.customSubDomainName
    privateEndpoints: [
      {
        subnetResourceId: resourceId(vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnet.name, vnet.subnetPrivateEndpoints)
      }
    ]
    tags: union(defaultTags, documentIntelligenceTags)

  }
}