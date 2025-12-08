.PHONY: help run push-inference helm-upgrade helm-status helm-uninstall test-local test-gke

PROJECT_ID ?= lily-demo-ml
REGION ?= us-central1

INFERENCE_IMAGE := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/churn-pipeline/churn-inference:latest

help:
	@echo "Inference Deployment:"
	@echo "  make push-inference   - Build and push inference image"
	@echo "  make helm-upgrade     - Deploy/upgrade GKE service"
	@echo "  make helm-status      - Check deployment status"
	@echo "  make helm-uninstall   - Remove deployment"
	@echo "  make test-local       - Test inference API locally"
	@echo "  make test-gke         - Test deployed service"

run:
	cd trainer && uv run python main.py

push-inference:
	gcloud auth configure-docker $(REGION)-docker.pkg.dev --quiet
	docker build -f docker/Dockerfile.inference -t $(INFERENCE_IMAGE) .
	docker push $(INFERENCE_IMAGE)

push-inference-cloudbuild:
	gcloud builds submit \
		--config docker/cloudbuild.yaml \
		--substitutions _PROJECT_ID=$(PROJECT_ID),_REGION=$(REGION) \
		.

helm-upgrade:
	kubectl delete deployment churn-inference --ignore-not-found
	helm upgrade churn-inference ./helm --install --wait --timeout=5m

helm-status:
	helm status churn-inference
	kubectl get pods,svc -l app.kubernetes.io/name=churn-inference

helm-uninstall:
	helm uninstall churn-inference

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
