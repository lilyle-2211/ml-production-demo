variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID"
  type        = string
  default     = "github-actions"
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

variable "project_roles" {
  description = "List of IAM roles to grant to the GitHub Actions service account"
  type        = list(string)
  default = [
    "roles/aiplatform.user",
    "roles/artifactregistry.writer",
    "roles/storage.objectAdmin",
    "roles/cloudbuild.builds.builder",
    "roles/container.developer",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/iam.serviceAccountUser"
  ]
}
