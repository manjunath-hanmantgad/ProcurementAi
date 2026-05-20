# Infrastructure — ProcureAI

## Deploy (dev)

```bash
az group create --name procureai-dev-rg --location eastus

az deployment group create \
  --resource-group procureai-dev-rg \
  --template-file infra/bicep/main.bicep \
  --parameters infra/environments/dev.parameters.json \
  --parameters postgresAdminPassword="$(openssl rand -base64 24)"
```

## Known gap — local vector store
ProcureAI currently uses an in-memory vector store for policy RAG (`app/rag/retriever.py`).
This does not survive container restarts. For production:
1. Replace with Azure AI Search (see T08 for the module pattern)
2. Add an index initialization step to the deploy pipeline
3. Store policy documents in Azure Blob Storage

This gap must be resolved before a production deployment but is acceptable for Azure PoC demo.

## MCP server
The MCP server runs as a separate process. For Azure PoC:
- Run it as a separate Container App (no ingress, internal only)
- Or run it as a sidecar process in the API container (simpler for demo)

Recommendation: Sidecar for PoC, separate Container App for production.
