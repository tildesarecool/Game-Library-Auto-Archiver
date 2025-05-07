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

# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_arrays?view=powershell-7.5
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pipelines?view=powershell-7.5
# https://grok.com/share/bGVnYWN5_e92068f6-0681-4d44-b2ca-6d88d0ca66a9

# 4 April 2025
# Note: I've recently learned that zip files created with compress-archive have a file size limit of 2GB, which I was not aware of. The only work arounds as far as I can tell is to either auto-create ~2 gig zip files of folders larger than this or to use a third party utility like 7zip. I don't have any interest in splitting a 110 gigabyte folder into many 2 gigabyte zip files. Actually the default zip file size limit is 4 gigaybtes anyway. Apparently compress-archive doesn't do zip64 which has no such file size limits. I actually thought of my own alternative as well which I'm still assessing.
# 
# A long winded a way of saying this script is on hold while I 're-assess my options.'
# CmdletBinding: Adds support for -Verbose and -Debug (run with Set-DestPathObject -Verbose).
[CmdletBinding(DefaultParameterSetName="Manual", SupportsShouldProcess=$true)]
<# 
.SYNOPSIS
    Compresses Steam game folders into dated zip archives with parallel processing and duplicate management.

.DESCRIPTION
    SteamZipper scans a ...
#>


