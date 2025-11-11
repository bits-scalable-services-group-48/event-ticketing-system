# Event Ticketing System - Microservices Architecture

[![Java](https://img.shields.io/badge/Java-17-orange)](https://www.oracle.com/java/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.5.7-green)](https://spring.io/projects/spring-boot)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-blue)](https://kubernetes.io/)

A production-ready microservices-based event ticketing system built with Spring Boot, PostgreSQL, Docker, and Kubernetes.

## 📋 Project Overview

This system demonstrates modern microservices architecture patterns including:
- **Microservices Architecture**: 4 independent services with separate databases
- **Database-per-Service Pattern**: Complete data isolation
- **Idempotency**: Safe retry mechanism for distributed operations
- **TTL-based Reservations**: Automatic seat release after timeout
- **Distributed Tracing**: Correlation IDs across services
- **Observability**: Prometheus metrics and structured logging
- **Containerization**: Docker and Kubernetes deployment

## 🏗️ Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       v
┌─────────────────────┐
│  Order Service      │  Port 8083
│  (Orchestrator)     │
└──────┬──────────────┘
       │
       ├──────────────────┐
       │                  │
       v                  v
┌─────────────┐    ┌────────────────┐
│  Catalog    │    │   Seating      │
│  Service    │    │   Service      │
│  Port 8081  │    │   Port 8082    │
└─────────────┘    └────────────────┘
       │                  │
       v                  v
┌─────────────┐    ┌────────────────┐
│  Payment    │    │   PostgreSQL   │
│  Service    │    │   (4 DBs)      │
│  Port 8084  │    │                │
└─────────────┘    └────────────────┘
```

## 🎯 Features Implemented

### ✅ Task 1: Microservices (6 Marks)
- **Catalog Service**: Event and seat inventory management
- **Seating Service**: Seat reservations with TTL
- **Order Service**: Ticket purchase orchestration
- **Payment Service**: Payment processing with idempotency

### ✅ Task 2: Database-per-Service (1.5 Marks)
- 4 separate PostgreSQL databases
- Complete data isolation
- JPA/Hibernate for schema management

### ✅ Task 3: Buy Tickets Workflow (2.5 Marks)
- Idempotent order creation
- 15-minute seat reservation TTL
- Payment integration
- Automatic cleanup on failure
- Ticket generation on success

### ✅ Task 4: Dockerization (2 Marks)
- Multi-stage Dockerfiles for all services
- Docker Compose orchestration
- Health checks and proper networking

### ✅ Task 5: Kubernetes (2 Marks)
- Complete K8s manifests
- Minikube deployment ready
- PersistentVolumeClaims for databases
- NodePort services for external access

### ✅ Task 6: Monitoring (2 Marks)
- Prometheus metrics at `/actuator/prometheus`
- Structured JSON logging with Logstash
- Correlation IDs via `X-Correlation-Id` header

### ✅ Task 7: Documentation (2 Marks)
- Comprehensive setup guide
- API documentation
- Deployment instructions
- Testing guidelines

## 🚀 Quick Start

### Prerequisites
- Java 17+
- Docker Desktop
- Minikube (optional for K8s)
- Git

### Option 1: Docker Compose (Easiest)

```powershell
# Clone and navigate
cd d:\ss\code

# Start all services
docker-compose up --build

# Test
curl http://localhost:8081/actuator/health
```

### Option 2: Kubernetes (Minikube)

```powershell
# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Deploy
cd d:\ss\code
.\deploy-minikube.ps1

# Access services at http://<minikube-ip>:3008X
```

### Option 3: Local Development

```powershell
# Start databases
docker run -d --name catalog-db -p 5433:5432 -e POSTGRES_USER=catalog_user -e POSTGRES_PASSWORD=catalog_password -e POSTGRES_DB=catalog_db postgres:17
docker run -d --name seating-db -p 5434:5432 -e POSTGRES_USER=seating_user -e POSTGRES_PASSWORD=seating_password -e POSTGRES_DB=seating_db postgres:17
docker run -d --name order-db -p 5435:5432 -e POSTGRES_USER=order_user -e POSTGRES_PASSWORD=order_password -e POSTGRES_DB=order_db postgres:17
docker run -d --name payment-db -p 5436:5432 -e POSTGRES_USER=payment_user -e POSTGRES_PASSWORD=payment_password -e POSTGRES_DB=payment_db postgres:17

# Build services
cd catalog-service && .\gradlew.bat build && cd ..
cd seating-service && .\gradlew.bat build && cd ..
cd order-service && .\gradlew.bat build && cd ..
cd payment-service && .\gradlew.bat build && cd ..

# Run services (4 terminals)
cd catalog-service && .\gradlew.bat bootRun
cd seating-service && .\gradlew.bat bootRun
cd order-service && .\gradlew.bat bootRun
cd payment-service && .\gradlew.bat bootRun
```

## 📚 API Usage

### Complete Workflow Example

```powershell
# 1. Create Venue
curl -X POST http://localhost:8081/v1/venues `
  -H "Content-Type: application/json" `
  -d '{
    "name": "Madison Square Garden",
    "location": "New York",
    "capacity": 20000
  }'

# 2. Create Event
curl -X POST http://localhost:8081/v1/events `
  -H "Content-Type: application/json" `
  -d '{
    "name": "Rock Concert 2024",
    "venueId": 1,
    "eventDate": "2024-12-31T20:00:00",
    "totalSeats": 200,
    "status": "ON_SALE"
  }'

# 3. Generate Seats
curl -X POST http://localhost:8081/v1/events/1/seats/generate `
  -H "Content-Type: application/json" `
  -d '{
    "section": "VIP",
    "rows": 10,
    "seatsPerRow": 20,
    "price": 150.00
  }'

# 4. Buy Tickets (Complete Workflow)
curl -X POST http://localhost:8083/v1/orders `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: order-12345" `
  -d '{
    "userId": 1,
    "eventId": 1,
    "seatIds": [1, 2, 3],
    "paymentMethod": "CREDIT_CARD"
  }'

# 5. Check Order
curl http://localhost:8083/v1/orders/1
```

## 📊 Monitoring

### Prometheus Metrics
```powershell
# Each service exposes metrics
curl http://localhost:8081/actuator/prometheus  # Catalog
curl http://localhost:8082/actuator/prometheus  # Seating
curl http://localhost:8083/actuator/prometheus  # Order
curl http://localhost:8084/actuator/prometheus  # Payment
```

### Structured Logging
All logs are in JSON format with correlation IDs:
```json
{
  "timestamp": "2024-11-10T10:30:45.123Z",
  "level": "INFO",
  "service": "order-service",
  "correlationId": "abc-123-def-456",
  "message": "Order created successfully"
}
```

### Correlation ID Tracing
```powershell
curl -H "X-Correlation-Id: my-trace-123" http://localhost:8083/v1/orders/1
# Check logs - all entries will have correlationId: my-trace-123
```

## 🧪 Testing

Run automated test suite:
```powershell
cd d:\ss\code
.\test-api.ps1
```

## 📁 Project Structure

```
code/
├── catalog-service/          # Event & seat management
│   ├── src/
│   ├── Dockerfile
│   └── build.gradle
├── seating-service/          # Seat reservations with TTL
│   ├── src/
│   ├── Dockerfile
│   └── build.gradle
├── order-service/            # Order orchestration
│   ├── src/
│   ├── Dockerfile
│   └── build.gradle
├── payment-service/          # Payment processing
│   ├── src/
│   ├── Dockerfile
│   └── build.gradle
├── event-ticketing-system/
│   └── k8s/                  # Kubernetes manifests
│       ├── catalog.yaml
│       ├── seating.yaml
│       ├── order.yaml
│       └── payment.yaml
├── docker-compose.yml        # Docker orchestration
├── deploy-minikube.ps1       # K8s deployment script
├── test-api.ps1              # Test suite
├── SETUP_GUIDE.md            # Detailed documentation
└── README.md                 # This file
```

## 🔧 Technology Stack

- **Language**: Java 17
- **Framework**: Spring Boot 3.5.7
- **Database**: PostgreSQL 17
- **Build Tool**: Gradle 8.11
- **Containerization**: Docker
- **Orchestration**: Kubernetes (Minikube)
- **Monitoring**: Micrometer + Prometheus
- **Logging**: Logstash Logback Encoder

## 📖 Documentation

- [Complete Setup Guide](SETUP_GUIDE.md) - Detailed instructions
- [API Documentation](SETUP_GUIDE.md#api-documentation) - All endpoints
- [Deployment Guide](SETUP_GUIDE.md#kubernetes-minikube-deployment) - K8s setup
- [Testing Guide](SETUP_GUIDE.md#testing-the-system) - Test workflows

## 🐛 Troubleshooting

### Services not starting?
```powershell
# Check Docker
docker ps

# Check logs
docker-compose logs -f catalog-service

# Restart
docker-compose restart
```

### Kubernetes issues?
```powershell
# Check pods
kubectl get pods

# Check logs
kubectl logs -f deployment/catalog-service

# Delete and redeploy
kubectl delete -f event-ticketing-system/k8s/
kubectl apply -f event-ticketing-system/k8s/
```

## 👥 Authors

**Group 48 - Scalable Services**  
BITS Pilani - MTech Software Engineering

## 📄 License

Academic Project - BITS Pilani

## 🎓 Assignment Completion

| Task | Description | Marks | Status |
|------|-------------|-------|--------|
| 1 | 4 Microservices | 6 | ✅ Complete |
| 2 | Database-per-Service | 1.5 | ✅ Complete |
| 3 | Buy Tickets Workflow | 2.5 | ✅ Complete |
| 4 | Dockerization | 2 | ✅ Complete |
| 5 | Kubernetes | 2 | ✅ Complete |
| 6 | Monitoring | 2 | ✅ Complete |
| 7 | Documentation | 2 | ✅ Complete |
| **Total** | | **18** | **✅ 100%** |

---

**Need help?** Check [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions.
