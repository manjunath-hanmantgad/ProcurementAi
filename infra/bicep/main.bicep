targetScope = 'resourceGroup'

param location string = resourceGroup().location
param appName string = 'procureai'
param environment string = 'dev'
param acrImageTag string = 'latest'

@secure()
param postgresAdminPassword string

var suffix = '${appName}-${environment}'
var acrName = take(replace('${suffix}acr', '-', ''), 50)
var logAnalyticsSharedKey = listKeys(resourceId('Microsoft.OperationalInsights/workspaces', '${suffix}-law'), '2020-08-01').primarySharedKey
var commonEnv = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.outputs.connectionString
  }
  {
    name: 'LLM_PROVIDER'
    value: 'azure'
  }
  {
    name: 'OPENAI_API_KEY'
    value: ''
  }
  {
    name: 'OPENAI_MODEL'
    value: 'gpt-4o-mini'
  }
  {
    name: 'LANGFUSE_PUBLIC_KEY'
    value: ''
  }
  {
    name: 'LANGFUSE_SECRET_KEY'
    value: ''
  }
  {
    name: 'LANGFUSE_HOST'
    value: 'https://cloud.langfuse.com'
  }
  {
    name: 'AZURE_OPENAI_ENDPOINT'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_KEY'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_CHAT_DEPLOYMENT'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_EMBED_DEPLOYMENT'
    value: ''
  }
  {
    name: 'PROCUREAI_DB_PATH'
    value: '/app/data/procureai.db'
  }
  {
    name: 'PROCUREAI_POLICY_PATH'
    value: '/app/data/procurement_policy.md'
  }
  {
    name: 'APPROVAL_MATRIX_PATH'
    value: '/app/data/approval_matrix.yaml'
  }
  {
    name: 'HOST'
    value: '0.0.0.0'
  }
  {
    name: 'PORT'
    value: '8004'
  }
  {
    name: 'CORS_ORIGINS'
    value: '*'
  }
  {
    name: 'JSON_LOGS'
    value: 'false'
  }
  {
    name: 'LOG_LEVEL'
    value: 'INFO'
  }
  {
    name: 'AZURE_TENANT_ID'
    value: ''
  }
  {
    name: 'AZURE_CLIENT_ID'
    value: ''
  }
  {
    name: 'AZURE_CLIENT_SECRET'
    value: ''
  }
  {
    name: 'AZURE_KEY_VAULT_URL'
    value: ''
  }
]

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    acrName: acrName
  }
}

module appInsights 'modules/appinsights.bicep' = {
  name: 'appinsights'
  params: {
    location: location
    appInsightsName: '${suffix}-ai'
    workspaceName: '${suffix}-law'
  }
}

module postgres 'modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    location: location
    serverName: '${suffix}-pg'
    adminPassword: postgresAdminPassword
  }
}

module acaEnv 'modules/aca-environment.bicep' = {
  name: 'aca-env'
  params: {
    location: location
    environmentName: '${suffix}-env'
    logAnalyticsWorkspaceId: appInsights.outputs.workspaceId
    logAnalyticsSharedKey: logAnalyticsSharedKey
  }
}

module api 'modules/aca-app.bicep' = {
  name: 'api'
  params: {
    location: location
    appName: '${suffix}-api'
    environmentId: acaEnv.outputs.id
    imageName: '${acr.outputs.loginServer}/procureai:${acrImageTag}'
    containerPort: 8004
    command: [
      'uvicorn'
      'app.main:app'
      '--host'
      '0.0.0.0'
      '--port'
      '8004'
    ]
    env: commonEnv
  }
}

module dashboard 'modules/aca-app.bicep' = {
  name: 'dashboard'
  params: {
    location: location
    appName: '${suffix}-dashboard'
    environmentId: acaEnv.outputs.id
    imageName: '${acr.outputs.loginServer}/procureai:${acrImageTag}'
    containerPort: 8501
    command: [
      'streamlit'
      'run'
      'dashboard/app.py'
      '--server.address'
      '0.0.0.0'
      '--server.port'
      '8501'
    ]
    env: commonEnv
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    keyVaultName: '${suffix}-kv'
    managedIdentityPrincipalId: api.outputs.principalId
  }
}

output apiUrl string = 'https://${api.outputs.fqdn}'
output dashboardUrl string = 'https://${dashboard.outputs.fqdn}'
output keyVaultUri string = keyvault.outputs.uri
output postgresHost string = postgres.outputs.fqdn
