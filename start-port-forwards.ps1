# Start port-forwarding for all services to make them accessible on localhost
# Run this in the background before running test-api.ps1 -Target minikube

Write-Host "Starting port forwards for all services..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop all forwards" -ForegroundColor Yellow
Write-Host ""

# Start port forwards in background jobs
$jobs = @()

$jobs += Start-Job -ScriptBlock { kubectl port-forward svc/catalog-service 30081:8081 }
Write-Host "[OK] Catalog Service: localhost:30081" -ForegroundColor Green

$jobs += Start-Job -ScriptBlock { kubectl port-forward svc/seating-service 30082:8082 }
Write-Host "[OK] Seating Service: localhost:30082" -ForegroundColor Green

$jobs += Start-Job -ScriptBlock { kubectl port-forward svc/order-service 30083:8083 }
Write-Host "[OK] Order Service: localhost:30083" -ForegroundColor Green

$jobs += Start-Job -ScriptBlock { kubectl port-forward svc/payment-service 30084:8084 }
Write-Host "[OK] Payment Service: localhost:30084" -ForegroundColor Green

Write-Host ""
Write-Host "All port forwards started. Services accessible on localhost:3008X" -ForegroundColor Green
Write-Host "Run: .\test-api.ps1 -Target minikube" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitoring... (Ctrl+C to stop)" -ForegroundColor Yellow

# Keep script running and monitor jobs
try {
    while ($true) {
        Start-Sleep -Seconds 5
        # Check if any job failed
        $failed = $jobs | Where-Object { $_.State -eq 'Failed' }
        if ($failed) {
            Write-Host "[ERROR] Some port forwards failed. Restarting..." -ForegroundColor Red
            $failed | Remove-Job -Force
            # Restart failed ones
            if ($jobs[0].State -eq 'Failed') {
                $jobs[0] = Start-Job -ScriptBlock { kubectl port-forward svc/catalog-service 30081:8081 }
            }
            if ($jobs[1].State -eq 'Failed') {
                $jobs[1] = Start-Job -ScriptBlock { kubectl port-forward svc/seating-service 30082:8082 }
            }
            if ($jobs[2].State -eq 'Failed') {
                $jobs[2] = Start-Job -ScriptBlock { kubectl port-forward svc/order-service 30083:8083 }
            }
            if ($jobs[3].State -eq 'Failed') {
                $jobs[3] = Start-Job -ScriptBlock { kubectl port-forward svc/payment-service 30084:8084 }
            }
        }
    }
} finally {
    Write-Host ""
    Write-Host "Stopping all port forwards..." -ForegroundColor Yellow
    $jobs | Stop-Job
    $jobs | Remove-Job -Force
    Write-Host "All port forwards stopped." -ForegroundColor Green
}
