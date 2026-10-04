.PHONY: help build build-l4 build-control-plane build-data-plane build-api-gateway run-user run-order run-payment run-all run-nginx stop-nginx run-l4 stop-l4 run-control-plane stop-control-plane run-data-plane stop-data-plane run-api-gateway stop-api-gateway test-user test-order test-payment test-all test-nginx test-l4 test-control-plane test-data-plane test-api-gateway run-all-with-proxy run-all-l4-l7 run-all-control-data run-all-api-gateway logs-nginx k8s-deploy k8s-build-images k8s-cluster-create k8s-deploy-only k8s-status k8s-test k8s-clean monitoring-install monitoring-clean kube-state-metrics-install grafana-dashboard-install ingress-install ingress-test ingress-clean envoy-install envoy-test envoy-break envoy-restore envoy-admin argocd-install argocd-clean argocd-reinstall argocd-create-app clean

help:
	@echo "MiniMesh - Networking Lab"
	@echo ""
	@echo "Services (Milestone 1):"
	@echo "  make build              - Build all services"
	@echo "  make run-user           - Run user-service (port 8001)"
	@echo "  make run-order          - Run order-service (port 8002)"
	@echo "  make run-payment        - Run payment-service (port 8003)"
	@echo "  make run-all            - Run all services in tmux"
	@echo ""
	@echo "NGINX Reverse Proxy (Milestone 2):"
	@echo "  make run-nginx          - Start NGINX on port 8080"
	@echo "  make stop-nginx         - Stop NGINX"
	@echo "  make run-all-with-proxy - Run services + NGINX in tmux"
	@echo ""
	@echo "L4 Proxy (Milestone 3):"
	@echo "  make build-l4           - Build L4 TCP proxy"
	@echo "  make run-l4             - Start L4 proxy on port 9000"
	@echo "  make stop-l4            - Stop L4 proxy"
	@echo "  make test-l4            - Test L4 proxy routing"
	@echo "  make run-all-l4-l7      - Run services + NGINX + L4 proxy"
	@echo ""
	@echo "API Gateway (Milestone 4):"
	@echo "  make build-api-gateway      - Build API Gateway"
	@echo "  make run-api-gateway        - Start API Gateway on port 9999"
	@echo "  make stop-api-gateway       - Stop API Gateway"
	@echo "  make test-api-gateway       - Test API Gateway (auth, rate limit)"
	@echo "  make run-all-api-gateway    - Run services + API Gateway"
	@echo ""
	@echo "Control Plane & Data Plane (Milestone 4):"
	@echo "  make build-control-plane    - Build control plane"
	@echo "  make run-control-plane      - Start control plane on port 7000"
	@echo "  make stop-control-plane     - Stop control plane"
	@echo "  make build-data-plane       - Build data plane"
	@echo "  make run-data-plane         - Start data plane on port 8080"
	@echo "  make stop-data-plane        - Stop data plane"
	@echo "  make test-control-plane     - Test control plane"
	@echo "  make test-data-plane        - Test data plane"
	@echo "  make run-all-control-data   - Run services + control + data plane"
	@echo ""
	@echo "Kubernetes (Milestone 5):"
	@echo "  make k8s-deploy             - Full deployment (create cluster, build, deploy)"
	@echo "  make k8s-cluster-create     - Create local kind cluster"
	@echo "  make k8s-build-images       - Build Docker images for all services"
	@echo "  make k8s-deploy-only        - Deploy to existing cluster"
	@echo "  make k8s-status             - Check cluster status"
	@echo "  make k8s-test               - Test services in cluster"
	@echo "  make k8s-clean              - Delete kind cluster"
	@echo ""
	@echo "Observability (Monitoring):"
	@echo "  make monitoring-install           - Install Prometheus + Grafana"
	@echo "  make kube-state-metrics-install   - Install kube-state-metrics (Kubernetes metrics)"
	@echo "  make grafana-dashboard-install    - Install MiniMesh Grafana Dashboard"
	@echo "  make monitoring-clean             - Remove Prometheus + Grafana"
	@echo ""
	@echo "Kubernetes Ingress:"
	@echo "  make ingress-install        - Install ingress-nginx + MiniMesh Ingress rules"
	@echo "  make ingress-test           - Test Ingress routing (/api/users, /api/orders, /api/payments)"
	@echo "  make ingress-clean          - Remove Ingress resources + controller"
	@echo ""
	@echo "Envoy Sidecar (order-service -> payment-service):"
	@echo "  make envoy-install          - Install Envoy sidecar on order-service"
	@echo "  make envoy-test             - Test proxying + the timeout experiment"
	@echo "  make envoy-break            - Scale payment-service to 0 (retry experiment)"
	@echo "  make envoy-restore          - Restore payment-service replicas"
	@echo "  make envoy-admin            - Port-forward Envoy's admin interface"
	@echo ""
	@echo "GitOps (ArgoCD):"
	@echo "  make argocd-install         - Install ArgoCD"
	@echo "  make argocd-create-app      - Create ArgoCD Application"
	@echo "  make argocd-clean           - Remove ArgoCD"
	@echo "  make argocd-reinstall       - Clean and reinstall ArgoCD"
	@echo ""
	@echo "Access (Port-forward):"
	@echo "  Prometheus:  kubectl port-forward -n monitoring svc/prometheus 9090:9090"
	@echo "  Grafana:     kubectl port-forward -n monitoring svc/grafana 3000:3000"
	@echo "  ArgoCD:      kubectl port-forward -n argocd svc/argocd-server 8080:443"
	@echo ""
	@echo "Testing:"
	@echo "  make test-user          - Test user-service"
	@echo "  make test-order         - Test order-service"
	@echo "  make test-payment       - Test payment-service"
	@echo "  make test-all           - Test all services"
	@echo "  make test-nginx         - Test NGINX routing (L7)"
	@echo "  make test-l4            - Test L4 proxy routing"
	@echo ""
	@echo "Observability:"
	@echo "  make logs-nginx         - Tail NGINX access logs"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean              - Remove binaries, logs, stop all proxies"

