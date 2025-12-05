# GKE Cluster (Standard Mode)
resource "google_container_cluster" "ml_cluster" {
  name     = var.gke_cluster_name
  location = var.gke_zone

  # Workload Identity for pod authentication to GCP services
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Standard mode node pool configuration
  initial_node_count       = 1
  remove_default_node_pool = true

  # Network configuration
  network    = "default"
  subnetwork = "default"

  depends_on = [google_project_service.required_apis]
}

# Node Pool for standard mode
resource "google_container_node_pool" "ml_nodes" {
  count = var.gke_enable_autopilot ? 0 : 1

  name     = "ml-node-pool"
  location = var.gke_zone
  cluster  = google_container_cluster.ml_cluster.name

  initial_node_count = var.gke_initial_node_count

  autoscaling {
    min_node_count = var.gke_min_nodes
    max_node_count = var.gke_max_nodes
  }

  node_config {
    machine_type = var.gke_machine_type
    disk_size_gb = 50

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service Account for inference workload
resource "google_service_account" "inference_sa" {
  account_id   = "churn-inference"
  display_name = "Churn Inference Service Account"
  description  = "Service account for churn inference pods to access GCS"

  depends_on = [google_project_service.required_apis]
}

# Grant GCS read permissions to inference service account
resource "google_storage_bucket_iam_member" "inference_sa_gcs_read" {
  bucket = "lily-ml-models-20251205"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.inference_sa.email}"
}

# Workload Identity binding: GCP SA <-> Kubernetes SA
resource "google_service_account_iam_member" "inference_workload_identity" {
  service_account_id = google_service_account.inference_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/churn-inference-sa]"
}
