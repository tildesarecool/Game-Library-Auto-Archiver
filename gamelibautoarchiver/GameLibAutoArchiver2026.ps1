# July 14 2026: A New approach
# 
#   tl;dr: split the script into four phases, as modular as possible, all handled by an
#    'orchestrator' function that will call each phase in order, and handle any errors that may occur.
#
# I've decided to split the script into four phases, hopefully as 
# modular as possible. The four phases are:
# 0. Pre-Processing: This phase will handle any necessary setup,
#    such as checking for required PS version, and preparing the environment.
#    things like .synopsis and .description would go in this phase.
# 1. going through the source and destination directories, 
#    and identifying the folders to be archived based on the specified criteria. 
#    Effectively filtering out source folders that do not meet the criteria for archiving, 
#    and creating a list of folders to be archived.
# 2. 
# 3. Archiving: This phase will perform the actual archiving of the game library
#    based on the specified criteriahanded to it from phase 2, such as folder sizes, and last write dates.
# 4. Reporting: This phase will generate a report of the archiving process,
#    including details such as the number of files archived, the total size of  
#    the archived files, and any errors encountered during the process.
#########################################################################################
#Requires -Version 7.0

<#PSScriptInfo
.version 1.0.0
.guid 12345678-1234-1234-1234-123456789012
.author Tildes
.tags "Game Library Archiver", "Steam", "GOG", "Epic Games", "Amazon Games"
#>

<#
.SYNOPSIS
    Compresses Steam (gog, amazon, epic, etc.) game folders into dated zip archives and duplicate management.
.DESCRIPTION
    Game Lib Auto Archiver scans a ...
.PARAMETER sourceFolder
    The folder containing the Steam game folders to be archived.
.PARAMETER destinationFolder
    The folder where the archived zip files will be saved.
# add .example as well in here   
#>



[CmdletBinding(DefaultParameterSetName="Manual", SupportsShouldProcess=$true)]
param (
    [string]$sourceFolder,
    [string]$destinationFolder
    # ideas for additional parameters:
    # config file path, log file path, dry run mode, verbose mode, etc.
    #
    #
    #    
)


if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Write-Host "Unable to establish the path of this script, exiting..." -ForegroundColor Red
    exit 1
}
try {
    # Start the transcript to log the script execution
    Start-Transcript -Path "$PSScriptRoot\Start-GameLibraryArchive-log.txt" -Append
}
catch {
    Write-Host "Failed to start transcript: $_" -ForegroundColor Red
    exit 1
}
#Start-Transcript -Path $PSScriptRoot\Start-GameLibraryArchive-log.txt -Append


$minFolderSizeKB = 512 # Minimum folder size in KB to be considered for archiving (arbitrary value, can be adjusted as needed)
$PreferredDateFormat = "MMddyyyy" # date for the archive name, can be adjusted as needed
# no log file yet, but when I do this is where it  would be specified.
# logBaseName = "Start-GameLibraryArchive-log.txt"

# won't be offering alternative compression formats at this time, but if I do, this is where the user would specify it. 
# CompressionExtension = "zip"

function Invoke-Phase0 {
    $config = @{
        "minFolderSizeKB" = $minFolderSizeKB
        "PreferredDateFormat" = $PreferredDateFormat
        "sourceFolder" = $sourceFolder
        "destinationFolder" = $destinationFolder
    }
return $config
}




function Get-PlatformShortName {
    # phase 1 function to determine the platform short name based on the source folder path
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

# Phase functions will be defined here, such as Phase1, Phase2, Phase3, and Phase4. Each phase will handle a specific part of the archiving process.

function Invoke-Phase0 {
    param (
        [int]$MinFolderSizeKB,
        [string]$PreferredDateFormat,
        [string]$SourceFolder,
        [string]$DestinationFolder
    )

    $config = @{
        MinFolderSizeKB     = $MinFolderSizeKB
        PreferredDateFormat = $PreferredDateFormat
        SourceFolder        = $SourceFolder
        DestinationFolder   = $DestinationFolder
    }

    return $config
}

function Invoke-Phase1 {
    param (
        [hashtable]$Config
    )

    # Implement the logic for Phase 1 here, using the parameters from $Config
    # For example, you might want to validate the source and destination folders,
    # check for required permissions, etc.

    try {
        # ... do the actual work ...

        if (<some validation failed>) {
            return @{ Success = $false; Data = $null; Reason = "explain why" }
        }

        # work succeeded
        return @{ Success = $true; Data = <whatever Phase2 will need>; Reason = $null }
    }
    catch {
        # catches unexpected/thrown errors, not just your own validation checks
        return @{ Success = $false; Data = $null; Reason = $_.Exception.Message }
    }
}


# hypothetical psuedo-code for a phase function, which would be implemented in a similar manner for each phase of the script. Each phase function would take the necessary input parameters, perform its specific tasks, and return a result indicating success or failure, along with any relevant data or error messages.
#function Phase1 {
#    param ( <whatever this phase needs as input> )
#
#    try {
#        # ... do the actual work ...
#
#        if ( <some validation failed> ) {
#            return @{ Success = $false; Data = $null; Reason = "explain why" }
#        }
#
#        # work succeeded
#        return @{ Success = $true; Data = <whatever Phase2 will need>; Reason = $null }
#    }
#    catch {
#        # catches unexpected/thrown errors, not just your own validation checks
#        return @{ Success = $false; Data = $null; Reason = $_.Exception.Message }
#    }
#}


######################## Orchestrator Function Calls #############################

$config = Invoke-Phase0 -MinFolderSizeKB $minFolderSizeKB `
                         -PreferredDateFormat $PreferredDateFormat `
                         -SourceFolder $sourceFolder `
                         -DestinationFolder $destinationFolder

$phase1Result = Invoke-Phase1 -Config $config
if (-not $phase1Result.Success) {
    Write-Host "Phase 1 failed, exiting: $($phase1Result.Reason)" -ForegroundColor Red
    exit 1
}





# very bottom of orchestrator/last line: stop transcript, so that the transcript is closed and saved properly at the end of the script execution.
try {
    Stop-Transcript
}
catch {
    Write-Host "Failed to stop transcript: $_" -ForegroundColor Red
    exit 1
}