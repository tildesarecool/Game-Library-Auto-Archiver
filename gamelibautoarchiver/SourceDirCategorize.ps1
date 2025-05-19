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


# if ( Test-Path "C:\Users\keith\Documents\Game-Library-Auto-Archiver\GameSource" ) {
#     # path for lenovo laptop
#     $sourceFolder = "C:\Users\keith\Documents\Game-Library-Auto-Archiver\GameSource"    
# } else {
#     Write-Host "unable to find path, exiting"
#     exit 0
# }

if ( Test-Path "P:\Game-Library-Auto-Archiver\SteamSource" ) {
    # path for lenovo laptop
    $sourceFolder = "P:\Game-Library-Auto-Archiver\SteamSource"
} else {
    Write-Host "unable to find path, exiting"
    exit 0
}

# if ( Test-Path "P:\Program Files (x86)\Steam\steamapps\common" ) {
#     # path for lenovo laptop
#     $sourceFolder = "P:\Program Files (x86)\Steam\steamapps\common"
# } else {
#     Write-Host "unable to find path, exiting"
#     exit 0
# }

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

    # $potentialPath = $null
    # 
    # if (Test-Path $folderPath) { # -PathType Container) {
    #     $resolvedPath = $folderPath
    # }
#        Write-Verbose "Using provided path: $resolvedPath"            
#    } else {
#        $folderName = if ($folderPath -is [System.IO.DirectoryInfo]) { $folderPath.Name } else { [string]$folderPath }
#        $potentialPath = Join-Path -Path $sourceFolder -ChildPath $folderName # childPath parameter only takes string types
#        if (Test-Path -Path $potentialPath -PathType Container) {
#            $resolvedPath = $potentialPath
##            Write-Verbose "Using constructed path: $resolvedPath"
#        }
#    }

    # if (-not $resolvedPath) {
    #     Write-Verbose "Invalid path: $folderPath (and not found under `$sourceFolder)"
    #     return $false
    # }    


    $FolderSizeKBTracker = 0
#    foreach ($file in Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable err) {
    
    $IsUnderMinSize     = $false
    $isOverMaxSize      = $false
    $isBetweenMinAndMax = $false

    $MeetsMaxfileSize = ($global:MaxFileSizeLimitGB * 1MB) / 1KB

    #Write-Host "the value of MeetsMaxfileSize is $MeetsMaxfileSize" -ForegroundColor Green


    foreach ($file in Get-ChildItem -Path $folderPath -Recurse -File ) {
        $FolderSizeKBTracker += $file.Length / 1KB



        #Write-Host "FolderSizeKBTracker is currently $FolderSizeKBTracker"
        #$folderName = $_.BaseName
        
        #$FolderDetermineMin = 
#        if ($FolderSizeKBTracker -lt $MinFileSizeLimitKB) {
#            # -and ($FolderSizeKBTracker -lt $MeetsMaxfileSize) ) { 
#            #Write-Host "For $resolvedPath, the value of FolderDetermineMin is $FolderDetermineMin"
#            $IsUnderMinSize = $true
#            break
#            #return $true  
#        #} elseif (($FolderSizeKBTracker -gt $MinFileSizeLimitKB) ){ # -and ($FolderSizeKBTracker -lt $MeetsMaxfileSize) ) {  
#        } 
        
        if ( $FolderSizeKBTracker -ge $MeetsMaxfileSize ) {
            $isOverMaxSize = $true
            $isBetweenMinAndMax = $false
            $IsUnderMinSize = $false
        } else { $isOverMaxSize = $false }

    }

    Write-Host "Value of foldersizetracker is $FolderSizeKBTracker and MeetsMaxfileSize is $MeetsMaxfileSize" -ForegroundColor Red
    

#    if ($FolderSizeKBTracker -gt ($MeetsMaxfileSize -10KB)) {
#        $isOverMaxSize = $true
#        $isBetweenMinAndMax = $false
#        $IsUnderMinSize = $false
#    } else { $isOverMaxSize = $false }

#    if ( ($FolderSizeKBTracker -gt $MinFileSizeLimitKB) -and ($FolderSizeKBTracker -lt $MeetsMaxfileSize) ) { # -and ($FolderSizeKBTracker -lt $MeetsMaxfileSize) ) {  
#        $isBetweenMinAndMax = $true
#        $IsUnderMinSize = $false
#    } 

    [PSCustomObject]@{
        #FolderName = $folderPath
        #IsUnderMinSize = $IsUnderMinSize
        #isBetweenMinAndMax = $isBetweenMinAndMax
        IsOverMaxSize = $isOverMaxSize
        #FolderSize = $FolderSizeKBTracker
    }    

#    if ($err) { Write-Debug "Errors during enumeration: $($err | Out-String)" }
#    Write-Verbose "Folder $resolvedPath size: $FolderSizeKBTracker KB, does not exceed $sizeLimitKB KB"
#    return $false
}



function Categorize-SourcePathObject {
    [CmdletBinding()]
    param()

    Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
        # $isOver50KB = Get-FolderSizeKB $_ 
        $SizeCurFolder = Get-FolderSizeKB $_ 
        #Write-Host "Value of curfolder is $SizeCurFolder, hypothetical size is $($SizeCurFolder.FolderSize)"
        
        #if ($SizeCurFolder.IsUnderMinSize)      { Write-Host "The size of $_ is under min size, which is $($SizeCurFolder.IsUnderMinSize)" }
        # if ($SizeCurFolder.isBetweenMinAndMax)  { Write-Host "The size of $_ is between min and max size." }
         if ($SizeCurFolder.IsOverMaxSize)       { Write-Host "The size of $_ is over max size." } else { Write-Host "it is not over max size" }


        #if ($SizeCurFolder.isBetweenMinAndMax) {
        #    Write-Host "The size of $_ is between min and max size."
        #}



#        $folderName = $_.BaseName
#        $SetExtToZip =  if ( $isBetween50KB2GB ) { "zip" } else { "Either Under 50K or over 1.9GB" }
#
#        #Write-Host "value of SetExtToZip is $SetExtToZip"
#
#
#        [PSCustomObject]@{
#            FolderName = $folderName
#            FileExt    = $SetExtToZip
#            IsOver50KB = $isBetween50KB2GB
#        }
    }
    
}

# $DetermineSize = Get-FolderSizeKB $sourceFolder
# $DetermineSize | Format-Table -AutoSize


$GetSizeStatus = Categorize-SourcePathObject
#$GetSizeStatus | Format-Table -AutoSize

# I put this screen against my steam library folder path (184 folders of varoius sizes)
# c:\Program Files (x86)\Steam\steamapps\common
# and the total command took ~13 seconds; not sure if that's worth running in the background or not

#$timeToSize = Measure-Command {
   


    #$GetSizeStatus = Categorize-SourcePathObject
    #$GetSizeStatus | Format-Table -AutoSize

#}

#$roundedTime = [Math]::round($timeToSize.TotalSeconds, 1)

#Write-Host "Total time to get the table took $roundedTime seconds."


# $FolderDetermineMin = if ($FolderSizeKBTracker -gt $MinFileSizeLimitKB) { 
#     Write-Host "For $resolvedPath, the value of FolderDetermineMin is $FolderDetermineMin"
#     return $true  
# } #else {  return $false }