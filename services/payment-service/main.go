package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

const port = 8003
const serviceName = "payment-service"

type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
}

type PaymentRequest struct {
	OrderID string  `json:"order_id"`
	Amount  float64 `json:"amount"`
}

type PaymentResponse struct {
	TransactionID string `json:"transaction_id"`
	OrderID       string `json:"order_id"`
	Amount        float64 `json:"amount"`
	Status        string `json:"status"`
	Timestamp     string `json:"timestamp"`
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

func paymentsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		logRequest(r.Method, r.URL.Path, http.StatusMethodNotAllowed, time.Since(start))
		return
	}

	var req PaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		logRequest(r.Method, r.URL.Path, http.StatusBadRequest, time.Since(start))
		return
	}

	// Debug knob for the Envoy timeout experiment: ?delay=<seconds> sleeps
	// before responding so callers can observe the sidecar's route timeout.
	if delaySec, err := strconv.Atoi(r.URL.Query().Get("delay")); err == nil && delaySec > 0 {
		log.Printf("[%s] simulating %ds delay before responding\n", serviceName, delaySec)
		time.Sleep(time.Duration(delaySec) * time.Second)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(PaymentResponse{
		TransactionID: fmt.Sprintf("txn-%d", time.Now().Unix()),
		OrderID:       req.OrderID,
		Amount:        req.Amount,
		Status:        "processed",
		Timestamp:     time.Now().Format(time.RFC3339),
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
	mux.HandleFunc("/payments", paymentsHandler)
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
