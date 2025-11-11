# Event Ticketing System - Setup and Deployment Guide

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Local Development Setup](#local-development-setup)
5. [Docker Deployment](#docker-deployment)
6. [Kubernetes (Minikube) Deployment](#kubernetes-minikube-deployment)
7. [Testing the System](#testing-the-system)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [API Documentation](#api-documentation)

---

## 🎯 Project Overview

Event Ticketing System is a microservices-based application for managing event ticketing operations including:
- Event catalog management
- Seat inventory and reservations
- Order processing with idempotency
- Payment processing

### Key Features Implemented

#### ✅ Task 1: Microservices Architecture (6 Marks)
- **Catalog Service** (Port 8081): Manages events, venues, and seat inventory
- **Seating Service** (Port 8082): Handles seat reservations with TTL-based holds
- **Order Service** (Port 8083): Orchestrates ticket purchasing workflow
- **Payment Service** (Port 8084): Processes payments with idempotency

#### ✅ Task 2: Database-per-Service Pattern (1.5 Marks)
- Each service has its own PostgreSQL database
- Schema management via JPA/Hibernate
- Complete data isolation between services

#### ✅ Task 3: Buy Tickets Workflow (2.5 Marks)
- Idempotent order creation using `Idempotency-Key` header
- Seat reservation with 15-minute TTL (automatically expires)
- Payment integration with success/failure handling
- Automatic seat release on payment failure
- Ticket generation on successful payment

#### ✅ Task 4: Dockerization (2 Marks)
- Multi-stage Dockerfiles for all services
- Docker Compose orchestration with 4 databases + 4 services
- Health checks and proper networking

#### ✅ Task 5: Kubernetes Deployment (2 Marks)
- Complete K8s manifests (Deployments, Services, ConfigMaps, PVCs)
- Minikube-ready with NodePort services
- Database persistence with PersistentVolumeClaims

#### ✅ Task 6: Monitoring (2 Marks)
- **Prometheus Metrics**: Exposed at `/actuator/prometheus` endpoint
- **Structured Logging**: JSON format with Logstash encoder
- **Correlation IDs**: `X-Correlation-Id` header for distributed tracing across all services

---

## 🏗️ Architecture

### Service Communication
```
Client → Order Service (8083)
         ↓
         ├→ Catalog Service (8081) - Get event & seat details
         ├→ Seating Service (8082) - Reserve/Allocate seats
         └→ Payment Service (8084) - Process payment
```

### Database Schema
- **catalog_db**: events, venues, seats
- **seating_db**: seat_reservations (with TTL)
- **order_db**: orders, tickets
- **payment_db**: payments (with idempotency tracking)

---

## 🔧 Prerequisites

### Required Software
- **Java 17** or higher
- **Docker Desktop** (with Kubernetes enabled) or Minikube
- **Gradle** (wrapper included)
- **PostgreSQL 17** (for local development)
- **Git**
- **Postman** or **curl** (for API testing)

### Verify Installation
```powershell
java -version          # Should show Java 17+
docker --version       # Docker 20.10+
minikube version       # If using Minikube
kubectl version        # Kubernetes CLI
```

---

## 💻 Local Development Setup

### 1. Start PostgreSQL Databases

```powershell
# Using Docker for databases
docker run -d --name catalog-db -p 5433:5432 -e POSTGRES_USER=catalog_user -e POSTGRES_PASSWORD=catalog_password -e POSTGRES_DB=catalog_db postgres:17

docker run -d --name seating-db -p 5434:5432 -e POSTGRES_USER=seating_user -e POSTGRES_PASSWORD=seating_password -e POSTGRES_DB=seating_db postgres:17

docker run -d --name order-db -p 5435:5432 -e POSTGRES_USER=order_user -e POSTGRES_PASSWORD=order_password -e POSTGRES_DB=order_db postgres:17

docker run -d --name payment-db -p 5436:5432 -e POSTGRES_USER=payment_user -e POSTGRES_PASSWORD=payment_password -e POSTGRES_DB=payment_db postgres:17
```

### 2. Build All Services

```powershell
# Catalog Service
cd catalog-service
.\gradlew.bat clean build
cd ..

# Seating Service
cd seating-service
.\gradlew.bat clean build
cd ..

# Order Service
cd order-service
.\gradlew.bat clean build
cd ..

# Payment Service
cd payment-service
.\gradlew.bat clean build
cd ..
```

### 3. Run Services

Open 4 terminals and run:

```powershell
# Terminal 1 - Catalog Service
cd catalog-service
.\gradlew.bat bootRun

# Terminal 2 - Seating Service
cd seating-service
.\gradlew.bat bootRun

# Terminal 3 - Payment Service
cd payment-service
.\gradlew.bat bootRun

# Terminal 4 - Order Service
cd order-service
.\gradlew.bat bootRun
```

### 4. Verify Services

```powershell
curl http://localhost:8081/actuator/health  # Catalog
curl http://localhost:8082/actuator/health  # Seating
curl http://localhost:8083/actuator/health  # Order
curl http://localhost:8084/actuator/health  # Payment
```

---

## 🐳 Docker Deployment

### 1. Build and Start All Services

```powershell
cd d:\ss\code

# Build and start with Docker Compose
docker-compose up --build
```

### 2. Verify Containers

```powershell
docker ps
```

You should see 8 containers:
- catalog-db, seating-db, order-db, payment-db
- catalog-service, seating-service, order-service, payment-service

### 3. Check Service Health

```powershell
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
curl http://localhost:8083/actuator/health
curl http://localhost:8084/actuator/health
```

### 4. View Logs

```powershell
docker-compose logs -f catalog-service
docker-compose logs -f order-service
```

### 5. Stop Services

```powershell
docker-compose down
# To remove volumes as well
docker-compose down -v
```

---

## ☸️ Kubernetes (Minikube) Deployment

### 1. Start Minikube

```powershell
# Start Minikube with Docker driver
minikube start --driver=docker --cpus=4 --memory=8192

# Verify
kubectl cluster-info
kubectl get nodes
```

### 2. Build Docker Images in Minikube

```powershell
# Configure Docker to use Minikube's Docker daemon
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Build images
cd d:\ss\code

docker build -t catalog-service:latest ./catalog-service
docker build -t seating-service:latest ./seating-service
docker build -t order-service:latest ./order-service
docker build -t payment-service:latest ./payment-service

# Verify images
docker images | Select-String "service"
```

### 3. Deploy to Kubernetes

```powershell
cd d:\ss\code\event-ticketing-system\k8s

# Deploy all services (in order)
kubectl apply -f catalog.yaml
kubectl apply -f seating.yaml
kubectl apply -f payment.yaml
kubectl apply -f order.yaml
```

### 4. Monitor Deployment

```powershell
# Check pods
kubectl get pods -w

# Check services
kubectl get services

# Check persistent volume claims
kubectl get pvc
```

### 5. Access Services

```powershell
# Get Minikube IP
minikube ip

# Services are available at:
# Catalog: http://<minikube-ip>:30081
# Seating: http://<minikube-ip>:30082
# Order:   http://<minikube-ip>:30083
# Payment: http://<minikube-ip>:30084

# Or use port forwarding
kubectl port-forward service/catalog-service 8081:8081
kubectl port-forward service/order-service 8083:8083
```

### 6. View Logs

```powershell
kubectl logs -f deployment/catalog-service
kubectl logs -f deployment/order-service
```

### 7. Cleanup

```powershell
kubectl delete -f order.yaml
kubectl delete -f payment.yaml
kubectl delete -f seating.yaml
kubectl delete -f catalog.yaml

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

---

## 🧪 Testing the System

### Test Data Setup

#### 1. Create a Venue
```powershell
curl -X POST http://localhost:8081/v1/venues `
  -H "Content-Type: application/json" `
  -d '{
    "name": "Madison Square Garden",
    "location": "New York",
    "capacity": 20000
  }'
```

#### 2. Create an Event
```powershell
curl -X POST http://localhost:8081/v1/events `
  -H "Content-Type: application/json" `
  -d '{
    "name": "Rock Concert 2024",
    "venueId": 1,
    "eventDate": "2024-12-31T20:00:00",
    "totalSeats": 200,
    "status": "ON_SALE"
  }'
```

#### 3. Generate Seats
```powershell
curl -X POST http://localhost:8081/v1/events/1/seats/generate `
  -H "Content-Type: application/json" `
  -d '{
    "section": "VIP",
    "rows": 10,
    "seatsPerRow": 20,
    "price": 150.00,
    "replaceIfExists": false
  }'
```

#### 4. Get Available Seats
```powershell
curl http://localhost:8081/v1/events/1/seats
```

### Complete Order Flow (Buy Tickets)

#### 5. Create Order (Buy Tickets)
```powershell
curl -X POST http://localhost:8083/v1/orders `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: order-12345" `
  -d '{
    "userId": 1,
    "eventId": 1,
    "seatIds": [1, 2, 3],
    "paymentMethod": "CREDIT_CARD"
  }'
```

**Expected Response:**
```json
{
  "orderId": 1,
  "userId": 1,
  "eventId": 1,
  "status": "CONFIRMED",
  "paymentStatus": "SUCCESS",
  "orderTotal": 472.50,
  "idempotencyKey": "order-12345",
  "createdAt": "2024-11-10T...",
  "tickets": [
    {
      "ticketId": 1,
      "eventId": 1,
      "seatId": 1,
      "pricePaid": 150.00
    },
    ...
  ]
}
```

#### 6. Test Idempotency (Retry Same Request)
```powershell
# Same request - should return existing order
curl -X POST http://localhost:8083/v1/orders `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: order-12345" `
  -d '{
    "userId": 1,
    "eventId": 1,
    "seatIds": [1, 2, 3],
    "paymentMethod": "CREDIT_CARD"
  }'
```

#### 7. Get Order Details
```powershell
curl http://localhost:8083/v1/orders/1
```

#### 8. Check Seat Availability
```powershell
curl http://localhost:8082/v1/seating/events/1/availability
```

---

## 📊 Monitoring and Observability

### Prometheus Metrics

Access Prometheus metrics for each service:

```powershell
curl http://localhost:8081/actuator/prometheus  # Catalog
curl http://localhost:8082/actuator/prometheus  # Seating
curl http://localhost:8083/actuator/prometheus  # Order
curl http://localhost:8084/actuator/prometheus  # Payment
```

**Key Metrics Available:**
- `http_server_requests_seconds` - Request duration
- `jvm_memory_used_bytes` - Memory usage
- `process_cpu_usage` - CPU usage
- Custom business metrics (if added)

### Structured Logging

All services log in JSON format with correlation IDs:

```json
{
  "timestamp": "2024-11-10T10:30:45.123Z",
  "level": "INFO",
  "service": "order-service",
  "correlationId": "abc-123-def-456",
  "logger": "com.ticketing.orderservice.service.OrderService",
  "message": "Order created successfully",
  "thread": "http-nio-8083-exec-1"
}
```

### Correlation ID Tracing

The `X-Correlation-Id` header is:
1. Extracted from incoming requests
2. Generated if not present
3. Logged in all log entries (MDC)
4. Returned in response headers

**Test Correlation ID:**
```powershell
curl -X POST http://localhost:8083/v1/orders `
  -H "X-Correlation-Id: test-trace-123" `
  -H "Idempotency-Key: order-99999" `
  -H "Content-Type: application/json" `
  -d '{...}'
```

Check logs - all entries will have `"correlationId": "test-trace-123"`

### Health Checks

```powershell
# Basic health
curl http://localhost:8081/actuator/health

# Detailed health (if configured)
curl http://localhost:8081/actuator/health/liveness
curl http://localhost:8081/actuator/health/readiness
```

---

## 📚 API Documentation

### Catalog Service (8081)

#### Venues
- `POST /v1/venues` - Create venue
- `GET /v1/venues/{id}` - Get venue
- `GET /v1/venues` - List all venues

#### Events
- `POST /v1/events` - Create event
- `GET /v1/events/{id}` - Get event
- `GET /v1/events` - List all events
- `PUT /v1/events/{id}` - Update event
- `DELETE /v1/events/{id}` - Delete event

#### Seats
- `POST /v1/seats` - Create seat
- `GET /v1/seats/{id}` - Get seat
- `GET /v1/events/{eventId}/seats` - Get seats for event
- `POST /v1/events/{eventId}/seats/generate` - Bulk generate seats

### Seating Service (8082)

- `GET /v1/seating/events/{eventId}/availability` - Get seat availability
- `POST /v1/seating/reserve` - Reserve seats (creates HELD status with TTL)
- `POST /v1/seating/release` - Release seats
- `POST /v1/seating/allocate` - Allocate seats (HELD → RESERVED)

### Order Service (8083)

- `POST /v1/orders` - Create order (Requires: Idempotency-Key header)
- `GET /v1/orders/{id}` - Get order details
- `GET /v1/orders?userId={userId}` - Get user's orders
- `POST /v1/orders/{id}/cancel` - Cancel order

### Payment Service (8084)

- `POST /v1/payments/charge` - Process payment (Requires: Idempotency-Key header)
- `GET /v1/payments/{id}` - Get payment details
- `POST /v1/payments/{id}/refund` - Refund payment

---

## 🎬 Demo Workflow

### Complete End-to-End Test

```powershell
# 1. Create Venue
$venueResp = curl -X POST http://localhost:8081/v1/venues -H "Content-Type: application/json" -d '{...}'

# 2. Create Event
$eventResp = curl -X POST http://localhost:8081/v1/events -H "Content-Type: application/json" -d '{...}'

# 3. Generate Seats
curl -X POST http://localhost:8081/v1/events/1/seats/generate -H "Content-Type: application/json" -d '{...}'

# 4. Buy Tickets (Complete Workflow)
curl -X POST http://localhost:8083/v1/orders `
  -H "Idempotency-Key: $(New-Guid)" `
  -H "Content-Type: application/json" `
  -d '{
    "userId": 1,
    "eventId": 1,
    "seatIds": [1, 2],
    "paymentMethod": "CREDIT_CARD"
  }'

# 5. Verify Order
curl http://localhost:8083/v1/orders/1

# 6. Check Prometheus Metrics
curl http://localhost:8083/actuator/prometheus | Select-String "http_server_requests"
```

---

## 📝 Assignment Tasks Completion Checklist

- ✅ **Task 1 (6 Marks)**: 4 microservices implemented and working
- ✅ **Task 2 (1.5 Marks)**: Database-per-service pattern with separate PostgreSQL instances
- ✅ **Task 3 (2.5 Marks)**: Complete buy tickets workflow with idempotency, TTL, payment
- ✅ **Task 4 (2 Marks)**: Dockerfiles + docker-compose.yml
- ✅ **Task 5 (2 Marks)**: Kubernetes manifests for Minikube
- ✅ **Task 6 (2 Marks)**: Prometheus metrics + structured logging + correlation IDs
- ✅ **Task 7 (2 Marks)**: This documentation

**Total: 18 Marks**

---

## 🐛 Troubleshooting

### Services Not Starting
- Check if ports 8081-8084 are available
- Verify PostgreSQL databases are running
- Check logs: `docker-compose logs -f <service-name>`

### Database Connection Issues
- Verify database containers are healthy: `docker ps`
- Check connection strings in application.yaml
- Ensure network connectivity: `docker network ls`

### Kubernetes Pod Issues
- Check pod status: `kubectl get pods`
- View pod logs: `kubectl logs <pod-name>`
- Describe pod: `kubectl describe pod <pod-name>`
- Check PVC: `kubectl get pvc`

### Build Failures
- Clean Gradle cache: `.\gradlew.bat clean`
- Check Java version: `java -version` (must be 17+)
- Delete `build/` and `.gradle/` directories

---

## 👥 Authors

**Group 48 - Scalable Services**

---

## 📄 License

This project is for academic purposes - BITS Pilani MTech Software Engineering.

---

**End of Documentation**
