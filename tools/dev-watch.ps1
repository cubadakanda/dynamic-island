# dev-watch.ps1 - Live Reload Watcher for Oceru Dynamic Island Development
$rootDir = Split-Path $PSScriptRoot -Parent
$script = Join-Path $rootDir "run-island.ps1"

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  OCERU DYNAMIC ISLAND - LIVE DEV MODE (HOT RELOAD)" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "Oceru Dynamic Island sedang berjalan di desktop kamu." -ForegroundColor White
Write-Host "Setiap kali kamu/AI mengedit dan menyimpan file:" -ForegroundColor Yellow
Write-Host "  -> Dynamic Island akan OTOMATIS me-reload tampilan terbarunya!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Tip: Kamu juga bisa klik kanan pada notch -> 'Muat Ulang / Reload'" -ForegroundColor Gray
Write-Host "Tekan Ctrl+C di jendela ini jika ingin keluar dari mode Dev.`n" -ForegroundColor Gray

# Start island initially
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $rootDir
$watcher.Filter = "run-island.ps1"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$lastChange = [DateTime]::MinValue

try {
    while ($true) {
        $result = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::Changed, 800)
        if (-not $result.TimedOut) {
            $now = [DateTime]::Now
            if (($now - $lastChange).TotalMilliseconds -gt 800) {
                $lastChange = $now
                Write-Host "[Auto-Reload $(Get-Date -Format 'HH:mm:ss')] File run-island.ps1 diperbarui -> Me-reload notch..." -ForegroundColor Green
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
            }
        }
    }
} finally {
    $watcher.Dispose()
}
