# gamelibautoarchiver.psm1
$ModuleRoot = $PSScriptRoot

function Start-GameLibraryArchive {
    param (
        [Parameter(Mandatory)]
        [string]$LibraryPath
    )
    Get-ChildItem -Path $LibraryPath -Directory | ForEach-Object {
        $gameFolder = $_.FullName
        $lastWrite = $_.LastWriteTime.ToString("yyyyMMdd")
        $platform = "Unknown" # Add platform detection later
        $zipName = Join-Path $ModuleRoot "$($_.Name)_$lastWrite_$platform.zip"
        Compress-Archive -Path $gameFolder -DestinationPath $zipName -Force
    }
}
Export-ModuleMember -Function Start-GameLibraryArchive