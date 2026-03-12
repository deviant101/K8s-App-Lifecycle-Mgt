#!/usr/bin/env bash
# =============================================================================
# Task 4 – Roll back the Deployment to a previous stable version
# Run:    bash k8s/04-rollback/rollback.sh
# =============================================================================
set -euo pipefail

NAMESPACE="webapp"
DEPLOYMENT="nginx-deployment"

separator() { echo; echo "─────────────────────────────────────────"; echo "$*"; echo "─────────────────────────────────────────"; }

# ── 1. Inspect rollout history ────────────────────────────────────────────────
separator "Rollout History"
kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE"

# ── 2. View details of a specific revision ───────────────────────────────────
separator "Revision 1 details"
kubectl rollout history deployment/"$DEPLOYMENT" --revision=1 -n "$NAMESPACE"

# ── 3. Roll back to the PREVIOUS revision ────────────────────────────────────
separator "Rolling back to previous revision (nginx:1.24)"
kubectl rollout undo deployment/"$DEPLOYMENT" -n "$NAMESPACE"

# To roll back to a specific revision number instead:
#   kubectl rollout undo deployment/"$DEPLOYMENT" --to-revision=1 -n "$NAMESPACE"

echo "Waiting for rollback to complete..."
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE"

# ── 4. Verify the active image ───────────────────────────────────────────────
separator "Active image after rollback"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

echo; echo "Current pods:"
kubectl get pods -n "$NAMESPACE" -l app=nginx
