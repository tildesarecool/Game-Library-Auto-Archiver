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
$PreferredDateFormat = "MMddyyyy"
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
#       Write-Host "value of `$_.LastWriteTime is $($_.LastWriteTime)"
        # generate hypothetical name
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
    Get-ChildItem -Path $destinationFolder -File -ErrorAction SilentlyContinue | ForEach-Object {
        $fileBasename = $_.BaseName # should be a file name, like Outzone_11012024_steam
#        Write-Host "value of `$fileBasename is $fileBasename`n"  -ForegroundColor Green
        $FileSplit = $fileBasename -split "_" # break file name into pieces based on _, like Outzone 11012024 steam
#        Write-Host "value of `$fileSplit is $fileSplit`n"  -ForegroundColor Green
        $DateCodeFromFile = $FileSplit[-2].Trim()
#        Write-Host "value of `$DateCodeFromFile is $DateCodeFromFile and is of type $($DateCodeFromFile.GetType().Name)`n"  -ForegroundColor Blue
#        Write-Host "now attempting to send date into GetFileDate...`n"

        try {
        $finalDateCode = Get-FileDateStamp $DateCodeFromFile
#        Write-Host "value of `$finalDateCode is $finalDateCode`n"  -ForegroundColor Magenta 
        } 
        catch {
            Write-Verbose "Invalid date code in $fileBaseName`: $_"
            return
        }

        $underscoreName = ($fileSplit[0..($fileSplit.Count - 3)] -join "_")
        $platform = $fileSplit[-1]

        [PSCustomObject]@{
            FileName = $fileBasename
            UnderScoreName = $underscoreName
            LastWriteDate  = $finalDateCode
            Platform       = $platform
        }
    }
    # for debugging at least return whatever $ExtractedFileNameDate is
    #return $ExtractedFileNameDate
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
        #$GetIsContain = Get-Item $StrToConvert
        #if ($GetIsContain -and $GetIsContain.PSIsContainer) {
