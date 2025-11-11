# Build All Services Script
# This script builds all microservices

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Event Ticketing System Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$services = @("catalog-service", "order-service", "payment-service", "seating-service")
$failed = @()

foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Yellow
    Push-Location $service
    
    .\gradlew.bat clean build -x test
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to build $service" -ForegroundColor Red
        $failed += $service
    } else {
        Write-Host "✅ Successfully built $service" -ForegroundColor Green
    }
    
    Pop-Location
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($failed.Count -eq 0) {
    Write-Host "✅ All services built successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed services: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
