FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY main.go .

RUN go build -o order-service main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/order-service .

EXPOSE 8002

CMD ["./order-service"]
