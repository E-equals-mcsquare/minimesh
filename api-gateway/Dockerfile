FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY main.go .

RUN go build -o api-gateway main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/api-gateway .

EXPOSE 9999

CMD ["./api-gateway"]
