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
$global:maxJobsDefine = [System.Environment]::ProcessorCount
$ThrottleLimit = $null
$libpath = "P:\Game-Library-Auto-Archiver\GameSource"
$zipDestpath = "P:\Game-Library-Auto-Archiver\GameDest"
# next i'm going to do a little if/else and math against that number to establish
# a throttle limit:

if ($maxJobsDefine -ge 8) { $ThrottleLimit = 8 } elseif ( $maxJobsDefine -le 7) {
    $ThrottleLimit = $maxJobsDefine
} elseif (($maxJobsDefine -eq $null) -or ($null -eq $ThrottleLimit) ) { # bail
    Write-Host "ProcessorCount environment variable indeterminate, exiting"
    exit 1
}

# these two checks are actually fine
if (-not (Test-Path $libpath)) {
    Write-Error "Library path not found: $libpath"
    return
}

# Get folders to archive
$folders = Get-ChildItem -Path $libpath -Directory
if ($folders.Count -eq 0) {
    Write-Host "No folders found to archive in $libpath."
    return
}

# but I'll add a third one as well
if (-not (Test-Path $zipDestpath)) {
    Write-Error "Dest path not found: $zipDestpath"
    return
}

# out of the ones below, i think these will be most useful
# Initialize tracking
$totalJobs = $folders.Count
$completedJobs = 0
$failedJobs = 0
$jobs = @()
$jobTimeoutSeconds = 300  # 5 minutes per job

# I guess i will just use the name of the function from the llm as it makes sense
# but also use destination as a parameter
function Start-GameLibraryArchive {
    param (
        [Parameter(Mandatory)]
        [string]$LibraryPath,
        [Parameter(Mandatory)]
        [string]$destPath
    )


     
}


# here is a main function to call any other functions because
# it's easier to do start/end transcripts that way and just call main versus other functions
# i'm putting this at the bottom of the script

function main {
    Start-GameLibraryArchive -LibraryPath $libpath -destPath $zipDestpath
}

# call main
main


# Start-GameLibraryArchive
# Archives game folders concurrently using Jobs with event-driven status updates

# function Start-GameLibraryArchive {
#     param (
#         [Parameter(Mandatory)]
#         [string]$LibraryPath
#     )
# 
#     # Validate path
#     if (-not (Test-Path $LibraryPath)) {
#         Write-Error "Library path not found: $LibraryPath"
#         return
#     }
# 
#     # Get folders to archive
#     $folders = Get-ChildItem -Path $LibraryPath -Directory
#     if ($folders.Count -eq 0) {
#         Write-Host "No folders found to archive in $LibraryPath."
#         return
#     }
# 
#     # Initialize tracking
#     $totalJobs = $folders.Count
#     $completedJobs = 0
#     $failedJobs = 0
#     $jobs = @()
#     $maxConcurrentJobs = 4  # Limit to avoid CPU overload
#     $jobTimeoutSeconds = 300  # 5 minutes per job
# 
#     # Event handler for job state changes
#     $eventHandler = Register-EngineEvent -SourceIdentifier "JobStateChanged" -Action {
#         $global:completedJobs = ($using:jobs | Where-Object { $_.State -eq 'Completed' }).Count
#         $global:failedJobs = ($using:jobs | Where-Object { $_.State -eq 'Failed' }).Count
#         $runningJobs = ($using:jobs | Where-Object { $_.State -eq 'Running' }).Count
#         $percentComplete = (($global:completedJobs + $global:failedJobs) / $using:totalJobs) * 100
# 
#         Write-Progress -Activity "Archiving game folders" `
#                       -Status "$global:completedJobs completed, $global:failedJobs failed, $runningJobs running" `
#                       -PercentComplete $percentComplete `
#                       -CurrentOperation "Press Ctrl+C to cancel all jobs"
# 
#         # Check if all jobs are done
#         if ($global:completedJobs + $global:failedJobs -eq $using:totalJobs) {
#             Write-Progress -Activity "Archiving game folders" -Completed
#             Write-Host "All archiving jobs finished: $global:completedJobs completed, $global:failedJobs failed."
#         }
#     }
# 
#     # Start jobs with throttling and timeout
#     Write-Host "Starting $totalJobs archiving jobs (max $maxConcurrentJobs at a time, timeout $jobTimeoutSeconds seconds per job)..."
#     foreach ($folder in $folders) {
#         # Wait if max concurrent jobs reached
#         while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
#             # Check for timeouts during wait
#             $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
#             foreach ($job in $runningJobs) {
#                 if ((Get-Date) - $job.PSBeginTime -gt [TimeSpan]::FromSeconds($jobTimeoutSeconds)) {
#                     Stop-Job -Job $job -PassThru | Remove-Job -Force
#                     Write-Warning "Job $($job.Id) for $($job.Name) timed out after $jobTimeoutSeconds seconds."
#                 }
#             }
#             Start-Sleep -Milliseconds 500
#         }
# 
#         # Define ZIP destination (same directory as source)
#         $zipPath = Join-Path -Path $LibraryPath -ChildPath "$($folder.Name).zip"
#         $job = Start-Job -ScriptBlock {
#             param ($source, $dest)
#             Compress-Archive -Path $source -DestinationPath $dest -Force
#         } -ArgumentList $folder.FullName, $zipPath
# 
#         # Subscribe to job state changes
#         Register-ObjectEvent -InputObject $job -EventName StateChanged -SourceIdentifier "JobStateChanged" `
#                             -MessageData @{ Folder = $folder.Name }
# 
#         $jobs += $job
#     }
# 
#     # Main loop to keep script alive and handle Ctrl+C
#     try {
#         Write-Host "Please wait for jobs to finish. Press Ctrl+C to cancel all jobs."
#         while (($completedJobs + $failedJobs) -lt $totalJobs) {
#             # Check for job timeouts in main loop
#             $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
#             foreach ($job in $runningJobs) {
#                 if ((Get-Date) - $job.PSBeginTime -gt [TimeSpan]::FromSeconds($jobTimeoutSeconds)) {
#                     Stop-Job -Job $job -PassThru | Remove-Job -Force
#                     Write-Warning "Job $($job.Id) for $($job.Name) timed out after $jobTimeoutSeconds seconds."
#                 }
#             }
#             Start-Sleep -Seconds 1  # Light polling
#         }
#     }
#     catch [System.OperationCanceledException] {
#         Write-Host "Cancellation requested. Stopping all jobs..."
#         $jobs | Stop-Job -PassThru | Remove-Job -Force
#         Write-Progress -Activity "Archiving game folders" -Status "Cancelled" -Completed
#         Write-Host "All jobs stopped. Check $LibraryPath for incomplete ZIPs."
#     }
#     finally {
#         Get-EventSubscriber -SourceIdentifier "JobStateChanged" | Unregister-Event
#         $jobs | Where-Object { $_.State -eq 'Running' } | Stop-Job -PassThru | Remove-Job -Force
#         $jobs | Remove-Job -ErrorAction SilentlyContinue
#     }
# }


#  Example usage
#  Start-GameLibraryArchive -LibraryPath "P:\Game-Library-Auto-Archiver\GameSource"