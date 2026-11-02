# Test Screenshot Storage & FIFO Cache Engine

$testDir = "C:\Users\paris\.gemini\antigravity\brain\e59453fe-587c-4f26-9705-a701dc9a293b\scratch\test_screenshot_cache"
if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

Add-Type -AssemblyName PresentationCore, WindowsBase

# Define Mock Storage Helper
function Initialize-ScreenshotStorageTest($dir) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $files = Get-ChildItem -Path $dir -Filter "screenshot_*.png" | Sort-Object CreationTime -Descending | Select-Object -First 5
    return @($files | ForEach-Object { $_.FullName })
}

function Save-ScreenshotToCacheTest($dir, $bitmap) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    $ts = (Get-Date).ToString("yyyyMMdd_HHmmss_fff")
    $filePath = Join-Path $dir "screenshot_$ts.png"

    # Encode Bitmap to PNG file
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $fs = New-Object System.IO.FileStream($filePath, [System.IO.FileMode]::Create)
    $encoder.Save($fs)
    $fs.Close()
    $fs.Dispose()

    # FIFO Rotation: Keep only the 5 latest screenshots
    $allFiles = Get-ChildItem -Path $dir -Filter "screenshot_*.png" | Sort-Object CreationTime -Descending
    if ($allFiles.Count -gt 5) {
        $toRemove = $allFiles | Select-Object -Skip 5
        foreach ($old in $toRemove) {
            try { Remove-Item -Force $old.FullName } catch {}
        }
    }

    return $filePath
}

# 1. Create a dummy BitmapSource (10x10 colored bitmap)
$width = 10; $height = 10; $dpi = 96
$rawStride = $width * 4
$rawImage = New-Object byte[] ($rawStride * $height)
for ($i = 0; $i -lt $rawImage.Length; $i += 4) {
    $rawImage[$i] = 255; $rawImage[$i+1] = 128; $rawImage[$i+2] = 0; $rawImage[$i+3] = 255
}
$bs = [System.Windows.Media.Imaging.BitmapSource]::Create($width, $height, $dpi, $dpi, [System.Windows.Media.PixelFormats]::Bgra32, $null, $rawImage, $rawStride)

# 2. Test saving 7 consecutive screenshots
for ($i = 1; $i -le 7; $i++) {
    Start-Sleep -Milliseconds 60
    $saved = Save-ScreenshotToCacheTest $testDir $bs
    Write-Host ("Saved #" + $i + ": " + $saved)
}

# 3. Verify exactly 5 files remain
$remaining = Get-ChildItem -Path $testDir -Filter "screenshot_*.png"
Write-Host "Remaining files count: $($remaining.Count)"

if ($remaining.Count -ne 5) {
    Write-Error "FAIL: Expected 5 files, but found $($remaining.Count)"
    exit 1
}

# 4. Verify Initialize-ScreenshotStorage returns 5 files
$loaded = Initialize-ScreenshotStorageTest $testDir
if ($loaded.Count -ne 5) {
    Write-Error "FAIL: Initialize returned $($loaded.Count) files instead of 5"
    exit 1
}

Write-Host "SUCCESS: FIFO 5-screenshot storage engine verified!" -ForegroundColor Green

# Cleanup test dir
Remove-Item -Recurse -Force $testDir
exit 0
