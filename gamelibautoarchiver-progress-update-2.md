# Game-Library-Auto-Archiver — Progress Update #2
July 2026 (follow-up to the July 17 2026 handoff doc)

Purpose of this document: continues from the prior handoff summary (`Game-Library-Auto-Archiver — Development Progress Summary`, July 17 2026). That document remains valid background — architecture, naming convention, Phase 2/3 design, stretch goals, etc. are unchanged. This document only covers what has changed or been newly built since then: the orchestrator's calling skeleton now exists and has been debugged, and Phase 1 is under active development with several real bugs found and partially fixed. Read the original doc first for full context; this doc assumes it.

## What's New Since the Original Handoff

### 1. Orchestrator calling skeleton — built and validated

The orchestrator now exists as real code, not just pseudocode, with all three phase calls wired in following the agreed shape (call phase → check `.Success` → log `.Reason` and `exit 1` on failure → pass `.Data` forward on success). Phase 0 is called and its unwrapped `$config` hashtable is passed into Phase 1.

Two real bugs were found and fixed during this process:

**Bug: `Stop-Transcript` was never being reached.** The original flat top-to-bottom script structure meant every `exit` call inside the orchestrator (on phase failure, on the "nothing to do" branch, on final success) terminated the script before execution ever reached the `Stop-Transcript` block at the bottom, since `exit` is immediate/unconditional and doesn't respect code position. **Fix:** the entire orchestrator call chain (Phase 0 through Phase 3, all `exit` calls) is now wrapped in `try { }`, with `Stop-Transcript` moved into a `finally { }` block. `finally` runs regardless of how the `try` block exits — including via `exit` calls inside it — which guarantees the transcript always closes. Per the original doc's decision, a `Stop-Transcript` failure inside `finally` is still logged via `Write-Host`/`Write-Warning` only, never `exit`, since the real work is already done by that point. This has been tested and confirmed working: transcript now closes correctly on every failure branch and on success.

