output "service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions.email
}

output "service_account_name" {
  description = "Name of the GitHub Actions service account"
  value       = google_service_account.github_actions.name
}

output "workload_identity_provider" {
  description = "Full identifier of the Workload Identity Provider"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "github_secrets_instructions" {
  description = "Instructions for setting up GitHub secrets"
  value       = <<-EOT
    Add these secrets to your GitHub repository:

    GCP_WORKLOAD_IDENTITY_PROVIDER: ${google_iam_workload_identity_pool_provider.github_provider.name}
    GCP_SERVICE_ACCOUNT: ${google_service_account.github_actions.email}

    Go to: https://github.com/${var.github_org}/${var.github_repo}/settings/secrets/actions
  EOT
}
