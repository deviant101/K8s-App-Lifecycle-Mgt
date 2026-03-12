#!/usr/bin/env bash
# =============================================================================
# Task 2 – Scale the Deployment up and down
# Run:    bash k8s/02-scale/scale.sh
# =============================================================================
set -euo pipefail

NAMESPACE="webapp"
DEPLOYMENT="nginx-deployment"

separator() { echo; echo "─────────────────────────────────────────"; echo "$*"; echo "─────────────────────────────────────────"; }

# ── Scale UP to 5 replicas ────────────────────────────────────────────────────
separator "Scaling UP → 5 replicas"
kubectl scale deployment "$DEPLOYMENT" --replicas=5 -n "$NAMESPACE"

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE"

echo; echo "Current pod state:"
kubectl get pods -n "$NAMESPACE" -l app=nginx

# ── Scale DOWN to 2 replicas ──────────────────────────────────────────────────
separator "Scaling DOWN → 2 replicas"
kubectl scale deployment "$DEPLOYMENT" --replicas=2 -n "$NAMESPACE"

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE"

echo; echo "Current pod state:"
kubectl get pods -n "$NAMESPACE" -l app=nginx

# ── Alternative: declarative patch ───────────────────────────────────────────
# kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" \
#   -p '{"spec":{"replicas":3}}'
