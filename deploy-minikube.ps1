# Minikube Deployment Script for Event Ticketing System
# Run this script to deploy all services to Minikube

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Event Ticketing System - Minikube Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Start Minikube
Write-Host "Step 1: Starting Minikube..." -ForegroundColor Yellow
minikube start --driver=docker --cpus=4 --memory=3072

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start Minikube" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Minikube started successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Configure Docker to use Minikube's daemon
Write-Host "Step 2: Configuring Docker to use Minikube..." -ForegroundColor Yellow
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
Write-Host "✅ Docker configured" -ForegroundColor Green
Write-Host ""

# Step 3: Build Docker images
Write-Host "Step 3: Building Docker images..." -ForegroundColor Yellow

$services = @("catalog-service", "seating-service", "order-service", "payment-service")
foreach ($service in $services) {
    Write-Host "  Building $service..." -ForegroundColor Cyan
    docker build -t ${service}:latest ./$service
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to build $service" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All Docker images built" -ForegroundColor Green
Write-Host ""

# Step 4: Deploy to Kubernetes
Write-Host "Step 4: Deploying to Kubernetes..." -ForegroundColor Yellow

Push-Location event-ticketing-system\k8s

Write-Host "  Deploying Catalog Service..." -ForegroundColor Cyan
kubectl apply -f catalog.yaml

Write-Host "  Deploying Seating Service..." -ForegroundColor Cyan
kubectl apply -f seating.yaml

Write-Host "  Deploying Payment Service..." -ForegroundColor Cyan
kubectl apply -f payment.yaml

Write-Host "  Deploying Order Service..." -ForegroundColor Cyan
kubectl apply -f order.yaml

Pop-Location

Write-Host "✅ All services deployed" -ForegroundColor Green
Write-Host ""

# Step 5: Wait for pods to be ready
Write-Host "Step 5: Waiting for pods to be ready..." -ForegroundColor Yellow
Write-Host "  This may take 2-3 minutes..." -ForegroundColor Gray

Start-Sleep -Seconds 30

kubectl get pods

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$minikubeIp = minikube ip
Write-Host "Minikube IP: $minikubeIp" -ForegroundColor Green
Write-Host ""
Write-Host "Services are available at:" -ForegroundColor Yellow
Write-Host "  Catalog Service:  http://${minikubeIp}:30081" -ForegroundColor White
Write-Host "  Seating Service:  http://${minikubeIp}:30082" -ForegroundColor White
Write-Host "  Order Service:    http://${minikubeIp}:30083" -ForegroundColor White
Write-Host "  Payment Service:  http://${minikubeIp}:30084" -ForegroundColor White
Write-Host ""
Write-Host "To check pod status:" -ForegroundColor Yellow
Write-Host "  kubectl get pods" -ForegroundColor White
Write-Host ""
Write-Host "To check services:" -ForegroundColor Yellow
Write-Host "  kubectl get services" -ForegroundColor White
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Yellow
Write-Host "  kubectl logs -f deployment/catalog-service" -ForegroundColor White
Write-Host ""
