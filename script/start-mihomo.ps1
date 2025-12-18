$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir
Write-Host "Starting Mihomo service..."
Start-Process winsw.exe -ArgumentList "start" -Wait
Write-Host "Mihomo service start command issued."