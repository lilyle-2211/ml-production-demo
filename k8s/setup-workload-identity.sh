#!/bin/bash
set -e

PROJECT_ID="lily-demo-ml"
SA_NAME="churn-inference"
KSA_NAME="churn-inference-sa"
NAMESPACE="default"

echo "Setting up Workload Identity for GKE..."

# Create GCP service account if it doesn't exist
echo "Creating GCP service account..."
gcloud iam service-accounts create ${SA_NAME} \
  --display-name="Churn Inference Service Account" \
  --project=${PROJECT_ID} || echo "Service account already exists"

# Grant permissions to access GCS
echo "Granting GCS permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Enable Workload Identity binding
echo "Binding Kubernetes SA to GCP SA..."
gcloud iam service-accounts add-iam-policy-binding \
  ${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]"

echo "Workload Identity setup complete!"
echo "Now you can deploy the Kubernetes manifests."
