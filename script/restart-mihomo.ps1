$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir
Write-Host "Restarting Mihomo service..."
Start-Process winsw.exe -ArgumentList "restart" -Wait
Write-Host "Mihomo service restart command issued."