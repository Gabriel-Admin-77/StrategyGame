<#
.SYNOPSIS
    Runs every headless GDScript test suite plus a main-scene smoke run.

.DESCRIPTION
    Discovers tests/test_*.gd, runs them sequentially with the console build of
    Godot (so stdout/stderr are captured), and fails if any suite fails.
    Each suite is expected to call quit(0) on success and quit(1) on failure.

.PARAMETER GodotExe
    Path to the Godot executable. Auto-detected from the workspace when omitted.

.PARAMETER LowGraphics
    Passes "-- --low-gfx" to the project (read via GameSettings.is_low_gfx()).

.PARAMETER SkipSmoke
    Skips the main-scene startup check.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 -LowGraphics
#>
[CmdletBinding()]
param(
    [string]$GodotExe = "",
    [switch]$LowGraphics,
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Continue"
$testDirectory = $PSScriptRoot
$projectRoot = Split-Path -Parent $testDirectory

function Find-GodotExecutable {
    param([string]$ExplicitPath, [string]$ProjectRoot)

    if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $workspace = Split-Path -Parent $ProjectRoot
    $candidates = @(
        (Join-Path $workspace "Godot_v4.7.2-stable_win64_console.exe"),
        (Join-Path $workspace "Godot_v4.7.2-stable_win64.exe"),
        (Join-Path $ProjectRoot "Godot_v4.7.2-stable_win64_console.exe"),
        "C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $onPath = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($onPath) {
        return $onPath.Source
    }

    throw "Godot executable not found. Pass -GodotExe <path>."
}

$godot = Find-GodotExecutable -ExplicitPath $GodotExe -ProjectRoot $projectRoot
Write-Host "Godot  : $godot"
Write-Host "Project: $projectRoot"
Write-Host ""

$userArgs = @()
if ($LowGraphics) {
    $userArgs = @("--", "--low-gfx")
}

$results = @()
$testFiles = Get-ChildItem -LiteralPath $testDirectory -Filter "test_*.gd" -File | Sort-Object Name

if ($testFiles.Count -eq 0) {
    Write-Host "No test_*.gd files found in $testDirectory" -ForegroundColor Yellow
    exit 1
}

foreach ($testFile in $testFiles) {
    $scriptPath = "res://tests/$($testFile.Name)"
    Write-Host "=== $($testFile.BaseName) ===" -ForegroundColor Cyan

    $godotArgs = @("--headless", "--path", $projectRoot, "--script", $scriptPath) + $userArgs
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = & $godot @godotArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $stopwatch.Stop()

    Write-Host $output.TrimEnd()
    if ($exitCode -ne 0) {
        Write-Host ("-> FAILED (exit $exitCode, {0:N1}s)" -f $stopwatch.Elapsed.TotalSeconds) -ForegroundColor Red
    }
    else {
        Write-Host ("-> passed ({0:N1}s)" -f $stopwatch.Elapsed.TotalSeconds) -ForegroundColor Green
    }
    Write-Host ""

    $results += [pscustomobject]@{
        Name     = $testFile.BaseName
        ExitCode = $exitCode
        Output   = $output
        Seconds  = $stopwatch.Elapsed.TotalSeconds
    }
}

if (-not $SkipSmoke) {
    Write-Host "=== main scene smoke run ===" -ForegroundColor Cyan
    $smokeArgs = @("--headless", "--path", $projectRoot, "--quit-after", "20") + $userArgs
    $smokeOutput = & $godot @smokeArgs 2>&1 | Out-String
    $smokeExit = $LASTEXITCODE
    Write-Host $smokeOutput.TrimEnd()

    $hasScriptError = $smokeOutput -match "(?m)^(SCRIPT ERROR|ERROR:|Failed to load|Cannot open)"
    if ($smokeExit -ne 0 -or $hasScriptError) {
        Write-Host "-> FAILED (startup errors detected)" -ForegroundColor Red
        $results += [pscustomobject]@{
            Name     = "main_scene_smoke"
            ExitCode = 1
            Output   = $smokeOutput
            Seconds  = 0
        }
    }
    else {
        Write-Host "-> passed" -ForegroundColor Green
    }
    Write-Host ""
}

$failed = @($results | Where-Object { $_.ExitCode -ne 0 })
$total = $results.Count
$passed = $total - $failed.Count

Write-Host "============================================="
Write-Host ("RESULT: {0}/{1} suites passed" -f $passed, $total)
if ($failed.Count -gt 0) {
    foreach ($failure in $failed) {
        Write-Host ("  FAILED: {0} (exit {1})" -f $failure.Name, $failure.ExitCode) -ForegroundColor Red
    }
    Write-Host "============================================="
    exit 1
}

Write-Host "ALL SUITES PASSED" -ForegroundColor Green
Write-Host "============================================="
exit 0
