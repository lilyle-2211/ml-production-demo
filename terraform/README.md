# Terraform Infrastructure Guide

## Overview

This directory contains Terraform configuration for managing GCP infrastructure for the churn prediction ML pipeline.

## File Structure

```
terraform/
├── providers.tf       # Terraform & Google Cloud provider configuration
├── variables.tf       # Input variables (project_id, region, GKE settings)
├── outputs.tf         # Output values (URLs, service accounts, commands)
├── storage.tf         # GCS buckets and Artifact Registry
├── iam.tf            # IAM roles for users and service accounts
├── gke.tf            # GKE cluster for inference deployment
├── github-actions.tf # GitHub Actions Workload Identity setup
├── backend.tfbackend # Backend configuration for state storage
└── users.yaml        # List of user emails for IAM permissions
```

## Prerequisites

- GCP project created (`lily-demo-ml`)
- `gcloud` CLI installed and authenticated
- Terraform >= 1.0 installed

## Initial Setup

1. **Initialize Terraform**
```bash
cd terraform
terraform init -backend-config=backend.tfbackend
```

2. **Review the plan**
```bash
terraform plan
```

3. **Apply configuration**
```bash
terraform apply
```

## Key Resources

### Storage (storage.tf)
- **Artifact Registry**: Docker repository for ML images
- **GCS Bucket**: Pipeline artifacts storage

### GKE Cluster (gke.tf)
- **Cluster**: Standard mode GKE cluster (ml-cluster)
- **Node Pool**: 2-node pool with autoscaling (1-3 nodes)
- **Service Account**: Inference workload SA with GCS access
- **Workload Identity**: Secure pod authentication to GCP

### IAM (iam.tf)
- User permissions (AI Platform, Storage, BigQuery, Artifact Registry)
- Compute Engine service account permissions
- Cloud Build service account permissions
- AI Platform service account permissions

### GitHub Actions (github-actions.tf)
- **Service Account**: `github-actions@lily-demo-ml.iam.gserviceaccount.com`
- **Workload Identity Pool**: OIDC authentication for GitHub
- **Permissions**: AI Platform, Artifact Registry, Storage, Cloud Build

## Outputs

After applying Terraform, you'll get:

```bash
terraform output
```

Key outputs:
- `gke_cluster_name`: Name of the GKE cluster
- `gke_connect_command`: Command to configure kubectl
- `inference_service_account`: Email for inference workload
- `github_actions_service_account`: Email for CI/CD
- `workload_identity_provider`: For GitHub secrets
- `artifact_registry_url`: Docker registry URL

## GitHub Actions Setup

After `terraform apply`, configure GitHub repository secrets:

```bash
# Get the values from Terraform outputs
terraform output github_secrets_instructions
```

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `GCP_PROJECT_ID`: `lily-demo-ml`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: From Terraform output
- `GCP_SERVICE_ACCOUNT`: From Terraform output

GitHub Actions workflow authentication:
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

## Workload Identity (GKE)

For inference pods to access GCS:

1. Kubernetes ServiceAccount: `churn-inference-sa` (in `default` namespace)
2. Annotated with: `iam.gke.io/gcp-service-account: churn-inference@lily-demo-ml.iam.gserviceaccount.com`
3. GCP SA has `roles/storage.objectViewer` on model bucket

See `helm/templates/serviceaccount.yaml` for configuration.

## Updating Infrastructure

### Add a new user
```bash
# Edit users.yaml
vim terraform/users.yaml

# Apply changes
terraform apply
```

### Modify GKE cluster
```bash
# Edit variables in variables.tf
vim terraform/variables.tf

# Plan and apply
terraform plan
terraform apply
```

## Importing Existing Resources

If resources were created manually (like the current GKE cluster):

```bash
# Import GKE cluster
terraform import google_container_cluster.ml_cluster lily-demo-ml/us-central1-a/ml-cluster

# Import service account
terraform import google_service_account.inference_sa projects/lily-demo-ml/serviceAccounts/churn-inference@lily-demo-ml.iam.gserviceaccount.com
```

## Troubleshooting

### Validation
```bash
terraform validate
```

### Format code
```bash
terraform fmt
```

### View state
```bash
terraform state list
```

### Check drift
```bash
terraform plan -refresh-only
```
