# CI/CD with MLflow - Quick Reference

## Current Setup

### ✅ What Works Now (Local Development)
```bash
# Local development - no changes needed
cd /Users/lilyle/Documents/ml-production-demo
python trainer/main.py  # Uses local file:// MLflow
./start_api.sh          # API loads from local mlruns/
```

### ❌ What Won't Work in CI/CD
```python
# Hard-coded local paths won't work in GitHub Actions
MLFLOW_TRACKING_URI = "file:///Users/lilyle/Documents/ml-production-demo/trainer/mlruns"
```

## Your Code is Already CI/CD Ready! ✨

I've updated `trainer/main.py` to use environment variables:

```python
# trainer/main.py
mlflow_tracking_uri = os.getenv(
    "MLFLOW_TRACKING_URI",
    f"file://{os.path.join(os.path.dirname(__file__), 'mlruns')}"  # Local fallback
)
mlflow.set_tracking_uri(mlflow_tracking_uri)
```

```python
# inference/fastapi-inference/main.py (already done)
mlflow_tracking_uri = os.getenv(
    "MLFLOW_TRACKING_URI",
    "file:///Users/lilyle/Documents/ml-production-demo/trainer/mlruns"  # Local fallback
)
```

## Environment Variable Strategy

### Local Development
```bash
# No env var = uses local file system
python trainer/main.py
```

### CI/CD / Production
```bash
# Set env var = uses remote MLflow server
export MLFLOW_TRACKING_URI="https://your-mlflow-server.com"
python trainer/main.py
```

## Next Steps for Full CI/CD

### Phase 1: Current State ✅
- [x] Code uses environment variables
- [x] Works locally without changes
- [x] Ready for remote MLflow when you set it up

### Phase 2: Set Up Remote MLflow (Choose One)

#### Option A: MLflow on Google Cloud Run (Recommended)
**Pros:** Fully managed, scalable, pay-per-use
**Cost:** ~$10-30/month

```bash
# See docs/mlflow_remote_setup.md for full instructions

# Quick setup:
1. Create Cloud SQL database
2. Create GCS bucket for artifacts
3. Deploy MLflow server to Cloud Run
4. Get the URL (e.g., https://mlflow-xxx.run.app)
```

#### Option B: MLflow on Compute Engine VM
**Pros:** Full control, persistent
**Cost:** ~$20-50/month

```bash
# Deploy on a VM
gcloud compute instances create mlflow-server \
  --machine-type=e2-small \
  --zone=us-central1-a

# Install MLflow, set up nginx, configure SSL
```

#### Option C: Use Databricks (Easiest)
**Pros:** Fully managed, includes MLflow
**Cost:** Pay per compute unit

```bash
# Get workspace URL from Databricks
export MLFLOW_TRACKING_URI="databricks://workspace-url"
```

#### Option D: Development Workaround (Not for Production)
Store mlruns in the repository (not recommended):

```bash
# Add to .gitignore exceptions
!trainer/mlruns/

# Commit mlruns to git (⚠️ gets large quickly!)
git add trainer/mlruns/
git commit -m "Add mlruns"
```

### Phase 3: Update GitHub Actions

`.github/workflows/ci-cd.yml`:
```yaml
name: Train and Deploy

on:
  push:
    branches: [main]

env:
  MLFLOW_TRACKING_URI: https://your-mlflow-server.com  # ← Set this

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Train model
        run: python trainer/main.py
        env:
          MLFLOW_TRACKING_URI: ${{ env.MLFLOW_TRACKING_URI }}

  deploy:
    needs: train
    runs-on: ubuntu-latest
    steps:
      - name: Deploy API
        run: |
          gcloud run deploy churn-api \
            --set-env-vars MLFLOW_TRACKING_URI=${{ env.MLFLOW_TRACKING_URI }}
```

## Testing Both Modes

### Test Local Mode
```bash
# No environment variable
cd /Users/lilyle/Documents/ml-production-demo
python trainer/main.py
# Uses: file:///.../trainer/mlruns
```

### Test Remote Mode (After Setting Up Remote MLflow)
```bash
# With environment variable
export MLFLOW_TRACKING_URI="https://your-mlflow-server.com"
python trainer/main.py
# Uses: https://your-mlflow-server.com
```

## Summary

✅ **Your code is already ready for CI/CD!**

The only thing you need to do is:
1. Set up a remote MLflow server (one-time setup)
2. Set the `MLFLOW_TRACKING_URI` environment variable in GitHub Actions
3. Deploy!

**For now:**
- Continue using local MLflow for development
- When ready for CI/CD, follow `docs/mlflow_remote_setup.md`

**Key Principle:**
```
Local Dev:  No env var → Uses local files
CI/CD/Prod: Set env var → Uses remote server
```

No code changes needed when switching between environments! 🎉