**Bug: `Write-Error $phaseXResult.Reason` crashed with `Cannot bind argument to parameter 'Exception' because it is null.`** This happened when a phase stub returned `Reason = $null` (a legitimate case a real phase could also produce). `Write-Error` cannot accept `$null` as a message argument. **Fix applied to all three phase-failure branches:** a guard that substitutes a fallback string when `Reason` is null/empty before it's used, e.g.:
```powershell
$reasonText = if ($phaseXResult.Reason) { $phaseXResult.Reason } else { "No reason provided" }
Write-Host "Phase X failed, exiting: $reasonText" -ForegroundColor Red
Write-Error $reasonText
exit 1
```
Confirmed working via transcript output. Note: `Write-Error` is deliberately being kept (not replaced with `Write-Host`-only) because the user wants the clearer error-stream marker to show up in the transcript log, despite a known cosmetic quirk where `Write-Error` can appear duplicated in transcript output (harmless, not investigated further — transcripts are for human reading, not parsing, per the original doc's own reasoning).

Current orchestrator skeleton shape (confirmed working end-to-end with Phase 1 real, Phase 2/3 still stubs):
```powershell
try {
    $config = Invoke-Phase0 -MinFolderSizeKB $minFolderSizeKB `
                             -PreferredDateFormat $PreferredDateFormat `
                             -SourceFolder $sourceFolder `
                             -DestinationFolder $destinationFolder

    $phase1Result = Invoke-Phase1 -Config $config
    if (-not $phase1Result.Success) {
        $reasonText = if ($phase1Result.Reason) { $phase1Result.Reason } else { "No reason provided" }
        Write-Host "Phase 1 failed, exiting: $reasonText" -ForegroundColor Red
        Write-Error $reasonText
        exit 1
    }

    $phase2Result = Invoke-Phase2 -ValidatedPaths $phase1Result.Data
    if (-not $phase2Result.Success) {
        $reasonText = if ($phase2Result.Reason) { $phase2Result.Reason } else { "No reason provided" }
        Write-Host "Phase 2 failed, exiting: $reasonText" -ForegroundColor Red
        Write-Error $reasonText
        exit 1
    }
    if ($phase2Result.Data.CompressedFilesList.Count -eq 0) {
        Write-Host "No files to compress, exiting."
        exit 0
    }

    $phase3Result = Invoke-Phase3 -CompressList $phase2Result.Data.CompressedFilesList
    if (-not $phase3Result.Success) {
        $reasonText = if ($phase3Result.Reason) { $phase3Result.Reason } else { "No reason provided" }
        Write-Host "Phase 3 failed, exiting: $reasonText" -ForegroundColor Red
        Write-Error $reasonText
        exit 1
    }

    Write-Host "Archiving completed successfully. Archived $($phase3Result.Data.ArchivedFilesList) files." -ForegroundColor Green
    exit 0
}
finally {
    try {
        Stop-Transcript
    }
    catch {
        Write-Host "Failed to stop transcript: $_" -ForegroundColor Red
    }
}
```
Note the working key name is `CompressedFilesList` (not `CompressList` as in the original doc's pseudocode) — this is what Phase 2's real/stub output and the orchestrator's check currently agree on. Keep this consistent going forward, or reconcile the naming deliberately if it should match the original doc instead.

Phase 2 and Phase 3 are still stub functions (hardcoded fake `Success = $true` results, `Write-Host "Phase X stub called"`) — not yet implemented for real. Working as placeholders to let the orchestrator's control flow be tested independently of real phase logic, per the user's stated preference to build/verify one phase at a time rather than fully speccing all stubs up front.

### 2. Phase 1 — in progress, real logic being written, several bugs found this session

Current draft (as of this document) has all checks from the original doc's Phase 1 responsibility list at least attempted, but is not fully debugged yet — user has not finished testing all branches. Known state:

**Confirmed working / fixed this session:**
- Path trimming: `$config.sourceFolder = $config.sourceFolder.Trim()` (and same for destinationFolder) — works. Earlier syntax attempt failed with parser error "An expression was expected after '('" because the `$` sigil was omitted (`config.sourceFolder.Trim()` instead of `$config.sourceFolder.Trim()`) — fixed by adding `$`.
- Subfolder-count check: originally compared the full `Get-ChildItem` result array to `0` instead of `.Count`, which silently never threw (array-to-scalar `-eq` comparison in PowerShell filters the array rather than erroring, producing a falsy empty array — no error, just silently wrong logic). Fixed by using `$srcFolderCount.Count -eq 0`. **However:** the `Get-ChildItem` call that produces `$SrcFolderCount` is currently sitting above the try/catch block (see open issue below).
- Scope bug: `$SrcFolderCount = Get-ChildItem -Path $sourceFolder -Directory` was reading `$sourceFolder` from outer script scope instead of `$config.sourceFolder` (the anti-pattern flagged repeatedly in the original doc). Fixed to use `$config.sourceFolder`. Same fix was said to be applied to the platform-lookup loop's source-path check, but this is bundled with the still-open platform logic bug below and not independently confirmed yet.

**Open bug, not yet fixed — platform resolution loop overwrites its own result on every iteration:**
```powershell
foreach ($platform in $platforms.Keys) {
    if ($sourceFolder -like "*$platform*") {
        $ResolvedPlatform = $platforms[$platform]
    } else {
        $ResolvedPlatform = "unknown"
    }
}
```
This reassigns `$ResolvedPlatform` on *every* iteration of the loop, match or not — so the final value is determined by whichever key happens to be enumerated *last* in the hashtable, not by whether an earlier key actually matched. This has not visibly caused wrong output yet only because hashtable enumeration order hasn't happened to expose it in testing so far — it is a real, live bug. Correct fix (not yet applied — user is doing this last, deliberately):
```powershell
$ResolvedPlatform = "unknown"
foreach ($platform in $platforms.Keys) {
    if ($config.sourceFolder -like "*$platform*") {
        $ResolvedPlatform = $platforms[$platform]
        break
    }
}
```
Reminder from the original doc, still outstanding: this logic should eventually become its own standalone function, `Get-PlatformShortName`, taking `-Path` as an explicit parameter (not reading from `$config`/script scope directly) and using `[ordered]@{}` instead of plain `@{}` for the lookup table, since match order needs to be predictable and regular hashtables don't guarantee enumeration order. Currently this logic is inlined directly in `Invoke-Phase1`, not yet extracted.

**Open issue — path resolution and subfolder count happen outside the try/catch block, so they cannot report failure through the phase's own contract.** Currently:
```powershell
$config.sourceFolder      = $config.sourceFolder.Trim()
$config.destinationFolder = $config.destinationFolder.Trim()

