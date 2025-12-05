# MLflow Remote Tracking Setup Guide

## Problem
Local file-based MLflow (`file:///path/to/mlruns`) doesn't work with CI/CD because:
- GitHub Actions can't access your local filesystem
- Need centralized model registry accessible from anywhere
- Production deployments can't mount local directories

## Solution: Remote MLflow Tracking Server

### Architecture Options

#### Option 1: MLflow on Google Cloud (Recommended for GCP)
```
┌─────────────────┐      ┌─────────────────┐      ┌──────────────────┐
│  GitHub Actions │─────▶│  MLflow Server  │─────▶│  GCS Bucket      │
│  (CI/CD)        │      │  (Cloud Run/VM) │      │  (Model Storage) │
└─────────────────┘      └─────────────────┘      └──────────────────┘
                               │
                               ▼
                         ┌──────────────────┐
                         │  Cloud SQL       │
                         │  (Metadata DB)   │
                         └──────────────────┘
```

#### Option 2: MLflow on AWS
```
GitHub Actions ──▶ MLflow on EC2/ECS ──▶ S3 (artifacts) + RDS (metadata)
```

#### Option 3: Managed MLflow
```
GitHub Actions ──▶ Databricks MLflow / AWS SageMaker / GCP Vertex AI
```

## Quick Setup: MLflow on Google Cloud

### Step 1: Create Cloud SQL Database (PostgreSQL)
```bash
gcloud sql instances create mlflow-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database
gcloud sql databases create mlflow --instance=mlflow-db

# Create user
gcloud sql users create mlflow-user \
  --instance=mlflow-db \
  --password=YOUR_PASSWORD
```

### Step 2: Create GCS Bucket for Artifacts
```bash
gsutil mb -l us-central1 gs://YOUR_PROJECT-mlflow-artifacts
```

### Step 3: Deploy MLflow Server to Cloud Run

Create `mlflow-server/Dockerfile`:
```dockerfile
FROM python:3.12-slim

RUN pip install mlflow psycopg2-binary google-cloud-storage

EXPOSE 5000

# MLflow will be configured via environment variables
CMD mlflow server \
    --host 0.0.0.0 \
    --port 5000 \
    --backend-store-uri ${BACKEND_STORE_URI} \
    --default-artifact-root ${ARTIFACT_ROOT}
```

Deploy to Cloud Run:
```bash
# Build and push
gcloud builds submit --tag gcr.io/YOUR_PROJECT/mlflow-server

# Deploy
gcloud run deploy mlflow-server \
  --image gcr.io/YOUR_PROJECT/mlflow-server \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars BACKEND_STORE_URI="postgresql://mlflow-user:PASSWORD@/mlflow?host=/cloudsql/PROJECT:REGION:mlflow-db" \
  --set-env-vars ARTIFACT_ROOT="gs://YOUR_PROJECT-mlflow-artifacts" \
  --add-cloudsql-instances PROJECT:REGION:mlflow-db
```

### Step 4: Update Your Code

Update `trainer/main.py`:
```python
import os
import mlflow

# Use environment variable for MLflow tracking URI
MLFLOW_TRACKING_URI = os.getenv(
    "MLFLOW_TRACKING_URI",
    "https://mlflow-server-xxx.run.app"  # Your Cloud Run URL
)

mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

def main():
    mlflow.set_experiment("churn-prediction")

    with mlflow.start_run():
        # Your training code
        ...
        mlflow.xgboost.log_model(
            model,
            artifact_path="model",
            registered_model_name="churn-prediction-model"
        )
```

Update `inference/fastapi-inference/main.py`:
```python
import os
import mlflow

# Load from remote MLflow
MLFLOW_TRACKING_URI = os.getenv(
    "MLFLOW_TRACKING_URI",
    "https://mlflow-server-xxx.run.app"
)

@app.on_event("startup")
async def startup_event():
    global model, model_version

    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

    model, model_version = load_model_from_registry(
        model_name="churn-prediction-model",
        stage="Production"
    )
```

### Step 5: Update GitHub Actions

`.github/workflows/train-and-deploy.yml`:
```yaml
name: Train and Deploy Model

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  MLFLOW_TRACKING_URI: https://mlflow-server-xxx.run.app
  GCP_PROJECT_ID: your-project-id
  GCP_REGION: us-central1

jobs:
  train-model:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          pip install uv
          uv pip install -r requirements.txt

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Train model
        run: |
          python trainer/main.py
        env:
          MLFLOW_TRACKING_URI: ${{ env.MLFLOW_TRACKING_URI }}

      - name: Promote model to Production
        run: |
          python scripts/promote_model.py
        env:
          MLFLOW_TRACKING_URI: ${{ env.MLFLOW_TRACKING_URI }}

  deploy-api:
    needs: train-model
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Build and deploy to Cloud Run
        run: |
          gcloud builds submit --tag gcr.io/$GCP_PROJECT_ID/churn-api
          gcloud run deploy churn-api \
            --image gcr.io/$GCP_PROJECT_ID/churn-api \
            --platform managed \
            --region $GCP_REGION \
            --set-env-vars MLFLOW_TRACKING_URI=$MLFLOW_TRACKING_URI \
            --set-env-vars MODEL_NAME=churn-prediction-model \
            --set-env-vars MODEL_STAGE=Production
```

## Alternative: Simpler Setup for Development

If you don't want to set up cloud infrastructure yet, use **SQLite + Shared Storage**:

### Option A: GitHub Actions Artifacts (Development Only)
```yaml
# Save mlruns as artifact after training
- name: Upload MLflow artifacts
  uses: actions/upload-artifact@v3
  with:
    name: mlruns
    path: trainer/mlruns/

# Download in deployment job
- name: Download MLflow artifacts
  uses: actions/download-artifact@v3
  with:
    name: mlruns
    path: trainer/mlruns/
```

⚠️ **Not recommended for production** - artifacts are temporary and not shared across workflows.

### Option B: Mount GCS Bucket as Volume
Use gcsfuse to mount GCS bucket containing mlruns directory.

## Recommended Approach

### For Development/Testing:
```bash
# Local development - use file-based MLflow
export MLFLOW_TRACKING_URI="file://$(pwd)/trainer/mlruns"
python trainer/main.py
```

### For CI/CD and Production:
```bash
# Use remote MLflow server
export MLFLOW_TRACKING_URI="https://mlflow-server-xxx.run.app"
python trainer/main.py
```

## Migration Path

1. **Phase 1 (Now)**: Use local MLflow for development
2. **Phase 2**: Set up remote MLflow server (Cloud Run + Cloud SQL + GCS)
3. **Phase 3**: Update code to use environment variable for tracking URI
4. **Phase 4**: Configure GitHub Actions with remote URI
5. **Phase 5**: Deploy API with remote model loading

## Code Changes Needed

Update both training and inference code to use environment variables:

```python
import os
import mlflow

# Default to local for development, override for production
MLFLOW_TRACKING_URI = os.getenv(
    "MLFLOW_TRACKING_URI",
    f"file://{os.path.dirname(os.path.abspath(__file__))}/mlruns"
)

mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
```

This way:
- ✅ Works locally without changes
- ✅ Works in CI/CD with environment variable
- ✅ Works in production deployment
- ✅ Easy to switch between environments

## Summary

**The key insight:**
- Local MLflow = Good for development
- Remote MLflow = Required for CI/CD and production

You need to decouple your code from the local file system and use a centralized tracking server.
