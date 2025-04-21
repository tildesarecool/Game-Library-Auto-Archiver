
$hypotheticalName = "bit_dungeon_03162025_steam.zip"

 $foldername = (Get-Item $sourcFolder).BaseName
 $lastwritedate = (Get-Item $sourcFolder).LastWriteTime

#$foldername = (Get-Item $sourcFolder)
#$lastwritedate = (Get-Item $sourcFolder)

$singlefolder = [PSCustomObject]@{
    FolderName = $foldername # full path prop not available; use join with $sourcedir to get full path
    LastWriteDate = $lastwritedate.LastWriteTime
}



$sourcFolder = "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon\"

# can also use this method
#$hypotheticalName = "bit_dungeon_03162025_steam.zip"
#$singleFolder.HypotheticalName = $hypotheticalName

$singleFolder | Add-Member -MemberType NoteProperty -Name HypotheticalName -Value $hypotheticalName


$singlefolder | Format-Table -AutoSize


Write-Host "value of hypothetical name (singlefolder.HypotheticalName) is $($singlefolder.HypotheticalName)"

Write-Host "value of  name (singlefolder.FolderName.FullName) is $($singlefolder.FolderName.Name)"

$NewSingFolder = $singlefolder


#Write-Host "methods of the object instance is $($NewSingFolder.FolderName.FullName)"

#$NewSingFolder | remove-



$sourcFolder2 = "P:\Game-Library-Auto-Archiver\GameSource\pac-man\"

$foldername2 = (Get-Item $sourcFolder2).BaseName
$lastwritedate2 = (Get-Item $sourcFolder2).LastWriteTime

$singlefolder2 = [PSCustomObject]@{
    FolderName2 = $foldername2
    LastWriteDate2 = $lastwritedate2
}

$singlefolder2 | Format-Table -AutoSize

$compareDates =  ($singlefolder.LastWriteDate -lt $singlefolder2.LastWriteDate2 )

Write-Host "comparedates is $($compareDates)"

#$singlefolder | Format-Table -AutoSize

Write-Host "`nvalue of custom object is $($singlefolder)`n" -ForegroundColor Green

# older syntax
# Why Use Approach 1:
# 
# [PSCustomObject]@{...} is concise, modern, and the standard since PowerShell 3.0.
# New-Object is older and mainly used in legacy scripts or when dynamically adding properties in loops.
#$sourcefolder = "P:\Game-Library-Auto-Archiver\GameSource\bit Dungeon\"
#$folderName = (Get-Item $sourcefolder).BaseName
#$lastWriteDate = (Get-Item $sourcefolder).LastWriteTime
#
#$singleFolder = New-Object -TypeName PSObject
#$singleFolder | Add-Member -MemberType NoteProperty -Name FolderName -Value $folderName
#$singleFolder | Add-Member -MemberType NoteProperty -Name LastWriteDate -Value $lastWriteDate
#
#$singlefolder | Format-Table -AutoSize
#Write-Host "`nvalue of custom object is $($singlefolder)`n" -ForegroundColor Green