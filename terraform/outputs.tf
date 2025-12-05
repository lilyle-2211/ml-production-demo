output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.churn_pipeline.repository_id}"
}

output "bucket_name" {
  description = "GCS bucket name for pipeline artifacts"
  value       = google_storage_bucket.pipeline_bucket.name
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

# GitHub Actions Workload Identity outputs
output "github_actions_service_account" {
  description = "GitHub Actions service account email"
  value       = module.github_actions.service_account_email
}

output "workload_identity_provider" {
  description = "Workload Identity Provider name for GitHub secrets"
  value       = module.github_actions.workload_identity_provider
}

output "github_secrets_instructions" {
  description = "Instructions for setting up GitHub secrets"
  value       = module.github_actions.github_secrets_instructions
}

# GKE outputs
output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.ml_cluster.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.ml_cluster.endpoint
  sensitive   = true
}

output "gke_cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.ml_cluster.location
}

output "inference_service_account" {
  description = "Service account email for inference workload"
  value       = google_service_account.inference_sa.email
}

output "gke_connect_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.ml_cluster.name} --zone=${google_container_cluster.ml_cluster.location} --project=${var.project_id}"
}
