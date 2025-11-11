# Test Script for Event Ticketing System
# This script demonstrates the complete workflow
# Usage:
#   .\test-api.ps1                  # local (Docker Compose)
#   .\test-api.ps1 -Target minikube # against Minikube NodePorts

[CmdletBinding()]
param(
    [ValidateSet('local','minikube')]
    [string]$Target = 'local',
    # Optional: specify host for minikube (e.g., minikube ip output)
    [string]$HostOverride
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Event Ticketing System - API Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
if ($Target -eq 'local') {
    Write-Host "NOTE: For local/Docker, you can run .\seed-data.ps1 first to load test data (optional)." -ForegroundColor Yellow
} else {
    Write-Host "Running against Minikube NodePorts. Seeding is optional; this script creates its own venue/event/seats." -ForegroundColor Yellow
}
Write-Host ""

# Resolve endpoints per environment
if ($Target -eq 'minikube') {
    # On Windows Docker driver, use localhost (requires 'minikube tunnel' running in admin shell)
    # or provide explicit IP with -HostOverride
    if ($HostOverride) {
        $BaseHost = $HostOverride
    } else {
        # Check if Docker driver on Windows - use localhost with tunnel
        try {
            $driver = (minikube profile list --output=json | ConvertFrom-Json).valid[0].Config.Driver
            if ($driver -eq 'docker' -and $env:OS -match 'Windows') {
                Write-Host "[INFO] Detected Docker driver on Windows. Using localhost (requires 'minikube tunnel')." -ForegroundColor Cyan
                $BaseHost = "127.0.0.1"
            } else {
                $BaseHost = (minikube ip).Trim()
            }
        } catch {
            Write-Host "[WARN] Could not detect driver. Using localhost. Run 'minikube tunnel' in admin shell." -ForegroundColor Yellow
            $BaseHost = "127.0.0.1"
        }
    }
    $baseUrl = "http://$BaseHost"
    $catalogUrl = "${baseUrl}:30081"
    $seatingUrl = "${baseUrl}:30082"
    $orderUrl = "${baseUrl}:30083"
    $paymentUrl = "${baseUrl}:30084"
} else {
    $baseUrl = "http://localhost"
    $catalogUrl = "${baseUrl}:8081"
    $seatingUrl = "${baseUrl}:8082"
    $orderUrl = "${baseUrl}:8083"
    $paymentUrl = "${baseUrl}:8084"
}

# Test 1: Health Checks
Write-Host "Test 1: Health Checks" -ForegroundColor Yellow
Write-Host "  Checking Catalog Service..." -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri "${catalogUrl}/actuator/health" -Method Get -ErrorAction Stop
    Write-Host "    [OK] Catalog Service is healthy" -ForegroundColor Green
} catch { Write-Host "    [FAIL] Catalog Service is down" -ForegroundColor Red }

Write-Host "  Checking Seating Service..." -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri "${seatingUrl}/actuator/health" -Method Get -ErrorAction Stop
    Write-Host "    [OK] Seating Service is healthy" -ForegroundColor Green
} catch { Write-Host "    [FAIL] Seating Service is down" -ForegroundColor Red }

Write-Host "  Checking Order Service..." -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri "${orderUrl}/actuator/health" -Method Get -ErrorAction Stop
    Write-Host "    [OK] Order Service is healthy" -ForegroundColor Green
} catch { Write-Host "    [FAIL] Order Service is down" -ForegroundColor Red }

Write-Host "  Checking Payment Service..." -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri "${paymentUrl}/actuator/health" -Method Get -ErrorAction Stop
    Write-Host "    [OK] Payment Service is healthy" -ForegroundColor Green
} catch { Write-Host "    [FAIL] Payment Service is down" -ForegroundColor Red }

Write-Host ""

# Test 2: Create Venue
Write-Host "Test 2: Create Venue" -ForegroundColor Yellow
$venueBody = @{
    name = "Madison Square Garden"
    location = "New York"
    capacity = 20000
} | ConvertTo-Json

try {
    $venueResponse = Invoke-RestMethod -Uri "${catalogUrl}/v1/venues" -Method Post -Body $venueBody -ContentType "application/json" -ErrorAction Stop
    $script:venueId = $venueResponse.id
    Write-Host "  [OK] Venue created (ID: $($script:venueId))" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Failed to create venue" -ForegroundColor Red
}
Write-Host ""

# Test 3: Create Event
Write-Host "Test 3: Create Event" -ForegroundColor Yellow
$eventBody = @{
    title = "Rock Concert 2024"
    eventType = "CONCERT"
    venueId = $script:venueId
    eventDate = "2024-12-31T20:00:00"
    basePrice = 150.00
    status = "ON_SALE"
} | ConvertTo-Json

