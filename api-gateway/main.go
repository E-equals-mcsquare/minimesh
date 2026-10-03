package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

type Route struct {
	Path    string
	Backend string
	Port    int
}

type RateLimit struct {
	Limit   int
	Current int
	ResetAt time.Time
}

type APIGateway struct {
	routes     map[string]Route
	tokens     map[string]bool
	rateLimits map[string]*RateLimit
	mu         sync.RWMutex
}

func NewAPIGateway() *APIGateway {
	gw := &APIGateway{
		routes: map[string]Route{
			"/api/users": {
				Path:    "/api/users",
				Backend: "user-service",
				Port:    8001,
			},
			"/api/orders": {
				Path:    "/api/orders",
				Backend: "order-service",
				Port:    8002,
			},
			"/api/payments": {
				Path:    "/api/payments",
				Backend: "payment-service",
				Port:    8003,
			},
		},
		tokens: map[string]bool{
			"demo-token-1": true,
			"demo-token-2": true,
			"valid-token":  true,
		},
		rateLimits: map[string]*RateLimit{},
	}
	return gw
}

func (gw *APIGateway) checkAuth(r *http.Request) (bool, string) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return false, "missing_authorization_header"
	}

	token := strings.TrimPrefix(authHeader, "Bearer ")
	if token == authHeader || token == "" {
		return false, "invalid_authorization_format"
	}

	gw.mu.RLock()
	valid := gw.tokens[token]
	gw.mu.RUnlock()

	if !valid {
		return false, "invalid_token"
	}

	return true, ""
}

func (gw *APIGateway) checkRateLimit(clientIP string) (bool, string) {
	gw.mu.Lock()
	defer gw.mu.Unlock()

	// Initialize if not exists
	if _, exists := gw.rateLimits[clientIP]; !exists {
		gw.rateLimits[clientIP] = &RateLimit{
			Limit:   5,
			Current: 0,
			ResetAt: time.Now().Add(1 * time.Second),
		}
	}

	limit := gw.rateLimits[clientIP]

	// Reset if time has passed
	if time.Now().After(limit.ResetAt) {
		limit.Current = 0
		limit.ResetAt = time.Now().Add(1 * time.Second)
	}

	// Check limit
	if limit.Current >= limit.Limit {
		return false, "rate_limit_exceeded"
	}

	limit.Current++
	return true, ""
}

func (gw *APIGateway) getClientIP(r *http.Request) string {
	ip := r.Header.Get("X-Forwarded-For")
	if ip != "" {
		return strings.Split(ip, ",")[0]
	}
	return strings.Split(r.RemoteAddr, ":")[0]
}

