# Helm Chart - ML Inference Service

Simple Helm chart for deploying the churn prediction inference service to GKE.

## Structure

```
helm/
├── Chart.yaml           # Chart metadata
├── values.yaml          # Configuration values
├── .helmignore         # Files to ignore
├── templates/          # Kubernetes resources
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── serviceaccount.yaml
└── README.md
```

## Prerequisites

- GKE cluster with Workload Identity (provisioned by Terraform)
- Artifact Registry repository (provisioned by Terraform)
- Service Account with proper IAM roles (provisioned by Terraform)
- Helm 3.x installed

## Quick Start

```bash
# Get cluster credentials
gcloud container clusters get-credentials fastapi-cluster \
  --zone=us-central1-a --project=lily-demo-ml

# Deploy
helm install churn-inference ./helm --wait

# Upgrade
helm upgrade churn-inference ./helm --wait

# Check status
kubectl get pods,svc -l app.kubernetes.io/name=churn-inference

# Get external IP
kubectl get svc churn-inference -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Configuration

Key settings in `values.yaml`:

| Setting | Description | Default |
|---------|-------------|---------|
| `replicaCount` | Number of pod replicas | `2` |
| `image.repository` | Container image repository | `us-central1-docker.pkg.dev/lily-demo-ml/churn-pipeline/churn-inference` |
| `image.tag` | Container image tag | `"latest"` |
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `true` |

## Autoscaling

Configured for 2-10 replicas based on CPU (70%) and memory (80%) usage.

## Workload Identity

Service account automatically configured with:
```yaml
annotations:
  iam.gke.io/gcp-service-account: churn-inference@lily-demo-ml.iam.gserviceaccount.com
```

## Health Checks

- **Liveness**: `/health` endpoint (restarts unhealthy pods)
- **Readiness**: `/health` endpoint (removes unready pods from load balancer)

## Makefile Integration

Use project Makefile commands:
```bash
make helm-upgrade    # Deploy/upgrade
make helm-status     # Check status
make helm-uninstall  # Remove
make test-gke        # Test endpoints
```

## Troubleshooting

```bash
# Check pod logs
kubectl logs -l app.kubernetes.io/name=churn-inference -f

# Describe deployment
kubectl describe deployment churn-inference

# Check events
kubectl get events --field-selector type=Warning

# Validate templates locally
helm template churn-inference ./helm
```

## Cleanup

```bash
helm uninstall churn-inference
```
