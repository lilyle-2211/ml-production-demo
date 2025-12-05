# ============================================================================
# ML Production Demo - Terraform Infrastructure
# ============================================================================
#
# This Terraform configuration manages GCP infrastructure for a churn
# prediction ML pipeline, including:
#
# - GCS buckets and Artifact Registry for storage
# - GKE cluster for inference service deployment
# - IAM permissions for service accounts and users
# - GitHub Actions Workload Identity for CI/CD
#
# File Organization:
# - providers.tf       : Terraform and provider configuration
# - variables.tf       : Input variables
# - outputs.tf         : Output values
# - storage.tf         : GCS buckets and Artifact Registry
# - iam.tf            : IAM roles and permissions
# - gke.tf            : GKE cluster and inference service account
# - github-actions.tf : GitHub Actions Workload Identity module
# - modules/          : Reusable Terraform modules
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply
#
# ============================================================================
