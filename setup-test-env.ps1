# this is supposed to be a helper script to reset the source and destination folders back to
# where they started from to start the next script run/test
# in the theory i have the "always there/never change" folders that this script draws from
# and the actual folders the script runs against
# so i'm not sure if i need that list of game folders or not because i'm copying them
#
# setup-test-env.ps1
# Reset test environment by copying reference folders and setting LastWriteTime

# these are the do-not-touch folder/zip file sources from which a test env 
if (Test-Path "C:\Users\keith\Documents\Game-Library-Auto-Archiver\test env - source large game folders ref") {
    $sourceRefDir = "C:\Users\keith\Documents\Game-Library-Auto-Archiver\test env - source large game folders ref"
    Write-Host "Game source set to P drive path"
} elseif (Test-Path "P:\Game-Library-Auto-Archiver\test env - source large game folders ref") {
    $sourceRefDir = "P:\Game-Library-Auto-Archiver\test env - source large game folders ref"
    Write-Host "Game source set to C drive path"
} else {
    Write-Host "Didn't find either path (source)"
    exit 1
}

if (Test-Path "C:\Users\keith\Documents\Game-Library-Auto-Archiver\test env - dest game folders ref") {  # Game folders") {
    $destRefDir = "C:\Users\keith\Documents\Game-Library-Auto-Archiver\test env - dest game folders ref"  # Game folders"
    Write-Host "Game dest set to P drive path"
} elseif (Test-Path "P:\Game-Library-Auto-Archiver\test env - dest game folders ref") {
    $destRefDir = "P:\Game-Library-Auto-Archiver\test env - dest game folders ref"
    Write-Host "Game dest set to C drive path"
} else {
    Write-Host "Didn't find either path (dest)"
    exit 1
}

# actual test directories
if (Test-Path "P:\Game-Library-Auto-Archiver\GameSource") {
    $testSourceDir = "P:\Game-Library-Auto-Archiver\GameSource"
    Write-Host "Game source set to P drive path"
} elseif (Test-Path "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameSource") {
    $testSourceDir = "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameSource"
    Write-Host "Game source set to C drive path"
} else {
    Write-Host "Didn't find either path (source)"
    exit 1
}

if (Test-Path "P:\Game-Library-Auto-Archiver\GameDest") {
    $testDestDir = "P:\Game-Library-Auto-Archiver\GameDest"
    Write-Host "Game dest set to P drive path"
} elseif (Test-Path "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameDest") {
    $testDestDir = "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameDest"
    Write-Host "Game dest set to C drive path"
} else {
    Write-Host "Didn't find either path (dest)"
    exit 1
}
# Date variables for LastWriteTime
$dates = @(
    (Get-Date).AddDays(-10),  # Old date
    (Get-Date).AddDays(-5),   # Recent date
    (Get-Date).AddDays(5),    # Future date
    (Get-Date)                # Today
)

# Step 1: Clean up test directories
if (-not ((Test-Path $testSourceDir) -and (Test-Path $testDestDir))) {
    Write-Error "Test path missing: $testSourceDir or $testDestDir"
    exit 1
}
Remove-Item -Path "$testSourceDir\*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "$testDestDir\*" -Force -Recurse -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1  # Brief wait for NVMe sync
Write-Host "Cleared $testSourceDir and $testDestDir"

# Step 2: Copy from reference to test directories
if (-not ((Test-Path $sourceRefDir) -and (Test-Path $destRefDir))) {
    Write-Error "Reference path missing: $sourceRefDir or $destRefDir"
    exit 1
}
Copy-Item -Path "$destRefDir\*" -Destination $testDestDir -Recurse -Force
Copy-Item -Path "$sourceRefDir\*" -Destination  $testSourceDir -Recurse -Force
Start-Sleep -Seconds 1  # Brief wait for NVMe sync
Write-Host "Copied from reference to $testSourceDir and $testDestDir"

# Step 3: Set LastWriteTime on copied folders
$copiedFolders = Get-ChildItem -Path $testSourceDir -Directory
if ($copiedFolders.Count -eq 0) {
    Write-Error "No folders found in $testSourceDir after copy!"
    exit 1
}

foreach ($i in 0..($copiedFolders.Count - 1)) {
    $folderPath = $copiedFolders[$i].FullName
    $dateIndex = $i % $dates.Count  # Cycle through dates
    Write-Host "Setting LastWriteTime for $folderPath to $($dates[$dateIndex])"
    Set-ItemProperty -Path $folderPath -Name LastWriteTime -Value $dates[$dateIndex]
}

Write-Host "Test environment reset complete: $testSourceDir and $testDestDir ready."