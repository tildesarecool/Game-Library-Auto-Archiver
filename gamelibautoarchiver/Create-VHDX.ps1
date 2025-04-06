# Create-VHDX.ps1
# $sourcePath = 'P:\Program Files (x86)\Steam\steamapps\common\Dig Dog'
# $vhdxPath = 'P:\DigDog2.vhdx'
$sourcePath = 'c:\Program Files (x86)\Steam\steamapps\common\Dig Dog'
$vhdxPath = 'C:\Users\keith\Documents\Game-Library-Auto-Archiver\DigDog2.vhdx'
#$sourcePath = 'P:\Program Files (x86)\Steam\steamapps\common\DiRT Rally 2.0'
#$vhdxPath = 'P:\dirt rally 2 save\dirtrally2.vhdx'
#$folderSize = 130 #(Get-ChildItem $sourcePath -Recurse -File | Measure-Object -Property Length -Sum).Sum
#$vhdxSize = 130GB # dirt rally 2.0
$vhdxSize = 110MB # dig dog

# the vhd related cmdlets like new-vhd are enabled via turning on hyper-v
# check hyper-v status with 
# Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -like "Microsoft-Hyper-V*" }
# if it says 'state: disabled" then enable with ...
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
# likely you'll have reboot windows
# alternatively, if your Windows version is incabpable of hyper-v or you just don't want it
# all or most all the functionality can be re-created just using diskpart
#https://grok.com/share/bGVnYWN5_c5194154-817a-4b29-88da-22d0ed7ca621


Measure-Command {
    New-VHD -Path $vhdxPath -SizeBytes $vhdxSize -Dynamic
    #Read-Host "press any key to continue"
    $disk = Mount-VHD -Path $vhdxPath -PassThru
    #Read-Host "press any key to continue"
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    #Read-Host "press any key to continue"
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -Confirm:$false 
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
