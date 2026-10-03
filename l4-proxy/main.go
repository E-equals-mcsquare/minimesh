package main

import (
	"io"
	"log"
	"net"
)

const proxyPort = "9000"
const backendAddr = "localhost:8001"

func handleConnection(clientConn net.Conn) {
	defer clientConn.Close()

	backendConn, err := net.Dial("tcp", backendAddr)
	if err != nil {
		log.Printf("Failed to connect to backend: %v", err)
		return
	}
	defer backendConn.Close()

	log.Printf("Connection established: %v <-> %v",
		clientConn.RemoteAddr(), backendAddr)

	// Forward client -> backend
	go io.Copy(backendConn, clientConn)

	// Forward backend -> client
	io.Copy(clientConn, backendConn)
}

func main() {
	listener, err := net.Listen("tcp", ":"+proxyPort)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}
	defer listener.Close()

	log.Printf("L4 proxy listening on :%s", proxyPort)
	log.Printf("Forwarding to %s", backendAddr)

	for {
		clientConn, err := listener.Accept()
		if err != nil {
			log.Printf("Failed to accept: %v", err)
			continue
		}
		go handleConnection(clientConn)
	}
}
