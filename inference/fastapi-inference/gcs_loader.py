"""Load trained model from Google Cloud Storage for inference."""
import logging
import tempfile
from pathlib import Path
from typing import Any, Tuple

import mlflow.pyfunc
from google.cloud import storage

logger = logging.getLogger(__name__)


def download_model_from_gcs(gcs_path: str, local_dir: str = None) -> str:
    """
    Download model from GCS to local directory.

    Args:
        gcs_path: GCS URI (e.g., gs://bucket-name/models/model-v1/)
        local_dir: Local directory to download to (defaults to temp dir)

    Returns:
        Path to downloaded model directory
    """
    logger.info(f"Downloading model from GCS: {gcs_path}")

    # Parse GCS path
    if not gcs_path.startswith("gs://"):
        raise ValueError(f"Invalid GCS path: {gcs_path}")

    # Extract bucket and prefix
    path_parts = gcs_path.replace("gs://", "").split("/", 1)
    bucket_name = path_parts[0]
    prefix = path_parts[1] if len(path_parts) > 1 else ""

    # Ensure prefix ends with /
    if prefix and not prefix.endswith("/"):
        prefix += "/"

    logger.info(f"Bucket: {bucket_name}, Prefix: {prefix}")

    # Create local directory
    if local_dir is None:
        local_dir = tempfile.mkdtemp(prefix="model_")
    else:
        Path(local_dir).mkdir(parents=True, exist_ok=True)

    # Initialize GCS client
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    # List and download all blobs with the prefix
    blobs = bucket.list_blobs(prefix=prefix)
    downloaded_files = []

    for blob in blobs:
        # Skip if it's a directory marker
        if blob.name.endswith("/"):
            continue

        # Get relative path after prefix
        relative_path = blob.name[len(prefix) :]

        # Build local file path
        local_file_path = Path(local_dir) / relative_path
        local_file_path.parent.mkdir(parents=True, exist_ok=True)

        # Download file
        blob.download_to_filename(str(local_file_path))
        downloaded_files.append(relative_path)
        logger.debug(f"Downloaded: {relative_path}")

    logger.info(f"Downloaded {len(downloaded_files)} files to {local_dir}")
    return local_dir


def load_model_from_gcs(gcs_path: str, cache_dir: str = "/tmp/models") -> Tuple[Any, str]:
    """
    Load MLflow model from GCS.

    Args:
        gcs_path: GCS URI to model directory
        cache_dir: Local cache directory

    Returns:
        Tuple of (loaded model, version info)
    """
    try:
        # Download model from GCS
        local_model_path = download_model_from_gcs(gcs_path, cache_dir)

        # Load model with MLflow
        model = mlflow.pyfunc.load_model(local_model_path)

        # Extract version from path
        version = Path(gcs_path).name

        logger.info(f"Successfully loaded model from GCS: {version}")
        return model, version

    except Exception as e:
        logger.error(f"Error loading model from GCS: {e}")
        raise


def list_models_in_gcs(bucket_name: str, prefix: str = "models") -> list:
    """
    List available models in GCS bucket.

    Args:
        bucket_name: GCS bucket name
        prefix: Prefix/folder to search in

    Returns:
        List of model paths
    """
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    # List all "directories" (prefixes)
    blobs = bucket.list_blobs(prefix=prefix, delimiter="/")

    models = []
    for prefix in blobs.prefixes:
        models.append(f"gs://{bucket_name}/{prefix}")

    return models
