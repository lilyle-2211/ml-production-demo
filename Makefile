.PHONY: help run build deploy push-inference helm-upgrade test-local test-gke terraform

PROJECT_ID := lily-demo-ml
REGION := us-central1
INFERENCE_IMAGE := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/churn-pipeline/churn-inference:latest

help:
	@echo "Training:"
	@echo "  make run              - Run training locally"
	@echo "  make build            - Build trainer image"
	@echo "  make deploy           - Deploy to Vertex AI"
	@echo ""
	@echo "Inference:"
	@echo "  make push-inference   - Build and push inference image"
	@echo "  make helm-upgrade     - Update GKE deployment"
	@echo "  make test-local       - Test inference API unit tests"
	@echo "  make test-gke         - Test deployed inference service"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make terraform        - Apply Terraform"

run:
	cd trainer && uv run python main.py

build:
	gcloud builds submit --config docker/cloudbuild-trainer.yaml --project $(PROJECT_ID)

deploy:
	uv run --extra deploy python pipeline/deploy.py --project-id=$(PROJECT_ID) --region=$(REGION)

push-inference:
	gcloud auth configure-docker $(REGION)-docker.pkg.dev --quiet
	docker build -f docker/Dockerfile.inference -t $(INFERENCE_IMAGE) .
	docker push $(INFERENCE_IMAGE)

helm-upgrade:
	helm upgrade churn-inference ./helm --install --wait --timeout=5m

test-local:
	PYTHONPATH=. uv run --with pytest --with fastapi --with httpx --with xgboost --with pyyaml --with google-cloud-storage --with pandas \
		pytest tests/test_inference_api.py -v

test-gke:
	@SERVICE_IP=$$(kubectl get service churn-inference -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	echo "Testing service at $$SERVICE_IP..."; \
	curl -f http://$$SERVICE_IP/health && \
	curl -f -X POST http://$$SERVICE_IP/predict \
		-H "Content-Type: application/json" \
		-d '{"f_0":1.5,"f_1":2.3,"f_2":0.8,"f_3":-0.5,"f_4":1.2,"months_since_signup":12,"calendar_month":6,"signup_month":6,"is_first_month":0}' && \
	echo "All tests passed"

terraform:
	cd terraform && terraform apply
