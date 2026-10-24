$ErrorActionPreference = 'SilentlyContinue'

$startupDir = [Environment]::GetFolderPath('Startup')
$rootDir = Split-Path $PSScriptRoot -Parent
$targetScript = Join-Path $rootDir "run-island.ps1"

$wsh = New-Object -ComObject WScript.Shell
$startupLnk = Join-Path $startupDir "OceruIsland.lnk"
$s = $wsh.CreateShortcut($startupLnk)
$s.TargetPath = "powershell.exe"
$s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`""
$s.WorkingDirectory = "$rootDir"
$s.Description = "Oceru Dynamic Island Desktop"
$s.Save()

# Try Desktop shortcut as well if accessible
$desktopDir = [Environment]::GetFolderPath('DesktopDirectory')
if (-not $desktopDir) { $desktopDir = Join-Path $env:USERPROFILE "Desktop" }
if (Test-Path $desktopDir) {
    $desktopLnk = Join-Path $desktopDir "Oceru Dynamic Island.lnk"
    $d = $wsh.CreateShortcut($desktopLnk)
    $d.TargetPath = "powershell.exe"
    $d.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`""
    $d.WorkingDirectory = "$rootDir"
    $d.Description = "Oceru Dynamic Island Desktop"
    $d.Save()
}

Write-Output "INSTALLED_SUCCESS"
