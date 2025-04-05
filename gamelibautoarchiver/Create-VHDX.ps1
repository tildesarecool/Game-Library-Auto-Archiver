# Create-VHDX.ps1
$sourcePath = 'P:\Program Files (x86)\Steam\steamapps\common\Dig Dog'
$vhdxPath = 'P:\DigDog2.vhdx'
#$folderSize = 130 #(Get-ChildItem $sourcePath -Recurse -File | Measure-Object -Property Length -Sum).Sum
$vhdxSize = 140MB

Measure-Command {
    New-VHD -Path $vhdxPath -SizeBytes $vhdxSize -Dynamic
    #Read-Host "press any key to continue"
    $disk = Mount-VHD -Path $vhdxPath -PassThru
    #Read-Host "press any key to continue"
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    #Read-Host "press any key to continue"
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -Confirm:$false | Out-Null
    #Read-Host "press any key to continue"
    $driveLetter = (Get-Partition -DiskNumber $disk.Number).DriveLetter
    $driveLetter = [string]$driveLetter # 'E' as [string], but not necessary here
    $driveLetter = $driveLetter[-1]
    #$driveLetter = $driveLetter + ":\"
    #Read-Host "press any key to continue: disk number is $($disk.Number) and drive letter: $($driveLetter) or with partition: $($partition.DriveLetter)"
    #Copy-Item -Path "$sourcePath\*" -Destination "$driveLetter`:\" -Recurse
    #Copy-Item -Path "$sourcePath\*" -Destination (Join-Path $($driveLetter): "") -Recurse
    #$destination = [System.IO.DirectoryInfo]$driveLetter
    #Read-Host "press any key to continue: disk number is $($disk.Number) and drive letter: $($driveLetter)"

    $driveLetter = $driveLetter + ":\"
    function trycopy {
        Write-Host "source path: $($sourcePath) and destination as drive letter: $($driveLetter)"

        if (  (Test-Path $driveLetter) ) {
            Copy-Item -Path $($sourcePath) -Destination $($driveLetter) -Recurse
            return $true
        } else {
            Write-Host "test path of drive letter is false - $($driveLetter)"
            return $false
        }
    }

    if (-not (trycopy) ) { trycopy } else {
#        exit 0
        Write-Host "running compact /c on allthe files in E:"
        #Read-Host "press any key to continue"
        Get-ChildItem $driveLetter -Recurse | ForEach-Object { compact /c $_.FullName }
        Write-Host "dismounting vhdx path ($($vhdxPath))"
        Dismount-VHD -Path $vhdxPath
    }

    
#    Read-Host "press any key to continue"
#    Get-ChildItem "$driveLetter`:\" -Recurse | ForEach-Object { compact /c $_.FullName }
#    Dismount-VHD -Path $vhdxPath
#    Read-Host "press any key to continue: last step is to compact the vhdx itself - $($vhdxPath)"
    compact /c $vhdxPath
} | Format-Table TotalSeconds
