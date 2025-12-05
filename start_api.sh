#!/bin/bash
# Start script for FastAPI inference service (No Docker Required!)

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set default values
export MLFLOW_TRACKING_URI="${MLFLOW_TRACKING_URI:-file://${SCRIPT_DIR}/trainer/mlruns}"
export MODEL_NAME="${MODEL_NAME:-churn-prediction-model}"
export MODEL_STAGE="${MODEL_STAGE:-Production}"
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"

echo "========================================"
echo "  Churn Prediction API"
echo "========================================"
echo ""
echo "Configuration:"
echo "  MLflow URI:   $MLFLOW_TRACKING_URI"
echo "  Model Name:   $MODEL_NAME"
echo "  Model Stage:  $MODEL_STAGE"
echo "  Host:         $HOST"
echo "  Port:         $PORT"
echo ""
echo "Starting server..."
echo ""

cd "${SCRIPT_DIR}/inference"

# Start the FastAPI server with uv
uv run uvicorn main:app --host "$HOST" --port "$PORT" --reload
