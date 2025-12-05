# Helm Deployment Guide

## Overview

The churn prediction inference service is deployed to GKE using Helm for simplified Kubernetes resource management.

## Prerequisites

- **GKE cluster**: `fastapi-cluster` (us-central1-a)
- **Artifact Registry**: `churn-pipeline` (us-central1)
- **Cloud Storage**: `lily-demo-ml-pipeline`
- kubectl configured with cluster access
- Helm 3.x installed
- Docker image pushed to Artifact Registry

## Chart Structure

```
helm/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Configuration values
└── templates/
    ├── deployment.yaml     # Pod deployment spec
    ├── service.yaml        # LoadBalancer service
    └── serviceaccount.yaml # Workload Identity SA
```

## Configuration

Key values in `helm/values.yaml`:

- `replicaCount`: Number of pod replicas (default: 2)
- `image.repository`: Full Artifact Registry path
- `image.tag`: Docker image tag
- `service.type`: LoadBalancer for external access
- `resources`: CPU/memory limits and requests
- `serviceAccount`: Workload Identity annotation

## Deployment Commands

### Install
```bash
make helm-install
# or
helm install churn-inference ./helm
```

### Upgrade (after model changes)
```bash
make helm-upgrade
# or
helm upgrade churn-inference ./helm
```

### Status
```bash
make helm-status
# or
helm status churn-inference
```

### Uninstall
```bash
make helm-uninstall
# or
helm uninstall churn-inference
```

## Accessing the Service

After deployment, get the external IP:
```bash
kubectl get service churn-inference
```

Endpoints:
- Health: `http://<EXTERNAL-IP>/health`
- Docs: `http://<EXTERNAL-IP>/docs`
- Predict: `http://<EXTERNAL-IP>/predict`

## Updating the Model

1. Train and upload new model to GCS bucket
2. Rebuild Docker image with new tag
3. Update `helm/values.yaml` with new image tag
4. Run `make helm-upgrade` to restart pods with new model

## Troubleshooting

View pod logs:
```bash
kubectl logs -l app=churn-inference
```

Describe resources:
```bash
kubectl describe deployment churn-inference
kubectl describe service churn-inference
```

Validate templates locally:
```bash
helm template churn-inference ./helm
```
