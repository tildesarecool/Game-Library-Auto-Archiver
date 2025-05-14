#[CmdletBinding(DefaultParameterSetName="Manual", SupportsShouldProcess=$true)]
#<# 
#.SYNOPSIS
#    Compresses Steam game folders into dated zip archives with parallel processing and duplicate management.
#
#.DESCRIPTION
#    SteamZipper scans a ...
##>
#
#
#param (
#    [string]$sourceFolder,
#    [string]$destinationFolder
#)
# GLOBAL VARIABLES
# commented out are all "coming soon". just like to be prepared.
#$global:maxJobsDefine = [System.Environment]::ProcessorCount
$PreferredDateFormat = "MMddyyyy"
#$global:CompressionExtension = "zip"
$global:MinFileSizeLimitKB = 50 # arbitrary folder size
$global:MaxFileSizeLimitGB = 1.9
$global:logBaseName = "Start-GameLibraryArchive-log.txt"


if ( Test-Path "C:\Users\keith\Documents\Game-Library-Auto-Archiver\GameSource" ) {
    # path for lenovo laptop
    $sourceFolder = "C:\Users\keith\Documents\Game-Library-Auto-Archiver\GameSource"    
} else {
    Write-Host "unable to find path, existing"
    exit 0
}

$ModuleRoot = $PSScriptRoot
# a list of reasons to prematurally bail...
# such as the variable storing the path to the script not being defined...
if ( -not (Test-Path ($ModuleRoot)) ) {
    Write-Host "Unable to establish the path of this script, exiting..."
    exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Error: This script requires PowerShell 7 or later. You are running PowerShell $($PSVersionTable.PSVersion.ToString())." -ForegroundColor Red
    Write-Host "Please upgrade to PowerShell 7 or higher. Download it from: https://aka.ms/powershell (or try install via winget)" -ForegroundColor Yellow
    Write-Host "Exiting now." -ForegroundColor Red
    exit 1
}

function Validate-SourcePathPopulation {
    $SrcFolderCount =  Get-ChildItem -Path $sourceFolder -Directory
    if ( $SrcFolderCount.count -le 0 ) { 
        write-host "no subfolders found in source path provided ($sourceFolder), bailing..." -foregroundcolor Red
        exit 1
    }
}

function Get-FolderSizeKB {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $folderPath, # left untyped on purpose. so that folderPath can be either a string or a [System.IO.DirectoryInfo] type
        [int]$MinFileSizeLimitKB = $global:MinFileSizeLimitKB
    )

    $potentialPath = $null
    
    if (Test-Path $folderPath -PathType Container) {
        $resolvedPath = $folderPath
#        Write-Verbose "Using provided path: $resolvedPath"            
    } else {
        $folderName = if ($folderPath -is [System.IO.DirectoryInfo]) { $folderPath.Name } else { [string]$folderPath }
        $potentialPath = Join-Path -Path $sourceFolder -ChildPath $folderName # childPath parameter only takes string types
        if (Test-Path -Path $potentialPath -PathType Container) {
            $resolvedPath = $potentialPath
#            Write-Verbose "Using constructed path: $resolvedPath"
        }
    }

    if (-not $resolvedPath) {
        Write-Verbose "Invalid path: $folderPath (and not found under `$sourceFolder)"
        return $false
    }    


    $FolderSizeKBTracker = 0
#    foreach ($file in Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable err) {
    foreach ($file in Get-ChildItem -Path $resolvedPath -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable err) {
        $FolderSizeKBTracker += $file.Length / 1KB
        
        $FolderDetermineMin = if ($FolderSizeKBTracker -gt $MinFileSizeLimitKB) { 
            Write-Host "For $resolvedPath, the value of FolderDetermineMin is $FolderDetermineMin"
            return $true  
        } #else {  return $false }
        
        
    }
    
    if ($err) { Write-Debug "Errors during enumeration: $($err | Out-String)" }
#    Write-Verbose "Folder $resolvedPath size: $FolderSizeKBTracker KB, does not exceed $sizeLimitKB KB"
    return $false
}



function Categorize-SourcePathObject {
    [CmdletBinding()]
    param()

    Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
        $isOver50KB = Get-FolderSizeKB $_ 
        #Write-Host "Value of curfolder is $isOver50KB"
        $folderName = $_.BaseName
        $SetExtToZip =  if ( $isOver50KB ) { "zip" } else { "less than 50K" }

        #Write-Host "value of SetExtToZip is $SetExtToZip"


        [PSCustomObject]@{
            FolderName = $folderName
            FileExt    = $SetExtToZip
            IsOver50KB = $isOver50KB
        }
    }
    
}

Get-FolderSizeKB "C:\Users\keith\Documents\Game-Library-Auto-Archiver\GameSource"

#$GetSizeStatus = Categorize-SourcePathObject
#
#$GetSizeStatus | Format-Table -AutoSize