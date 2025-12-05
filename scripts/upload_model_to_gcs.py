"""Upload trained model from MLflow to GCS."""
import logging
import os
import tempfile
from pathlib import Path

import mlflow
from google.cloud import storage

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def upload_model_to_gcs(model_uri: str, bucket_name: str, gcs_path: str):
    """
    Download model from MLflow and upload to GCS.

    Args:
        model_uri: MLflow model URI (e.g., "runs:/run_id/model" or "models:/model_name/version")
        bucket_name: GCS bucket name
        gcs_path: Destination path in GCS bucket
    """
    logger.info(f"Loading model from MLflow: {model_uri}")

    # Download model to temp directory
    with tempfile.TemporaryDirectory() as tmp_dir:
        local_path = mlflow.artifacts.download_artifacts(artifact_uri=model_uri, dst_path=tmp_dir)

        logger.info(f"Model downloaded to {local_path}")

        # Upload to GCS
        client = storage.Client()
        bucket = client.bucket(bucket_name)

        # Upload all files
        local_path = Path(local_path)
        for file_path in local_path.rglob("*"):
            if file_path.is_file():
                # Calculate relative path
                relative_path = file_path.relative_to(local_path)
                blob_name = f"{gcs_path}/{relative_path}"

                # Upload
                blob = bucket.blob(blob_name)
                blob.upload_from_filename(str(file_path))
                logger.info(f"Uploaded {blob_name}")

        logger.info(f"✓ Model uploaded to gs://{bucket_name}/{gcs_path}")


if __name__ == "__main__":
    # Example usage
    bucket = os.getenv("GCS_BUCKET_NAME", "lily-demo-ml-mlflow")
    gcs_path = os.getenv("GCS_MODEL_PATH", "models/churn-prediction-model")

    # Get latest production model
    mlflow_uri = os.getenv("MLFLOW_TRACKING_URI", "file://./trainer/mlruns")
    mlflow.set_tracking_uri(mlflow_uri)

    # Upload latest production model
    model_uri = "models:/churn-prediction-model/Production"

    try:
        upload_model_to_gcs(model_uri, bucket, gcs_path)
    except Exception as e:
        logger.error(f"Failed to upload model: {e}")
        # Try latest version if Production doesn't exist
        logger.info("Trying latest version...")
        model_uri = "models:/churn-prediction-model/latest"
        upload_model_to_gcs(model_uri, bucket, gcs_path)