build:
	@echo "Building services..."
	@go build -o bin/user-service ./services/user-service
	@go build -o bin/order-service ./services/order-service
	@go build -o bin/payment-service ./services/payment-service
	@echo "Build complete!"

build-l4:
	@echo "Building L4 proxy..."
	@go build -o bin/l4-proxy ./l4-proxy
	@echo "L4 proxy build complete!"

build-control-plane:
	@echo "Building control plane..."
	@go build -o bin/control-plane ./control-plane
	@echo "Control plane build complete!"

build-data-plane:
	@echo "Building data plane..."
	@go build -o bin/data-plane ./data-plane
	@echo "Data plane build complete!"

build-api-gateway:
	@echo "Building API Gateway..."
	@go build -o bin/api-gateway ./api-gateway
	@echo "API Gateway build complete!"

run-user: build
	@echo "Starting user-service on port 8001..."
	@./bin/user-service

run-order: build
	@echo "Starting order-service on port 8002..."
	@./bin/order-service

run-payment: build
	@echo "Starting payment-service on port 8003..."
	@./bin/payment-service

run-all: build
	@echo "Starting all services..."
	@tmux new-session -d -s minimesh -x 200 -y 50
	@tmux send-keys -t minimesh "cd $(PWD) && ./bin/user-service" Enter
	@tmux split-window -t minimesh -h "cd $(PWD) && ./bin/order-service"
	@tmux split-window -t minimesh -h "cd $(PWD) && ./bin/payment-service"
	@tmux select-layout -t minimesh even-horizontal
	@echo "Services started in tmux session 'minimesh'"
	@echo "Attach with: tmux attach-session -t minimesh"
	@echo "Detach with: Ctrl+B d"
	@echo "Kill with: tmux kill-session -t minimesh"

run-nginx:
	@echo "Starting NGINX on port 80..."
	@echo "Config: $(PWD)/nginx/nginx.conf"
	@nginx -c "$(PWD)/nginx/nginx.conf"
	@echo "NGINX started"
	@echo "Test with: make test-nginx"

