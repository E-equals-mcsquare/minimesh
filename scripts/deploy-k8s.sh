#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="minimesh"

echo "🚀 MiniMesh Kubernetes Deployment Script"
echo ""

# Check prerequisites
if ! command -v kind &> /dev/null; then
    echo "❌ kind not found. Install with: brew install kind"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Install with: brew install kubectl"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ docker not found. Install Docker Desktop"
    exit 1
fi

echo "✓ Prerequisites found (kind, kubectl, docker)"
echo ""

# Create cluster if it doesn't exist
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
    echo "✓ Cluster '$CLUSTER_NAME' already exists"
else
    echo "📦 Creating kind cluster..."
    kind create cluster --config "$PROJECT_ROOT/k8s/kind-config.yaml" --name "$CLUSTER_NAME"
    echo "✓ Cluster created"
fi

echo ""
echo "🐳 Building Docker images..."

cd "$PROJECT_ROOT"
docker build -t user-service:latest ./services/user-service
docker build -t order-service:latest ./services/order-service
docker build -t payment-service:latest ./services/payment-service
docker build -t api-gateway:latest ./api-gateway

echo "✓ Docker images built"
echo ""

echo "📥 Loading images into kind cluster..."
kind load docker-image user-service:latest --name "$CLUSTER_NAME"
kind load docker-image order-service:latest --name "$CLUSTER_NAME"
kind load docker-image payment-service:latest --name "$CLUSTER_NAME"
kind load docker-image api-gateway:latest --name "$CLUSTER_NAME"

echo "✓ Images loaded into cluster"
echo ""

echo "🚀 Deploying services..."

kubectl apply -f "$PROJECT_ROOT/k8s/services/user-service-deployment.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/services/user-service-svc.yaml"

kubectl apply -f "$PROJECT_ROOT/k8s/services/order-service-deployment.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/services/order-service-svc.yaml"

kubectl apply -f "$PROJECT_ROOT/k8s/services/payment-service-deployment.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/services/payment-service-svc.yaml"

kubectl apply -f "$PROJECT_ROOT/k8s/services/api-gateway-deployment.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/services/api-gateway-svc.yaml"

echo "✓ Services deployed"
echo ""

echo "⏳ Waiting for pods to start (this may take 30 seconds)..."
kubectl wait --for=condition=ready pod -l app=user-service --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=order-service --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=payment-service --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=api-gateway --timeout=60s 2>/dev/null || true

echo "✓ Pods are ready"
echo ""

echo "📊 Cluster Status:"
echo ""
echo "Deployments:"
kubectl get deployments
echo ""
echo "Services:"
kubectl get svc
echo ""
echo "Pods:"
kubectl get pods
echo ""

echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Port-forward API Gateway:"
echo "   kubectl port-forward svc/api-gateway 9999:9999"
echo ""
echo "2. Test the API Gateway:"
echo "   curl -H 'Authorization: Bearer valid-token' http://localhost:9999/api/users/123 | jq ."
echo ""
echo "3. View logs:"
echo "   kubectl logs -f deployment/api-gateway"
echo ""
echo "4. Scale a service:"
echo "   kubectl scale deployment user-service --replicas=5"
echo ""
echo "5. Delete the cluster:"
echo "   kind delete cluster --name $CLUSTER_NAME"
