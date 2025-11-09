# 🎟️ Event Ticketing System (Microservices)

## Overview
This project implements a microservices-based event ticketing platform using **Spring Boot**, **Docker**, and **Kubernetes (Minikube)**.

### Services
| Service | Port | Description |
|----------|------|-------------|
| Catalog Service | 8081 | Manages events and venues |
| Seating Service | 8082 | Manages seat availability and holds |
| Order Service | 8083 | Manages ticket orders |
| Payment Service | 8084 | Handles payment processing |

### Technologies
- Java 17
- Spring Boot 3.5
- PostgreSQL 17
- Docker & Docker Compose
- Kubernetes (Minikube)

### Deployment
1. Build Docker images:
   ```bash
   docker build -t catalog-service:latest ./catalog-service
   docker build -t seating-service:latest ./seating-service
   docker build -t order-service:latest ./order-service
   docker build -t payment-service:latest ./payment-service
2. Deploy to Minikube:
    kubectl apply -f k8s/
3. Verify:
  kubectl get pods
  kubectl get svc
  minikube service catalog-service --url
