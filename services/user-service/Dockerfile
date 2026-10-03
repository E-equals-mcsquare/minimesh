FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY main.go .

RUN go build -o user-service main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/user-service .

EXPOSE 8001

CMD ["./user-service"]
