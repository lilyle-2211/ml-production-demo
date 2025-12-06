# GitHub Actions Workflows

## Quick Reference

| Workflow | Purpose | Triggers | Manual Command |
|----------|---------|----------|----------------|
| **ci-trainer.yml** | Test training code | Push to dev, PR to main | `gh workflow run ci-trainer.yml --ref dev` |
| **ci-inference.yml** | Test API code | Push to dev, PR to main | `gh workflow run ci-inference.yml --ref dev` |
| **cd-trainer.yml** | Deploy to Vertex AI | Push to dev | `gh workflow run cd-trainer.yml --ref dev` |
| **cd-inference.yml** | Deploy to GKE | Push to dev | `gh workflow run cd-inference.yml --ref dev` |

## What Each Does

### CI (Testing)
- **ci-trainer**: Tests `trainer/` code
- **ci-inference**: Tests `inference/` API

### CD (Deployment)
- **cd-trainer**: Build Docker → Push to registry → Deploy to Vertex AI
- **cd-inference**: Build Docker → Push to registry → Deploy to GKE with Helm

## Path Filters

Workflows trigger only when specific files change (OR logic):
- `trainer/**`, `inference/**` = all files in directory
- `tests/*.py` = test files
- `pyproject.toml` = dependencies
- `docker/Dockerfile.*` = Docker configs

## Common Commands

```bash
# View runs
gh run list
gh run watch <run-id>
gh run view <run-id> --log

# Check deployments
gcloud builds list --limit 5
kubectl get pods -l app=churn-inference
```

## Required Secrets

In repo `Settings > Secrets > Actions`:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`

Get from: `cd terraform && terraform output`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not triggering | Check if files match `paths` filter |
| Auth error | `gcloud iam service-accounts describe github-actions@lily-demo-ml.iam.gserviceaccount.com` |
| Build failed | `gcloud builds log <build-id>` |
| GKE issues | `kubectl logs -l app=churn-inference` |
