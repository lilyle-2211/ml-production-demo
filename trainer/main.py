"""Main pipeline script for XGBoost churn prediction model.

This script orchestrates the entire model training pipeline:
1. Load data from BigQuery
2. Preprocess and prepare features
3. Split data into train/val/test sets
4. Tune hyperparameters with Optuna
5. Train final model
6. Evaluate and save model to MLflow Model Registry
"""
import logging
import os

import mlflow
import mlflow.xgboost
from data_loader import load_data_from_bigquery, upload_model_to_gcs
from data_preprocessing import compute_scale_pos_weight, time_ordered_split
from model_evaluation import evaluate_model
from model_training import (
    create_dmatrix,
    log_feature_importance,
    train_final_model,
    tune_hyperparameters,
)
from validation import load_config


def main():
    """
    Run the complete churn prediction pipeline.

    Returns:
        Trained XGBoost model and evaluation metrics
    """
    mlflow_tracking_uri = os.getenv(
        "MLFLOW_TRACKING_URI", f"file://{os.path.join(os.path.dirname(__file__), 'mlruns')}"
    )
    mlflow.set_tracking_uri(mlflow_tracking_uri)
    logging.info(f"MLflow Tracking URI: {mlflow_tracking_uri}")

    # Load configuration
    config = load_config()

    # Get configuration values
    feature_cols = config.features.all_features
    categorical_features = config.features.categorical
    test_frac = config.data.test_frac
    val_frac = config.data.val_frac
    n_trials = config.model.n_trials

    # Set experiment name
    mlflow.set_experiment("churn-prediction")

    with mlflow.start_run(run_name="xgboost_churn_prediction"):
        #  Load and prepare data from BigQuery
        logging.info("1. Loading data from BigQuery...")
        df = load_data_from_bigquery(config)

        # Split data (returns X_train, y_train, X_val, y_val, X_test, y_test)
        X_train, y_train, X_val, y_val, X_test, y_test = time_ordered_split(
            df, test_frac, val_frac, feature_cols, label_col="is_churn"
        )

        # Compute scale_pos_weight
        scale_pos_weight = compute_scale_pos_weight(y_train)

        # Create DMatrix objects
        dtrain = create_dmatrix(
            X_train, y_train, feature_cols, config.features.numeric, categorical_features
        )
        dval = create_dmatrix(
            X_val, y_val, feature_cols, config.features.numeric, categorical_features
        )
        dtest = create_dmatrix(
            X_test, y_test, feature_cols, config.features.numeric, categorical_features
        )

        # Tune hyperparameters
        best_params = tune_hyperparameters(dtrain, dval, y_val, scale_pos_weight, n_trials)

        # Train final model
        model = train_final_model(dtrain, dval, best_params, scale_pos_weight)

        # Upload model to GCS
        gcs_bucket = config.gcs.bucket_name
        gcs_model_path = config.gcs.model_path
        logging.info(f"Uploading model to gs://{gcs_bucket}/{gcs_model_path}")
        upload_model_to_gcs(model, gcs_bucket, gcs_model_path)

        # Evaluate model
        evaluate_model(model, dval, dtest, y_val, y_test)

        # Log feature importance
        log_feature_importance(model, feature_cols, categorical_features)

        # Log model to MLflow registry
        mlflow.xgboost.log_model(
            model, artifact_path="model", registered_model_name="churn-prediction-model"
        )

        logging.info("Pipeline finished successfully!")


if __name__ == "__main__":
    model, metrics = main()
    print("\nPipeline complete!")
