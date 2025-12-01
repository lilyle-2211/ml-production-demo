#!/usr/bin/env python3
"""
Deploy PyTorch training job with GPU to Vertex AI.
"""
import argparse
import os
from datetime import datetime

from google.cloud import aiplatform
from kfp import compiler, dsl
from kfp.dsl import Metrics, Model, Output, component

# GPU-enabled container image (default, can be overridden)
DEFAULT_PYTORCH_GPU_IMAGE = (
    "us-central1-docker.pkg.dev/lily-demo-ml/churn-pipeline/pytorch-trainer:latest"
)


def create_training_component(image_uri: str):
    """Create training component with specified image."""

    @component(base_image=image_uri)
    def train_pytorch_model(
        project_id: str,
        epochs: int,
        batch_size: int,
        learning_rate: float,
        model_output: Output[Model],
        metrics_output: Output[Metrics],
    ):
        """Train PyTorch churn prediction model."""
        import sys

        import torch

        sys.path.append("/app/eda")

        # Check GPU
        device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"Using device: {device}")
        if device == "cuda":
            print(f"GPU: {torch.cuda.get_device_name(0)}")

        # Import and run main from pytorch_trainer.py
        # Note: This import works in Docker container where /app/eda is in sys.path
        from pytorch_trainer import main  # type: ignore

        # Run training
        model, metrics = main()

        # Log metrics to Vertex AI
        print("\nLogging metrics to Vertex AI...")
        metrics_output.log_metric("roc_auc_test", float(metrics["roc_auc"]))
        metrics_output.log_metric("pr_auc_test", float(metrics["pr_auc"]))

        # Upload model artifact
        model_output.path = "churn_model.pt"
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_output.uri = f"gs://{project_id}-pipeline/pytorch_models/{timestamp}/model.pt"
        print(f"Model saved to {model_output.uri}")

    return train_pytorch_model


def create_pipeline(image_uri: str):
    """Create pipeline with specified image."""
    train_component = create_training_component(image_uri)

    @dsl.pipeline(name="pytorch-churn-prediction-gpu")
    def pytorch_churn_pipeline(
        project_id: str = "lily-demo-ml",
        epochs: int = 100,
        batch_size: int = 512,
        learning_rate: float = 0.001,
    ):
        """PyTorch churn prediction pipeline with GPU support."""
        train_task = train_component(
            project_id=project_id,
            epochs=epochs,
            batch_size=batch_size,
            learning_rate=learning_rate,
        )

        # Configure GPU resources
        train_task.set_cpu_limit("8")
        train_task.set_memory_limit("32G")
        train_task.set_gpu_limit(1)  # Request 1 GPU

        # Set accelerator type (NVIDIA Tesla T4 is cost-effective)
        # Options: NVIDIA_TESLA_K80, NVIDIA_TESLA_P4, NVIDIA_TESLA_T4, NVIDIA_TESLA_V100, NVIDIA_TESLA_A100
        train_task.set_accelerator_type("NVIDIA_TESLA_T4")

    return pytorch_churn_pipeline


def deploy(
    project_id: str,
    region: str = "us-central1",
    bucket: str = None,
    image_uri: str = None,
    epochs: int = 100,
    batch_size: int = 512,
    learning_rate: float = 0.001,
    run_local: bool = False,
):
    """Compile and deploy PyTorch pipeline to Vertex AI."""

    # Use default image if not specified
    if image_uri is None:
        image_uri = DEFAULT_PYTORCH_GPU_IMAGE

    print(f"Using image: {image_uri}")

    # Create pipeline with specified image
    pytorch_churn_pipeline = create_pipeline(image_uri)

    pipeline_file = "pytorch_churn_pipeline.json"

    # Compile pipeline
    compiler.Compiler().compile(pipeline_func=pytorch_churn_pipeline, package_path=pipeline_file)
    print(f"Pipeline compiled to {pipeline_file}")

    if run_local:
        print("Local execution not supported for GPU pipelines")
        return

    # Deploy to Vertex AI
    if bucket is None:
        bucket = f"{project_id}-pipeline"

    aiplatform.init(project=project_id, location=region)

    job = aiplatform.PipelineJob(
        display_name=f"pytorch-churn-gpu-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
        template_path=pipeline_file,
        pipeline_root=f"gs://{bucket}/pytorch-churn",
        parameter_values={
            "project_id": project_id,
            "epochs": epochs,
            "batch_size": batch_size,
            "learning_rate": learning_rate,
        },
        enable_caching=False,
    )

    print("Submitting pipeline job to Vertex AI...")
    job.submit(service_account=None)
    print(f"Pipeline submitted: {job.resource_name}")
    run_id = job.resource_name.split("/")[-1]
    console_url = (
        f"https://console.cloud.google.com/vertex-ai/pipelines/runs/"
        f"{run_id}?project={project_id}"
    )
    print(f"View in console: {console_url}")

    # Clean up compiled pipeline file
    if os.path.exists(pipeline_file):
        os.remove(pipeline_file)
        print(f"✓ Cleaned up {pipeline_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Deploy PyTorch training to Vertex AI with GPU")
    parser.add_argument("--project-id", required=True, help="GCP project ID")
    parser.add_argument("--region", default="us-central1", help="GCP region")
    parser.add_argument("--bucket", help="GCS bucket for pipeline artifacts")
    parser.add_argument("--image-uri", help="Docker image URI (default: latest pytorch-trainer)")
    parser.add_argument("--epochs", type=int, default=100, help="Number of training epochs")
    parser.add_argument("--batch-size", type=int, default=512, help="Training batch size")
    parser.add_argument("--learning-rate", type=float, default=0.001, help="Learning rate")
    parser.add_argument("--local", action="store_true", help="Run locally (not supported for GPU)")

    args = parser.parse_args()

    deploy(
        project_id=args.project_id,
        region=args.region,
        bucket=args.bucket,
        image_uri=args.image_uri,
        epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.learning_rate,
        run_local=args.local,
    )
