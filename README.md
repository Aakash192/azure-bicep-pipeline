# Azure Bicep Pipeline

Infrastructure as code for an Azure static website, deployed by GitHub Actions. Every push to `main` deploys the same Bicep template to a staging environment first, then to production.

## How the pipeline works

```
push to main
     |
     v
 deploy-staging        GitHub Environment: staging
 (bicepstg, LRS)       azure/login, then azure/arm-deploy
     |
     |  runs only if staging succeeds
     v
 deploy-production     GitHub Environment: production
 (bicepprd, GRS)       azure/login, then azure/arm-deploy
```

The workflow lives in `.github/workflows/deploy.yml`. The production job declares `needs: deploy-staging`, so a failed staging deployment stops the release. Pushes that only change Markdown files skip the deployment, and the workflow can also be started by hand from the Actions tab.

## What gets deployed

`main.bicep` creates:

| Resource | Details |
|----------|---------|
| Storage account | `StorageV2`, HTTPS traffic only, tagged with the environment name |
| Blob service | Static website hosting enabled, `index.html` as the index document, `404.html` as the error document |

Outputs: `storageAccountName` and `staticWebsiteUrl` (the primary web endpoint).

### Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `storagePrefix` | none (required) | 3 to 10 characters. A unique suffix from `uniqueString(resourceGroup().id)` is appended, so names do not collide globally |
| `storageSKU` | `Standard_LRS` | Restricted with `@allowed` to `Standard_LRS`, `Standard_GRS`, `Standard_RAGRS` |
| `location` | Resource group location | |
| `environment` | `production` | Applied as the `environment` tag |

### Staging versus production

| | Staging | Production |
|---|---------|------------|
| Storage prefix | `bicepstg` | `bicepprd` |
| Environment tag | `staging` | `production` |
| Redundancy | `Standard_LRS` (template default) | `Standard_GRS` |
| Resource group secret | `AZURE_RG_STAGING` | `AZURE_RG` |

## Design decisions

- **One template, two environments.** The environments differ only by parameters, so staging is a faithful preview of what production will receive.
- **Validated inputs.** Prefix length and SKU choices are enforced by the template itself, so bad values fail at deployment time with a clear error.
- **Deterministic unique names.** `uniqueString(resourceGroup().id)` gives a stable name per resource group. Redeploying updates the same account instead of creating a new one.
- **GitHub Environments.** Each job targets a named environment. This is where required reviewers and environment scoped secrets are configured, which gives the production job a manual approval gate.

## Setup

1. Create two Azure resource groups, one for staging and one for production.
2. Create a service principal with access scoped to those resource groups.
3. Add these repository secrets:
   - `AZURE_CREDENTIALS`: the service principal credentials as JSON
   - `AZURE_SUBSCRIPTION`: the subscription ID
   - `AZURE_RG_STAGING`: staging resource group name
   - `AZURE_RG`: production resource group name
4. In Settings, Environments, create `staging` and `production`. Add required reviewers to `production` to turn on the approval gate.
5. Push to `main`.

To deploy by hand instead:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file main.bicep \
  --parameters storagePrefix=bicepdev environment=dev
```

## Known gaps and next steps

- No lint or `what-if` step on pull requests, so template changes are only exercised on merge to `main`.
- Authentication uses a service principal secret. Federated (OIDC) credentials would remove the stored secret.
- The static website is enabled but the pipeline does not upload site content yet.
- Actions are pinned by version tag rather than commit SHA.
