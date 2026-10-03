package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const port = 8002
const serviceName = "order-service"

type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
}

type OrderResponse struct {
	ID        string `json:"id"`
	UserID    string `json:"user_id"`
	Total     float64 `json:"total"`
	Status    string `json:"status"`
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

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(OrderResponse{
		ID:        orderID,
		UserID:    "user-123",
		Total:     99.99,
		Status:    "completed",
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
