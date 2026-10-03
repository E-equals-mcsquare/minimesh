# MiniMesh: A Hands-On Networking Lab

A educational platform-engineering project that builds a realistic networking lab for learning:

- Proxies and reverse proxies
- L4 vs L7
- Control plane vs data plane
- API Gateways
- Kubernetes Ingress
- Envoy
- Service mesh concepts
- Failure scenarios
- Traffic management

## Building Incrementally

This project is built in **milestones**. Each milestone introduces new networking concepts and is fully functional before moving to the next.

---

## Milestone 1: Three Standalone Services

### Architecture

```
Client
  |
  +---> User Service      (port 8001)
  |
  +---> Order Service     (port 8002)
  |
  +---> Payment Service   (port 8003)
```

### Services

#### user-service (port 8001)
- `GET /health` - Health check
- `GET /users/{id}` - Get user by ID

#### order-service (port 8002)
- `GET /health` - Health check
- `GET /orders/{id}` - Get order by ID

#### payment-service (port 8003)
- `GET /health` - Health check
- `POST /payments` - Process a payment

### What We Built

Three simple Go HTTP services:

1. **user-service**: Returns user information by ID
2. **order-service**: Returns order information by ID
3. **payment-service**: Processes payment requests

Each service demonstrates:
- Structured logging (JSON format with request metadata)
- Graceful shutdown (handles SIGINT/SIGTERM)
- Health check endpoint
- Simple HTTP request/response handling
- Request timing and status tracking

### Running the Services

#### Option 1: Run Each Service Separately

Terminal 1:
```bash
make run-user
```

Terminal 2:
```bash
make run-order
```

Terminal 3:
```bash
make run-payment
```

#### Option 2: Run All Services in tmux (Recommended)

```bash
make run-all
```

This opens all three services in a split tmux window. You can see all logs at once.

- Attach: `tmux attach-session -t minimesh`
- Detach: `Ctrl+B` then `d`
- Kill: `tmux kill-session -t minimesh`

### Testing the Services

Test individual services:
```bash
make test-user
make test-order
make test-payment
```

Or test all at once:
```bash
make test-all
```

### Example Requests

#### User Service
```bash
curl -s http://localhost:8001/health | jq .
curl -s http://localhost:8001/users/123 | jq .
```

Expected output:
```json
{
  "id": "123",
  "name": "User 123",
  "email": "user123@example.com"
}
```

#### Order Service
```bash
curl -s http://localhost:8002/health | jq .
curl -s http://localhost:8002/orders/456 | jq .
```

Expected output:
```json
{
  "id": "456",
  "user_id": "user-123",
  "total": 99.99,
  "status": "completed"
}
```

#### Payment Service
```bash
curl -s http://localhost:8003/health | jq .
curl -s -X POST http://localhost:8003/payments \
  -H "Content-Type: application/json" \
  -d '{"order_id":"789","amount":99.99}' | jq .
```

Expected output:
```json
{
  "transaction_id": "txn-1695123456",
  "order_id": "789",
  "amount": 99.99,
  "status": "processed",
  "timestamp": "2024-09-26T12:00:00Z"
}
```

---

## What This Demonstrates

### ✅ Direct Service Communication

Each service runs independently on its own port. The client connects directly to each service.

### ✅ Structured Logging

Every request is logged with:
- Service name
- HTTP method
- Request path
- HTTP status code
- Request latency (milliseconds)
- Timestamp

Watch the logs while making requests—you'll see structured JSON output.

### ✅ Graceful Shutdown

Each service handles `SIGINT` (Ctrl+C) and `SIGTERM` gracefully:

```bash
# Stop a service with Ctrl+C
# It will log "Shutting down..." and complete in-flight requests
```

---

## Limitations: Why This Isn't Enough

This architecture has problems:

### 1. **Direct Service Addresses**
- Clients must know the exact address and port of each service
- If we move a service to a different port, all clients break
- No service discovery

### 2. **No Path Routing**
- Each service listens on a different port
- We can't route `/api/users` and `/api/orders` to the same port
- Users must remember which port is which

### 3. **No Load Balancing**
- If user-service gets 1000 requests/sec, they all hit one instance
- We can't run multiple instances of user-service

### 4. **No Authentication**
- Clients can call any endpoint without authorization
- No rate limiting or throttling

### 5. **No Visibility**
- Logs are scattered across three different processes
- No correlation between requests
- Hard to see which service is slow

### 6. **No Resilience**
- No retries if a service is temporarily unavailable
- No timeouts
- No circuit breaking

### 7. **No Traffic Control**
- All requests go to 100% of the instances
- We can't do canary deployments or traffic splitting

---

## 📝 Hands-On Experiment

### Experiment 1: Watch Request Logs

1. Start all services: `make run-all`
2. In another terminal, run: `make test-all`
3. Watch the logs in the tmux window
4. Notice the structured JSON logs with latency, status, and timestamp

### Experiment 2: Kill a Service

1. Start all services: `make run-all`
2. Kill the order-service window in tmux (`Ctrl+C` in the order-service window)
3. Try to test it: `curl -s http://localhost:8002/health`
4. You get a connection refused error
5. Restart it: `make run-order` in a new terminal

**Learning**: Direct service dependencies are fragile—if one service goes down, clients can't reach it and get connection errors.

### Experiment 3: Different Response Times

Modify `payment-service/main.go` to add artificial delay:

```go
func paymentsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	
	// Add delay
	time.Sleep(2 * time.Second)
	
	// ... rest of handler
}
```

Then rebuild and run:
```bash
make clean
make run-payment
```

Test it:
```bash
time curl -s -X POST http://localhost:8003/payments \
  -H "Content-Type: application/json" \
  -d '{"order_id":"789","amount":99.99}' | jq .
```

**Learning**: Without timeouts or retries, slow services block clients indefinitely.

---

## 🎓 Key Takeaways

1. **Each service runs independently** on its own port
2. **Clients must know service addresses** directly
3. **No routing or load balancing** at this level
4. **Distributed system challenges** become immediately apparent
5. **We need a proxy layer** to solve these problems

---

## Next Milestone

When you're ready to move to **Milestone 2**, we'll introduce **NGINX as a reverse proxy**:

- Single entry point instead of three
- Path-based routing: `/api/users` → user-service, etc.
- The beginning of L7 proxying concepts
- Why proxies are essential in distributed systems

---

## Clean Up

Stop all services:
```bash
# If using tmux: tmux kill-session -t minimesh
# If running separately: Ctrl+C in each terminal
```

Remove binaries:
```bash
make clean
```

---

## Requirements

- Go 1.21 or later
- `curl` for testing
- `jq` for pretty-printing JSON (optional but recommended)
- `tmux` for running all services together (optional)

---

## Commands Quick Reference

```bash
make help              # Show all commands
make build             # Build all services
make run-all           # Start all services (requires tmux)
make run-user          # Start user-service only
make run-order         # Start order-service only
make run-payment       # Start payment-service only
make test-all          # Test all services
make test-user         # Test user-service only
make test-order        # Test order-service only
make test-payment      # Test payment-service only
make clean             # Remove binaries
```
