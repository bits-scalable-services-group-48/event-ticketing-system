# Seed Data Script for Minikube
# Loads CSV data into catalog service running on Minikube
# Requires: start-port-forwards.ps1 running in another window

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Seeding Data to Minikube Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if port-forward is running
Write-Host "Checking connectivity..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:30081/actuator/health" -Method Get -ErrorAction Stop
    Write-Host "[OK] Catalog service accessible on localhost:30081" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot reach catalog service. Make sure start-port-forwards.ps1 is running!" -ForegroundColor Red
    Write-Host "Run this command in another window: .\start-port-forwards.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

$catalogUrl = "http://127.0.0.1:30081"
$dataPath = ".\etsr_seed_dataset"

# Check if data files exist
if (-not (Test-Path $dataPath)) {
    Write-Host "[ERROR] Seed data folder not found: $dataPath" -ForegroundColor Red
    exit 1
}

$venuesFile = Join-Path $dataPath "etsr_venues.csv"
$eventsFile = Join-Path $dataPath "etsr_events.csv"
$seatsFile = Join-Path $dataPath "etsr_seats.csv"

if (-not (Test-Path $venuesFile)) {
    Write-Host "[ERROR] Venues file not found: $venuesFile" -ForegroundColor Red
    exit 1
}

# Load and seed venues
Write-Host "Loading venues from CSV..." -ForegroundColor Yellow
$venues = Import-Csv $venuesFile
$venueCount = 0
$venueErrors = 0
$venueIdMap = @{}  # Map CSV venue_id to actual created venue ID

foreach ($venue in $venues) {
    $venueBody = @{
        name = $venue.name
        location = $venue.location
        capacity = [int]$venue.capacity
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "$catalogUrl/v1/venues" -Method Post -Body $venueBody -ContentType "application/json" -ErrorAction Stop
        $venueCount++
        $venueIdMap[$venue.venue_id] = $response.id  # Store mapping
        Write-Host "  [OK] Created venue: $($venue.name) (CSV ID: $($venue.venue_id) -> Actual ID: $($response.id))" -ForegroundColor Green
    } catch {
        $venueErrors++
        # Try to get existing venue by name
        try {
            $allVenues = Invoke-RestMethod -Uri "$catalogUrl/v1/venues" -Method Get -ErrorAction Stop
            $existingVenue = $allVenues | Where-Object { $_.name -eq $venue.name } | Select-Object -First 1
            if ($existingVenue) {
                $venueIdMap[$venue.venue_id] = $existingVenue.id
                Write-Host "  [OK] Found existing venue: $($venue.name) (CSV ID: $($venue.venue_id) -> Actual ID: $($existingVenue.id))" -ForegroundColor Cyan
            } else {
                Write-Host "  [SKIP] Venue '$($venue.name)' failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [SKIP] Venue '$($venue.name)' failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Venues: $venueCount created, $venueErrors skipped/failed" -ForegroundColor Cyan
Write-Host "Venue ID mappings: $($venueIdMap.Count)" -ForegroundColor Cyan
Write-Host ""

# Load and seed events
Write-Host "Loading events from CSV..." -ForegroundColor Yellow
$events = Import-Csv $eventsFile
$eventCount = 0
$eventErrors = 0

foreach ($event in $events) {
    # Map the CSV venue_id to actual venue ID
    $actualVenueId = $venueIdMap[$event.venue_id]
    
    if (-not $actualVenueId) {
        Write-Host "  [SKIP] Event '$($event.title)' - venue_id $($event.venue_id) not found in mapping" -ForegroundColor Yellow
        $eventErrors++
        continue
    }
    
    $eventBody = @{
        title = $event.title
        eventType = $event.event_type
        venueId = [int]$actualVenueId  # Use mapped venue ID
        eventDate = $event.event_date
        basePrice = [decimal]$event.base_price
        status = $event.status
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "$catalogUrl/v1/events" -Method Post -Body $eventBody -ContentType "application/json" -ErrorAction Stop
        $eventCount++
        Write-Host "  [OK] Created event: $($event.title) (ID: $($response.id), Venue: $actualVenueId)" -ForegroundColor Green
    } catch {
        $eventErrors++
        $errorMsg = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorMsg = $errorObj.message
            } catch {
                $errorMsg = $_.ErrorDetails.Message
            }
        }
        Write-Host "  [SKIP] Event '$($event.title)' failed: $errorMsg" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Events: $eventCount created, $eventErrors skipped/failed" -ForegroundColor Cyan
Write-Host ""

# Load and seed seats
if (Test-Path $seatsFile) {
    Write-Host "Loading seats from CSV..." -ForegroundColor Yellow
    $seats = Import-Csv $seatsFile
    $seatCount = 0
    $seatErrors = 0
    
    # Group seats by event_id to batch create
    $seatsByEvent = $seats | Group-Object -Property event_id
    
    foreach ($eventGroup in $seatsByEvent) {
        $eventId = $eventGroup.Name
        $eventSeats = $eventGroup.Group
        
        # Get unique sections from this event's seats
        $sections = $eventSeats | Select-Object -Property section, row, seat_number, price -Unique | Group-Object -Property section
        
        foreach ($sectionGroup in $sections) {
            $section = $sectionGroup.Name
            $sectionSeats = $sectionGroup.Group
            
            # Calculate rows and seats per row
            $maxRow = ($sectionSeats.row | Measure-Object -Maximum).Maximum
            $seatsPerRow = ($sectionSeats | Where-Object { $_.row -eq 1 } | Measure-Object).Count
            $price = ($sectionSeats | Select-Object -First 1).price
            
            if ($seatsPerRow -eq 0) { $seatsPerRow = 10 }  # Default if can't determine
            
            $seatsBody = @{
                section = $section
                rows = [int]$maxRow
                seatsPerRow = [int]$seatsPerRow
                price = [decimal]$price
                replaceIfExists = $false
            } | ConvertTo-Json
            
            try {
                $response = Invoke-RestMethod -Uri "$catalogUrl/v1/events/$eventId/seats/generate" -Method Post -Body $seatsBody -ContentType "application/json" -ErrorAction Stop
                $seatCount += $response.createdSeats
                Write-Host "  [OK] Generated $($response.createdSeats) seats for Event $eventId, Section $section" -ForegroundColor Green
            } catch {
                $seatErrors++
                Write-Host "  [SKIP] Seats for Event $eventId, Section $section may already exist" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
    Write-Host "Seats: $seatCount created, $seatErrors sections skipped/failed" -ForegroundColor Cyan
} else {
    Write-Host "[INFO] No seats CSV file found, skipping seat generation" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Seed Data Load Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Venues: $venueCount created" -ForegroundColor White
Write-Host "  Events: $eventCount created" -ForegroundColor White
Write-Host "  Seats: $seatCount created" -ForegroundColor White
Write-Host ""
Write-Host "You can now run: .\test-api.ps1 -Target minikube" -ForegroundColor Cyan
Write-Host ""
