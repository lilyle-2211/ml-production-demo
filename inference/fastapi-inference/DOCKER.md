# Docker Deployment Guide

## Quick Start

### 1. Build and Run with Script (Recommended)
```bash
# Make the script executable
chmod +x inference/fastapi-inference/run_docker.sh

# Run the deployment script
./inference/fastapi-inference/run_docker.sh
```

### 2. Manual Docker Commands

#### Build the Image
```bash
cd /Users/lilyle/Documents/ml-production-demo

docker build -t churn-prediction-api:latest \
  -f inference/fastapi-inference/Dockerfile \
  inference/fastapi-inference/
```

#### Run with Volume Mount
```bash
docker run -d \
  --name churn-api \
  -p 8000:8000 \
  -v /Users/lilyle/Documents/ml-production-demo/trainer/mlruns:/app/mlruns \
  -e MLFLOW_TRACKING_URI="file:///app/mlruns" \
  -e MODEL_NAME="churn-prediction-model" \
  -e MODEL_STAGE="Production" \
  churn-prediction-api:latest
```

**Explanation:**
- `-d`: Run in detached mode (background)
- `--name churn-api`: Name the container
- `-p 8000:8000`: Map host port 8000 to container port 8000
- `-v /path/to/mlruns:/app/mlruns`: Mount MLflow tracking directory
- `-e`: Set environment variables

## Volume Mount Explained

The volume mount `-v` flag connects your local MLflow directory to the container:

```bash
-v <HOST_PATH>:<CONTAINER_PATH>
-v /Users/lilyle/Documents/ml-production-demo/trainer/mlruns:/app/mlruns
```

**Benefits:**
- Container reads models directly from your local MLflow registry
- No need to copy models into the image
- Models stay in sync - update locally and container sees changes
- Smaller Docker image size

## Docker Management

### View Running Containers
```bash
docker ps
```

### View Container Logs
```bash
docker logs churn-api

# Follow logs in real-time
docker logs -f churn-api
```

### Stop Container
```bash
docker stop churn-api
```

### Start Stopped Container
```bash
docker start churn-api
```

### Restart Container
```bash
docker restart churn-api
```

### Remove Container
```bash
# Stop and remove
docker rm -f churn-api
```

### Execute Commands Inside Container
```bash
# Open shell in container
docker exec -it churn-api bash

# Check MLflow directory
docker exec churn-api ls -la /app/mlruns
```

## Testing the Dockerized API

### Health Check
```bash
curl http://localhost:8000/health
```

### Single Prediction
```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "f_0": 0.5,
    "f_1": 0.3,
    "f_2": 0.8,
    "f_3": 0.2,
    "f_4": 0.6,
    "months_since_signup": 12,
    "calendar_month": 6,
    "signup_month": 6,
    "is_first_month": 0
  }'
```

### Using Test Script
```bash
# Install requests if not already installed
pip install requests

# Run tests against dockerized API
python inference/fastapi-inference/test_api.py
```

## Environment Variables

Override defaults when running the container:

```bash
docker run -d \
  --name churn-api \
  -p 8000:8000 \
  -v /Users/lilyle/Documents/ml-production-demo/trainer/mlruns:/app/mlruns \
  -e MLFLOW_TRACKING_URI="file:///app/mlruns" \
  -e MODEL_NAME="churn-prediction-model" \
  -e MODEL_STAGE="Staging" \
  churn-prediction-api:latest
```

Available variables:
- `MLFLOW_TRACKING_URI`: MLflow tracking server URI
- `MODEL_NAME`: Name of registered model
- `MODEL_STAGE`: Model stage (None, Staging, Production, Archived)

## Production Deployment

### Using Docker Compose (Optional)

Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  churn-api:
    build:
      context: ./inference/fastapi-inference
      dockerfile: Dockerfile
    container_name: churn-api
    ports:
      - "8000:8000"
    volumes:
      - /Users/lilyle/Documents/ml-production-demo/trainer/mlruns:/app/mlruns
    environment:
      - MLFLOW_TRACKING_URI=file:///app/mlruns
      - MODEL_NAME=churn-prediction-model
      - MODEL_STAGE=Production
    restart: unless-stopped
```

Then run:
```bash
docker-compose up -d
```

### Cloud Deployment

For production on cloud platforms (GCP, AWS, Azure), you typically:

1. **Push image to container registry:**
```bash
# Tag for Google Container Registry
docker tag churn-prediction-api:latest gcr.io/PROJECT_ID/churn-api:latest

# Push to registry
docker push gcr.io/PROJECT_ID/churn-api:latest
```

2. **Deploy to Cloud Run / ECS / AKS**
- Instead of volume mount, use remote MLflow tracking server
- Set `MLFLOW_TRACKING_URI` to remote server URL

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs churn-api

# Check if port is already in use
lsof -i:8000

# Run in foreground to see errors
docker run --rm -it \
  -p 8000:8000 \
  -v /Users/lilyle/Documents/ml-production-demo/trainer/mlruns:/app/mlruns \
  churn-prediction-api:latest
```

### Model not found
```bash
# Verify volume mount
docker exec churn-api ls -la /app/mlruns

# Check MLflow directory structure
docker exec churn-api find /app/mlruns -name "*.ubj" -o -name "MLmodel"
```

### Permission issues
```bash
# Make sure mlruns directory is readable
chmod -R 755 /Users/lilyle/Documents/ml-production-demo/trainer/mlruns
```

## Image Management

### List Images
```bash
docker images | grep churn
```

### Remove Image
```bash
docker rmi churn-prediction-api:latest
```

### Clean Up Unused Images
```bash
docker image prune -a
```

## Performance Tips

1. **Multi-stage builds** (advanced): Reduce image size
2. **Layer caching**: Put frequently changing files last
3. **Use .dockerignore**: Exclude unnecessary files
4. **Resource limits**: Set CPU/memory limits in production

```bash
docker run -d \
  --name churn-api \
  --memory="1g" \
  --cpus="0.5" \
  -p 8000:8000 \
  -v /Users/lilyle/Documents/ml-production-demo/trainer/mlruns:/app/mlruns \
  churn-prediction-api:latest
```
