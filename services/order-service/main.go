package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

const port = 8002
const serviceName = "order-service"

var paymentServiceURL = getEnv("PAYMENT_SERVICE_URL", "http://payment-service:8003")

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
}

type OrderResponse struct {
	ID            string  `json:"id"`
	UserID        string  `json:"user_id"`
	Total         float64 `json:"total"`
	Status        string  `json:"status"`
	PaymentStatus string  `json:"payment_status"`
	TransactionID string  `json:"transaction_id,omitempty"`
}

type paymentRequest struct {
	OrderID string  `json:"order_id"`
	Amount  float64 `json:"amount"`
}

type paymentResponse struct {
	TransactionID string  `json:"transaction_id"`
	OrderID       string  `json:"order_id"`
	Amount        float64 `json:"amount"`
	Status        string  `json:"status"`
}

// chargePayment calls payment-service (through the Envoy sidecar when
// PAYMENT_SERVICE_URL points at localhost) to charge for this order.
// simulateDelaySeconds, when non-empty, is forwarded as a query param so
// payment-service artificially sleeps -- used to demonstrate Envoy's route
// timeout from the Experiment section of this milestone.
func chargePayment(orderID, simulateDelaySeconds string) (transactionID, status string) {
	body, _ := json.Marshal(paymentRequest{OrderID: orderID, Amount: 99.99})

	url := paymentServiceURL + "/payments"
	if simulateDelaySeconds != "" {
		url += "?delay=" + simulateDelaySeconds
	}

	// Intentionally longer than Envoy's configured route timeout (2s), so
	// when a timeout happens it's Envoy's timeout firing, not this client's.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		log.Printf("[%s] payment request build error: %v\n", serviceName, err)
		return "", "unavailable"
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		if strings.Contains(err.Error(), "context deadline exceeded") {
			log.Printf("[%s] payment call timed out: %v\n", serviceName, err)
			return "", "timeout"
		}
		log.Printf("[%s] payment call failed: %v\n", serviceName, err)
		return "", "unavailable"
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusGatewayTimeout {
		log.Printf("[%s] Envoy sidecar reported a route timeout (504)\n", serviceName)
		return "", "timeout"
	}
	if resp.StatusCode != http.StatusOK {
		log.Printf("[%s] payment call returned status %d\n", serviceName, resp.StatusCode)
		return "", "unavailable"
	}

	var pr paymentResponse
	if err := json.NewDecoder(resp.Body).Decode(&pr); err != nil {
		log.Printf("[%s] payment response decode error: %v\n", serviceName, err)
		return "", "unavailable"
	}

	return pr.TransactionID, "completed"
}

func logRequest(method, path string, status int, duration time.Duration) {
	log.Println(struct {
		Service  string `json:"service"`
		Method   string `json:"method"`
		Path     string `json:"path"`
		Status   int    `json:"status"`
		DurationMs float64 `json:"duration_ms"`
		Timestamp string `json:"timestamp"`
	}{
		Service: serviceName,
		Method: method,
		Path: path,
		Status: status,
		DurationMs: float64(duration.Milliseconds()),
		Timestamp: time.Now().Format(time.RFC3339),
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(HealthResponse{
		Status:  "healthy",
		Service: serviceName,
	})
	logRequest(r.Method, r.URL.Path, http.StatusOK, time.Since(start))
}

func ordersHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		logRequest(r.Method, r.URL.Path, http.StatusMethodNotAllowed, time.Since(start))
		return
	}

	// Extract order ID from path (e.g., /orders/123)
	orderID := r.URL.Path[len("/orders/"):]

	transactionID, paymentStatus := chargePayment(orderID, r.URL.Query().Get("simulate_delay"))

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(OrderResponse{
		ID:            orderID,
		UserID:        "user-123",
		Total:         99.99,
		Status:        "completed",
		PaymentStatus: paymentStatus,
		TransactionID: transactionID,
	})
	logRequest(r.Method, r.URL.Path, http.StatusOK, time.Since(start))
}

func notFoundHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	w.WriteHeader(http.StatusNotFound)
	w.Write([]byte("Not Found"))
	logRequest(r.Method, r.URL.Path, http.StatusNotFound, time.Since(start))
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/orders/", ordersHandler)
	mux.HandleFunc("/", notFoundHandler)

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("[%s] Starting on port %d\n", serviceName, port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[%s] Server error: %v\n", serviceName, err)
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Printf("[%s] Shutting down...\n", serviceName)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("[%s] Shutdown error: %v\n", serviceName, err)
	}
	log.Printf("[%s] Stopped\n", serviceName)
}
