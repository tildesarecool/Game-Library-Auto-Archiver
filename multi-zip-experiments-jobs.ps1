# this is what grok came up with address my requirements for me to work from
# rather the hypothetical script grok wrote is commented out at the bottom of this file
# in the function Start-GameLibraryArchive
# i'm going to write my own version, though
# this is experimental, not for the main script yet

# How It Meets Your Requirements
# No Blinking Cursor, Clear Feedback
# Progress Bar: Write-Progress shows real-time updates—completed, failed, running jobs, and percentage.
# Messages: Initial “Starting…” and “Please wait…” keep the user informed. No CLI drop until all jobs finish or are cancelled.
# Script Stays Active
# Main Loop: The while loop keeps the script running until all jobs complete, avoiding the CLI drop. Write-Progress reinforces that work is ongoing.
# Hardware Safety
# Throttle: $maxConcurrentJobs = 4 limits concurrent jobs to 4 (tweakable)—prevents CPU overload like your last crash. Jobs are process-based, so memory use is higher (~50MB each), but 4 should be safe on most systems.
# Graceful Failure
# Job Isolation: Each Compress-Archive runs in its own job. If one fails (e.g., disk full), others continue—event handler tracks failures separately.
# Cancel All Actions
# Ctrl+C: Caught via try/catch—stops all jobs cleanly with Stop-Job, updates UI, and informs the user. Partial ZIPs might remain, but the script exits gracefully.
# Feedback: “Cancellation requested…” and “All jobs stopped…” messages keep the user in the loop.
# Readable & Maintainable
# Structure: Clear sections—setup, job launch, event handling, main loop. Comments explain intent.
# Variables: Descriptive ($totalJobs, $completedJobs)—easy for you to tweak later.
# No .NET Deep Dive: Sticks to PowerShell cmdlets you can learn and adjust without LLM help.


# First i'm going to the number of concurrent zips jobs the number of cores of the system CPU
# as reported by the environment variable defined by the OS:
# multi-zip-experiments-jobs.ps1
# Experimental script for concurrent archiving with Jobs and events

# multi-zip-experiments-jobs.ps1
# Experimental script for concurrent archiving with Jobs and events

$maxJobsDefine = [System.Environment]::ProcessorCount
$ThrottleLimit = $null


if ($maxJobsDefine -le 0) {
    Write-Host "ProcessorCount indeterminate or invalid, exiting"
    exit 1
}

$ThrottleLimit = [Math]::Min(8, [Math]::Max(1, [Math]::Floor($maxJobsDefine / 2)))

# if ($maxJobsDefine -ge 8) { 
#     $ThrottleLimit = 8 
# } elseif ($maxJobsDefine -le 7 -and $maxJobsDefine -gt 0) {
#     $ThrottleLimit = $maxJobsDefine
# } else {
#     Write-Host "ProcessorCount indeterminate or invalid, exiting"
#     exit 1
# }

if (Test-Path "P:\Game-Library-Auto-Archiver\GameSource") {
    $libpath = "P:\Game-Library-Auto-Archiver\GameSource"
    Write-Host "Game source set to P drive path"
} elseif (Test-Path "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameSource") {
    $libpath = "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameSource"
    Write-Host "Game source set to C drive path"
} else {
    Write-Host "Didn't find either path (source)"
    exit 1
}

if (Test-Path "P:\Game-Library-Auto-Archiver\GameDest") {
    $zipDestpath = "P:\Game-Library-Auto-Archiver\GameDest"
    Write-Host "Game dest set to P drive path"
} elseif (Test-Path "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameDest") {
    $zipDestpath = "C:\Users\Keith\Documents\Game-Library-Auto-Archiver\GameDest"
    Write-Host "Game dest set to C drive path"
} else {
    Write-Host "Didn't find either path (dest)"
    exit 1
}

if (-not (Test-Path $libpath)) {
    Write-Error "Library path not found: $libpath"
    exit 1
}
if (-not (Test-Path $zipDestpath)) {
    Write-Error "Dest path not found: $zipDestpath"
    exit 1
}

