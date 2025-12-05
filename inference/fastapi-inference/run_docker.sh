#!/bin/bash
# Script to build and run the FastAPI inference service with Docker

set -e

# Configuration
IMAGE_NAME="churn-prediction-api"
IMAGE_TAG="latest"
CONTAINER_NAME="churn-api"
HOST_PORT=8000
CONTAINER_PORT=8000

# Paths
MLRUNS_PATH="/Users/lilyle/Documents/ml-production-demo/trainer/mlruns"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Churn Prediction API Docker Deployment ===${NC}"

# Build the Docker image
echo -e "\n${GREEN}Step 1: Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} \
  -f inference/fastapi-inference/Dockerfile \
  inference/fastapi-inference/

# Stop and remove existing container if it exists
echo -e "\n${GREEN}Step 2: Stopping existing container (if any)...${NC}"
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# Run the container with volume mount
echo -e "\n${GREEN}Step 3: Starting new container...${NC}"
docker run -d \
  --name ${CONTAINER_NAME} \
  -p ${HOST_PORT}:${CONTAINER_PORT} \
  -v ${MLRUNS_PATH}:/app/mlruns \
  -e MLFLOW_TRACKING_URI="file:///app/mlruns" \
  -e MODEL_NAME="churn-prediction-model" \
  -e MODEL_STAGE="Production" \
  ${IMAGE_NAME}:${IMAGE_TAG}

# Wait a few seconds for the container to start
echo -e "\n${GREEN}Waiting for container to start...${NC}"
sleep 3

# Check if container is running
if docker ps | grep -q ${CONTAINER_NAME}; then
    echo -e "\n${GREEN}✓ Container started successfully!${NC}"
    echo -e "\nContainer Details:"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo -e "\n${BLUE}API Endpoints:${NC}"
    echo "  - API Root:     http://localhost:${HOST_PORT}"
    echo "  - Health Check: http://localhost:${HOST_PORT}/health"
    echo "  - API Docs:     http://localhost:${HOST_PORT}/docs"
    echo "  - Prediction:   http://localhost:${HOST_PORT}/predict"

    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  - View logs:    docker logs -f ${CONTAINER_NAME}"
    echo "  - Stop:         docker stop ${CONTAINER_NAME}"
    echo "  - Restart:      docker restart ${CONTAINER_NAME}"
    echo "  - Remove:       docker rm -f ${CONTAINER_NAME}"

    echo -e "\n${GREEN}Testing the API...${NC}"
    sleep 2
    curl -s http://localhost:${HOST_PORT}/health | python3 -m json.tool || echo "API not ready yet, try again in a few seconds"
else
    echo -e "\n${RED}✗ Container failed to start${NC}"
    echo "Checking logs:"
    docker logs ${CONTAINER_NAME}
    exit 1
fi
