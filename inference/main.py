"""Simple FastAPI inference service that loads model from GCS."""
import logging
from typing import List

import pandas as pd
from fastapi import FastAPI, HTTPException

from inference.schemas import PredictionInput, PredictionOutput
from inference.utils import download_model_from_gcs, load_config, load_model

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load config
config = load_config()
app = FastAPI(title=config["api"]["title"])

# Global model
model = None
model_version = None


@app.on_event("startup")
async def startup_event():
    """Load model on startup."""
    global model, model_version

    # Get from env vars or config file (env vars take precedence)
    bucket_name = config["gcs"]["bucket_name"]
    model_path = config["gcs"]["model_path"]

    try:
        # Download and load model from GCS
        local_model_dir = download_model_from_gcs(bucket_name, model_path)
        model = load_model(local_model_dir)
        model_version = model_path.split("/")[-1]

        logger.info(f"Model loaded successfully: {model_version}")

    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


@app.get("/")
def root():
    """Root endpoint."""
    return {"message": "Churn Prediction API", "health": "/health", "docs": "/docs"}


@app.get("/health")
def health():
    """Health check."""
    return {
        "status": "healthy" if model else "unhealthy",
        "model_loaded": model is not None,
        "model_version": model_version,
    }


@app.post("/predict", response_model=PredictionOutput)
def predict(input_data: PredictionInput):
    """Make single prediction."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        import xgboost as xgb

        input_df = pd.DataFrame([input_data.dict()])
        dmatrix = xgb.DMatrix(input_df)
        prediction_proba = model.predict(dmatrix)[0]
        prediction_binary = int(prediction_proba >= 0.5)

        return PredictionOutput(
            churn_probability=float(prediction_proba),
            churn_prediction=prediction_binary,
            model_version=model_version,
        )

    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict/batch")
def predict_batch(inputs: List[PredictionInput]):
    """Make batch predictions."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        import xgboost as xgb

        input_df = pd.DataFrame([inp.dict() for inp in inputs])
        dmatrix = xgb.DMatrix(input_df)
        predictions_proba = model.predict(dmatrix)
        predictions_binary = (predictions_proba >= 0.5).astype(int)

        results = [
            PredictionOutput(
                churn_probability=float(prob),
                churn_prediction=int(binary),
                model_version=model_version,
            )
            for prob, binary in zip(predictions_proba, predictions_binary)
        ]

        return results

    except Exception as e:
        logger.error(f"Batch prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config["api"]["host"], port=config["api"]["port"])
