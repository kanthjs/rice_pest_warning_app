# PowerShell script to find the latest R version and run export_shinylive.R

$r_root = "C:\Program Files\R"
if (-not (Test-Path $r_root)) {
    Write-Error "R installation directory not found at $r_root"
    exit 1
}

# Find the latest R version directory
$latest_r = Get-ChildItem -Path $r_root -Directory | 
    Where-Object { $_.Name -match "^R-\d+\.\d+\.\d+" } | 
    Sort-Object Name -Descending | 
    Select-Object -First 1

if (-not $latest_r) {
    Write-Error "No valid R installation found in $r_root"
    exit 1
}

$r_bin = Join-Path $latest_r.FullName "bin\Rscript.exe"

if (-not (Test-Path $r_bin)) {
    Write-Error "Rscript binary not found at $r_bin"
    exit 1
}

Write-Host "Using R version found at: $r_bin"
& $r_bin --vanilla "export_shinylive.R"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Export process completed successfully." -ForegroundColor Green
} else {
    Write-Host "Export process failed." -ForegroundColor Red
}