$folders = Get-ChildItem -Path $libpath -Directory | Where-Object { (Get-ChildItem $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum -gt 0 }
if ($folders.Count -eq 0) {
    Write-Host "No folders found to archive in $libpath."
    exit 1
}

$totalJobs = $folders.Count
$completedJobs = 0
$failedJobs = 0
$jobs = [System.Collections.ArrayList]::new()
$maxConcurrentJobs = $ThrottleLimit  # Use adaptive throttle
$jobTimeoutSeconds = 60

Write-Host "value of maxConcurrentJobs is $maxConcurrentJobs (based on $maxJobsDefine cores)"

function Start-GameLibraryArchive {
    param (
        [Parameter(Mandatory)][string]$LibraryPath,
        [Parameter(Mandatory)][string]$DestPath
    )

    $null = Register-EngineEvent -SourceIdentifier "JobStateChanged" -Action {
        $script:completedJobs = ($script:jobs | Where-Object { $_.State -eq 'Completed' }).Count
        $script:failedJobs = ($script:jobs | Where-Object { $_.State -eq 'Failed' }).Count
        $runningJobs = ($script:jobs | Where-Object { $_.State -eq 'Running' }).Count
        $percentComplete = (($script:completedJobs + $script:failedJobs) / $script:totalJobs) * 100

        Write-Progress -Activity "Archiving game folders" `
                      -Status "$script:completedJobs completed, $script:failedJobs failed, $runningJobs running" `
                      -PercentComplete $percentComplete `
                      -CurrentOperation "Press Ctrl+C to cancel all jobs"

        if ($script:completedJobs + $script:failedJobs -eq $script:totalJobs) {
            Write-Progress -Activity "Archiving game folders" -Completed
        }
    }

    Write-Host "maxConcurrentJobs: $maxConcurrentJobs, jobTimeoutSeconds: $jobTimeoutSeconds"
    Write-Host "jobs: $jobs, completedJobs: $completedJobs, failedJobs: $failedJobs, totalJobs: $totalJobs"
    Write-Host "Starting $totalJobs archiving jobs (max $maxConcurrentJobs at a time, timeout $jobTimeoutSeconds seconds per job)..."

    foreach ($folder in $folders) {
        Write-Host "Checking running jobs before starting job for $($folder.Name)..."
        while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
            Start-Sleep -Milliseconds 500
        }
        $zipPath = Join-Path -Path $DestPath -ChildPath "$($folder.Name).zip"
        Write-Host "Starting job for $($folder.Name) to $zipPath"
        $job = Start-Job -ScriptBlock {
            param ($source, $dest)
            Compress-Archive -Path $source -DestinationPath $dest -Force
        } -ArgumentList $folder.FullName, $zipPath

        Register-ObjectEvent -InputObject $job -EventName StateChanged -SourceIdentifier "JobStateChanged_$($job.Id)" `
                            -MessageData @{ Folder = $folder.Name }
        $jobs.Add($job) | Out-Null
    }

    try {
        Write-Host "Please wait for jobs to finish. Press Ctrl+C to cancel all jobs."
        $finishMessageShown = $false
        while (($completedJobs + $failedJobs) -lt $totalJobs) {
            $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
            $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
            $failed = $jobs | Where-Object { $_.State -eq 'Failed' }
            $completedJobs = $completed.Count
            $failedJobs = $failed.Count

            if (-not $finishMessageShown -and $completedJobs -ge ([Math]::Ceiling($totalJobs * 0.75))) {
                Write-Host "Finishing up last folders, please wait..."
                $finishMessageShown = $true
            }

            foreach ($job in $runningJobs) {
                if ((Get-Date) - $job.PSBeginTime -gt [TimeSpan]::FromSeconds($jobTimeoutSeconds)) {
                    Stop-Job -Job $job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
                    $failedJobs++
                    Write-Warning "Job $($job.Id) ($($job.Name)) timed out after $jobTimeoutSeconds seconds."
                }
                elseif ($job.HasMoreData -eq $false -and (Get-Date) - $job.PSBeginTime -gt [TimeSpan]::FromSeconds(5)) {
                    Stop-Job -Job $job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
                    $failedJobs++
                    Write-Warning "Job $($job.Id) ($($job.Name)) stuck (no data, >5s), forced stop."
                }
            }

            # Exit only if jobs failed and none are running
            if ($runningJobs.Count -eq 0 -and $failedJobs -gt 0) {
                Write-Host "All remaining jobs timed out or failed. Exiting..."
                break
            }
            Start-Sleep -Seconds 1
        }
        $zipCount = (Get-ChildItem -Path $DestPath -File *.zip).Count
        if ($zipCount -eq $completedJobs) {
            Write-Host "All jobs accounted for: $completedJobs completed, $failedJobs failed. $zipCount ZIPs created."
        } else {
            Write-Warning "Mismatch: $completedJobs completed, $failedJobs failed, but only $zipCount ZIPs found in $DestPath."
        }
    }
    catch [System.OperationCanceledException] {
        Write-Host "Cancellation requested. Stopping all jobs..."
        $jobs | Stop-Job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
        Write-Progress -Activity "Archiving game folders" -Status "Cancelled" -Completed
        Write-Host "All jobs stopped. Partial ZIPs may remain in $DestPath."
    }
    finally {
        Get-EventSubscriber | Where-Object { $_.SourceIdentifier -like "JobStateChanged*" } | Unregister-Event -ErrorAction SilentlyContinue
        $jobs | Stop-Job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
        $jobs.Clear()
    }
}

function main {
    Start-Transcript -Path "$PSScriptRoot\multi-zip.txt"
    Start-GameLibraryArchive -LibraryPath $libpath -DestPath $zipDestpath
    Stop-Transcript
}

main