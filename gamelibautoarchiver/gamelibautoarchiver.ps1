# gamelibautoarchiver.ps1
# Main modules for game library archiver
# March 2025
# https://github.com/tildesarecool/Game-Library-Auto-Archiver
# pwsh -command '& { .\gamelibautoarchiver.ps1 -sourceFolder "(source path)" -destinationFolder "(destination path)"  }'

# the psm1 is stored at
# reporoot\gamelibautoarchiver\gamelibautoarchiver.psm1
# which means probably $PSScriptRoot is reporoot\gamelibautoarchiver 
# so do i want to save the transcript to reporoot or actual reporoot\gamelibautoarchiver ?
# I think reporoot\gamelibautoarchiver for now
#
# i created a folder junction so the platform function would pick up the platform name
# new-item -ItemType Junction -Path "P:\Game-Library-Auto-Archiver\SteamSource" -Target "P:\Game-Library-Auto-Archiver\GameSource"


[CmdletBinding(DefaultParameterSetName="Manual", SupportsShouldProcess=$true)]
<# 
.SYNOPSIS
    Compresses Steam game folders into dated zip archives with parallel processing and duplicate management.

.DESCRIPTION
    SteamZipper scans a ...
#>

# # param (
# #     [Parameter(ParameterSetName="Manual")][string]$sourceFolder,
# #     [Parameter(ParameterSetName="Manual")][string]$destinationFolder
# # )
# #>

param (
    [string]$sourceFolder,
    [string]$destinationFolder
#    [Parameter(ParameterSetName="Manual")][string]$sourceFile,
#    [Parameter(ParameterSetName="Manual")][switch]$debugMode,
#    [Parameter(ParameterSetName="Manual")][switch]$VerbMode,
#    [Parameter(ParameterSetName="Manual")][switch]$keepDuplicates,
#    [Parameter(ParameterSetName="Manual")][ValidateSet("Optimal", "Fastest", "NoCompression")][string]$CompressionLevel = "Optimal",
#    [Parameter(ParameterSetName="Manual")][string]$answerFile,
#    [Parameter(ParameterSetName="Manual")][string]$createAnswerFile,
#    [Parameter(ParameterSetName="Manual")][switch]$Parallel,
#    [Parameter(ParameterSetName="Manual")][ValidateRange(1, 16)][int]$MaxJobs = $global:maxJobsDefine,
#    [Parameter(ParameterSetName="Manual")][switch]$Help
)

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


# hypothetical/rough/untested function not written yet
function Validate-SourcePathPopulation {
    $SrcFolderCount =  Get-ChildItem -Path $sourceFolder -Directory
    if ( $SrcFolderCount.count -le 0 ) { 
        write-host "no subfolders found in source path provided ($sourceFolder), bailing..." -foregroundcolor Red
        exit 1
    }
}


