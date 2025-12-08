# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "aiplatform.googleapis.com",
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "container.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "churn_pipeline" {
  location      = var.region
  repository_id = "churn-pipeline"
  format        = "DOCKER"
  description   = "Docker repository for churn prediction pipeline"

  depends_on = [google_project_service.required_apis]
}

# GCS bucket for pipeline artifacts
resource "google_storage_bucket" "pipeline_bucket" {
  name                        = "${var.project_id}-pipeline"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.required_apis]
}

# Grant Cloud Build service account permission to push to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "cloudbuild_repo_writer" {
  location   = var.region
  repository = google_artifact_registry_repository.churn_pipeline.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [google_artifact_registry_repository.churn_pipeline]
}