#            Write-Host "`n.....if seeing this then `"$($StrToConvert)`" both exists as a path and is a folder`n"
#            Write-Host "attempting to return last write time of StrToConvert, value is $(( Get-Item $StrToConvert).LastWriteTime)`n" -ForegroundColor Green
            #return $StrToConvert # just return the path, the end
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

                        
        # Step 2: Check for exact matches (up-to-date archive)
        $matchingArchives = $DisplayCustomeDstObj | Where-Object { $_.FileName -eq $hypotheticalName }

        if ($matchingArchives) {
            $archiveStatus = "AlreadyArchived"
            $matchingFiles = @($matchingArchives.FileName)
        } else {
            # Step 3: Check for related archives (older or future-dated)
            $relatedArchives = $DisplayCustomeDstObj | Where-Object {
                $_.UnderScoreName -eq $underscoreName -and
                $_.Platform -eq $platform
                #$_.FileName -like "*_${platform}" #-and
#                $_.LastWriteDate -lt $lastWriteDate
            }

            if ($relatedArchives) {
#                $olderArchives = $relatedArchives | Where-Object { $_.LastWriteDate -lt $lastWriteDate }
#                $futureArchives = $relatedArchives | Where-Object { $_.LastWriteDate -gt $lastWriteDate }

                $matchingFiles = @($relatedArchives.FileName)
                $futureArchives = $relatedArchives | Where-Object{ $_.LastWriteDate -gt $lastWriteDate }

                if ($futureArchives) {
                    $archiveStatus = "RequiredAction"
                    $warnings += "Future-dated archives detected`: $($futureArchives.FileName -join ', ')"
                }
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
 
        $DisplayCustomeDstObj = Set-DestPathObject
        $SourceObjects = Set-SrcPathObject
 
 
        # $SizeOfTest = Get-FolderSizeKB "Outzone"
        # Write-Host "value of SizeOfTest is $SizeOfTest"
#        $datesFromFilenames = Set-DestPathObject
#
##        $finalDateCode = $datesFromFilenames | Get-FolderSizeKB
#
#        $datesFromFilenames | Format-Table -AutoSize
#        $DisplayCustomeSrcObj = Set-SrcPathObject
#        $DisplayCustomeSrcObj | Format-Table -AutoSize
########################################

        Write-Host "Get-FoldersToArchive table:`n" -ForegroundColor Magenta

        $foldersToArchive = Get-FoldersToArchive -SourceObjects $SourceObjects -DisplayCustomeDstObj $DisplayCustomeDstObj
        #$foldersToArchive | Format-Table  FolderName,LastWriteDate,ArchiveStatus,MatchingFiles -AutoSize
        $foldersToArchive | Format-Table FolderName, LastWriteDate, ArchiveStatus, MatchingFiles, Warnings -AutoSize -Wrap

#        $foldersToArchiveNow = $foldersToArchive | Where-Object { $_.NeedsArchiving }
#        Write-Host "Folders to be archived:" -ForegroundColor Green
#        $foldersToArchiveNow | Format-Table FolderName, HypotheticalName -AutoSize

        $actionRequired = $foldersToArchive | Where-Object { $_.ArchiveStatus -eq "RequiredAction" }
        if ($actionRequired) {
            Write-Warning "Folders requiring action:"
            $actionRequired | Format-Table FolderName, HypotheticalName, Warnings -AutoSize -Wrap
        }
#
        # Final list of folders to archive
        $foldersToArchiveNow = $foldersToArchive | Where-Object { $_.NeedsArchiving }
        Write-Host "Folders to be archived:" -ForegroundColor Green
        $foldersToArchiveNow | Format-Table FolderName, HypotheticalName -AutoSize

#    $DisplayCustomeDstObj = Set-DestPathObject # | Select-Object -Property FileName,LastWriteDate
#    $DisplayCustomeDstObj | Format-Table -AutoSize

#    $DisplayCustomeSrcObj = Set-SrcPathObject -Verbose
#    $validFolders = $DisplayCustomeSrcObj | Where-Object { $_.IsOver50KB }
##    Write-Host "Folders to consider for archiving:" -ForegroundColor Green
#    $validFolders | Format-Table -AutoSize #FolderName, LastWriteDate, HypotheticalName, IsOver50KB -AutoSize
#    $excludedFolders = $DisplayCustomeSrcObj | Where-Object { -not $_.IsOver50KB }
#    if ($excludedFolders) {
#        Write-Host "Folders excluded (size < 50 KB):" -ForegroundColor Yellow
#        $excludedFolders | Format-Table FolderName, HypotheticalName -AutoSize
#    }
########################################

#
#        $srcDirCount = $DisplayCustomeSrcObj.count
#        Write-Host "Sourfolder number of items: $($srcDirCount)" -ForegroundColor Magenta
#
#        if ( $datesFromFilenames[0].LastWriteDate -ne $DisplayCustomeSrcObj[0].LastWriteDate ) {
#            Write-Host "`$datesFromFilenames[0].LastWriteDate is not equal to `$DisplayCustomeSrcObj[0].LastWriteDate"
#        }

        Stop-Transcript | Out-Null

    }

Start-GameLibAutoArchiver

        #$FilenameSplit = @()

        # Get validated non-empty folders: array with full paths, as FS objects
        #$nonEmptyFolders = Get-NonEmptySourceFolders

#        Write-Host "valid list should be $($nonEmptyFolders)"

        # Get their names with underscores for comparison: array of source folder names with _ in place of spaces
        # - should still be FS objects -- just names with underscores, no full paths
        #$validatedNamesUnderscored = $nonEmptyFolders.Name | ConvertTo-UnderscoreName

        #Write-Host "validatedNamesUnderscored value is  $validatedNamesUnderscored" -ForegroundColor Magenta

        #Write-Host "nonemptyfolders value is  $(($nonEmptyFolders).BaseName)" -ForegroundColor Magenta # list full paths

#        Write-Host " I can't believe `$((`$nonEmptyFolders).BaseName) actually works to list only the `
#folder names and not the whole paths:`n$(($nonEmptyFolders).BaseName)" -ForegroundColor Magenta
        #$DestFileList = Get-DestFileNames

    #see dates from file names

        #Write-Host "valid underscore list should be $($validatedNamesUnderscored)"

        # Get destination files - obviously i need some functions to handle the destination half of this
#        $destFiles = Get-ChildItem $destinationFolder -File | Select-Object -ExpandProperty BaseName

#        Write-Host "valid list should be $($destFiles)"


#         $getDatefromCode = Get-FileDateStamp " "
#         Write-Host "getDatefromCode value is $getDatefromCode"
# 
        #$getDateFromPathFolder = Get-FileDateStamp "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon III"
        #$getDateFromPathFolder = Get-FileDateStamp "bit Dungeon III"
        #Write-Host "getDatefromCode value is $getDateFromPathFolder"
# 
#         $getDateCodeFromDate = Get-FileDateStamp "01/04/2025"
#         Write-Host "getDateCodeFromDate value is $getDateCodeFromDate"

#        $getDateObject = Get-FileDateStamp "03312025"
#        Write-Host "(inside Start-GameLibAutoArchiver function) from date code string 03312025 now have value $($getDateObject) of type $($getDateObject.GetType()) `n"
        #$ConvertDateObjToCode = Get-FileDateStamp $getDateObject
        #Write-Host "ConvertDateObjToCode value return is $($ConvertDateObjToCode)"

#        if ($($getDateObject.GetType().Name) -eq ([datetime]) ) {
#            Write-Host "date time return is true" # came back true
#        } else { "did not come back true" }

#        $getDateObject = Get-FileDateStamp "Outzone_11012024_steam.zip"
#        Write-Host "from input Outzone_11012024_steam.zip, value return is $($getDateObject)" # of type $($getDateObject.GetType().Name)`n"
#        $getDateObject = Get-FileDateStamp "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon"
#        Write-Host "from input 'P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon', value return is $($getDateObject)" # of type $($getDateObject.GetType().Name)`n"    



    # Compare
        # $FileMatches = $validatedNamesUnderscored | Where-Object { $destFiles -contains $_ }
        

        # using the Select-Object -ExpandProperty BaseName in the Get-DestFileNames function does return file names only, no paths
        # but it also cuts off the .zip part of the name, which is probably better for file extension nuetrality in the long run
        # right? as far as i know this array should still be FS objects






        #        $DestFileList.
        #Write-Host "file name list: $($DestFileList)"

        #$FileMatches = $validatedNamesUnderscored | Where-Object {$DestFileList -contains ($_ -split '_',-3)[6] } # ($DestFileList -split '_',-3)[6] 

        #$justNames = ($DestFileList -split '_',-3)[6]
        #Write-Host "file name matches: $($justNames)"
        #Write-Host "file name matches: $($FileMatches)"

#         Write-Host "src name list: $($validatedNamesUnderscored)"
#         Write-Host "and"

#         $namesSplitted = ($DestFileList[0]) -split "_"
#         $elementcount = $namesSplitted.count - 3
#         $justGameName = $($namesSplitted[0..$elementcount])

#        $justFileNames  = $DestFileList | ForEach-Object { 
#            $namesSplitted = $_.Split("_")
#            $justSplit = $namesSplitted[0..-3]
#
#            #$FilenameSplit += ($namesSplitted)[0..-3]
#
#        }
#
#        Write-Host "dest file name list: $($DestFileList)`n"
#
#         write-host "namesSplitted is $($namesSplitted)`n"
#         Write-Host "justGameName is $($justGameName)`n"
# 
#         $joinBack = $justGameName -join "_"
# 
#         Write-Host "joinBack is $($justGameName -join "_")`n"
# 
        
        #
#        write-host "justSplit is $($justSplit)`n"


        #Write-Host "file name matches: $($FileMatches.count)"
        # Write-Host "file name matches: $($FileMatches)"

#        $getPlatform = Get-PlatformShortName
#        
#        $validList = Remove-EmptySrcFolders
#
#        $FoldersWithoutUnderscores = Get-ValidSourceFolderList -UnderscoreList

#        Write-Host "valid list should be $($FoldersWithoutUnderscores)"
        #Write-Host "valid list should be $($validList.fullName)"
        
        
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



# function Remove-EmptySrcFolders {
# # Removed $PathArrayNonEmpty and +=:
# # Instead of building a new array manually, Where-Object filters $PathArray to only include folders where Get-FolderSizeKB $_ returns $true.
# # This is more efficient (no array copying) and cleaner.
# #
# # The += Concern: Using $PathArrayNonEmpty += $_ works but is less efficient because it creates a new array each time 
# # --->(arrays in PowerShell are immutable, so += copies the array with the new element)<---. For small lists, it’s fine, but for larger ones, 
# # it’s slower than necessary.
# #        this usage works -
# #         $GetFolderInfo = Remove-EmptySrcFolders
# #         Write-Host "the names of the folders are: $($GetFolderInfo.Name)"
# #         Write-Host "the names of the folders are: $($GetFolderInfo.FullName)"
# 
# 
# 
#     $FoldersWithoutUnderscores = Get-ValidSourceFolderList -NonUnderscoreList
# 
#     # so i'll pipe in that array to a for-eachboject and this will make it into an array of full paths, each one
#     $PathArray = @()
# #    $PathArrayNonEmpty = @()
#     # this line actually fills the array with the full path as an filesystem path/object
#     $PathArray = $FoldersWithoutUnderscores | ForEach-Object { Get-Item (Join-Path $sourceFolder $_) }
# 
#     return $PathArray | Where-Object { Get-FolderSizeKB $_ }
# 
# }



# function Get-ValidSourceFolderList {
#     # underscored versus non-underscored
#     # using [switch] makes it so only -UnderscoreList is need, as support to -UnderscoreList (some value)
#     param (
#         [switch]$UnderscoreList,
#         [switch]$NonUnderscoreList
#     )
# 
#     # still trying to decide what all this function should do. 
#     # so far it gets the subfolder list as an array
#     # then i use a second array to create the version with underscores instead of spaces
# 
#     # below is saying: if the UnderscoreList parameter is used at all, return a list with foldernames
#     # that have underscores instead of spaces 
#     # (this has a problem if you just want names as opposed to full paths with names that have _ instad of spaces)
#     #
#     # and also if -NonUnderscoreList is used at all then return the non underscore version
# 
# 
#     if ($UnderscoreList) {
#         return Get-ChildItem $sourceFolder -Directory | ForEach-Object { $_.Name -replace ' ', '_' }
#     }
#     elseif ($NonUnderscoreList) {
#         return Get-ChildItem $sourceFolder -Directory | Select-Object -ExpandProperty Name
#     }
#     return $false
# 
# }





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