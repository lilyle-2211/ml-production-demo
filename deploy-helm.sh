#!/bin/bash
# Simple Helm deployment script

# Install
helm install churn-inference ./helm

# Upgrade
# helm upgrade churn-inference ./helm

# Uninstall
# helm uninstall churn-inference

# Status
# kubectl get all -l app.kubernetes.io/name=churn-inference
