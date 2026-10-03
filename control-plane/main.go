package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
)

type Route struct {
	Path    string `json:"path"`
	Service string `json:"service"`
	Port    int    `json:"port"`
}

type Config struct {
	Routes  []Route `json:"routes"`
	Version int     `json:"version"`
}

var (
	config Config
	mu     sync.RWMutex
)

func getConfigHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Config-Version", "1")
	json.NewEncoder(w).Encode(config)

	log.Printf("Config requested: %d routes, version %d", len(config.Routes), config.Version)
}

func getHealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"service": "control-plane",
	})
}

func init() {
	config = Config{
		Version: 1,
		Routes: []Route{
			{Path: "/api/users", Service: "user-service", Port: 8001},
			{Path: "/api/orders", Service: "order-service", Port: 8002},
			{Path: "/api/payments", Service: "payment-service", Port: 8003},
		},
	}
}

func main() {
	http.HandleFunc("/config", getConfigHandler)
	http.HandleFunc("/health", getHealthHandler)

	log.Println("Control plane listening on :7000")
	log.Printf("Serving %d routes", len(config.Routes))
	log.Println("Endpoints:")
	log.Println("  GET /config  - Fetch routing configuration")
	log.Println("  GET /health  - Health check")

	http.ListenAndServe(":7000", nil)
}