stop-nginx:
	@echo "Stopping NGINX..."
	@nginx -s stop -c "$(PWD)/nginx/nginx.conf" 2>/dev/null || echo "NGINX not running"
	@echo "NGINX stopped"

run-l4: build-l4
	@echo "Starting L4 proxy on port 9000..."
	@echo "Forwarding to localhost:8001 (user-service)"
	@./bin/l4-proxy

stop-l4:
	@echo "Stopping L4 proxy..."
	@pkill -f "l4-proxy" 2>/dev/null || echo "L4 proxy not running"
	@echo "L4 proxy stopped"

run-control-plane: build-control-plane
	@echo "Starting control plane on port 7000..."
	@echo "Configuration service - source of truth for routing"
	@./bin/control-plane

stop-control-plane:
	@echo "Stopping control plane..."
	@pkill -f "control-plane" 2>/dev/null || echo "Control plane not running"
	@echo "Control plane stopped"

run-data-plane: build-data-plane
	@echo "Starting data plane on port 8080..."
	@echo "Fetching config from control plane at :7000"
	@./bin/data-plane

stop-data-plane:
	@echo "Stopping data plane..."
	@pkill -f "data-plane" 2>/dev/null || echo "Data plane not running"
	@echo "Data plane stopped"

run-api-gateway: build-api-gateway
	@echo "Starting API Gateway on port 9999..."
	@echo "Features: authentication, rate limiting, request IDs"
	@echo "Valid tokens: demo-token-1, demo-token-2, valid-token"
	@./bin/api-gateway

stop-api-gateway:
	@echo "Stopping API Gateway..."
	@pkill -f "api-gateway" 2>/dev/null || echo "API Gateway not running"
	@echo "API Gateway stopped"

run-all-with-proxy: build
	@echo "Starting services + NGINX..."
	@tmux new-session -d -s minimesh-proxy -x 200 -y 50
	@tmux send-keys -t minimesh-proxy "cd $(PWD) && ./bin/user-service" Enter
	@tmux split-window -t minimesh-proxy -h "cd $(PWD) && ./bin/order-service"
	@tmux split-window -t minimesh-proxy -h "cd $(PWD) && ./bin/payment-service"
	@tmux select-layout -t minimesh-proxy even-horizontal
	@echo "Services started in tmux session 'minimesh-proxy'"
	@sleep 2
	@echo "Starting NGINX..."
	@nginx -c "$(PWD)/nginx/nginx.conf"
	@echo ""
	@echo "✅ All services and NGINX are running"
	@echo "Attach to services: tmux attach-session -t minimesh-proxy"
	@echo "Test routing: make test-nginx"
	@echo "Watch logs: make logs-nginx"
	@echo "Stop all: make stop-nginx && tmux kill-session -t minimesh-proxy"

run-all-l4-l7: build build-l4
	@echo "Starting services + NGINX (L7) + L4 proxy..."
	@tmux new-session -d -s minimesh-l4-l7 -x 200 -y 50
	@tmux send-keys -t minimesh-l4-l7 "cd $(PWD) && ./bin/user-service" Enter
	@tmux split-window -t minimesh-l4-l7 -h "cd $(PWD) && ./bin/order-service"
	@tmux split-window -t minimesh-l4-l7 -h "cd $(PWD) && ./bin/payment-service"
	@tmux select-layout -t minimesh-l4-l7 even-horizontal
	@echo "Services started in tmux session 'minimesh-l4-l7'"
	@sleep 2
	@echo "Starting NGINX (L7 proxy on port 8080)..."
	@nginx -c "$(PWD)/nginx/nginx.conf"
	@sleep 1
	@echo "Starting L4 proxy (port 9000)..."
	@./bin/l4-proxy &
	@echo ""
	@echo "✅ All services, NGINX (L7), and L4 proxy are running"
	@echo "Attach to services: tmux attach-session -t minimesh-l4-l7"
	@echo "Test L4 (all → 8001): make test-l4"
	@echo "Test L7 (intelligent routing): make test-nginx"
	@echo "Stop all: make stop-l4 && make stop-nginx && tmux kill-session -t minimesh-l4-l7"