$SrcFolderCount = Get-ChildItem -Path $config.sourceFolder -Directory

$resolvedSource      = (Resolve-Path -path $Config.sourceFolder -ErrorAction Stop).Path
$resolvedDestination = (Resolve-Path -path $Config.destinationFolder -ErrorAction Stop).Path
$testFilePath = Join-Path $resolvedDestination "phase1_write_test.tmp"
```
All of this sits above the `try` block. `Resolve-Path -ErrorAction Stop` throws a terminating error if the path doesn't exist, and `Get-ChildItem` can likewise throw on a bad path — but since none of this is inside `try`, nothing in `Invoke-Phase1` currently catches it. A bad/missing path from the user would currently cause an uncaught exception to propagate out of the function rather than a clean `Success = $false` / `Reason` result, which defeats the phase/orchestrator contract (phases should report failure, not blow up unhandled). **Not yet fixed as of this document** — needs `Resolve-Path` calls and the `Get-ChildItem` call moved inside the `try` block, ordered before anything that depends on `$resolvedSource`/`$resolvedDestination`/`$SrcFolderCount`.

**Fixed this session — destination write-access test.** Original attempt used `Out-File` inside an `if()` condition expecting a boolean return, which doesn't work (`Out-File` doesn't return anything on success, so the condition was always falsy and the throw could never fire); a follow-up attempt used the `&&` pipeline chain operator wrapped in a `-not(...)` boolean expression, which technically ran but was flagged as unnecessarily convoluted and hard to trust on review. Simplified fix (functionally confirmed working): since `Out-File -ErrorAction Stop` already throws into the existing `catch` block on failure, no `if`/boolean wrapper is needed at all —
```powershell
Out-File -FilePath $testFilePath -ErrorAction Stop
Remove-Item -Path $testFilePath -ErrorAction Stop
```
Two plain lines relying on the existing catch block. This also fixed a side issue where a stray `test.txt` file could previously be left behind in the destination folder with no cleanup.

**Still not independently verified:** the "source ≠ destination" and "destination not nested inside source" checks (present in the draft using `-eq` and `-like "$resolvedSource*"` respectively) have not been specifically stress-tested yet (e.g., trailing-slash edge cases, case sensitivity on Windows paths).

### 3. Minor conventions reinforced this session (apply going forward, not new decisions)
- Hashtable key lookups in PowerShell are case-insensitive, so mixed casing (`sourceFolder` vs `SourceFolder`) hasn't caused functional bugs, but consistency (the original doc's PascalCase convention: `SourceFolder`, `DestinationFolder`, etc.) is still the target and has not yet been fully applied across the draft.
- `Write-Error` produces a **non-terminating** error by default and does not itself stop script execution — the `exit 1` calls immediately following it in the orchestrator are what actually stop the run, not `Write-Error`.
- `Test-Path -Path <path> -PathType Container` is the correct, direct way to get a clean boolean for "does this path exist and is it a folder" — preferred over trying to infer folder-ness from `Get-ChildItem` behavior, which is built for listing contents, not testing the target path itself.
- `-Directory` (dynamic, FileSystem-provider-only parameter) vs `-Container` (core `Get-ChildItem` parameter, provider-agnostic) behave identically for filesystem paths; `-Directory` was judged more self-documenting for this filesystem-only script and is what's being used.

## Suggested Immediate Next Steps
1. Move `Resolve-Path` (both calls) and the `Get-ChildItem` subfolder-count call inside the `try` block in `Invoke-Phase1`, ordered above anything that consumes their results, so bad paths are caught and reported via the phase's normal `Success/Data/Reason` contract instead of throwing uncaught.
2. Fix the platform-resolution loop's overwrite bug (`break` on match, initialize `$ResolvedPlatform = "unknown"` before the loop) — user has explicitly deferred this to do last, so likely next real step once ready.
3. Extract platform resolution into its own `Get-PlatformShortName` function per the original doc: explicit `-Path` parameter, `[ordered]@{}` lookup table.
4. Once Phase 1 is solid: stress-test source≠destination / nested-destination checks, standardize hashtable key casing throughout, then move to writing Phase 2's real filtering logic (still just a stub as of this document).
