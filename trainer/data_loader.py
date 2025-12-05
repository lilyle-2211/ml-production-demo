"""
Data loading from BigQuery.
"""
import logging

import pandas as pd
from google.cloud import bigquery
from validation import Config


def load_data_from_bigquery(
    config: Config,
) -> pd.DataFrame:
    """
    Load data from BigQuery.

    Args:
        config: Configuration object with BigQuery settings

    Returns:
        DataFrame with churn data
    """
    client = bigquery.Client(project=config.bigquery.project_id)

    query = f"""
    SELECT *
    FROM {config.bigquery.table_name}
    """
    df = client.query(query).to_dataframe()
    return df


def upload_model_to_gcs(model, bucket_name: str, gcs_path: str):
    """Upload model directly to GCS."""
    import tempfile
    from pathlib import Path

    from google.cloud import storage

    # Save model locally first
    with tempfile.TemporaryDirectory() as tmp_dir:
        local_model_file = Path(tmp_dir) / "model.json"
        model.save_model(str(local_model_file))

        # Upload to GCS
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(f"{gcs_path}/model.json")
        blob.upload_from_filename(str(local_model_file))

        logging.info(f"Model uploaded to gs://{bucket_name}/{gcs_path}/model.json")
