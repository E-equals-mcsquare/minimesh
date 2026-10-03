package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"sync"
	"time"
)

type Route struct {
	Path    string
	Service string
	Port    int
}

type DataPlane struct {
	routes  []Route
	version int
	mu      sync.RWMutex
}

func (dp *DataPlane) fetchConfig() error {
	resp, err := http.Get("http://localhost:7000/config")
	if err != nil {
		log.Printf("Failed to fetch config: %v", err)
		return err
	}
	defer resp.Body.Close()

	var config struct {
		Routes  []Route `json:"routes"`
		Version int     `json:"version"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&config); err != nil {
		log.Printf("Failed to decode config: %v", err)
		return err
	}

	dp.mu.Lock()
	dp.routes = config.Routes
	dp.version = config.Version
	dp.mu.Unlock()

	log.Printf("Updated routes: %d routes (version %d)", len(config.Routes), config.Version)
	return nil
}

func (dp *DataPlane) startConfigRefresh(interval time.Duration) {
	go func() {
		// Fetch immediately on start
		dp.fetchConfig()

		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		for range ticker.C {
			dp.fetchConfig()
		}
	}()
}

func (dp *DataPlane) findRoute(path string) *Route {
	dp.mu.RLock()
	defer dp.mu.RUnlock()

	for _, route := range dp.routes {
		if route.Path == path {
			return &route
		}
	}
	return nil
}

func (dp *DataPlane) handleRequest(w http.ResponseWriter, r *http.Request) {
	route := dp.findRoute(r.URL.Path)
	if route == nil {
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte("Route not found"))
		log.Printf("Route not found: %s", r.URL.Path)
		return
	}

	// Connect to backend
	backendAddr := fmt.Sprintf("localhost:%d", route.Port)
	backendConn, err := net.Dial("tcp", backendAddr)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte("Failed to connect to backend"))
		log.Printf("Failed to connect to %s: %v", backendAddr, err)
		return
	}
	defer backendConn.Close()

	// Forward request
	fmt.Fprintf(backendConn, "%s %s HTTP/1.1\r\n", r.Method, r.URL.Path)
	fmt.Fprintf(backendConn, "Host: %s\r\n", r.Host)
	fmt.Fprintf(backendConn, "Connection: close\r\n\r\n")

	if r.Method == "POST" && r.ContentLength > 0 {
		io.Copy(backendConn, r.Body)
	}

	// Read response
	response, err := io.ReadAll(backendConn)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		log.Printf("Failed to read response: %v", err)
		return
	}

	w.Write(response)
	log.Printf("Routed %s %s to %s", r.Method, r.URL.Path, backendAddr)
}

func (dp *DataPlane) statusHandler(w http.ResponseWriter, r *http.Request) {
	dp.mu.RLock()
	defer dp.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"service": "data-plane",
		"routes":  len(dp.routes),
		"version": dp.version,
	})
}

func main() {
	dp := &DataPlane{}

	// Start config refresh (every 5 seconds)
	dp.startConfigRefresh(5 * time.Second)

	// Wait for initial config fetch
	time.Sleep(1 * time.Second)

	http.HandleFunc("/", dp.handleRequest)
	http.HandleFunc("/_status", dp.statusHandler)

	log.Println("Data plane listening on :8080")
	log.Println("Fetching config from control plane at :7000")
	log.Println("Config refresh interval: 5 seconds")
	log.Println("")
	log.Println("Try:")
	log.Println("  curl http://localhost:8080/api/users/123")
	log.Println("  curl http://localhost:8080/_status")

	http.ListenAndServe(":8080", nil)
}
