variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "lily-demo-ml"
}

variable "project_number" {
  description = "GCP Project Number"
  type        = string
  default     = "167672209455"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "user_emails" {
  description = "List of user emails for IAM permissions (loaded from users.yaml)"
  type        = list(string)
  default     = []
}


variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "lilyle-2211"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "churn-demo"
}

# ============================================================================
# GKE Variables
# ============================================================================

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "fastapi-cluster"
}

variable "gke_cluster_location" {
  description = "Location for the GKE cluster"
  type        = string
  default     = "us-central1-a"
}

variable "gke_zone" {
  description = "Zone for the GKE cluster"
  type        = string
  default     = "us-central1-a"
}

variable "gke_enable_autopilot" {
  description = "Enable GKE Autopilot mode (true) or Standard mode (false)"
  type        = bool
  default     = false
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes (standard mode only)"
  type        = string
  default     = "n1-standard-2"
}

variable "gke_initial_node_count" {
  description = "Initial number of nodes per zone (standard mode only)"
  type        = number
  default     = 2
}

variable "gke_min_nodes" {
  description = "Minimum number of nodes for autoscaling (standard mode only)"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Maximum number of nodes for autoscaling (standard mode only)"
  type        = number
  default     = 3
}
