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
    # $FileName is either a path to a folder or the zip file name. 
    # must pass in whole path for the folder but just a file name is fine for zip
    # so the folder i do the lastwritetime.tostring to get the date
    # and zip file name parse to date code with the [-2]

    #I didn't think I'd have to re-think this function ever since it 'was' working but
    # i discoverred get-date can also do some converting so
    #
    # scenario 1: given folder last write date convert to a string of format MMddyyyy
    #  $GameFolder = Get-Item "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon" # sample value: Sunday, March 16, 2025 11:40:26
    # $gameFolderWriteTime = $GameFolder.LastWriteTime # $gameFolderWriteTime is date object
    # $gameFolderDateCode = $gameFolderWriteTime | Get-Date -Format "MMddyyyy"
    # $gameFolderDateCode now string value of 03162025
    #
    # scenario 2: given string value "03162025" convert to date object
    #
    # $getAdatecode = "03162025"
    # $StrToDateObj = [datetime]::ParseExact($getAdatecode, "MMddyyyy", $null) # $StrToDateObj now a date object
    # 
    # so really the function should either take in a zip file name as a string or a 

    param ( [Parameter(Mandatory=$true)] 
    #[string]$StrToConvert
    #[switch]$StrToConvert
    $StrToConvert
    )

    write-host "type of parameter sent in is $($StrToConvert.GetType().Name)"

    if ($StrToConvert -is [Int32]) {Write-Host "came back int32"}
    #$ParamLengthValidate = ( $PreferredDateFormat.Length -eq $StrToConvert.Length )
    #$SeeIfLeaf = Test-Path (Join-Path -Path $sourceFolder -ChildPath $StrToConvert)

    #$SeeIfAbsPath = ( (Split-Path -Path $StrToConvert -IsAbsolute) -or (Test-Path $StrToConvert) )


#    if ( ( $StrToConvert -is [String]) -or ($StrToConvert -is [Int32]) ) {     # the format ($StrToConvert -is [Int32]) works better than the $StrToConvert.GetType().Name one for if/bools anyway
    if (  $StrToConvert -is [Int32]  ) { 
        #[int32]$StrToConvert
        try {
            $StrToConvert = "{0:D8}" -f $StrToConvert
            Write-Host "parameter value after the {0:d8} conversion is $($StrToConvert)"
            $getIfDateConvertable = [datetime]::ParseExact($StrToConvert, $PreferredDateFormat, $null)
            Write-Host "`n(inside getfiledatestamp function) Value of getIfDateConvertable is $($getIfDateConvertable) of type $($getIfDateConvertable.GetType().Name)`n"
            return $getIfDateConvertable
        } catch {
            Write-Host "invalid date code"
            $getIfDateConvertable = $false
        }
    } elseif ( ( $StrToConvert -is [String] ) -and ( $StrToConvert.Length -eq 8)  ) { # ($StrToConvert -eq [string]) {
        try {
            $getIfDateConvertable = [datetime]::ParseExact($StrToConvert, $PreferredDateFormat, $null)
            Write-Host "`n(inside second try in getfiledatestamp function) Value of getIfDateConvertable is $($getIfDateConvertable) of type $($getIfDateConvertable.GetType().Name)`n"
            return $getIfDateConvertable
        } catch {
            $getIfDateConvertable = $false
        }
    }

    if ( $StrToConvert -is [DateTime] ) {
        return $StrToConvert | Get-Date -Format $PreferredDateFormat
    }


    #if ($getIfDateConvertable) {
    #    Write-Host "`n(inside getfiledatestamp function) Value of getIfDateConvertable is $($getIfDateConvertable) of type $($getIfDateConvertable.GetType().Name)`n"
    #} else {
    #    Write-Host "`nNot the date stamp`n"
    #}

    $SeeIfAbsPath = Test-Path $StrToConvert

    if ($SeeIfAbsPath) { # if the parameter is already a path
        Write-Host "`nvalue of SeeIfAbsPath is $($SeeIfAbsPath) and passed in value is $($StrToConvert)`n"
        return $SeeIfAbsPath # just return the path, the end
    }

    if (-not $SeeIfAbsPath) { # if parameter does not come back as a path alrady
        $seeIfJoinedPath = Join-Path -Path $destinationFolder -ChildPath $StrToConvert # attempt to make into a full path
        $JoinedPathMakeAbs = Test-Path $seeIfJoinedPath # and test again if it's a path that exists

        if ($JoinedPathMakeAbs) { # if it is now a path
            Write-Host "after join the path is $($seeIfJoinedPath) and whether it's a valid path is $($JoinedPathMakeAbs)`n"
            return $seeIfJoinedPath # return the path, the end
        }
        else {
            try {
                return [datetime]::ParseExact($StrToConvert, $PreferredDateFormat, $null)
            }
            catch {
                Write-Warning "value $($StrToConvert) not a valid date code`n"
                return $false
            }
        }
    }


    Write-Host "value of seeIfJoinedPath is $($seeIfJoinedPath )`n"
    Write-Host "value of SeeIfAbsPath is $($SeeIfAbsPath)`n"
    #Write-Host "value of testJoinedPath is $($testJoinedPath)`n"

    #$ParamLengthValidate = ( ($PreferredDateFormat.Length -eq $StrToConvert.Length) -and -not (Test-Path $StrToConvert ) -and -not ($SeeIfLeaf) )

