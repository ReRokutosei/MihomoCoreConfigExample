$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir
Write-Host "Stopping Mihomo service..."
Start-Process winsw.exe -ArgumentList "stop" -Wait
Write-Host "Mihomo service stop command issued."