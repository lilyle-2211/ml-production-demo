.PHONY: help build deploy run terraform lint-terraform build-gpu deploy-gpu build-base-gpu clean

# Project configuration
PROJECT_ID := lily-demo-ml
REGION := us-central1
REPOSITORY := ml-docker-repo
IMAGE_URI := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/churn-pipeline/churn-trainer:latest
PYTORCH_GPU_IMAGE := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/churn-pipeline/pytorch-trainer:latest
BASE_GPU_IMAGE := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPOSITORY)/pytorch-base-gpu:latest

# Get git commit SHA for versioning
GIT_SHA := $(shell git rev-parse --short HEAD)
GIT_DIRTY := $(shell git diff --quiet || echo '-dirty')
VERSION := $(GIT_SHA)$(GIT_DIRTY)
PYTORCH_VERSIONED_IMAGE := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/churn-pipeline/pytorch-trainer:$(VERSION)

help:
	@echo "Available commands:"
	@echo "  make build            - Build and push Docker image (XGBoost) to Artifact Registry"
	@echo "  make deploy           - Deploy XGBoost training job to Vertex AI"
	@echo "  make build-base-gpu   - Build base GPU image with common ML dependencies (run this first!)"
	@echo "  make build-gpu        - Build and push PyTorch GPU Docker image"
	@echo "  make deploy-gpu       - Deploy PyTorch GPU training to Vertex AI"
	@echo "  make run              - Run training locally with uv"
	@echo "  make terraform        - Apply Terraform infrastructure"
	@echo "  make lint-terraform   - Lint Terraform code with TFLint"

build:
	@echo "Building Docker image: $(IMAGE_URI)"
	gcloud builds submit --config docker/cloudbuild.yaml --project $(PROJECT_ID)
	@echo "Image built and pushed"

deploy:
	@echo "Deploying to Vertex AI..."
	uv run python pipeline/deploy.py --project-id=$(PROJECT_ID) --region=$(REGION)
	@echo "Pipeline deployed to Vertex AI"

run:
	@echo "Running training locally..."
	cd trainer && uv run python main.py

terraform:
	@echo "Applying Terraform configuration..."
	cd terraform && terraform init && terraform apply
	@echo "Infrastructure deployed"

lint-terraform:
	@echo "Linting Terraform code..."
	cd terraform && tflint --init && tflint
	@echo "Terraform linting complete"

build-base-gpu:
	@echo "Building base GPU image with common ML dependencies..."
	@echo "Image: $(BASE_GPU_IMAGE)"
	@echo "Version: $(VERSION)"
	@echo ""
	gcloud builds submit \
		--config docker/cloudbuild.base-gpu.yaml \
		--project $(PROJECT_ID) \
		--substitutions=_VERSION=$(VERSION),_REPOSITORY=$(REPOSITORY)
	@echo "Base GPU image built and pushed with tags: latest, $(VERSION)"

build-gpu:
	@echo "Building PyTorch GPU Docker image: $(PYTORCH_GPU_IMAGE)"
	@echo "Version: $(VERSION)"
	gcloud builds submit \
		--config docker/cloudbuild.gpu.yaml \
		--project $(PROJECT_ID) \
		--substitutions=_VERSION=$(VERSION)
	@echo "PyTorch GPU image built and pushed with tags: latest, $(VERSION)"

deploy-gpu:
	@echo "Deploying PyTorch GPU training to Vertex AI..."
	@echo "Using image: $(PYTORCH_GPU_IMAGE)"
	uv run python pipeline/deploy_pytorch_gpu.py \
		--project-id=$(PROJECT_ID) \
		--region=$(REGION) \
		--image-uri=$(PYTORCH_GPU_IMAGE) \
		--epochs=100 \
		--batch-size=512 \
		--learning-rate=0.001
	@echo "PyTorch GPU pipeline deployed to Vertex AI"

clean:
	@echo "Cleaning up temporary files..."
	rm -f churn_demo_pipeline.json pytorch_churn_pipeline.json
	rm -f eda/churn_model.pt
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	@echo "Cleanup complete"