run-all-control-data: build build-control-plane build-data-plane
	@echo "Starting services + control plane + data plane..."
	@tmux new-session -d -s minimesh-cp-dp -x 200 -y 50
	@tmux send-keys -t minimesh-cp-dp "cd $(PWD) && ./bin/user-service" Enter
	@tmux split-window -t minimesh-cp-dp -h "cd $(PWD) && ./bin/order-service"
	@tmux split-window -t minimesh-cp-dp -h "cd $(PWD) && ./bin/payment-service"
	@tmux select-layout -t minimesh-cp-dp even-horizontal
	@echo "Services started in tmux session 'minimesh-cp-dp'"
	@sleep 2
	@echo "Starting control plane on port 7000..."
	@./bin/control-plane > /tmp/control-plane.log 2>&1 &
	@sleep 1
	@echo "Starting data plane on port 8080..."
	@./bin/data-plane > /tmp/data-plane.log 2>&1 &
	@echo ""
	@echo "✅ All services, control plane, and data plane are running"
	@echo "Attach to services: tmux attach-session -t minimesh-cp-dp"
	@echo ""
	@echo "Test control plane: make test-control-plane"
	@echo "Test data plane: make test-data-plane"
	@echo ""
	@echo "Watch logs:"
	@echo "  tail -f /tmp/control-plane.log"
	@echo "  tail -f /tmp/data-plane.log"
	@echo ""
	@echo "Stop all: make stop-control-plane && make stop-data-plane && tmux kill-session -t minimesh-cp-dp"

run-all-api-gateway: build build-api-gateway
	@echo "Starting services + API Gateway..."
	@tmux new-session -d -s minimesh-gw -x 200 -y 50
	@tmux send-keys -t minimesh-gw "cd $(PWD) && ./bin/user-service" Enter
	@tmux split-window -t minimesh-gw -h "cd $(PWD) && ./bin/order-service"
	@tmux split-window -t minimesh-gw -h "cd $(PWD) && ./bin/payment-service"
	@tmux select-layout -t minimesh-gw even-horizontal
	@echo "Services started in tmux session 'minimesh-gw'"
	@sleep 2
	@echo "Starting API Gateway on port 9999..."
	@./bin/api-gateway > /tmp/api-gateway.log 2>&1 &
	@echo ""
	@echo "✅ All services and API Gateway are running"
	@echo "Attach to services: tmux attach-session -t minimesh-gw"
	@echo ""
	@echo "Test API Gateway: make test-api-gateway"
	@echo ""
	@echo "Watch logs: tail -f /tmp/api-gateway.log"
	@echo ""
	@echo "Stop all: make stop-api-gateway && tmux kill-session -t minimesh-gw"

logs-nginx:
	@echo "Tailing NGINX access log (Ctrl+C to stop)..."
	@tail -f /tmp/nginx_access.log

test-user:
	@echo "Testing user-service..."
	@echo "  GET /health"
	@curl -s http://localhost:8001/health | jq .
	@echo ""
	@echo "  GET /users/123"
	@curl -s http://localhost:8001/users/123 | jq .

test-order:
	@echo "Testing order-service..."
	@echo "  GET /health"
	@curl -s http://localhost:8002/health | jq .
	@echo ""
	@echo "  GET /orders/456"
	@curl -s http://localhost:8002/orders/456 | jq .

test-payment:
	@echo "Testing payment-service..."
	@echo "  GET /health"
	@curl -s http://localhost:8003/health | jq .
	@echo ""
	@echo "  POST /payments"
	@curl -s -X POST http://localhost:8003/payments \
		-H "Content-Type: application/json" \
		-d '{"order_id":"789","amount":99.99}' | jq .

test-all: test-user test-order test-payment

