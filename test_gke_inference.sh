#!/bin/bash
# Test inference service on GKE

set -e

# Get service IP
echo "Getting service IP..."
SERVICE_IP=$(kubectl get service churn-inference -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$SERVICE_IP" ]; then
    echo "❌ Error: Could not get service IP"
    exit 1
fi

echo "✓ Service IP: $SERVICE_IP"
echo ""

# Test health endpoint
echo "Testing /health endpoint..."
HEALTH=$(curl -s http://$SERVICE_IP/health)
echo "Response: $HEALTH"

if echo "$HEALTH" | grep -q '"status":"healthy"'; then
    echo "✓ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi
echo ""

# Test single prediction
echo "Testing /predict endpoint..."
PREDICTION=$(curl -s -X POST http://$SERVICE_IP/predict \
  -H "Content-Type: application/json" \
  -d '{
    "f_0": 1.5,
    "f_1": 2.3,
    "f_2": 0.8,
    "f_3": -0.5,
    "f_4": 1.2,
    "months_since_signup": 12,
    "calendar_month": 6,
    "signup_month": 6,
    "is_first_month": 0
  }')
echo "Response: $PREDICTION"

if echo "$PREDICTION" | grep -q 'churn_probability'; then
    echo "✓ Single prediction passed"
else
    echo "❌ Single prediction failed"
    exit 1
fi
echo ""

# Test batch prediction
echo "Testing /predict/batch endpoint..."
BATCH=$(curl -s -X POST http://$SERVICE_IP/predict/batch \
  -H "Content-Type: application/json" \
  -d '[
    {
      "f_0": 1.5,
      "f_1": 2.3,
      "f_2": 0.8,
      "f_3": -0.5,
      "f_4": 1.2,
      "months_since_signup": 12,
      "calendar_month": 6,
      "signup_month": 6,
      "is_first_month": 0
    },
    {
      "f_0": -0.5,
      "f_1": 1.1,
      "f_2": -1.2,
      "f_3": 0.3,
      "f_4": 2.1,
      "months_since_signup": 3,
      "calendar_month": 3,
      "signup_month": 12,
      "is_first_month": 1
    }
  ]')
echo "Response: $BATCH"

if echo "$BATCH" | grep -q 'churn_probability'; then
    echo "✓ Batch prediction passed"
else
    echo "❌ Batch prediction failed"
    exit 1
fi
echo ""

echo "✅ All tests passed!"
echo ""
echo "Access Swagger UI at: http://$SERVICE_IP/docs"
