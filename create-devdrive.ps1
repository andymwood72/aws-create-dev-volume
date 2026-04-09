Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-DevDriveMounted {
    foreach ($code in 65..90) {
        $letter = [char]$code
        $volumePath = "$letter`:\"

        if (-not (Test-Path -LiteralPath $volumePath)) {
            continue
        }

        $queryOutput = (& fsutil devdrv query "$letter`:" 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
            continue
        }

        $isDevDrive = $queryOutput -match "(?i)(dev drive|developer volume)"
        $isNegative = $queryOutput -match "(?i)(not a dev drive|not a developer volume|is not a developer volume)"
        if ($isDevDrive -and -not $isNegative) {
            return "$letter`:"
        }
    }

    return $null
}

function Read-ValidSizeGb {
    param(
        [Parameter(Mandatory = $true)]
        [int]$MaxSizeGb
    )

    while ($true) {
        $inputText = Read-Host "Drive Size in GB (integer 50-$MaxSizeGb)"
        $parsed = 0
        $isInt = [int]::TryParse($inputText, [ref]$parsed)

        if (-not $isInt) {
            Write-Host "Invalid size. Enter a whole number." -ForegroundColor Yellow
            continue
        }

        if ($parsed -lt 50) {
            Write-Host "Invalid size. Minimum is 50 GB." -ForegroundColor Yellow
            continue
        }

        if ($parsed -gt $MaxSizeGb) {
            Write-Host "Invalid size. Maximum allowed is $MaxSizeGb GB." -ForegroundColor Yellow
            continue
        }

        return $parsed
    }
}

function Read-ValidDriveLetter {
    while ($true) {
        $inputText = Read-Host "Drive letter (single letter, not in use)"
        $letter = ($inputText ?? "").Trim().TrimEnd(":").ToUpperInvariant()

        if ($letter -notmatch "^[A-Z]$") {
            Write-Host "Invalid drive letter. Enter one letter A-Z." -ForegroundColor Yellow
            continue
        }

        if (Test-Path -LiteralPath "$letter`:\") {
            Write-Host "Drive letter $letter`: is already in use." -ForegroundColor Yellow
            continue
        }

        return $letter
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$createScript = Join-Path $scriptRoot "create-devdrive.cmd"
if (-not (Test-Path -LiteralPath $createScript)) {
    throw "Could not find create-devdrive.cmd at $createScript"
}

$existingDevDrive = Test-DevDriveMounted
if ($existingDevDrive) {
    Write-Host "Dev Drive is already mounted at $existingDevDrive. No action taken." -ForegroundColor Cyan
    exit 0
}

$dDrive = Get-PSDrive -Name "D" -ErrorAction SilentlyContinue
if (-not $dDrive) {
    throw "D: drive was not found."
}

$freeGb = [int][Math]::Floor($dDrive.Free / 1GB)
$maxAllowedGb = $freeGb - 50

if ($maxAllowedGb -lt 50) {
    throw "Not enough free space on D:. Free: $freeGb GB. Need at least 100 GB free to allow a minimum 50 GB Dev Drive while leaving 50 GB unused."
}

Write-Host "D: free space: $freeGb GB. Allowed size range: 50-$maxAllowedGb GB." -ForegroundColor Cyan

$sizeGb = Read-ValidSizeGb -MaxSizeGb $maxAllowedGb
$driveLetter = Read-ValidDriveLetter

Write-Host "Starting elevated create-devdrive with size $sizeGb GB and drive letter $driveLetter`: ..." -ForegroundColor Cyan

$process = Start-Process -FilePath $createScript `
    -ArgumentList @("--size", "$sizeGb`GB", "--letter", $driveLetter) `
    -Verb RunAs `
    -PassThru `
    -Wait

if ($process.ExitCode -eq 0) {
    Write-Host "Dev Drive creation command completed successfully." -ForegroundColor Green
    exit 0
}

Write-Host "create-devdrive.cmd failed with exit code $($process.ExitCode)." -ForegroundColor Red
exit $process.ExitCode
