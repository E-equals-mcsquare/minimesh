FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY main.go .

RUN go build -o payment-service main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/payment-service .

EXPOSE 8003

CMD ["./payment-service"]
