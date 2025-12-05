# Model Storage on Google Cloud Storage (GCS)

## Overview

This guide shows how to store trained models on GCS and load them in your FastAPI inference service.

## Architecture

```
┌─────────────────┐      ┌─────────────────┐      ┌──────────────────┐
│  GitHub Actions │─────▶│  Train Model    │─────▶│  Upload to GCS   │
│                 │      │  (Local MLflow) │      │  gs://bucket/    │
└─────────────────┘      └─────────────────┘      └──────────────────┘
                                                            │
                                                            ▼
                                                   ┌──────────────────┐
                                                   │  Cloud Run API   │
                                                   │  (Downloads GCS) │
                                                   └──────────────────┘
```

## Benefits of GCS Storage

✅ **Scalable**: No size limits, handles large models
✅ **Fast**: High-speed downloads, global distribution
✅ **Versioned**: Keep multiple model versions
✅ **Cost-effective**: ~$0.02/GB/month
✅ **CI/CD friendly**: Works seamlessly with GitHub Actions
✅ **Production-ready**: Used by major ML platforms

## Setup Guide

### Step 1: Create GCS Bucket

```bash
# Create bucket
gsutil mb -l us-central1 gs://YOUR_PROJECT-ml-models

# Set lifecycle (optional - auto-delete old versions)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 90,
          "matchesPrefix": ["models/"]
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://YOUR_PROJECT-ml-models
```

### Step 2: Set Up Service Account

```bash
# Create service account
gcloud iam service-accounts create ml-models-sa \
  --display-name="ML Models Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT \
  --member="serviceAccount:ml-models-sa@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding YOUR_PROJECT \
  --member="serviceAccount:ml-models-sa@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

# Create key
gcloud iam service-accounts keys create key.json \
  --iam-account=ml-models-sa@YOUR_PROJECT.iam.gserviceaccount.com

# Add to GitHub Secrets
# Go to: Settings > Secrets > Actions > New repository secret
# Name: GCP_SA_KEY
# Value: <paste contents of key.json>
```

### Step 3: Add GitHub Secrets

In your GitHub repository, add these secrets:

- `GCP_SA_KEY`: Service account JSON key
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCS_BUCKET`: Your bucket name (e.g., `my-project-ml-models`)

### Step 4: Update Dependencies

Add to `requirements.txt`:
```
google-cloud-storage>=2.10.0
```

## Usage

### Local Development

#### Train and Upload
```bash
# Train model locally
python trainer/main.py

# Upload to GCS
python scripts/upload_model_to_gcs.py \
  --model-name churn-prediction-model \
  --stage Production \
  --bucket YOUR_PROJECT-ml-models \
  --version-tag v1.0.0
```

#### Test API with GCS Model
```bash
# Set environment variable
export MODEL_GCS_PATH="gs://YOUR_PROJECT-ml-models/models/churn-prediction-model-Production-v1.0.0"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

# Start API
cd inference/fastapi-inference
uvicorn main:app --reload
```

### CI/CD with GitHub Actions

The workflow `.github/workflows/train-deploy-gcs.yml` automatically:

1. **Trains** model in GitHub Actions runner
2. **Uploads** to GCS with version tag (git SHA + timestamp)
3. **Deploys** API to Cloud Run with GCS model path
4. **Tests** the deployed API

#### Trigger Deployment
```bash
# Push to main branch
git push origin main

# Or manually trigger
gh workflow run train-deploy-gcs.yml
```

## Model Versioning

Models are versioned using: `{model-name}-{stage}-{git-sha}-{timestamp}`

Example:
```
gs://my-bucket/models/churn-prediction-model-Production-abc1234-20251205-143022/
```

### List Available Models
```bash
# Using gsutil
gsutil ls gs://YOUR_BUCKET/models/

# Using Python
python -c "
from inference.fastapi_inference.gcs_loader import list_models_in_gcs
models = list_models_in_gcs('YOUR_BUCKET', 'models')
for m in models: print(m)
"
```

## Dockerfile for Cloud Run

Update `inference/fastapi-inference/Dockerfile`:
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .
COPY gcs_loader.py .

EXPOSE 8000

# Model will be downloaded from GCS at runtime
ENV MODEL_GCS_PATH=""
ENV GCP_PROJECT_ID=""

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Environment Variables

### For Training
- `MLFLOW_TRACKING_URI`: MLflow server URI (optional, defaults to local)

### For Inference
- `MODEL_GCS_PATH`: GCS URI to model (e.g., `gs://bucket/models/model-v1/`)
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account key (local only)
- `GCP_PROJECT_ID`: GCP project ID (for Cloud Run)

## Model Loading Strategy

The FastAPI app loads models in this order:

1. **GCS** (if `MODEL_GCS_PATH` is set) - **Production**
2. **MLflow Registry** (if `MLFLOW_TRACKING_URI` is set)
3. **Local file** (fallback for development)

```python
# In main.py
if os.getenv("MODEL_GCS_PATH"):
    # Load from GCS (production)
    model = load_from_gcs()
elif os.getenv("MLFLOW_TRACKING_URI"):
    # Load from MLflow (staging)
    model = load_from_mlflow()
else:
    # Load from local file (development)
    model = load_from_file()
```

## Cost Estimation

Based on typical ML model:

| Component | Size | Cost |
|-----------|------|------|
| XGBoost model | 50 MB | $0.001/month storage |
| 10 versions | 500 MB | $0.01/month storage |
| Downloads (100/day) | 5 GB/month | $0.12/month egress |
| **Total** | | **~$0.13/month** |

Very affordable! 💰

## Monitoring

### Check Model in GCS
```bash
# List files
gsutil ls -lh gs://YOUR_BUCKET/models/churn-prediction-model-*/

# Download metadata
gsutil cat gs://YOUR_BUCKET/models/churn-prediction-model-Production-*/metadata.json
```

### View Logs
```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=churn-api" --limit 50

# Filter for model loading
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~'model'" --limit 20
```

## Troubleshooting

### Permission Denied
```bash
# Verify service account has storage.objectViewer role
gcloud projects get-iam-policy YOUR_PROJECT \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:ml-models-sa@*"
```

### Model Not Found
```bash
# Check if model exists
gsutil ls gs://YOUR_BUCKET/models/

# Verify path in Cloud Run
gcloud run services describe churn-api --region us-central1 --format yaml | grep MODEL_GCS_PATH
```

### Slow Downloads
- Use same region for GCS bucket and Cloud Run
- Enable Cloud CDN if serving globally
- Consider caching downloaded model in Cloud Run instance

## Best Practices

1. **Version Everything**: Include git SHA in model path
2. **Keep Metadata**: Store model info (version, metrics, date)
3. **Set Lifecycle**: Auto-delete old models after 90 days
4. **Use Same Region**: GCS bucket and Cloud Run in same region
5. **Monitor Costs**: Set up billing alerts
6. **Cache Models**: In Cloud Run, cache to `/tmp` (up to 2GB)
7. **Validate on Load**: Check model can make predictions on startup

## Next Steps

1. ✅ Set up GCS bucket
2. ✅ Create service account
3. ✅ Add GitHub secrets
4. ✅ Test locally with `upload_model_to_gcs.py`
5. ✅ Push code to trigger GitHub Actions
6. ✅ Verify deployment on Cloud Run
7. ✅ Test API endpoints

## Summary

✅ **Best for**: Production ML deployments
✅ **Cost**: Pennies per month
✅ **Complexity**: Medium (one-time setup)
✅ **Scalability**: Excellent
✅ **CI/CD**: Perfect fit

This is the **recommended approach** for production ML systems on GCP!