function Validate-ScriptParameters {
    $cleanSource = $sourceFolder.Trim('"', "'")
    $cleanDest = $destinationFolder.Trim('"', "'")
    if (-not (Test-Path -Path $cleanSource -PathType Container)) {
        Write-Host "Error: Source folder '$cleanSource' does not exist. Please provide a valid path." -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path -Path $cleanDest -PathType Container)) {
        try {
            New-Item -Path $cleanDest -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Successfully created destination folder: $cleanDest" -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to create destination folder '$cleanDest': $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

# GLOBAL VARIABLES
# commented out are all "coming soon". just like to be prepared.
#$global:maxJobsDefine = [System.Environment]::ProcessorCount
$global:PreferredDateFormat = "MMddyyyy"
#$global:CompressionExtension = "zip"
$global:sizeLimitKB = 50 # arbitrary folder size
$global:logBaseName = "Start-GameLibraryArchive-log.txt"

# NON-GLOBAL VARIABLES
# i haven't decided which if any of these to keep so I'm just leaving this block here
#if ($null -ne $params.sourceFolder) { $sourceFolder = $params.sourceFolder }
#if ($null -ne $params.destinationFolder) { $destinationFolder = $params.destinationFolder }
#if ($null -ne $params.debugMode) { $debugMode = $params.debugMode }
#if ($null -ne $params.VerbMode) { $VerbMode = $params.VerbMode }
#if ($null -ne $params.keepDuplicates) { $keepDuplicates = $params.keepDuplicates }
#if ($null -ne $params.CompressionLevel) { $CompressionLevel = $params.CompressionLevel }
#if ($null -ne $params.sourceFile) { $sourceFile = $params.sourceFile }


function Get-PlatformShortName {
    $platforms = @{
        "epic games"   = "epic"
        "Amazon Games" = "amazon"
        "GOG"          = "gog"
        "Steam"        = "steam"
        #"Origin"      = "origin"
    }
    foreach ($platform in $platforms.Keys) {
        if ($sourceFolder -like "*$platform*") {
            return $platforms[$platform]
        }
    }
    return "unknown"  # Default value if no match
}


function Get-FolderSizeKB {
#    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $folderPath, # left untyped on purpose. so that folderPath can be either a string or a [System.IO.DirectoryInfo] type
        [int]$sizeLimitKB = 50
    )
    
    $FolderSizeKBTracker = 0
    foreach ($file in Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable err) {
        $FolderSizeKBTracker += $file.Length / 1KB
        if ($FolderSizeKBTracker -gt $sizeLimitKB) {
            return $true
        }
    }
    
    if ($err) { Write-Debug "Errors during enumeration: $($err | Out-String)" }
    return $false
}

function Get-ValidSourceFolderList {
    # underscored versus non-underscored
    param (
        [switch]$UnderscoreList,
        [switch]$NonUnderscoreList
    )

    # still trying to decide what all this function should do. 
    # so far it gets the subfolder list as an array
    # then i use a second array to create the version with underscores instead of spaces

    if ($UnderscoreList) {
        return Get-ChildItem $sourceFolder -Directory | ForEach-Object { $_.Name -replace ' ', '_' }
    }
    elseif ($NonUnderscoreList) {
        return Get-ChildItem $sourceFolder -Directory | Select-Object -ExpandProperty Name
    }
    return $false

}

#     $SrceSubfolders =@() # new array
#     $SrceSubfoldersUnderscores = @()
#     $SrceSubfolders = Get-ChildItem $sourceFolder -Directory | Select-Object -ExpandProperty Name #-replace ' ','_'   # populate array
#     $SrceSubfoldersUnderscores = $SrceSubfolders -replace ' ','_' # too bruteforce? or too elegant? 
    # Write-Host "initial list of subfolders is:"
    # $SrceSubfoldersUnderscores | ForEach-Object {"Item: [$PSItem]"}

    # apparently i'm actually returning strings with these return statement
#    if ($underscorelist -eq $true ) { 
#        return $SrceSubfoldersUnderscores 
#    } elseif ($nonunderscorelist -eq $true) { 
#        return $SrceSubfolders # Get-ChildItem $sourceFolder -Directory | Select-Object -ExpandProperty Name 
#    } else { 
#        return $false 
#    }
#}

function Remove-EmptySrcFolders {

# 
# Removed $PathArrayNonEmpty and +=:
# Instead of building a new array manually, Where-Object filters $PathArray to only include folders where Get-FolderSizeKB $_ returns $true.
# This is more efficient (no array copying) and cleaner.
#
# The += Concern: Using $PathArrayNonEmpty += $_ works but is less efficient because it creates a new array each time 
# --->(arrays in PowerShell are immutable, so += copies the array with the new element)<---. For small lists, it’s fine, but for larger ones, 
# it’s slower than necessary.
#        this usage works -
#         $GetFolderInfo = Remove-EmptySrcFolders
#         Write-Host "the names of the folders are: $($GetFolderInfo.Name)"
#         Write-Host "the names of the folders are: $($GetFolderInfo.FullName)"

    $FoldersWithoutUnderscores = Get-ValidSourceFolderList -UnderscoreList

    # so i'll pipe in that array to a for-eachboject and this will make it into an array of full paths, each one
    $PathArray = @()
#    $PathArrayNonEmpty = @()
    # this line actually fills the array with the full path as an filesystem path/object
    $PathArray = $FoldersWithoutUnderscores | ForEach-Object { Get-Item (Join-Path $sourceFolder $_) }

    return $PathArray | Where-Object { Get-FolderSizeKB $_ }

}



function Start-GameLibAutoArchiver {

    # startt of transcript ##################################################
    Start-Transcript -Path "$ModuleRoot\$logBaseName" | Out-Null
    #Start-GameLibraryArchive -LibraryPath $libpath -DestPath $zipDestpath

        Validate-ScriptParameters
        Validate-SourcePathPopulation

        $getPlatform = Get-PlatformShortName
        
        $validList = Remove-EmptySrcFolders

        #$FoldersWithoutUnderscores = Get-ValidSourceFolderList -NonUnderscoreList

        # Write-Host "valid list should be $($FoldersWithoutUnderscores)"
        Write-Host "valid list should be $($validList)"
        
        
        #Write-Host "the platform is $getPlatform"
        # $determineEmptyNot = Get-FolderSizeKB "P:\Game-Library-Auto-Archiver\SteamSource\bit Dungeon"
        #$determineEmptyNot = Get-FolderSizeKB "P:\Game-Library-Auto-Archiver\SteamSource\cyberpunk"
        #Write-Host "Result of determining if path is empty or not is $($determineEmptyNot)"

    #    Get-ValidSourceFolderList
        # $folderswithUnderscores = Get-ValidSourceFolderList -underscorelist "underscorelist"
        # $FoldersWithoutUnderscores = Get-ValidSourceFolderList -nonunderscorelist "nonunderscorelist"
        # Write-Host "a list without underscores is $FoldersWithoutUnderscores"
        # Write-Host "and"
        # Write-Host "a list with underscores is $folderswithUnderscores"






    # end of transcript ##################################################
    Stop-Transcript | Out-Null

}

Start-GameLibAutoArchiver

#Export-ModuleMember -Function Start-GameLibraryArchive
#Export-ModuleMember -Function Main






# hypothetical start of script produced by an LLM. Not actually needed here, though.
#function Start-GameLibraryArchive {
#    param (
#        [Parameter(Mandatory)]
#        [string]$LibraryPath
#    )
#    Get-ChildItem -Path $LibraryPath -Directory | ForEach-Object {
#        $gameFolder = $_.FullName
#        $lastWrite = $_.LastWriteTime.ToString("yyyyMMdd")
#        $platform = "Unknown" # Add platform detection later
#        $zipName = Join-Path $ModuleRoot "$($_.Name)_$lastWrite_$platform.zip"
#        Compress-Archive -Path $gameFolder -DestinationPath $zipName -Force
#    }
#}