test-nginx:
	@echo "Testing NGINX reverse proxy (L7 - port 8080)..."
	@echo ""
	@echo "  GET /api/users/123 (routes to 8001)"
	@curl -s http://localhost:8080/api/users/123 | jq .
	@echo ""
	@echo "  GET /api/orders/456 (routes to 8002)"
	@curl -s http://localhost:8080/api/orders/456 | jq .
	@echo ""
	@echo "  POST /api/payments (routes to 8003)"
	@curl -s -X POST http://localhost:8080/api/payments \
		-H "Content-Type: application/json" \
		-d '{"order_id":"789","amount":99.99}' | jq .
	@echo ""
	@echo "  GET /health (NGINX health)"
	@curl -s http://localhost:8080/health | jq .

test-l4:
	@echo "Testing L4 proxy (port 9000)..."
	@echo "Note: L4 proxy routes ALL requests to 8001 (user-service)"
	@echo ""
	@echo "  GET /users/123 (L4 forwards to 8001)"
	@curl -s http://localhost:9000/users/123 | jq .
	@echo ""
	@echo "  GET /orders/456 (L4 also forwards to 8001)"
	@curl -s http://localhost:9000/orders/456 | jq .
	@echo ""
	@echo "  GET /payments (L4 also forwards to 8001)"
	@curl -s http://localhost:9000/payments | jq .
	@echo ""
	@echo "⚠️  All requests went to port 8001!"
	@echo "L4 proxy can't read paths, so it forwards everything to the same backend."
	@echo ""
	@echo "Compare with L7 (make test-nginx):"
	@echo "L7 reads paths and routes intelligently to different backends."

test-control-plane:
	@echo "Testing control plane (port 7000)..."
	@echo ""
	@echo "  GET /config (fetch routing configuration)"
	@curl -s http://localhost:7000/config | jq .
	@echo ""
	@echo "  GET /health (control plane health)"
	@curl -s http://localhost:7000/health | jq .

test-data-plane:
	@echo "Testing data plane (port 8080)..."
	@echo "Data plane fetches config from control plane and uses it for routing"
	@echo ""
	@echo "  GET /api/users/123 (routed via data plane)"
	@curl -s http://localhost:8080/api/users/123 | jq .
	@echo ""
	@echo "  GET /api/orders/456 (routed via data plane)"
	@curl -s http://localhost:8080/api/orders/456 | jq .
	@echo ""
	@echo "  GET /api/payments (routed via data plane)"
	@curl -s http://localhost:8080/api/payments | jq .
	@echo ""
	@echo "  GET /_status (data plane status)"
	@curl -s http://localhost:8080/_status | jq .

test-api-gateway:
	@echo "Testing API Gateway (port 9999)..."
	@echo ""
	@echo "Test 1: Valid request with valid token (should succeed)"
	@curl -s -H "Authorization: Bearer valid-token" http://localhost:9999/api/users/123 | jq .
	@echo ""
	@echo "Test 2: Missing auth header (should fail with 401)"
	@curl -s http://localhost:9999/api/users/123 | jq .
	@echo ""
	@echo "Test 3: Invalid token (should fail with 401)"
	@curl -s -H "Authorization: Bearer invalid-token" http://localhost:9999/api/users/123 | jq .
	@echo ""
	@echo "Test 4: Rate limiting (10 requests, first 5 succeed, next 5 fail)"
	@for i in {1..10}; do \
		curl -s -H "Authorization: Bearer valid-token" http://localhost:9999/api/users/123 | jq '.error // "success"'; \
	done
	@echo ""
	@echo "Test 5: API Gateway status"
	@curl -s http://localhost:9999/_status | jq .

k8s-deploy:
	@echo "🚀 Starting full Kubernetes deployment..."
	@chmod +x scripts/deploy-k8s.sh
	@scripts/deploy-k8s.sh

k8s-cluster-create:
	@echo "📦 Creating kind cluster..."
	@kind create cluster --config k8s/kind-config.yaml --name minimesh
	@echo "✅ Cluster created!"

k8s-build-images:
	@echo "🐳 Building Docker images..."
	@docker build -t user-service:latest ./services/user-service
	@docker build -t order-service:latest ./services/order-service
	@docker build -t payment-service:latest ./services/payment-service
	@docker build -t api-gateway:latest ./api-gateway
	@echo "✅ Docker images built!"

