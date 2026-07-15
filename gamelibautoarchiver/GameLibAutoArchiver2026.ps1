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

<# 
.PSScriptInfo
.SYNOPSIS
    Compresses Steam (gog, amazon, epic, etc.) game folders into dated zip archives with parallel processing and duplicate management.
.DESCRIPTION
    SteamZipper scans a ...
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


$minFolderSizeKB = 512 # Minimum folder size in KB to be considered for archiving (arbitrary value, can be adjusted as needed)
$PreferredDateFormat = "MMddyyyy" # date for the archive name, can be adjusted as needed
# no log file yet, but when I do this is where it  would be specified.
# logBaseName = "Start-GameLibraryArchive-log.txt"

# won't be offering alternative compression formats at this time, but if I do, this is where the user would specify it. 
# CompressionExtension = "zip"


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