func (gw *APIGateway) handleRequest(w http.ResponseWriter, r *http.Request) {
	requestID := r.Header.Get("X-Request-ID")
	if requestID == "" {
		requestID = fmt.Sprintf("req-%d", time.Now().UnixNano())
	}

	clientIP := gw.getClientIP(r)
	startTime := time.Now()

	// Middleware chain
	authOK, authErr := gw.checkAuth(r)
	if !authOK {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":       "unauthorized",
			"reason":      authErr,
			"request_id":  requestID,
		})
		log.Printf("[%s] auth=FAILED (%s), client=%s, method=%s, path=%s, duration=%dms",
			requestID, authErr, clientIP, r.Method, r.URL.Path, time.Since(startTime).Milliseconds())
		return
	}

	rateLimitOK, rateLimitErr := gw.checkRateLimit(clientIP)
	if !rateLimitOK {
		w.WriteHeader(http.StatusTooManyRequests)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":       "rate_limit_exceeded",
			"reason":      rateLimitErr,
			"request_id":  requestID,
			"limit":       "5 requests per second",
		})
		log.Printf("[%s] auth=OK, rate_limit=EXCEEDED, client=%s, method=%s, path=%s, duration=%dms",
			requestID, clientIP, r.Method, r.URL.Path, time.Since(startTime).Milliseconds())
		return
	}

	// Find route (match prefix)
	gw.mu.RLock()
	var route Route
	routeExists := false
	for routePath, routeConfig := range gw.routes {
		if strings.HasPrefix(r.URL.Path, routePath) {
			route = routeConfig
			routeExists = true
			break
		}
	}
	gw.mu.RUnlock()

	if !routeExists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":      "route_not_found",
			"request_id": requestID,
		})
		log.Printf("[%s] auth=OK, rate_limit=OK, route=NOT_FOUND, client=%s, method=%s, path=%s, duration=%dms",
			requestID, clientIP, r.Method, r.URL.Path, time.Since(startTime).Milliseconds())
		return
	}

	// Forward to backend
	backendAddr := fmt.Sprintf("localhost:%d", route.Port)
	backendConn, err := net.Dial("tcp", backendAddr)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":      "backend_unavailable",
			"request_id": requestID,
		})
		log.Printf("[%s] auth=OK, rate_limit=OK, route=%s, backend_error, client=%s, method=%s, path=%s, duration=%dms",
			requestID, route.Backend, clientIP, r.Method, r.URL.Path, time.Since(startTime).Milliseconds())
		return
	}
	defer backendConn.Close()

	// Send HTTP request to backend (strip /api prefix)
	backendPath := strings.TrimPrefix(r.URL.Path, "/api")
	if backendPath == "" {
		backendPath = "/"
	}
	fmt.Fprintf(backendConn, "%s %s HTTP/1.1\r\n", r.Method, backendPath)
	fmt.Fprintf(backendConn, "Host: %s\r\n", r.Host)
	fmt.Fprintf(backendConn, "X-Request-ID: %s\r\n", requestID)
	fmt.Fprintf(backendConn, "Connection: close\r\n\r\n")

	if r.Method == "POST" && r.ContentLength > 0 {
		io.Copy(backendConn, r.Body)
	}

	// Parse HTTP response from backend
	reader := io.Reader(backendConn)
	resp, err := http.ReadResponse(bufio.NewReader(reader), r)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":      "backend_read_error",
			"request_id": requestID,
		})
		log.Printf("[%s] auth=OK, rate_limit=OK, route=%s, read_error, client=%s, method=%s, path=%s, duration=%dms",
			requestID, route.Backend, clientIP, r.Method, r.URL.Path, time.Since(startTime).Milliseconds())
		return
	}
	defer resp.Body.Close()

	// Write response headers and status back to client
	w.Header().Set("X-Request-ID", requestID)
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}
	w.WriteHeader(resp.StatusCode)

	// Write response body
	io.Copy(w, resp.Body)

	log.Printf("[%s] auth=OK, rate_limit=OK, route=%s, status=%d, client=%s, method=%s, path=%s, duration=%dms",
		requestID, route.Backend, resp.StatusCode, clientIP, r.Method, r.URL.Path, time.Since(startTime).Milliseconds())
}

func (gw *APIGateway) statusHandler(w http.ResponseWriter, r *http.Request) {
	gw.mu.RLock()
	numClients := len(gw.rateLimits)
	numTokens := len(gw.tokens)
	gw.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "healthy",
		"service":   "api-gateway",
		"routes":    len(gw.routes),
		"tokens":    numTokens,
		"clients":   numClients,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func main() {
	gw := NewAPIGateway()

	http.HandleFunc("/", gw.handleRequest)
	http.HandleFunc("/_status", gw.statusHandler)

	log.Println("API Gateway listening on :9999")
	log.Println("")
	log.Println("Features:")
	log.Println("  - Authentication (Bearer tokens)")
	log.Println("  - Rate limiting (5 req/sec per client)")
	log.Println("  - Request IDs (X-Request-ID header)")
	log.Println("  - Routing to backends")
	log.Println("  - Comprehensive logging")
	log.Println("")
	log.Println("Valid tokens: demo-token-1, demo-token-2, valid-token")
	log.Println("")
	log.Println("Test:")
	log.Println("  curl -H 'Authorization: Bearer valid-token' http://localhost:9999/api/users/123")
	log.Println("  curl http://localhost:9999/_status")

	http.ListenAndServe(":9999", nil)
}
