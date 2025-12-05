# ============================================================================
# GitHub Actions - Workload Identity Federation
# ============================================================================

module "github_actions" {
  source = "./modules/github-actions"

  project_id  = var.project_id
  github_org  = var.github_org
  github_repo = var.github_repo
  pool_id     = "github-pool-v2"

  project_roles = [
    "roles/aiplatform.user",
    "roles/artifactregistry.writer",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/cloudbuild.builds.builder",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/iam.serviceAccountUser",
  ]

  depends_on = [google_project_service.required_apis]
}
