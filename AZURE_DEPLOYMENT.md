# Azure Deployment Guide — ProcureAI

## Prerequisites
- Azure CLI 2.50+
- Bicep CLI (`az bicep install`)
- Docker
- Access to deploy resource group and Container Apps
- Secrets for OpenAI/Azure OpenAI (if not using rule-based mode), database, and app config

## First-time deployment

### Step 1 — Create resource group
```bash
az login
az group create \
  --name procureai-dev-rg \
  --location eastus
```

### Step 2 — Deploy infrastructure
```bash
az deployment group create \
  --resource-group procureai-dev-rg \
  --template-file infra/bicep/main.bicep \
  --parameters infra/environments/dev.parameters.json \
  --parameters postgresAdminPassword="$(openssl rand -base64 24)"
```

Capture outputs for ACR, Key Vault, and Container App names.

### Step 3 — Build and push image
```bash
az acr login --name <ACR_NAME>

docker build -t <ACR_LOGIN_SERVER>/procureai:latest .
docker push <ACR_LOGIN_SERVER>/procureai:latest
```

### Step 4 — Add secrets to Key Vault
```bash
az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name procureai-openai-api-key \
  --value "$OPENAI_API_KEY"

az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name procureai-db-url \
  --value "postgresql://<user>:<password>@<host>:5432/procureai?sslmode=require"
```

### Step 5 — Configure Container App environment variables
```bash
az containerapp update \
  --name <PROCUREAI_CONTAINER_APP> \
  --resource-group procureai-dev-rg \
  --set-env-vars \
    LLM_PROVIDER=azure \
    AZURE_OPENAI_ENDPOINT=https://<your-openai-resource>.openai.azure.com/ \
    DATABASE_URL="postgresql://<user>:<password>@<host>:5432/procureai?sslmode=require" \
    CORS_ORIGINS=https://<your-ui-domain>
```

### Step 6 — Verify
```bash
curl https://<PROCUREAI_FQDN>/health
curl https://<PROCUREAI_FQDN>/mcp/tools
```
Expected: health status and tool list both return `200`.

## Ongoing deployments
- Push updated image to ACR.
- Update Container App revision.
- Smoke test `/health`, `/purchase-requests/analyze`, and `/audit/{request_id}`.

## Rollback
Use revision rollback steps from `RUNBOOK.md`.
