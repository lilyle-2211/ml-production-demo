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

variable "service_account_display_name" {
  description = "Service account display name"
  type        = string
  default     = "GitHub Actions"
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "pool_display_name" {
  description = "Workload Identity Pool display name"
  type        = string
  default     = "GitHub Actions Pool"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

variable "provider_display_name" {
  description = "Workload Identity Provider display name"
  type        = string
  default     = "GitHub Provider"
}

variable "project_roles" {
  description = "List of IAM roles to grant to the GitHub Actions service account"
  type        = list(string)
  default = [
    "roles/aiplatform.user",
    "roles/artifactregistry.writer",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/cloudbuild.builds.builder",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/iam.serviceAccountUser",
  ]
}
