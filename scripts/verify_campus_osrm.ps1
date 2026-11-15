# Checks that the campus OSRM server returns pedestrian routes.
# Usage: powershell -File scripts/verify_campus_osrm.ps1 [-BaseUrl http://localhost:5001]
param([string]$BaseUrl = "http://localhost:5001")
$ErrorActionPreference = "Stop"

$points = [ordered]@{
    "Gate 3"                            = "35.341330768462434,32.40734220259285"
    "Cafeteria"                         = "35.34214214101637,32.40700627577471"
    "Faculty of Information Technology" = "35.34339310908723,32.40675340855915"
    "Faculty of Arts and Education"     = "35.3446055638246,32.40800579792771"
    "Faculty of Engineering"            = "35.345630598143295,32.4082993911763"
}

$failed = 0
$start = $points["Gate 3"]
foreach ($name in $points.Keys) {
    if ($name -eq "Gate 3") { continue }
    $url = "$BaseUrl/route/v1/foot/$start;$($points[$name])?overview=false&steps=true&radiuses=20.0;20.0"
    try {
        $r = Invoke-RestMethod -Uri $url
    } catch {
        Write-Host "FAIL  Gate 3 -> ${name}: $($_.Exception.Message)"; $failed++; continue
    }
    $route = $r.routes[0]
    $modes = @($route.legs | ForEach-Object { $_.steps } | ForEach-Object { $_.mode } | Sort-Object -Unique)
    $kmh = if ($route.duration -gt 0) { [math]::Round($route.distance / $route.duration * 3.6, 1) } else { 0 }
    $snap = [math]::Round($r.waypoints[-1].distance, 1)
    $ok = ($modes.Count -eq 1 -and $modes[0] -eq "walking")
    if (-not $ok) { $failed++ }
    $status = if ($ok) { "OK  " } else { "FAIL" }
    Write-Host ("{0}  Gate 3 -> {1}: {2:N0} m, {3} km/h, mode={4}, end snap {5} m" -f $status, $name, $route.distance, $kmh, ($modes -join ","), $snap)
}
if ($failed -gt 0) { throw "$failed route(s) failed the pedestrian check." }
Write-Host "All campus routes are pedestrian routes."
