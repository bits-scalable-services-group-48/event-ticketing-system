# Seed Data Loader for Event Ticketing System
# This script loads data from CSV files into the microservices

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Event Ticketing System - Data Seeding" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost"
$catalogUrl = "${baseUrl}:8081"

# Check if services are running
Write-Host "Checking if services are running..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "${catalogUrl}/actuator/health" -Method Get -ErrorAction Stop
    Write-Host "  Catalog Service is UP" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Catalog Service is not running!" -ForegroundColor Red
    Write-Host "  Please start services first: docker-compose up" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Load venues
Write-Host "Loading Venues..." -ForegroundColor Yellow
$venues = Import-Csv "etsr_seed_dataset\etsr_venues.csv"
$venueCount = 0
$venueIdMap = @{}  # Map CSV venue_id to actual created venue ID

foreach ($venue in $venues) {
    $body = @{
        name = $venue.name
        location = $venue.city
        capacity = [int]$venue.capacity
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "${catalogUrl}/v1/venues" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
        $venueCount++
        $venueIdMap[$venue.venue_id] = $response.id  # Store mapping
        Write-Host "  Created: $($venue.name) in $($venue.city) (CSV ID: $($venue.venue_id) -> Actual ID: $($response.id))" -ForegroundColor Gray
    } catch {
        # Try to get existing venue by name
        try {
            $allVenues = Invoke-RestMethod -Uri "${catalogUrl}/v1/venues" -Method Get -ErrorAction Stop
            $existingVenue = $allVenues | Where-Object { $_.name -eq $venue.name } | Select-Object -First 1
            if ($existingVenue) {
                $venueIdMap[$venue.venue_id] = $existingVenue.id
                Write-Host "  Found existing: $($venue.name) (CSV ID: $($venue.venue_id) -> Actual ID: $($existingVenue.id))" -ForegroundColor Cyan
            } else {
                Write-Host "  Warning: Could not create venue $($venue.name)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Warning: Could not create venue $($venue.name)" -ForegroundColor Yellow
        }
    }
}
Write-Host "  Loaded $venueCount venues, mapped $($venueIdMap.Count) IDs" -ForegroundColor Green
Write-Host ""

# Load events
Write-Host "Loading Events..." -ForegroundColor Yellow
$events = Import-Csv "etsr_seed_dataset\etsr_events.csv"
$eventCount = 0
$eventSkipped = 0
$firstError = $true
foreach ($event in $events) {
    # Map the CSV venue_id to actual venue ID
    $actualVenueId = $venueIdMap[$event.venue_id]
    
    if (-not $actualVenueId) {
        $eventSkipped++
        if ($firstError) {
            Write-Host "  Warning: Event '$($event.title)' skipped - venue_id $($event.venue_id) not found in mapping" -ForegroundColor Yellow
            $firstError = $false
        }
        continue
    }
    
    # Parse the date
    $eventDate = [DateTime]::Parse($event.event_date).ToString("yyyy-MM-ddTHH:mm:ss")
    
    $body = @{
        title = $event.title
        eventType = $event.event_type
        venueId = [int]$actualVenueId  # Use mapped venue ID
        eventDate = $eventDate
        basePrice = [decimal]$event.base_price
        status = $event.status
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "${catalogUrl}/v1/events" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
        $eventCount++
        if ($eventCount % 10 -eq 0) {
            Write-Host "  Created $eventCount events..." -ForegroundColor Gray
        }
    } catch {
        $eventSkipped++
        if ($firstError) {
            Write-Host "  Error creating event: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
            $firstError = $false
        }
    }
}
Write-Host "  Loaded $eventCount events, skipped $eventSkipped" -ForegroundColor Green
Write-Host ""

# Load seats (this will take longer)
Write-Host "Loading Seats (this may take a few minutes)..." -ForegroundColor Yellow
$seats = Import-Csv "etsr_seed_dataset\etsr_seats.csv"
$seatCount = 0
$batchSize = 100

# Group seats by event for batch processing
$seatsByEvent = $seats | Group-Object -Property event_id

foreach ($eventGroup in $seatsByEvent) {
    $eventId = $eventGroup.Name
    Write-Host "  Loading seats for Event $eventId..." -ForegroundColor Gray
    
    foreach ($seat in $eventGroup.Group) {
        $body = @{
            eventId = [int]$seat.event_id
            section = $seat.section
            rowNumber = [int]$seat.row
            seatNumber = [int]$seat.seat_number
            price = [decimal]$seat.price
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri "${catalogUrl}/v1/seats" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
            $seatCount++
        } catch {
            # Silently skip duplicates or errors
        }
    }
    
    if ($seatCount % 500 -eq 0) {
        Write-Host "  Created $seatCount seats..." -ForegroundColor Gray
    }
}
Write-Host "  Loaded $seatCount seats" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Seeding Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Venues:  $venueCount" -ForegroundColor White
Write-Host "  Events:  $eventCount" -ForegroundColor White
Write-Host "  Seats:   $seatCount" -ForegroundColor White
Write-Host ""
Write-Host "You can now test the system with real data!" -ForegroundColor Green
Write-Host ""
Write-Host "Examples:" -ForegroundColor Yellow
Write-Host "  Get all venues:  curl http://localhost:8081/v1/venues" -ForegroundColor Gray
Write-Host "  Get all events:  curl http://localhost:8081/v1/events" -ForegroundColor Gray
Write-Host "  Get event seats: curl http://localhost:8081/v1/events/1/seats" -ForegroundColor Gray
Write-Host ""