param (
    [string]$sourceFolder,
    [string]$destinationFolder
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
$PreferredDateFormat = "MMddyyyy"
#$global:CompressionExtension = "zip"
$global:sizeLimitKB = 50 # arbitrary folder size
$global:logBaseName = "Start-GameLibraryArchive-log.txt"



function Set-SrcPathObject {
# CmdletBinding: Adds support for -Verbose and -Debug (run with Set-SrcPathObject -Verbose).
    [CmdletBinding()]
    param()
# (optional, used with params)
# despite the lack of a return keyword here, assigning a variable to
# Set-SrcPathObject results in an array data type
# so from $DisplayCustomeSrcObj = Set-SrcPathObject 
# $DisplayCustomeSrcObj is an array with all properties/methods for an array
# this alien to me as a concept but i'm learning
# i added in the extra lines that would make it look more like what i expect
# but i left them commented out
# possible idea for later: parameter to return pscustom object of folders left of out of ps custom object (e.g. under 50KB)?

########## $results = @()
    Get-ChildItem -Path $sourceFolder -Directory -ErrorAction SilentlyContinue | ForEach-Object {
#        $folderpath = $_.FullName
#        Write-Host "value of `$_.FullName is $($_.FullName)"
        $folderName = $_.BaseName
        #Write-Verbose "Processing folder: $FolderName"

        $IsOver50KB = Get-FolderSizeKB -FolderPath $FolderName -Verbose
        #Write-Verbose "Folder $FolderName size over 50 KB: $IsOver50KB"

        # check folder size
#        if (Get-FolderSizeKB -folderPath $folderpath) {
            
#       Write-Host "value of `$_.BaseName is $($_.BaseName)"
        $lastwritedate = $_.LastWriteTime
        $underscorename = ConvertTo-UnderscoreName -Name $folderName
        $datecode = $lastwritedate | Get-Date -Format $PreferredDateFormat
        $platform = Get-PlatformShortName
        $HypotheticalName = "$UnderscoreName`_$DateCode`_$Platform"
#        Write-Host "value of hypotheticalName is $hypotheticalName"
        # create pscustomobject
########## results += [PSCustomObject]@{
            [PSCustomObject]@{
                FolderName = $folderName
                UnderScoreName   = $underscorename
                Platform         = $platform
                LastWriteDate    = $lastwritedate
                HypotheticalName = $HypotheticalName
                IsOver50KB       = $IsOver50KB
            }
#        } # end of if (Get-FolderSizeKB -folderPath $folderpath)
    }     
########## return results

}

function Set-DestPathObject {
    [CmdletBinding()]
    param()
#    $ExtractedFileNameDate = @()

    $results = @()

    Get-ChildItem -Path $destinationFolder -File -ErrorAction SilentlyContinue | ForEach-Object {
        $fileBasename = $_.BaseName # should be a file name, like Outzone_11012024_steam
#        Write-Host "value of `$fileBasename is $fileBasename`n"  -ForegroundColor Green
        $FullFileName = $_.Name
        $FileSplit = $fileBasename -split "_" # break file name into pieces based on _, like Outzone 11012024 steam
#        Write-Host "value of `$fileSplit is $fileSplit`n"  -ForegroundColor Green
        $DateCodeFromFile = $FileSplit[-2].Trim()
        $Platform = $FileSplit[-1]
#        Write-Host "value of `$DateCodeFromFile is $DateCodeFromFile and is of type $($DateCodeFromFile.GetType().Name)`n"  -ForegroundColor Blue
#        Write-Host "now attempting to send date into GetFileDate...`n"

        try {
            $lastWriteDate = Get-FileDateStamp $DateCodeFromFile
            #$platform = Get-PlatformShortName 
            
            $underscoreName = ($fileSplit[0..($fileSplit.Count - 3)] -join "_")

            $results += [PSCustomObject]@{
                FileName        = $fileBasename
                FullFileName    = $FullFileName
                UnderScoreName  = $underscoreName
                lastWriteDate   = $lastWriteDate
                Platform        = $Platform
                Warnings        = $null
            }
            
            #$finalDateCode = Get-FileDateStamp $DateCodeFromFile
#        Write-Host "value of `$finalDateCode is $finalDateCode`n"  -ForegroundColor Magenta 
        } catch {
            Write-Verbose "Invalid date code in $fileBasename`: $_"
            $results += [PSCustomObject]@{
                FileName          = $fileBasename
                FullFileName      = $FullFileName
                UnderScoreName    = $null
                LastWriteDate     = $null
                Platform          = $null
                Warnings           = "Invalid date code in $FileNameWithExt`: $_"
            }                                      

        }
    }

#        $underscoreName = ($fileSplit[0..($fileSplit.Count - 3)] -join "_")
#        $platform = Get-PlatformShortName -Name $fileBasename

    # for debugging at least return whatever $ExtractedFileNameDate is
    #return $ExtractedFileNameDate
    return $results
}



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


function Get-FileDateStamp {
    # I come to further conclusions on what this function should actually do:
    # actually, it should only return date objects and that's it
    # as in send an 8 digit date code and it returns a date object
    # or send it a full path to folder and returns a date object (or just name of folder for same)
    # for any other conversions a different function should handl it or it should be handled differently
    # which means i can make the parameter of this function a string once again
    
    #
    # scenario 1: send in full path to a folder only, return a date object
    #  $GameFolder = Get-Item "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon" # sample value: Sunday, March 16, 2025 11:40:26
    # $gameFolderWriteTime = $GameFolder.LastWriteTime # $gameFolderWriteTime is date object
    # ---$gameFolderDateCode = $gameFolderWriteTime | Get-Date -Format "MMddyyyy"--- <-- handled in another function/another way
    # $gameFolderDateCode now string value of 03162025
    #
    # scenario 2: send only a folder name: attempt to join this with source path from user and see if that is valid path or not
    # $getDateFromPathFolder = Get-FileDateStamp "bit Dungeon III"
    #
    # scenario 3: send in an 8 digit date code (the parameter is cast to a string so with or without quotes)
    # $getAdatecode = "03162025"
    # $StrToDateObj = [datetime]::ParseExact($getAdatecode, $PreferredDateFormat, $null) # $StrToDateObj now a date object
    # and this also returns a date object
    

    param ( [Parameter(Mandatory=$true)] 
        [string]$StrToConvert
    )

    if ( ($StrToConvert -eq "") -or ($StrToConvert -eq " ") -or ( $null -eq $StrToConvert) ) {
        return $null
    }
    
    try {
        if ($StrToConvert -is [int]) {
            $StrToConvert = "{0:D8}" -f $StrToConvert
        } elseif ($StrToConvert -is [string]) {
            $StrToConvert = $StrToConvert.PadLeft(8,'0')
        }
#        Write-Host "inside the {0:d8} try, StrToConvert is $($StrToConvert)"
        $getIfDateConvertable = [datetime]::ParseExact($StrToConvert, $PreferredDateFormat, $null)
#        Write-Host "`n(inside getfiledatestamp function) Value of getIfDateConvertable is $($getIfDateConvertable) of type $($getIfDateConvertable.GetType().Name)`n"
        return $getIfDateConvertable
    } catch {
#        Write-Host "'$StrToConvert' is not a valid MMddyyyy date code."
        $getIfDateConvertable = $false
    }
    #-----------------------------------------------------------------------------

    #$SeeIfAbsPath = ( (Test-Path $StrToConvert) -and ((Get-Item $StrToConvert).PSIsContainer ) )
    $SeeIfAbsPath =  (Test-Path -Path $StrToConvert -PathType Container -ErrorAction SilentlyContinue) #-and ((Get-Item $StrToConvert).PSIsContainer ) 
#    Write-Host "SeeIfAbsPath value from the test of  ( (Test-Path `$StrToConvert) -and ((Get-Item `$StrToConvert).PSIsContainer ) ) is $($SeeIfAbsPath)"

    if ( $SeeIfAbsPath   ) { # if the parameter is already a path
            return (Get-Item $StrToConvert).LastWriteTime
        #}
    }

    if (-not $SeeIfAbsPath) { # if parameter does not come back as a path alrady
        $seeIfJoinedPath = Join-Path -Path $sourceFolder -ChildPath $StrToConvert # attempt to make into a full path
        $JoinedPathMakeAbs = (Test-Path -Path $seeIfJoinedPath -PathType Container -ErrorAction SilentlyContinue)  # -and ((Get-Item $seeIfJoinedPath).PSIsContainer ) )

#        Write-Host "value of seeIfJoinedPath is $seeIfJoinedPath and `$JoinedPathMakeAbs is $($JoinedPathMakeAbs)`n"
#        Write-Host "data type of $seeIfJoinedPath is $($seeIfJoinedPath.GetType().Name)"

        if ($JoinedPathMakeAbs) { # if it is now a path
#            Write-Host "after join the path is $($seeIfJoinedPath) and whether it's a valid path is $($JoinedPathMakeAbs)`n"
            return (Get-Item $seeIfJoinedPath).LastWriteTime # return the path, the end
        }
        else {
            return $false
        }        
    } 
    
    # All tests failed
#    Write-Host "'$StrToConvert' is neither a valid folder path, folder name, nor MMddyyyy date code."
    return $null
}



function Get-NonEmptySourceFolders {
#   Output: Array of DirectoryInfo objects for non-empty folders (e.g., full paths like P:\...\bit Dungeon).
#   Usage: $nonEmptyFolders = Get-NonEmptySourceFolders.

    return Get-ChildItem $sourceFolder -Directory | Where-Object { Get-FolderSizeKB $_ }
}

function Get-DestFileNames {
    #   Output: Array of DirectoryInfo objects for existing destination files (e.g., full paths like P:\...\bit Dungeon).
    #   Usage: $destinationFiles = Get-NonEmptySourceFolders.
    
    return Get-ChildItem $destinationFolder -File  | Select-Object -ExpandProperty BaseName  #Where-Object {  $_.BaseName }
}

function ConvertTo-UnderscoreName {
#   Input: A string (or piped array of strings).
#   Output: Transformed string(s) (e.g., bit Dungeon → bit_Dungeon).
#   Usage:
#   Single: ConvertTo-UnderscoreName "bit Dungeon"
#   Piped: $nonEmptyFolders.Name | ConvertTo-UnderscoreName

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Name
    )
    process {
        return $Name -replace ' ', '_'
    }
}

