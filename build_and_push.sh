#!/bin/bash
# Build and push Docker image to registry

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-lily-demo-ml}"
REGION="${GCP_REGION:-us-central1}"
REPOSITORY="${ARTIFACT_REGISTRY_REPO:-ml-models}"
IMAGE_NAME="churn-inference"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Full image path
FULL_IMAGE_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "🔨 Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f inference/fastapi-inference/Dockerfile .

echo ""
echo "🏷️  Tagging image for registry..."
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_PATH}

echo ""
echo "📤 Pushing to Artifact Registry..."
echo "Image: ${FULL_IMAGE_PATH}"
docker push ${FULL_IMAGE_PATH}

echo ""
echo "✅ Image pushed successfully!"
echo ""
echo "To deploy to Cloud Run:"
echo "  gcloud run deploy churn-inference \\"
echo "    --image ${FULL_IMAGE_PATH} \\"
echo "    --platform managed \\"
echo "    --region ${REGION} \\"
echo "    --allow-unauthenticated"
