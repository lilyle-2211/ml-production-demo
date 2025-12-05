# Storing Models in GitHub for CI/CD

## Option 1: Git LFS + GitHub Releases (Recommended for GitHub-based CI/CD)

### Setup Git LFS

```bash
# Install Git LFS
brew install git-lfs  # macOS
# or: apt-get install git-lfs  # Linux

# Initialize in your repo
cd /Users/lilyle/Documents/ml-production-demo
git lfs install

# Track model files
git lfs track "*.ubj"
git lfs track "*.pkl"
git lfs track "*.h5"
git lfs track "*.pt"
git lfs track "*.pth"

# Commit the tracking file
git add .gitattributes
git commit -m "Track model files with Git LFS"
```

### Workflow: Train → Save → Release → Deploy

#### Step 1: Train and Export Model

Create `scripts/export_model.py`:
```python
"""Export trained model for deployment."""
import os
import mlflow
import joblib
from pathlib import Path

def export_latest_model(
    model_name: str = "churn-prediction-model",
    output_dir: str = "models",
    export_format: str = "mlflow"  # or "pickle", "onnx"
):
    """
    Export the latest production model from MLflow.

    Args:
        model_name: Name of the registered model
        output_dir: Directory to save the exported model
        export_format: Format to export (mlflow, pickle, onnx)
    """
    # Set MLflow tracking URI
    mlflow_uri = os.getenv(
        "MLFLOW_TRACKING_URI",
        f"file://{os.path.dirname(__file__)}/../trainer/mlruns"
    )
    mlflow.set_tracking_uri(mlflow_uri)

    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    # Load latest production model
    try:
        model_uri = f"models:/{model_name}/Production"
        model = mlflow.pyfunc.load_model(model_uri)

        # Get model version info
        client = mlflow.tracking.MlflowClient()
        versions = client.get_latest_versions(model_name, stages=["Production"])
        version_num = versions[0].version if versions else "latest"

        print(f"Exporting {model_name} version {version_num}...")

        # Export based on format
        if export_format == "mlflow":
            # Save entire MLflow model
            mlflow.pyfunc.save_model(
                path=str(output_path / f"{model_name}-v{version_num}"),
                python_model=model
            )
        elif export_format == "pickle":
            # Save as pickle (smaller)
            joblib.dump(
                model,
                output_path / f"{model_name}-v{version_num}.pkl"
            )

        print(f"✓ Model exported to {output_path}")

        # Save metadata
        with open(output_path / "model_info.txt", "w") as f:
            f.write(f"Model: {model_name}\n")
            f.write(f"Version: {version_num}\n")
            f.write(f"Format: {export_format}\n")

        return str(output_path)

    except Exception as e:
        print(f"Error exporting model: {e}")
        raise

if __name__ == "__main__":
    export_latest_model()
```

#### Step 2: GitHub Actions Workflow

`.github/workflows/train-and-deploy.yml`:
```yaml
name: Train Model and Deploy API

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  MODEL_NAME: churn-prediction-model
  PYTHON_VERSION: "3.12"

jobs:
  train-model:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          lfs: true  # ← Important: fetch LFS files

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: |
          pip install uv
          uv pip install --system -r requirements.txt

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Train model
        run: python trainer/main.py
        env:
          MLFLOW_TRACKING_URI: file://$(pwd)/trainer/mlruns

      - name: Export model for deployment
        run: python scripts/export_model.py

      - name: Create release with model
        uses: softprops/action-gh-release@v1
        if: startsWith(github.ref, 'refs/tags/')
        with:
          files: |
            models/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload model as artifact
        uses: actions/upload-artifact@v3
        with:
          name: trained-model
          path: models/
          retention-days: 30

  deploy-api:
    needs: train-model
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Download model artifact
        uses: actions/download-artifact@v3
        with:
          name: trained-model
          path: models/

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Build and deploy to Cloud Run
        run: |
          gcloud builds submit --config cloudbuild.yaml

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy churn-api \
            --image gcr.io/${{ secrets.GCP_PROJECT_ID }}/churn-api:latest \
            --platform managed \
            --region us-central1 \
            --allow-unauthenticated
```

#### Step 3: Update FastAPI to Load from Local File