k8s-deploy-only:
	@echo "📥 Deploying to Kubernetes..."
	@kubectl apply -f k8s/services/user-service-deployment.yaml
	@kubectl apply -f k8s/services/user-service-svc.yaml
	@kubectl apply -f k8s/services/order-service-deployment.yaml
	@kubectl apply -f k8s/services/order-service-svc.yaml
	@kubectl apply -f k8s/services/payment-service-deployment.yaml
	@kubectl apply -f k8s/services/payment-service-svc.yaml
	@kubectl apply -f k8s/services/api-gateway-deployment.yaml
	@kubectl apply -f k8s/services/api-gateway-svc.yaml
	@echo "✅ Services deployed!"
	@echo ""
	@echo "Waiting for pods to start..."
	@sleep 5
	@kubectl get pods
	@echo ""
	@echo "Next: make k8s-test"

k8s-status:
	@echo "📊 Kubernetes Cluster Status"
	@echo ""
	@echo "Deployments:"
	@kubectl get deployments
	@echo ""
	@echo "Pods:"
	@kubectl get pods
	@echo ""
	@echo "Services:"
	@kubectl get svc

k8s-test:
	@echo "🧪 Testing Kubernetes deployment..."
	@echo ""
	@echo "Port-forward API Gateway (run in another terminal):"
	@echo "  kubectl port-forward svc/api-gateway 9999:9999"
	@echo ""
	@echo "Then test with:"
	@echo "  curl -H 'Authorization: Bearer valid-token' http://localhost:9999/api/users/123 | jq ."
	@echo ""
	@echo "Or test from inside cluster:"
	@echo "  kubectl exec -it deployment/api-gateway -- sh"
	@echo "  curl http://user-service:8001/health"

k8s-clean:
	@echo "🗑️  Deleting kind cluster..."
	@kind delete cluster --name minimesh
	@echo "✅ Cluster deleted!"

monitoring-install:
	@echo "📊 Installing Prometheus + Grafana..."
	@kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
	@kubectl apply -f k8s/monitoring/prometheus-config.yaml
	@kubectl apply -f k8s/monitoring/grafana-deployment.yaml
	@echo ""
	@echo "⏳ Waiting for Prometheus..."
	@kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=60s 2>/dev/null || true
	@echo "⏳ Waiting for Grafana..."
	@kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=60s 2>/dev/null || true
	@echo ""
	@echo "✅ Prometheus + Grafana installed!"
	@echo ""
	@echo "Access them:"
	@echo "  Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
	@echo "  Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:3000"
	@echo ""
	@echo "Grafana credentials:"
	@echo "  Username: admin"
	@echo "  Password: admin"
	@echo ""
	@echo "Grafana is already configured to use Prometheus as a data source."

grafana-dashboard-install:
	@echo "📊 Installing MiniMesh Grafana Dashboard..."
	@kubectl apply -f k8s/monitoring/grafana-dashboard-configmap.yaml
	@echo ""
	@echo "⏳ Restarting Grafana pod to load dashboard..."
	@kubectl rollout restart deployment/grafana -n monitoring
	@kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=60s 2>/dev/null || true
	@echo ""
	@echo "✅ Dashboard installed!"
	@echo ""
	@echo "View dashboard:"
	@echo "  kubectl port-forward -n monitoring svc/grafana 3000:3000"
	@echo "  Open: http://localhost:3000"
	@echo "  Login: admin / admin"
	@echo "  Dashboard: MiniMesh Platform Engineering Lab"

kube-state-metrics-install:
	@echo "📊 Installing kube-state-metrics..."
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update
	@helm install kube-state-metrics prometheus-community/kube-state-metrics -n monitoring --wait
	@echo ""
	@echo "⏳ Waiting for kube-state-metrics to be ready..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-state-metrics -n monitoring --timeout=60s 2>/dev/null || true
	@echo ""
	@echo "✅ kube-state-metrics installed!"
	@echo ""
	@echo "Prometheus will now have access to Kubernetes metrics:"
	@echo "  - kube_pod_info"
	@echo "  - kube_pod_status_phase"
	@echo "  - kube_deployment_status_replicas"
	@echo "  - container_memory_usage_bytes"
	@echo "  - container_cpu_usage_seconds_total"

