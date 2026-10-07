$ErrorActionPreference = "Stop"

$RepoOwner = "kevinevans98-crypto"
$RepoName = "ForeverLevelingCoach"
$Branch = "ForeverLevelingCoach"
$AddonName = "ForeverLevelingCoach"

Write-Host ""
Write-Host "Forever Leveling Coach Updater" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$possibleAddonDirs = @(
    "D:\Game Folder\World of Warcraft\_classic_beta_\Interface\AddOns",
    "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns",
    "C:\Program Files\World of Warcraft\_classic_beta_\Interface\AddOns",
    "C:\World of Warcraft\_classic_beta_\Interface\AddOns"
)

$AddOnsDir = $null
foreach ($candidate in $possibleAddonDirs) {
    if (Test-Path $candidate) {
        $AddOnsDir = $candidate
        break
    }
}

if (-not $AddOnsDir) {
    Write-Host "I couldn't auto-detect your WoW Forever Beta AddOns folder." -ForegroundColor Yellow
    Write-Host "Paste the full path to your AddOns folder below."
    Write-Host "Example: C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns"
    $AddOnsDir = Read-Host "AddOns folder"

    if (-not (Test-Path $AddOnsDir)) {
        throw "That AddOns folder does not exist: $AddOnsDir"
    }
}

Write-Host "Using AddOns folder:" -ForegroundColor Cyan
Write-Host "  $AddOnsDir" -ForegroundColor Cyan

$TargetDir = Join-Path $AddOnsDir $AddonName
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $AddOnsDir ($AddonName + ".backup-" + $timestamp)

$tempRoot = Join-Path $env:TEMP ("FLC-Updater-" + [Guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "repo.zip"
$extractDir = Join-Path $tempRoot "extract"

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

try {
    $zipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"

    Write-Host "Downloading latest Forever Leveling Coach..." -ForegroundColor Green
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "Extracting update..." -ForegroundColor Green
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $repoFolder = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    if (-not $repoFolder) {
        throw "Could not find the extracted repository folder."
    }

    $sourceAddon = Join-Path $repoFolder.FullName $AddonName
    if (-not (Test-Path $sourceAddon)) {
        throw "The downloaded repository does not contain the $AddonName addon folder."
    }

    if (Test-Path $TargetDir) {
        Write-Host "Backing up current addon to:" -ForegroundColor DarkGray
        Write-Host "  $BackupDir" -ForegroundColor DarkGray
        Copy-Item -Path $TargetDir -Destination $BackupDir -Recurse -Force
        Remove-Item -Path $TargetDir -Recurse -Force
    }

    Write-Host "Installing latest addon..." -ForegroundColor Green
    Copy-Item -Path $sourceAddon -Destination $TargetDir -Recurse -Force

    $tocPath = Join-Path $TargetDir "ForeverLevelingCoach.toc"
    if (-not (Test-Path $tocPath)) {
        throw "Install check failed: ForeverLevelingCoach.toc was not found."
    }

    Write-Host ""
    Write-Host "Update complete." -ForegroundColor Cyan
    Write-Host "Installed to:"
    Write-Host "  $TargetDir"
    Write-Host ""
    Write-Host "Your WoW SavedVariables are stored separately and are not replaced by this updater."
    Write-Host "If WoW is already running, use /reload after updating."
}
catch {
    Write-Host ""
    Write-Host "Update failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ((-not (Test-Path $TargetDir)) -and (Test-Path $BackupDir)) {
        Write-Host "Restoring previous addon backup..." -ForegroundColor Yellow
        Copy-Item -Path $BackupDir -Destination $TargetDir -Recurse -Force
    }

    exit 1
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Read-Host "Press Enter to close"
