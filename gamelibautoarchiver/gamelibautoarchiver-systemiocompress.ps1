# Requires PowerShell 7.1 or later
# Uses System.IO.Compression.ZipArchive in Update mode for in-place zip updates
param (
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [string]$MetadataExtension = ".zipmeta"
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Ensure root path exists
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path '$RootPath' does not exist."
    exit 1
}

# Function to get file metadata
function Get-FileMetadata {
    param ([string]$FolderPath)
    $metadata = @{}
    Get-ChildItem -Path $FolderPath -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($FolderPath.Length + 1).Replace('\', '/')
        $metadata[$relativePath] = @{
            Length = $_.Length
            LastWriteTime = $_.LastWriteTimeUtc.ToString('u')
        }
    }
    return $metadata
}

# Function to load metadata from file
function Get-StoredMetadata {
    param ([string]$MetadataFile)
    if (Test-Path $MetadataFile) {
        $content = Get-Content $MetadataFile -Raw | ConvertFrom-Json
        $metadata = @{}
        $content.PSObject.Properties | ForEach-Object {
            $metadata[$_.Name] = @{
                Length = $_.Value.Length
                LastWriteTime = $_.Value.LastWriteTime
            }
        }
        return $metadata
    }
    return @{}
}

# Function to save metadata to file
function Save-Metadata {
    param ([string]$MetadataFile, [hashtable]$Metadata)
    $Metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $MetadataFile
}

# Function to update zip file
function Update-ZipFile {
    param (
        [string]$FolderPath,
        [string]$ZipPath,
        [string]$MetadataFile
    )

    $folderName = Split-Path $FolderPath -Leaf
    Write-Host "Processing folder: $folderName"

    $currentMetadata = Get-FileMetadata -FolderPath $FolderPath
    $storedMetadata = Get-StoredMetadata -MetadataFile $MetadataFile

    # If no zip exists, create new
    if (-not (Test-Path $ZipPath)) {
        Write-Host "Creating new zip: $ZipPath"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($FolderPath, $ZipPath)
        Save-Metadata -MetadataFile $MetadataFile -Metadata $currentMetadata
        return
    }

    # Identify changes
    $toUpdate = @()
    $toDelete = @()

    # Check for new or modified files
    foreach ($file in $currentMetadata.Keys) {
        if (-not $storedMetadata.ContainsKey($file) -or
            $currentMetadata[$file].Length -ne $storedMetadata[$file].Length -or
            $currentMetadata[$file].LastWriteTime -ne $storedMetadata[$file].LastWriteTime) {
            $toUpdate += $file
        }
    }

    # Check for deleted files
    foreach ($file in $storedMetadata.Keys) {
        if (-not $currentMetadata.ContainsKey($file)) {
            $toDelete += $file
        }
    }

    if ($toUpdate.Count -eq 0 -and $toDelete.Count -eq 0) {
        Write-Host "No changes detected for: $folderName"
        return
    }

    # Update zip in-place
    $zip = $null
    try {
        # Open zip in Update mode
        $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Update)

        # Delete removed entries
        foreach ($file in $toDelete) {
            $entry = $zip.GetEntry($file)
            if ($null -ne $entry) {
                $entry.Delete()
                Write-Host "Deleted from zip: $file"
            }
        }

        # Add or update changed files
        foreach ($file in $toUpdate) {
            $fullPath = Join-Path $FolderPath $file
            # Delete existing entry if it exists
            $existingEntry = $zip.GetEntry($file)
            if ($null -ne $existingEntry) {
                $existingEntry.Delete()
            }
            # Add new entry
            $entry = $zip.CreateEntry($file)
            $entryStream = $entry.Open()
            $fileStream = [System.IO.File]::OpenRead($fullPath)
            $fileStream.CopyTo($entryStream)
            $fileStream.Close()
            $entryStream.Close()
            Write-Host "Updated in zip: $file"
        }

        Save-Metadata -MetadataFile $MetadataFile -Metadata $currentMetadata
        Write-Host "Updated zip: $ZipPath"
    }
    catch {
        Write-Error "Error updating zip: $_"
    }
    finally {
        if ($null -ne $zip) {
            $zip.Dispose()
        }
    }
}

# Main processing loop
Get-ChildItem -Path $RootPath -Directory | ForEach-Object {
    $folderPath = $_.FullName
    $zipPath = Join-Path $RootPath ($_.Name + ".zip")
    $metadataFile = Join-Path $RootPath ($_.Name + $MetadataExtension)

    Update-ZipFile -FolderPath $folderPath -ZipPath $zipPath -MetadataFile $metadataFile
}