`inference/fastapi-inference/main.py`:
```python
import os
import mlflow
from pathlib import Path

def load_model_from_file(model_path: str = "models"):
    """Load model from local file system (for GitHub-based deployment)."""
    try:
        model_dir = Path(model_path)

        # Find the latest model directory
        model_dirs = list(model_dir.glob("churn-prediction-model-*"))
        if not model_dirs:
            raise ValueError(f"No model found in {model_path}")

        latest_model = max(model_dirs, key=lambda p: p.stat().st_mtime)

        # Load model
        model = mlflow.pyfunc.load_model(str(latest_model))
        version = latest_model.name.split("-v")[-1] if "-v" in latest_model.name else "unknown"

        logger.info(f"Loaded model from {latest_model}")
        return model, f"version-{version}"

    except Exception as e:
        logger.error(f"Error loading model from file: {e}")
        raise


@app.on_event("startup")
async def startup_event():
    """Load model on startup."""
    global model, model_version

    # Try loading from local file first (GitHub deployment)
    model_path = os.getenv("MODEL_PATH", "models")
    if Path(model_path).exists():
        logger.info("Loading model from local file system...")
        model, model_version = load_model_from_file(model_path)
    else:
        # Fallback to MLflow registry
        logger.info("Loading model from MLflow registry...")
        mlflow_tracking_uri = os.getenv(
            "MLFLOW_TRACKING_URI",
            "file:///app/mlruns"
        )
        model_name = os.getenv("MODEL_NAME", "churn-prediction-model")
        model_stage = os.getenv("MODEL_STAGE", "Production")

        model, model_version = load_model_from_registry(
            model_name=model_name,
            stage=model_stage,
            mlflow_tracking_uri=mlflow_tracking_uri
        )
```

#### Step 4: Update Dockerfile to Include Model

`inference/fastapi-inference/Dockerfile`:
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Copy exported model (from CI/CD)
COPY models/ models/

EXPOSE 8000

ENV MODEL_PATH="models"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Option 2: GitHub Packages / Artifact Registry (Better)

Store models as artifacts, not in git:

```yaml
- name: Push model to GitHub Packages
  run: |
    # Package model as tar
    tar -czf model.tar.gz models/

    # Upload to GitHub Packages
    echo "${{ secrets.GITHUB_TOKEN }}" | \
      docker login ghcr.io -u ${{ github.actor }} --password-stdin

    docker tag model:latest ghcr.io/${{ github.repository }}/model:${{ github.sha }}
    docker push ghcr.io/${{ github.repository }}/model:${{ github.sha }}
```

## Option 3: Google Cloud Storage (Best for Production)

```yaml
- name: Upload model to GCS
  run: |
    gsutil cp -r models/ gs://your-bucket/models/${{ github.sha }}/

- name: Deploy with model from GCS
  run: |
    gcloud run deploy churn-api \
      --set-env-vars MODEL_GCS_PATH=gs://your-bucket/models/${{ github.sha }}
```

Update FastAPI:
```python
from google.cloud import storage

def download_model_from_gcs(bucket_name: str, model_path: str):
    """Download model from GCS."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)

    # Download all model files
    blobs = bucket.list_blobs(prefix=model_path)
    for blob in blobs:
        local_path = Path("models") / blob.name.split("/")[-1]
        blob.download_to_filename(str(local_path))

    return mlflow.pyfunc.load_model("models/")
```

## Comparison Table

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Git LFS** | Simple, version controlled | Costs for storage, GitHub limits | Small teams, < 1GB models |
| **GitHub Releases** | Clean, doesn't bloat repo | Manual tagging process | Versioned releases |
| **GitHub Artifacts** | Built-in CI/CD, temporary | 90-day retention limit | CI/CD pipelines only |
| **GCS/S3** | Scalable, fast, cheap | Requires cloud setup | Production, large models |
| **MLflow Remote** | Model registry + artifacts | Needs server setup | Enterprise, best practice |

## My Recommendation

For your use case (CI/CD with GitHub Actions):

1. **Short term** (Now): Use GitHub Artifacts
   - Quick to implement
   - Works in CI/CD pipeline
   - No extra infrastructure

2. **Medium term** (Production): Use GCS + MLflow Remote
   - Scalable
   - Professional
   - Proper model governance

3. **Avoid**: Storing raw model files in Git
   - Even with LFS, not ideal for frequent updates
   - Better options available

Would you like me to implement any of these approaches?
