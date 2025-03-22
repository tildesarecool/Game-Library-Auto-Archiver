# this is supposed to be a helper script to reset the source and destination folders back to
# where they started from to start the next script run/test
# in the theory i have the "always there/never change" folders that this script draws from
# and the actual folders the script runs against
# so i'm not sure if i need that list of game folders or not because i'm copying them
#

# these are the do-not-touch folder/zip file sources from which a test env 
# is established
# setup-test-env.ps1
# Reset test environment by copying reference folders and setting LastWriteTime

$sourceRefDir = "P:\Game-Library-Auto-Archiver\test env - dest game folders ref"  # ZIPs
$destRefDir = "P:\Game-Library-Auto-Archiver\test env - source large game folders ref"  # Game folders
$testSourceDir = "P:\Game-Library-Auto-Archiver\GameSource"
$testDestDir = "P:\Game-Library-Auto-Archiver\GameDest"

# Define date variables
$TenDaysPastDate = (Get-Date).AddDays(-10)
$FiveDaysPastDate = (Get-Date).AddDays(-5)
$FiveDaysFutureDate = (Get-Date).AddDays(5)
$TodayDate = (Get-Date)

# Step 1: Clean up test directories
if ((Test-Path $testSourceDir) -and (Test-Path $testDestDir)) {
    Remove-Item -Path "$testSourceDir\*" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$testDestDir\*" -Force -Recurse -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2  # Wait for deletion to sync
    Write-Host "Cleared $testSourceDir and $testDestDir"
} else {
    Write-Error "One of the test paths not found: $testSourceDir or $testDestDir"
    exit 1
}

# Step 2: Copy from reference to test directories
if ((Test-Path $sourceRefDir) -and (Test-Path $destRefDir)) {
    Copy-Item -Path "$destRefDir\*" -Destination $testSourceDir -Recurse -Force
    Copy-Item -Path "$sourceRefDir\*" -Destination $testDestDir -Recurse -Force
    Start-Sleep -Seconds 2  # Wait for copy to sync
    Write-Host "Copied from reference to $testSourceDir and $testDestDir"
} else {
    Write-Error "One of the reference paths not found: $sourceRefDir or $destRefDir"
    exit 1
}

# Pause for confirmation
Read-Host "Copy complete. Press Enter to set LastWriteTime..."

# Step 3: Set LastWriteTime on copied folders
$copiedFolders = Get-ChildItem -Path $testSourceDir -Directory
if ($copiedFolders.Count -eq 0) {
    Write-Error "No folders found in $testSourceDir after copy!"
    exit 1
}

$dates = @($TenDaysPastDate, $FiveDaysPastDate, $FiveDaysFutureDate, $TodayDate)
foreach ($folder in $copiedFolders) {
    $folderPath = $folder.FullName
    $dateIndex = [array]::IndexOf($copiedFolders, $folder) % $dates.Count
    $retryCount = 0
    $maxRetries = 5
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        if (Test-Path $folderPath) {
            try {
                Write-Host "Setting LastWriteTime for $folderPath to $($dates[$dateIndex])"
                Get-Item $folderPath -ErrorAction Stop | Set-ItemProperty -Name LastWriteTime -Value $dates[$dateIndex] -ErrorAction Stop
                $success = $true
            } catch {
                Write-Warning "Attempt $($retryCount + 1) failed for $folderPath $_"
                Start-Sleep -Milliseconds 500
                $retryCount++
            }
        } else {
            Write-Warning "Folder not found: $folderPath on attempt $($retryCount + 1)"
            Start-Sleep -Milliseconds 500
            $retryCount++
        }
    }

    if (-not $success) {
        Write-Error "Failed to set LastWriteTime for $folderPath after $maxRetries attempts"
    }
}

Write-Host "Test environment reset complete: $testSourceDir and $testDestDir ready."