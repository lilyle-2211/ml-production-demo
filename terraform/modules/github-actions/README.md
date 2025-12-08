# GitHub Actions Workload Identity Provider

This Terraform module sets up secure authentication between GitHub Actions and Google Cloud Platform using Workload Identity Federation, eliminating the need for service account JSON keys.

## What is Workload Identity?

Workload Identity Federation allows GitHub Actions to authenticate to Google Cloud using OIDC tokens instead of storing permanent service account keys. This provides:

- **Enhanced Security**: No permanent credentials stored in GitHub
- **Short-lived Tokens**: Automatic token expiration
- **Repository Scoping**: Access restricted to specific repositories
- **Audit Trail**: All authentication attempts are logged

## Architecture

```
GitHub Actions Workflow
        ↓ (OIDC Token)
Workload Identity Provider
        ↓ (Validates Token)
Google Cloud Service Account
        ↓ (Impersonation)
Google Cloud Services
```

## Prerequisites

1. **Google Cloud Project** with required APIs enabled:
   - Identity and Access Management (IAM) API
   - Security Token Service (STS) API
   - IAM Service Account Credentials API

2. **GitHub Repository** with Actions enabled

3. **Terraform** >= 1.0

## Module Usage

```hcl
module "github_actions" {
  source = "./modules/github-actions"

  project_id  = "your-project-id"
  github_org  = "your-github-org"
  github_repo = "your-repo-name"

  # Optional: Override default resource names
  pool_id     = "github-pool"
  provider_id = "github-provider"

  # Optional: Custom IAM roles
  project_roles = [
    "roles/aiplatform.user",
    "roles/artifactregistry.writer",
    "roles/storage.objectAdmin"
  ]
}
```

## Resources Created

1. **Google Service Account**: `github-actions@{project-id}.iam.gserviceaccount.com`
2. **Workload Identity Pool**: Manages trust relationships
3. **Workload Identity Provider**: Validates GitHub OIDC tokens
4. **IAM Bindings**: Grants necessary permissions

## Setup Instructions



### 1. Configure GitHub Repository Secrets

After deployment, get the required values:

```bash
terraform output github_secrets_instructions
```

Add these secrets to your GitHub repository:
- Go to: `https://github.com/{org}/{repo}/settings/secrets/actions`
- Add the following repository secrets:

| Secret Name | Value |
|-------------|-------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/{project-number}/locations/global/workloadIdentityPools/{pool-id}/providers/{provider-id}` |
| `GCP_SERVICE_ACCOUNT` | `github-actions@{project-id}.iam.gserviceaccount.com` |


### Debugging Commands

```bash
# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-actions@PROJECT_ID.iam.gserviceaccount.com"

# Verify workload identity pool
gcloud iam workload-identity-pools describe POOL_ID \
  --location=global

# Test workload identity provider
gcloud iam workload-identity-pools providers describe PROVIDER_ID \
  --location=global \
  --workload-identity-pool=POOL_ID
```

### Enable Detailed Logging

Add to your GitHub workflow for debugging:

```yaml
- name: Debug Authentication
  run: |
    gcloud auth list
    gcloud config list
  env:
    GOOGLE_CLOUD_PROJECT: ${{ vars.PROJECT_ID }}
```

## Module Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | - | **Required.** GCP Project ID |
| `github_org` | string | - | **Required.** GitHub organization/username |
| `github_repo` | string | - | **Required.** GitHub repository name |
| `service_account_id` | string | `"github-actions"` | Service account ID |
| `pool_id` | string | `"github-pool"` | Workload Identity Pool ID |
| `provider_id` | string | `"github-provider"` | Workload Identity Provider ID |
| `project_roles` | list(string) | See defaults | IAM roles for service account |

## Module Outputs

| Output | Description |
|--------|-------------|
| `service_account_email` | GitHub Actions service account email |
| `service_account_name` | Service account resource name |
| `workload_identity_provider` | Full provider identifier for GitHub secrets |
| `github_secrets_instructions` | Setup instructions for GitHub secrets |

## Default IAM Roles

The service account receives these roles by default:
- `roles/aiplatform.user` - AI Platform access
- `roles/artifactregistry.writer` - Container registry push/pull
- `roles/storage.objectAdmin` - Cloud Storage access
- `roles/cloudbuild.builds.builder` - Cloud Build execution
- `roles/container.developer` - GKE deployment
- `roles/serviceusage.serviceUsageConsumer` - Service usage
- `roles/iam.serviceAccountUser` - Service account impersonation

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Note:** This will delete the Workload Identity Pool and Provider. Ensure no other workflows are using them.

## Setting Up for Cloned Repository

When you clone this repository to create a new project, you'll need to set up Workload Identity for the new repository:

### Files to Modify

#### 1. `terraform/variables.tf`
```hcl
variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "YOUR-GITHUB-USERNAME"  # ← Change this
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "YOUR-NEW-REPO-NAME"    # ← Change this
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "your-gcp-project-id"   # ← Change this
}
```

#### 2. `terraform/github-actions.tf`
```hcl
module "github_actions" {
  source = "./modules/github-actions"

  project_id  = var.project_id
  github_org  = var.github_org
  github_repo = var.github_repo

  # Use unique names to avoid conflicts
  pool_id     = "github-pool-YOUR-REPO"      # ← Change this
  provider_id = "github-provider-YOUR-REPO"  # ← Change this

  depends_on = [google_project_service.required_apis]
}
```

#### 3. Create `terraform/terraform.tfvars`
```hcl
project_id   = "your-gcp-project-id"
github_org   = "your-github-username"
github_repo  = "your-new-repo-name"
region       = "us-central1"

user_emails = [
  "your-email@example.com"
]
```

### Deployment Steps

1. **Modify Configuration:**
   ```bash
   # Update the files above with your repository details
   ```

2. **Deploy Infrastructure:**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get GitHub Secrets:**
   ```bash
   terraform output github_secrets_instructions
   ```

4. **Add Secrets to GitHub:**
   - Go to: `https://github.com/YOUR-ORG/YOUR-NEW-REPO/settings/secrets/actions`
   - Add these repository secrets:
     - `GCP_WORKLOAD_IDENTITY_PROVIDER`: From terraform output
     - `GCP_SERVICE_ACCOUNT`: From terraform output

5. **Verify Setup:**
   - Push changes to trigger GitHub Actions workflow
   - Check that authentication works in the workflow logs

### Important Notes

- **Unique Resource Names**: Use different `pool_id` and `provider_id` to avoid conflicts with existing Workload Identity resources
- **Repository Scoping**: The Workload Identity Provider is automatically scoped to your specific repository
- **No Code Changes**: The GitHub workflow (`.github/workflows/*.yml`) should work as-is once secrets are configured

## References

- [Google Cloud Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
