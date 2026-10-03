#!/bin/bash

set -e

echo "📦 Installing ArgoCD..."

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Install with: brew install helm"
    exit 1
fi

# Create argocd namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# Install ArgoCD using Helm (lightweight version)
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set redis.enabled=true \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30080 \
  --wait \
  --timeout 5m

echo ""
echo "✅ ArgoCD installed!"
echo ""
echo "Access ArgoCD:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Open: https://localhost:8080"
echo ""
echo "Or via NodePort:"
echo "  Open: http://localhost:30080"
echo ""
echo "Default credentials:"
echo "  Username: admin"
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "admin")
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "Commands:"
echo "  argocd login localhost:30080 --username admin --password $ARGOCD_PASSWORD --insecure"
echo "  argocd app list"