#    $ParamLengthValidate = ( $SeeIfAbsPath )#-or $testJoinedPath)
#
#    Write-Host "value of ParamLengthValidate is $($ParamLengthValidate)" # returns True or false
#
#    if (-not $ParamLengthValidate) {
#        Write-Host "value sent in $($StrToConvert), returning date object version...`n" # converted to date object
#        # now return date and exit function
#        return [datetime]::ParseExact($StrToConvert, $PreferredDateFormat, $null)
#    }

#    if (($PreferredDateFormat.Length -eq $StrToConvert.Length) -and -not (Test-Path $StrToConvert)) {


}
#     $sampleDate = "03/31/2025 00:00:00"
# 
#     $convertedDate = [datetime]::ParseExact($sampleDate, $global:PreferredDateFormat, $null)
# 
#     write-host "convertedDate is $($convertedDate)"
# 
#     if ($InputValue.Length -eq $global:PreferredDateFormat.Length) {
#         try { 
#             Write-Host "(first if/about split) value of global:PreferredDateFormat is $global:PreferredDateFormat"
#             Write-Host "InputValue.Length -eq global:PreferredDateFormat.Length is ($($InputValue.Length) -eq $($global:PreferredDateFormat.Length))"
#             return [datetime]::ParseExact($InputValue, $global:PreferredDateFormat, $null) 
#         } catch {
#             Write-Output "Warning: Invalid DateCode format. Expected format is $global:PreferredDateFormat."
#             return $null
#         }
#     }
#     #$parts = $InputValue -split "_"
#     $justdate = ""
#     if (Test-Path -Path $InputValue -PathType Container) {
#         $FolderModDate = (Get-Item -path $InputValue).LastWriteTime.ToString($global:PreferredDateFormat)
#         $FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
#         if ($FolderModDate -is [datetime]) {
#             Write-Host "value sent in, `n`'$($InputValue)`' `nis a valid folder path"
#             return $FolderModDate
#         }
#     } elseif ( Test-Path -Path $InputValue -PathType Leaf) {
#         try {
#             $justdate = $InputValue -split "_"
#             if ($justdate.Length -ge 2) {
#                 $justdate = $justdate[-2]
#                 if ($justdate -eq 8) {
#                     return [datetime]::ParseExact($justdate,$global:PreferredDateFormat,$null)
#                 }
#             }
#         }
#         catch {
#             Write-Host "Unable to determine or convert to date object from value $justdate"
#             return $null
#         }
#     }  elseif  ( (!(Test-Path -Path $FileName -PathType Leaf)) -and (!( Test-Path -Path $FileName -PathType Container) ) )    {
#         Write-Host "the filename parameters, $FileName, is not a folder or a file"
#         return $null    
#     }
# }


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


function Start-GameLibAutoArchiver {

    # startt of transcript ##################################################
    Start-Transcript -Path "$ModuleRoot\$logBaseName" | Out-Null
    #Start-GameLibraryArchive -LibraryPath $libpath -DestPath $zipDestpath

        Validate-ScriptParameters
        Validate-SourcePathPopulation

        $FilenameSplit = @()

        # Get validated non-empty folders: array with full paths, as FS objects
        $nonEmptyFolders = Get-NonEmptySourceFolders

#        Write-Host "valid list should be $($nonEmptyFolders)"

        # Get their names with underscores for comparison: array of source folder names with _ in place of spaces
        # - should still be FS objects -- just names with underscores, no full paths
        $validatedNamesUnderscored = $nonEmptyFolders.Name | ConvertTo-UnderscoreName





        #Write-Host "valid underscore list should be $($validatedNamesUnderscored)"

        # Get destination files - obviously i need some functions to handle the destination half of this
#        $destFiles = Get-ChildItem $destinationFolder -File | Select-Object -ExpandProperty BaseName

#        Write-Host "valid list should be $($destFiles)"
    $DestFileList = Get-DestFileNames

#         $getDatefromCode = Get-FileDateStamp 01042025
#         Write-Host "getDatefromCode value is $getDatefromCode"
# 
#         $getDateFromPathFolder = Get-FileDateStamp "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon III"
#         Write-Host "getDatefromCode value is $getDateFromPathFolder"
# 
#         $getDateCodeFromDate = Get-FileDateStamp "01/04/2025"
#         Write-Host "getDateCodeFromDate value is $getDateCodeFromDate"

        $getDateObject = Get-FileDateStamp "03312025"
        Write-Host "(inside Start-GameLibAutoArchiver function) from date code string 03312025 now have value $($getDateObject) of type $($getDateObject.GetType()) `n"
        $ConvertDateObjToCode = Get-FileDateStamp $getDateObject
        Write-Host "ConvertDateObjToCode value return is $($ConvertDateObjToCode)"

#        if ($($getDateObject.GetType().Name) -eq ([datetime]) ) {
#            Write-Host "date time return is true" # came back true
#        } else { "did not come back true" }

#        $getDateObject = Get-FileDateStamp "Outzone_11012024_steam.zip"
#        Write-Host "from input Outzone_11012024_steam.zip, value return is $($getDateObject)" # of type $($getDateObject.GetType().Name)`n"
#        $getDateObject = Get-FileDateStamp "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon"
#        Write-Host "from input 'P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon', value return is $($getDateObject)" # of type $($getDateObject.GetType().Name)`n"    


    Stop-Transcript | Out-Null

}

Start-GameLibAutoArchiver

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