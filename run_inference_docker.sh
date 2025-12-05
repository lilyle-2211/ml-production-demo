#!/bin/bash
# Build and run inference API in Docker

set -e

# Configuration
IMAGE_NAME="churn-inference"
IMAGE_TAG="latest"
CONTAINER_NAME="churn-inference"
PORT=8000

echo "🔨 Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f inference/fastapi-inference/Dockerfile .

echo ""
echo "🧹 Cleaning up old container if exists..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

echo ""
echo "🚀 Running inference API on port ${PORT}..."
docker run -d \
  --name ${CONTAINER_NAME} \
  -p ${PORT}:8000 \
  -v ~/.config/gcloud:/root/.config/gcloud:ro \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
  ${IMAGE_NAME}:${IMAGE_TAG}

echo ""
echo "✅ Inference API started!"
echo "📊 API Docs: http://localhost:${PORT}/docs"
echo "💚 Health: http://localhost:${PORT}/health"
echo ""
echo "Useful commands:"
echo "  View logs:   docker logs -f ${CONTAINER_NAME}"
echo "  Stop:        docker stop ${CONTAINER_NAME}"
echo "  Remove:      docker rm ${CONTAINER_NAME}"
echo "  Shell:       docker exec -it ${CONTAINER_NAME} /bin/bash"