function Get-FolderSizeKB {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $folderPath, # left untyped on purpose. so that folderPath can be either a string or a [System.IO.DirectoryInfo] type
        [int]$sizeLimitKB = $global:sizeLimitKB
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
        if ($FolderSizeKBTracker -gt $sizeLimitKB) {
 #           Write-Verbose "Folder $resolvedPath size: $FolderSizeKBTracker KB, exceeds $sizeLimitKB KB"
            return $true
        }
    }
    
    if ($err) { Write-Debug "Errors during enumeration: $($err | Out-String)" }
#    Write-Verbose "Folder $resolvedPath size: $FolderSizeKBTracker KB, does not exceed $sizeLimitKB KB"
    return $false
}

function Get-FoldersToArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$SourceObjects,
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$DisplayCustomeDstObj
    )

    #$destFiles = Set-DestPathObject $DisplayCustomeDstObj #| Select-Object -Property FileName 
    #$DisplayCustomeDstObj = Set-DestPathObject #| Select-Object -Property FileName 
    #$SourceObjects = Set-SrcPathObject

    $results = @()
    foreach ($src in $SourceObjects) {
#        Write-Verbose "Processing source folder: $($src.FolderName)"

        $folderName = $src.FolderName
        $hypotheticalName = $src.HypotheticalName
        $underscoreName= $src.UnderScoreName
        $platform = $src.platform
        $lastWriteDate = $src.LastWriteDate
        $isOver50KB = $src.IsOver50KB
        $archiveStatus = "NeedsArchive"
        $matchingFiles = @()
        $warnings = @()

        # Skip folders under 50 KB
        # Step 1: Check if folder is excluded (< 50 KB)
        if (-not $IsOver50KB) { 
#            Write-Verbose "Folder $($src.FolderName) excluded (size < 50 KB)"
#            Write-Host "value of `$src is $src and kb status is $($src.IsOver50KB)" -ForegroundColor Green
            $archiveStatus = "Excluded"
            $results += [PSCustomObject]@{
                FolderName       = $FolderName
                HypotheticalName = $HypotheticalName
                LastWriteDate    = $LastWriteDate
                IsOver50KB       = $IsOver50KB
                ArchiveStatus    = $archiveStatus
                MatchingFiles    = $matchingFiles
                Warnings         = $warnings
                NeedsArchiving   = $false
            }
            continue
        }
        #}
        #return $results # for testing up to above foreach loop, shouldn't be required when function is finished

                        
        # Step 2: Check for related archives (older, exact, or future-dated)

        $relatedArchives = $DisplayCustomeDstObj | Where-Object {
            $_.UnderScoreName -eq $underscoreName -and
            $_.Platform -eq $platform
        }

        if ($relatedArchives) {
            #$archiveStatus = "AlreadyArchived"
            $matchingFiles = @($relatedArchives.FileNameWithExt)
            $futureArchives = $relatedArchives | Where-Object { $_.LastWriteDate -gt $lastWriteDate }
            if ($futureArchives) {
                $archiveStatus = "RequiresAction"
                $warnings += "Future-dated archive(s) detected: $($futureArchives.FileName -join ', ')"
            }
        } 

        # Step 3: Check for exact match to set ArchiveStatus

        $matchingArchives = $relatedArchives | Where-Object { $_.FileName -eq $hypotheticalName }
        if ( $matchingArchives ) {
            if ($matchingArchives.Count -gt 1)  {
                $archiveStatus = "RequiresAction"
                $warnings += "Multiple exact match archives detected: $($matchingArchives.FileNameWithExt -join ', ')"            
            } else {                
                $archiveStatus = "AlreadyArchived"            
            }
    }

        # Step 4: Add result to output
        $results += [PSCustomObject]@{
            FolderName       = $folderName
            HypotheticalName = $hypotheticalName
            LastWriteDate    = $LastWriteDate
            IsOver50KB       = $IsOver50KB
            ArchiveStatus    = $archiveStatus
            MatchingFiles    = $matchingFiles
            Warnings         = $warnings
            NeedsArchiving   = $archiveStatus -eq "NeedsArchive"

        }
    } # end foreach loop

    return $results
    
} # end of Get-FoldersToArchive


