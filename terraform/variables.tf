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