monitoring-clean:
	@echo "🗑️  Removing Prometheus + Grafana..."
	@kubectl delete namespace monitoring --ignore-not-found=true
	@echo "✅ Monitoring stack removed"

ingress-install:
	@echo "🌐 Labeling control-plane node as ingress-ready..."
	@kubectl label node minimesh-control-plane ingress-ready=true --overwrite
	@echo ""
	@echo "🌐 Installing ingress-nginx controller..."
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo ""
	@echo "⏳ Waiting for ingress-nginx controller to be ready..."
	@kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
	@echo ""
	@echo "🌐 Applying MiniMesh Ingress rules..."
	@kubectl apply -f k8s/ingress/ingress.yaml
	@echo ""
	@echo "✅ Ingress installed!"
	@echo ""
	@echo "Test it:"
	@echo "  curl http://localhost/api/users/123"
	@echo "  curl http://localhost/api/orders/123"
	@echo "  curl -X POST http://localhost/api/payments -d '{\"order_id\":\"123\",\"amount\":99.99}'"

ingress-test:
	@echo "🧪 Testing Ingress routing..."
	@echo ""
	@echo "GET /api/users/123:"
	@curl -s http://localhost/api/users/123
	@echo ""
	@echo ""
	@echo "GET /api/orders/123:"
	@curl -s http://localhost/api/orders/123
	@echo ""
	@echo ""
	@echo "POST /api/payments:"
	@curl -s -X POST http://localhost/api/payments -H "Content-Type: application/json" -d '{"order_id":"123","amount":99.99}'
	@echo ""
	@echo ""
	@echo "GET /orders/123 (no /api prefix — expect 404 from nginx):"
	@curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost/orders/123

ingress-clean:
	@echo "🗑️  Removing Ingress resources..."
	@kubectl delete -f k8s/ingress/ingress.yaml --ignore-not-found=true
	@kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml --ignore-not-found=true
	@echo "✅ Ingress removed"

envoy-install:
	@echo "🔀 Applying Envoy sidecar config..."
	@kubectl create configmap envoy-sidecar-config --from-file=envoy.yaml=k8s/envoy/envoy.yaml --dry-run=client -o yaml | kubectl apply -f -
	@echo ""
	@echo "🐳 Rebuilding order-service and payment-service images..."
	@docker build -t order-service:latest ./services/order-service
	@docker build -t payment-service:latest ./services/payment-service
	@kind load docker-image order-service:latest --name minimesh
	@kind load docker-image payment-service:latest --name minimesh
	@echo ""
	@echo "📥 Applying order-service deployment (adds the Envoy sidecar container)..."
	@kubectl apply -f k8s/services/order-service-deployment.yaml
	@kubectl rollout restart deployment/payment-service
	@kubectl rollout status deployment/order-service --timeout=90s
	@kubectl rollout status deployment/payment-service --timeout=60s
	@echo ""
	@echo "✅ Envoy sidecar installed!"
	@echo ""
	@echo "⚠️  If the ArgoCD minimesh-services Application has auto-sync enabled, it will"
	@echo "    revert this change back to whatever is in the Git repo. Disable it first:"
	@echo "    kubectl patch application minimesh-services -n argocd --type=merge -p '{\"spec\":{\"syncPolicy\":null}}'"
	@echo ""
	@echo "Test it: make envoy-test"

envoy-test:
	@echo "🧪 Testing Envoy sidecar proxying..."
	@echo ""
	@echo "GET /api/orders/123 (normal path: client -> Ingress -> order-service -> Envoy -> payment-service):"
	@curl -s http://localhost/api/orders/123
	@echo ""
	@echo ""
	@echo "Envoy access log for that request:"
	@sleep 1
	@kubectl logs -l app=order-service -c envoy-sidecar --tail=50 --prefix | grep "\[envoy\]" | grep -v "delay=" | tail -1
	@echo ""
	@echo "--- Timeout experiment (payment-service sleeps 3s; Envoy's route timeout is 2s) ---"
	@curl -s "http://localhost/api/orders/456?simulate_delay=3"
	@echo ""
	@sleep 1
	@kubectl logs -l app=order-service -c envoy-sidecar --tail=50 --prefix | grep "\[envoy\]" | grep "delay=" | tail -1
	@echo ""
	@echo "(watch for status=504, duration_ms=~2000, retries=UT -- Envoy's timeout fired, not payment-service's 3s sleep)"
	@echo ""
	@echo "--- Retry / connection-failure experiment: make envoy-break, then make envoy-restore ---"