function Start-GameLibAutoArchiver {

    # startt of transcript ##################################################
    Start-Transcript -Path "$ModuleRoot\$logBaseName" | Out-Null
    #Start-GameLibraryArchive -LibraryPath $libpath -DestPath $zipDestpath

        Validate-ScriptParameters
        Validate-SourcePathPopulation
 
        $DestinationObjects = Set-DestPathObject
        $SourceObjects = Set-SrcPathObject
 
 
########################################

    $DestinationObjects | Format-Table -AutoSize -Wrap
    $DestinationObjects.Warnings

    $foldersToArchive = Get-FoldersToArchive -SourceObjects $SourceObjects -DisplayCustomeDstObj $DestinationObjects

    $foldersToArchive | Format-Table FolderName, LastWriteDate, ArchiveStatus, MatchingFiles, Warnings -AutoSize -Wrap

    # Report malformed archives
    $malformedArchives = ($DestinationObjects | Where-Object { $_.Warnings })
    Write-Host "value of DestinationObjects.Warnings is $($DestinationObjects.Warnings)" -ForegroundColor Magenta
    if ($malformedArchives) {
        Write-Warning "Malformed archives detected:"
        $malformedArchives | Format-Table FileName, Warning -AutoSize -Wrap
    }
#
#    $foldersToArchive = Get-FoldersToArchive -SourceObjects $SourceObjects -DisplayCustomeDstObj ($DestinationObjects | Where-Object { -not $_.Warning })
#
#    # Display full results with wrapped MatchingFiles to avoid wide columns
#    $foldersToArchive | Format-Table FolderName, LastWriteDate, ArchiveStatus, @{Label='MatchingFiles';Expression={$_.MatchingFiles -join "`n"}}, Warnings -AutoSize -Wrap
#
#    # Display folders requiring action
#    $actionRequired = $foldersToArchive | Where-Object { $_.ArchiveStatus -eq "RequiresAction" }
#    if ($actionRequired) {
#        Write-Warning "Folders requiring action:"
#        $actionRequired | Format-Table FolderName, HypotheticalName, Warnings -AutoSize -Wrap
#    }
#
#    # Final list of folders to archive
#    $foldersToArchiveNow = $foldersToArchive | Where-Object { $_.NeedsArchiving }
#    Write-Host "Folders to be archived:" -ForegroundColor Green
#    $foldersToArchiveNow | Format-Table FolderName,  HypotheticalName  -AutoSize



#        Write-Host "Get-FoldersToArchive table:`n" -ForegroundColor Magenta

#        $foldersToArchive = Get-FoldersToArchive -SourceObjects $SourceObjects -DisplayCustomeDstObj $DestinationObjects
#        #$foldersToArchive | Format-Table  FolderName,LastWriteDate,ArchiveStatus,MatchingFiles -AutoSize
#        $foldersToArchive | Format-Table FolderName, LastWriteDate, ArchiveStatus, MatchingFiles, Warnings -AutoSize -Wrap
        #$foldersToArchive | Format-Table FolderName, LastWriteDate, MatchingFiles, Warnings -AutoSize -Wrap

########################################


        Stop-Transcript | Out-Null

    }

Start-GameLibAutoArchiver






# "$sourcePath = 'C:\SourceFolder';
# $vhdxPath = 'P:\Program Files (x86)\Steam\steamapps\common\Dig Dog';
# $folderSize = (Get-ChildItem $sourcePath -Recurse -File | Measure-Object -Property Length -Sum).Sum;
# $vhdxSize = $folderSize + 30MB;
# Measure-Command {
# New-VHD -Path $vhdxPath -SizeBytes $vhdxSize -Dynamic;
# $disk = Mount-VHD -Path $vhdxPath -PassThru;
# Initialize-Disk -Number $disk.Number -PartitionStyle GPT;
#  New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -Confirm:$false;
# $driveLetter = (Get-Partition -DiskNumber $disk.Number).DriveLetter;
# Copy-Item -Path \'$sourcePath\*\' -Destination \'$driveLetter`:\' -Recurse;
# Get-ChildItem \'$driveLetter`:\' -Recurse | ForEach-Object { compact /c \'$($_.FullName)\'
# };
# Dismount-VHD -Path $vhdxPath;
# compact /c $vhdxPath } | format-table TotalSeconds"