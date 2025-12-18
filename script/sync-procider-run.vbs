' run-sync.vbs - 隐藏运行 PowerShell 脚本
Set shell = CreateObject("WScript.Shell")
psScript = "<YOUR_MIHOMO_PATH>\script\sync-procider.ps1"
pwsh = """C:\Program Files\PowerShell\7\pwsh.exe"""
cmd = pwsh & " -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """"
shell.Run cmd, 0, False