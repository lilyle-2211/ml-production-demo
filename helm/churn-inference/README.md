# Churn Inference Helm Chart

A Helm chart for deploying the churn prediction inference service on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- GKE cluster with Workload Identity enabled
- Docker image pushed to Artifact Registry

## Installation

### Install the chart

```bash
helm install churn-inference ./helm/churn-inference
```

### Install with custom values

```bash
helm install churn-inference ./helm/churn-inference \
  --set image.tag=v1.0.0 \
  --set replicaCount=3
```

### Install with custom values file

```bash
helm install churn-inference ./helm/churn-inference -f my-values.yaml
```

## Upgrading

```bash
helm upgrade churn-inference ./helm/churn-inference
```

## Uninstalling

```bash
helm uninstall churn-inference
```

## Configuration

The following table lists the configurable parameters and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `us-central1-docker.pkg.dev/lily-demo-ml/ml-models/churn-inference` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Service type | `LoadBalancer` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `8000` |
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory` | Memory request | `512Mi` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `5` |

## Examples

### Production deployment with autoscaling

```bash
helm install churn-inference ./helm/churn-inference \
  --set replicaCount=3 \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=3 \
  --set autoscaling.maxReplicas=10 \
  --set resources.requests.cpu=1000m \
  --set resources.requests.memory=1Gi
```

### Development deployment

```bash
helm install churn-inference-dev ./helm/churn-inference \
  --set replicaCount=1 \
  --set image.tag=dev \
  --set resources.requests.cpu=250m \
  --set resources.requests.memory=256Mi
```

## Testing

Test the chart without installing:

```bash
helm template churn-inference ./helm/churn-inference
```

Dry run installation:

```bash
helm install churn-inference ./helm/churn-inference --dry-run --debug
```

## Monitoring

Get the service URL:

```bash
kubectl get service churn-inference -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Check pod status:

```bash
kubectl get pods -l app.kubernetes.io/name=churn-inference
```

View logs:

```bash
kubectl logs -l app.kubernetes.io/name=churn-inference -f
```
