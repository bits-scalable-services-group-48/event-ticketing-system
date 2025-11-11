# Cleanup Script for Event Ticketing System

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleanup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$choice = Read-Host "What do you want to cleanup? (1=Docker, 2=Kubernetes, 3=Both)"

if ($choice -eq "1" -or $choice -eq "3") {
    Write-Host "Cleaning up Docker resources..." -ForegroundColor Yellow
    
    # Stop and remove Docker Compose services
    docker-compose down -v
    
    # Remove individual database containers if they exist
    docker rm -f catalog-db seating-db order-db payment-db 2>$null
    
    # Remove service images
    docker rmi -f catalog-service:latest seating-service:latest order-service:latest payment-service:latest 2>$null
    
    Write-Host "✅ Docker cleanup complete" -ForegroundColor Green
}

if ($choice -eq "2" -or $choice -eq "3") {
    Write-Host "Cleaning up Kubernetes resources..." -ForegroundColor Yellow
    
    Push-Location event-ticketing-system\k8s
    
    kubectl delete -f order.yaml
    kubectl delete -f payment.yaml
    kubectl delete -f seating.yaml
    kubectl delete -f catalog.yaml
    
    Pop-Location
    
    # Check if we should stop Minikube
    $stopMinikube = Read-Host "Stop Minikube? (y/n)"
    if ($stopMinikube -eq "y") {
        minikube stop
        Write-Host "✅ Minikube stopped" -ForegroundColor Green
    }
    
    Write-Host "✅ Kubernetes cleanup complete" -ForegroundColor Green
}

Write-Host ""
Write-Host "Cleanup completed!" -ForegroundColor Green
