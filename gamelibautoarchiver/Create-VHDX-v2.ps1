# "the one without all the comments"
# Create-VHDX.ps1
$sourcePath = 'c:\Program Files (x86)\Steam\steamapps\common\Dig Dog'
$vhdxPath = 'C:\Users\user\Documents\Game-Library-Auto-Archiver\DigDog2.vhdx'
$vhdxSize = 110MB # dig dog

Measure-Command {
    New-VHD -Path $vhdxPath -SizeBytes $vhdxSize -Dynamic # only works with hyper-v enabled

    $disk = Mount-VHD -Path $vhdxPath -PassThru

    Initialize-Disk -Number $disk.Number -PartitionStyle GPT

    New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -Confirm:$false 
    $driveLetter = (Get-Partition -DiskNumber $disk.Number).DriveLetter
    $driveLetter = [string]$driveLetter # 'E' as [string], but not necessary here
    $driveLetter = $driveLetter[-1]

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
        Write-Host "running compact /c on allthe files in $driveLetter"
        #Read-Host "press any key to continue"
        Get-ChildItem $driveLetter -Recurse | ForEach-Object { compact /c $_.FullName }
        Write-Host "dismounting vhdx path ($($vhdxPath))"
        Dismount-VHD -Path $vhdxPath
    }

} | Format-Table TotalSeconds