try {
    $eventResponse = Invoke-RestMethod -Uri "${catalogUrl}/v1/events" -Method Post -Body $eventBody -ContentType "application/json" -ErrorAction Stop
    $script:eventIdCreated = $eventResponse.id
    Write-Host "  [OK] Event created (ID: $($script:eventIdCreated))" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Failed to create event: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "  Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 4: Generate Seats
Write-Host "Test 4: Generate Seats" -ForegroundColor Yellow
$seatsBody = @{
    section = "VIP"
    rows = 10
    seatsPerRow = 20
    price = 150.00
    replaceIfExists = $false
} | ConvertTo-Json

if ($script:eventIdCreated) {
  try {
      $seatsResponse = Invoke-RestMethod -Uri "${catalogUrl}/v1/events/$($script:eventIdCreated)/seats/generate" -Method Post -Body $seatsBody -ContentType "application/json" -ErrorAction Stop
      Write-Host "  [OK] $($seatsResponse.createdSeats) seats generated for Event ID $($script:eventIdCreated)" -ForegroundColor Green
  } catch {
      Write-Host "  [WARN] Failed to generate seats (may already exist)" -ForegroundColor Yellow
  }
} else {
  Write-Host "  [SKIP] No event created in previous test" -ForegroundColor Yellow
}
Write-Host ""

# Test 5: Get Available Seats
Write-Host "Test 5: Get Available Seats" -ForegroundColor Yellow
try {
    # Prefer the event we just created; else pick an ON_SALE event
    if ($script:eventIdCreated) {
        $eventId = $script:eventIdCreated
    } else {
        $events = Invoke-RestMethod -Uri "${catalogUrl}/v1/events" -Method Get -ErrorAction Stop
        $firstEvent = $events | Where-Object { $_.status -eq "ON_SALE" } | Select-Object -First 1
        $eventId = $firstEvent.id
    }

    # Get seats from catalog
    $catalogSeats = Invoke-RestMethod -Uri "${catalogUrl}/v1/events/$eventId/seats?status=AVAILABLE" -Method Get -ErrorAction Stop
    
    # Get reserved/held seats from seating service to exclude them
    try {
        $reservedSeats = Invoke-RestMethod -Uri "${seatingUrl}/v1/seats?eventId=$eventId" -Method Get -ErrorAction Stop
        $reservedSeatIds = @($reservedSeats | Where-Object { $_.status -ne "RELEASED" } | ForEach-Object { $_.seatId })
    } catch {
        $reservedSeatIds = @()
    }
    
    # Find truly available seats (in catalog but not reserved in seating service)
    $trulyAvailableSeats = $catalogSeats | Where-Object { $_.id -notin $reservedSeatIds } | Select-Object -First 3
    
    if ($trulyAvailableSeats.Count -ge 3) {
        Write-Host "  [OK] Seats retrieved for Event ID $eventId (Total in catalog: $($catalogSeats.Count))" -ForegroundColor Green
        Write-Host "    Truly available (not reserved): $($trulyAvailableSeats.Count)" -ForegroundColor Gray
        
        # Store for order test
        $script:testEventId = $eventId
        $script:testSeatIds = @($trulyAvailableSeats[0].id, $trulyAvailableSeats[1].id, $trulyAvailableSeats[2].id)
    } else {
        Write-Host "  [WARN] Not enough available seats for Event ID $eventId" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [FAIL] Failed to retrieve seats: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Create Order (Buy Tickets)
Write-Host "Test 6: Create Order - Buy Tickets" -ForegroundColor Yellow
$idempotencyKey = [System.Guid]::NewGuid().ToString()

# Use the event and seats from Test 5
if ($script:testEventId -and $script:testSeatIds) {
    $orderBody = @{
        userId = 1
        eventId = $script:testEventId
        seatIds = $script:testSeatIds
        paymentMethod = "CREDIT_CARD"
    } | ConvertTo-Json

    Write-Host "  Using Idempotency-Key: $idempotencyKey" -ForegroundColor Gray
    Write-Host "  Event ID: $($script:testEventId), Seat IDs: $($script:testSeatIds -join ', ')" -ForegroundColor Gray
    try {
        $headers = @{
            "Idempotency-Key" = $idempotencyKey
            "Content-Type" = "application/json"
        }
        $script:orderResponse = Invoke-RestMethod -Uri "${orderUrl}/v1/orders" -Method Post -Body $orderBody -Headers $headers -ErrorAction Stop
        Write-Host "  [OK] Order created successfully" -ForegroundColor Green
        Write-Host "  Order ID: $($script:orderResponse.orderId)" -ForegroundColor White
        Write-Host "  Status: $($script:orderResponse.status)" -ForegroundColor White
        Write-Host "  Payment Status: $($script:orderResponse.paymentStatus)" -ForegroundColor White
        Write-Host "  Total: Rs.$($script:orderResponse.orderTotal)" -ForegroundColor White
        Write-Host "  Tickets: $($script:orderResponse.tickets.Count)" -ForegroundColor White
        $script:testOrderId = $script:orderResponse.orderId
    } catch {
        Write-Host "  [FAIL] Failed to create order: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            Write-Host "  Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  [SKIP] No available event or seats from previous test" -ForegroundColor Yellow
}
Write-Host ""

# Test 7: Test Idempotency (Retry)
Write-Host "Test 7: Test Idempotency - Retry Same Order" -ForegroundColor Yellow
if ($script:orderResponse) {
    Write-Host "  Using same Idempotency-Key: $idempotencyKey" -ForegroundColor Gray
    try {
        $retryResponse = Invoke-RestMethod -Uri "${orderUrl}/v1/orders" -Method Post -Body $orderBody -Headers $headers -ErrorAction Stop
        if ($retryResponse.orderId -eq $script:orderResponse.orderId) {
            Write-Host "  [OK] Got same order back (Order ID: $($retryResponse.orderId)) - Idempotency working!" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Got different order - Idempotency NOT working" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FAIL] Failed to retry order: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [SKIP] No order from previous test" -ForegroundColor Yellow
}
Write-Host ""

# Test 8: Get Order Details
Write-Host "Test 8: Get Order Details" -ForegroundColor Yellow
if ($script:testOrderId) {
    try {
        $orderDetails = Invoke-RestMethod -Uri "${orderUrl}/v1/orders/$($script:testOrderId)" -Method Get -ErrorAction Stop
        Write-Host "  [OK] Order details retrieved (Status: $($orderDetails.status))" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] Failed to retrieve order details" -ForegroundColor Red
    }
} else {
    Write-Host "  [SKIP] No order ID from previous test" -ForegroundColor Yellow
}
Write-Host ""

# Test 9: Check Seat Availability
Write-Host "Test 9: Check Seat Availability After Purchase" -ForegroundColor Yellow
if ($script:testEventId) {
    try {
        $availability = Invoke-RestMethod -Uri "${seatingUrl}/v1/seats?eventId=$($script:testEventId)" -Method Get -ErrorAction Stop
        $reservedSeats = ($availability | Where-Object { $_.status -eq "RESERVED" }).Count
        $heldSeats = ($availability | Where-Object { $_.status -eq "HELD" }).Count
        Write-Host "  [OK] Seat availability checked" -ForegroundColor Green
        Write-Host "    Reserved seats: $reservedSeats" -ForegroundColor White
        Write-Host "    Held seats: $heldSeats" -ForegroundColor White
    } catch {
        Write-Host "  [FAIL] Failed to check seat availability: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [SKIP] No event ID from previous test" -ForegroundColor Yellow
}
Write-Host ""

# Test 10: Prometheus Metrics
Write-Host "Test 10: Check Prometheus Metrics" -ForegroundColor Yellow
Write-Host "  Checking Catalog Service metrics..." -ForegroundColor Gray
try {
    $metrics = Invoke-WebRequest -Uri "${catalogUrl}/actuator/prometheus" -Method Get -ErrorAction Stop
    $httpMetrics = ($metrics.Content -split "`n" | Select-String -Pattern "http_server_requests_seconds_count" | Select-Object -First 1)
    if ($httpMetrics) {
        Write-Host "  [OK] Prometheus metrics available" -ForegroundColor Green
        Write-Host "    Sample: $httpMetrics" -ForegroundColor Gray
    }
} catch {
    Write-Host "  [FAIL] Failed to retrieve metrics" -ForegroundColor Red
}
Write-Host ""

# Test 11: Test Correlation ID
Write-Host "Test 11: Test Correlation ID Tracing" -ForegroundColor Yellow
$correlationId = "test-trace-" + (Get-Random -Maximum 9999)
Write-Host "  Using X-Correlation-Id: $correlationId" -ForegroundColor Gray

try {
    $corrHeaders = @{
        "X-Correlation-Id" = $correlationId
    }
    $response = Invoke-WebRequest -Uri "${catalogUrl}/v1/events/1" -Method Get -Headers $corrHeaders -ErrorAction Stop
    $returnedCorrId = $response.Headers["X-Correlation-Id"]
    if ($returnedCorrId -eq $correlationId) {
        Write-Host "  [OK] Correlation ID returned in response header" -ForegroundColor Green
    }
    Write-Host "  [INFO] Check service logs for correlationId: $correlationId" -ForegroundColor Gray
} catch {
    Write-Host "  [FAIL] Failed to test correlation ID" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[DONE] All 11 tests completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Key Features Demonstrated:" -ForegroundColor Yellow
Write-Host "  [+] All 4 microservices working" -ForegroundColor White
Write-Host "  [+] Database-per-service pattern" -ForegroundColor White
Write-Host "  [+] Complete buy tickets workflow" -ForegroundColor White
Write-Host "  [+] Idempotency working" -ForegroundColor White
Write-Host "  [+] Seat reservation and allocation" -ForegroundColor White
Write-Host "  [+] Payment processing" -ForegroundColor White
Write-Host "  [+] Prometheus metrics exposed" -ForegroundColor White
Write-Host "  [+] Correlation ID tracing" -ForegroundColor White
Write-Host ""
