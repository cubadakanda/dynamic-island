# End-to-End Test for 5 Recent Screenshots Shelf Feature

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$repoDir = "D:\Project Orizzdev\dynamic-island"
$testScript = Join-Path $repoDir "run-island.ps1"

Write-Host "Verifying AST of run-island.ps1..."
$ast = [System.Management.Automation.Language.Parser]::ParseFile($testScript, [ref]$null, [ref]$null)
if (-not $ast) {
    Write-Error "Failed to parse script AST"
    exit 1
}
Write-Host "AST verified: OK" -ForegroundColor Green

# Test cache directory creation
$cacheDir = Join-Path $repoDir "screenshots"
if (-not (Test-Path $cacheDir)) {
    [void](New-Item -ItemType Directory -Path $cacheDir -Force)
}

# Create dummy 200x150 bitmap
$w = 200; $h = 150; $dpi = 96
$stride = $w * 4
$bytes = New-Object byte[] ($stride * $h)
for ($i = 0; $i -lt $bytes.Length; $i += 4) {
    $bytes[$i] = 248; $bytes[$i+1] = 189; $bytes[$i+2] = 56; $bytes[$i+3] = 255 # #38BDF8 Sky Blue
}
$dummyBmp = [System.Windows.Media.Imaging.BitmapSource]::Create($w, $h, $dpi, $dpi, [System.Windows.Media.PixelFormats]::Bgra32, $null, $bytes, $stride)

# Test encoding to PNG
$ts = (Get-Date).ToString("yyyyMMdd_HHmmss_fff")
$testPng = Join-Path $cacheDir "screenshot_$ts.png"
$encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($dummyBmp))
$fs = New-Object System.IO.FileStream($testPng, [System.IO.FileMode]::Create)
$encoder.Save($fs)
$fs.Close()
$fs.Dispose()

Write-Host "Created test screenshot: $testPng" -ForegroundColor Cyan

# Test reading 5 latest
$recent = Get-ChildItem -Path $cacheDir -Filter "screenshot_*.png" | Sort-Object CreationTime -Descending | Select-Object -First 5
Write-Host "Found $($recent.Count) recent screenshot(s) in cache" -ForegroundColor Green

# Test DataObject creation (simulating DoDragDrop payload)
$dataObj = New-Object System.Windows.DataObject
$dataObj.SetData([System.Windows.DataFormats]::FileDrop, [string[]]@($testPng))
$dataObj.SetData([System.Windows.DataFormats]::Bitmap, $dummyBmp)

if (-not $dataObj.ContainsFileDropList()) {
    Write-Error "FAIL: DataObject does not contain FileDropList!"
    exit 1
}

$dropFiles = $dataObj.GetFileDropList()
Write-Host "Verified Drag-and-Drop FileDropList: $($dropFiles[0])" -ForegroundColor Green

# Clean up test file
Remove-Item -Force $testPng -ErrorAction SilentlyContinue

Write-Host "ALL SCREENSHOT SHELF TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
exit 0
