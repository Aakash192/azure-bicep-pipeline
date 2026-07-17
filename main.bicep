@description('The prefix to use for the storage account name.')
@minLength(3)
@maxLength(10)
param storagePrefix string

@description('The SKU for the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageSKU string = 'Standard_LRS'

@description('The Azure region for the resources.')
param location string = resourceGroup().location

var uniqueStorageName = '${storagePrefix}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: uniqueStorageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageSKU
  }
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-08-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    staticWebsite: {
      enabled: true
      indexDocument: 'index.html'
      errorDocument404Path: '404.html'
    }
  }
}

output storageAccountName string = storageAccount.name
output staticWebsiteUrl string = storageAccount.properties.primaryEndpoints.web
