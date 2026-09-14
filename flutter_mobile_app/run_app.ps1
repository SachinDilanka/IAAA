$env:Path = "C:\src\flutter\bin;" + $env:Path
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Starting AcousticAware Flutter Mobile App with 3D Avatar..." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Set-Location -Path $PSScriptRoot
& "C:\src\flutter\bin\flutter.bat" run -d windows