envoy-break:
	@echo "💥 Scaling payment-service to 0 replicas (simulates a total outage)..."
	@kubectl scale deployment payment-service --replicas=0
	@sleep 3
	@echo ""
	@echo "GET /api/orders/999 (Envoy will retry, then give up):"
	@curl -s http://localhost/api/orders/999
	@echo ""
	@echo ""
	@echo "Envoy access log (watch for retries=URX,UF -- retries exhausted, upstream connect failure):"
	@sleep 1
	@kubectl logs -l app=order-service -c envoy-sidecar --tail=50 --prefix | grep "\[envoy\]" | grep "status=503" | tail -1
	@echo ""
	@echo "Restore with: make envoy-restore"

envoy-restore:
	@echo "🔧 Restoring payment-service to 2 replicas..."
	@kubectl scale deployment payment-service --replicas=2
	@kubectl rollout status deployment/payment-service --timeout=60s
	@echo "✅ Restored"

envoy-admin:
	@echo "📊 Port-forwarding Envoy admin interface on one order-service pod..."
	@POD=$$(kubectl get pod -l app=order-service -o jsonpath='{.items[0].metadata.name}'); \
	echo "Forwarding $$POD:9901 -> localhost:9901"; \
	echo "Open http://localhost:9901/clusters (upstream health) or /stats once forwarded"; \
	kubectl port-forward pod/$$POD 9901:9901

argocd-install:
	@echo "🚀 Installing ArgoCD..."
	@chmod +x scripts/install-argocd.sh
	@scripts/install-argocd.sh

argocd-clean:
	@echo "🗑️  Removing ArgoCD..."
	@helm uninstall argocd -n argocd 2>/dev/null || true
	@kubectl delete namespace argocd --ignore-not-found=true
	@echo "✅ ArgoCD removed"

argocd-reinstall: argocd-clean
	@echo ""
	@echo "🔄 Reinstalling ArgoCD..."
	@sleep 3
	@make argocd-install

argocd-create-app:
	@echo "📦 Creating ArgoCD Application..."
	@kubectl apply -f k8s/argocd/minimesh-app.yaml
	@echo ""
	@echo "✅ ArgoCD Application created!"
	@echo ""
	@echo "View in UI:"
	@echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
	@echo "  Open: https://localhost:8080"
	@echo ""
	@echo "Or check status:"
	@echo "  argocd app list"
	@echo "  argocd app info minimesh-services"

clean:
	@echo "Cleaning up..."
	@rm -f bin/user-service bin/order-service bin/payment-service bin/l4-proxy bin/control-plane bin/data-plane bin/api-gateway
	@rm -f /tmp/nginx_access.log /tmp/nginx_error.log /tmp/control-plane.log /tmp/data-plane.log /tmp/api-gateway.log
	@pkill -f "nginx -c" 2>/dev/null || true
	@pkill -f "l4-proxy" 2>/dev/null || true
	@pkill -f "control-plane" 2>/dev/null || true
	@pkill -f "data-plane" 2>/dev/null || true
	@pkill -f "api-gateway" 2>/dev/null || true
	@tmux kill-session -t minimesh 2>/dev/null || true
	@tmux kill-session -t minimesh-proxy 2>/dev/null || true
	@tmux kill-session -t minimesh-l4-l7 2>/dev/null || true
	@tmux kill-session -t minimesh-cp-dp 2>/dev/null || true
	@tmux kill-session -t minimesh-gw 2>/dev/null || true
	@echo "Cleanup complete"
