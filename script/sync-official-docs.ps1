# sync-official-docs.ps1
param (
    [string]$LogPath = "$PSScriptRoot/logs/sync-mihomo-docs.log"
)

$IconUpdated = "$PSScriptRoot/../config/ui/icons/March7th(2)_256.png"
$IconCurrent = "$PSScriptRoot/../config/ui/icons/March7th(3)_256.png"
$IconFailed  = "$PSScriptRoot/../config/ui/icons/March7th(12)_256.png"

function Write-Log { 
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $Message" | Add-Content $LogPath -Encoding UTF8
    Write-Host "[$ts] $Message"
}

# 初始化日志目录
$null = New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force

# 加载通知模块（静默）
Import-Module BurntToast -ErrorAction SilentlyContinue

Write-Log "开始同步官方配置文件..."

$RepoRoot = Resolve-Path "$PSScriptRoot/.."
$TargetFile = "$RepoRoot/config/otherfiles/offical_example_config.yaml"
$TempFile = "$TargetFile.tmp"

try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MetaCubeX/mihomo/Alpha/docs/config.yaml" -OutFile $TempFile -TimeoutSec 30
    Write-Log "成功下载配置文件。"

    $NeedUpdate = $true
    $summary = ""

    if (Test-Path $TargetFile) {
        $oldHash = (Get-FileHash $TargetFile -Algorithm SHA256).Hash
        $newHash = (Get-FileHash $TempFile -Algorithm SHA256).Hash

        if ($oldHash -eq $newHash) {
            $NeedUpdate = $false
            Write-Log "文件未变化，跳过更新。"
            Remove-Item $TempFile -Force
            New-BurntToastNotification -Text "Mihomo Docs Current", "配置文件无变动。" -AppLogo $IconCurrent -Silent
        } else {
            # 计算新增/删除的行数（基于内容对比）
            $oldContent = @(Get-Content $TargetFile)
            $newContent = @(Get-Content $TempFile)

            $diffResult = Compare-Object -ReferenceObject $oldContent -DifferenceObject $newContent

            $added   = @($diffResult | Where-Object { $_.SideIndicator -eq "=>" }).Count
            $removed = @($diffResult | Where-Object { $_.SideIndicator -eq "<=" }).Count

            if ($added -eq 0 -and $removed -eq 0) {
                $summary = "内容无变化"
            } elseif ($added -eq 0) {
                $summary = "文档删除 $removed 行"
            } elseif ($removed -eq 0) {
                $summary = "文档新增 $added 行"
            } else {
                $summary = "文档新增 $added 行, 删除 $removed 行"
            }
        }
    } else {
        # 首次下载，没有旧文件
        $newLines = @(Get-Content $TempFile).Count
        $summary = "首次下载，共 $newLines 行"
    }

    if ($NeedUpdate) {
        Move-Item -Force $TempFile $TargetFile
        Set-Location $RepoRoot
        & git add "config/otherfiles/offical_example_config.yaml"
        if (& git status --porcelain "config/otherfiles/offical_example_config.yaml") {
            & git commit -m "chore(config): sync official example config from mihomo/Alpha"
            Write-Log "✅ Git 提交成功。"
        }
        Write-Log "✅ 配置文件已更新。"
        New-BurntToastNotification -Text "Mihomo Docs Synced", $summary -AppLogo $IconUpdated -Silent
    }

} catch {
    Write-Log "❌ 同步失败: $_"

    # 只取错误的第一行
    $firstLine = ($_.Exception.Message -split '\r?\n')[0]
    if (-not $firstLine) { $firstLine = "未知错误" }

    if (Test-Path $TempFile) { Remove-Item $TempFile -Force }
    New-BurntToastNotification -Text "Mihomo Docs Sync Failed", $firstLine -AppLogo $IconFailed -Silent
    exit 1
}

Write-Log "同步任务结束。"