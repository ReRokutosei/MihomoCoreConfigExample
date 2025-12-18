#!/usr/bin/env pwsh

param (
    [string]$ProviderDir = "$PSScriptRoot/../config/proxy_provider",
    [string]$OutputFile = "$PSScriptRoot/../config/otherfiles/proxies.yaml",
    [string]$LogPath = "$PSScriptRoot/logs/proxies-change.log"
)

# 初始化日志目录
$null = New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force

function Write-Log { 
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $Message" | Add-Content $LogPath -Encoding UTF8
    Write-Host "[$ts] $Message"
}

# 加载通知模块（静默）
Import-Module BurntToast -ErrorAction SilentlyContinue

# 定义图标路径
$IconUpdated = "config\ui\icons\March7th(2)_256.png"
$IconCurrent = "config\ui\icons\March7th(3)_256.png"

Write-Log "开始记录节点变化情况..."

# 如果存在旧的过滤文件，则加载它以便比较
$oldProxies = @{}
if (Test-Path $OutputFile) {
    $oldContent = Get-Content $OutputFile -Raw
    # 简单解析旧的YAML内容以获取每个供应商的代理数量和名称
    $oldSections = $oldContent -split "\n(?=\w+:)"
    foreach ($section in $oldSections) {
        if ($section -match "^(\w+):") {
            $provider = $matches[1]
            # 获取代理名称列表
            $proxyNames = @()
            $lines = $section -split "\n"
            foreach ($line in $lines) {
                if ($line -match "name:\s*'([^']+)'") {
                    $proxyNames += $matches[1]
                } elseif ($line -match 'name:\s*"([^"]+)"') {
                    $proxyNames += $matches[1]
                }
            }
            $oldProxies[$provider] = $proxyNames
        }
    }
}

# 创建或清空输出文件
$outputLines = @("# Auto-generated proxies list - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")

# 存储新的代理信息用于比较
$newProxies = @{}

# 动态获取目录中的所有yaml文件并按名称排序
$providerFiles = Get-ChildItem -Path $ProviderDir -Filter "*.yaml" | Sort-Object Name

# 处理每个提供者文件，按文件名字母顺序
foreach ($file in $providerFiles) {
    $provider = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $filePath = $file.FullName
    
    if (Test-Path $filePath) {
        Write-Host "Processing $filePath..."
        
        # 读取文件内容
        $content = Get-Content $filePath -Raw
        
        # 提取 proxies 部分
        if ($content -match '(?s)proxies:(.*?)(proxy-groups:|$)') {
            $proxiesSection = $matches[1]
            
            # 将 proxies 部分按行分割
            $lines = $proxiesSection -split '\r?\n'
            
            # 收集代理名称
            $proxyNames = @()
            
            # 添加 provider 名称作为标题
            $outputLines += "$($provider):"
            
            # 处理每一行代理配置
            foreach ($line in $lines) {
                # 匹配包含 name 和 type 的代理行
                if (($line -match "-\s*\{\s*name:\s*'([^']*?)'.*?type:\s*(\w+)") -or 
                    ($line -match '-\s*\{\s*name:\s*"([^"]*?)".*?type:\s*(\w+)') -or
                    ($line -match '-\s*\{\s*name:\s*([^,]*?),.*?type:\s*(\w+)')) {
                    $name = $matches[1].Trim()
                    $type = $matches[2]
                    
                    # 过滤掉包含"剩余流量"或"套餐到期"关键词的节点
                    if ($name -notmatch "剩余流量|套餐到期") {
                        # 添加代理名称到列表
                        $proxyNames += $name
                        
                        # 写入格式化的代理信息
                        $outputLines += "    - { name: '$name', type: $type}"
                    }
                }
            }
            
            # 记录新代理名称列表
            $newProxies[$provider] = $proxyNames
        }
    } else {
        Write-Warning "File not found: $filePath"
        Write-Log "警告: 文件未找到 $filePath"
    }
}

# 将所有内容一次性写入文件
$outputLines | Set-Content -Path $OutputFile

# 检查变化并记录详细日志
$hasChanges = $false
$providerOrder = $providerFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }

foreach ($provider in $providerOrder) {
    $oldList = if ($oldProxies.ContainsKey($provider)) { $oldProxies[$provider] } else { @() }
    $newList = if ($newProxies.ContainsKey($provider)) { $newProxies[$provider] } else { @() }
    
    # 找出新增和删除的节点
    $added = $newList | Where-Object { $oldList -notcontains $_ }
    $removed = $oldList | Where-Object { $newList -notcontains $_ }
    
    if ($added.Count -gt 0 -or $removed.Count -gt 0) {
        $hasChanges = $true
        if ($added.Count -gt 0) {
            Write-Log "[$provider] [增加] [$($added.Count) 个节点] 具体为[$($added -join ', ')]"
        }
        if ($removed.Count -gt 0) {
            Write-Log "[$provider] [减少] [$($removed.Count) 个节点] 具体为[$($removed -join ', ')]"
        }
    }
}


# 在检测变化后，构建一个简短摘要
$summary = if ($hasChanges) {
    $msgs = foreach ($provider in $providerOrder) {
        $old = $oldProxies[$provider] ?? @()
        $new = $newProxies[$provider] ?? @()
        $added   = @($new | Where-Object { $_ -notin $old }).Count
        $removed = @($old | Where-Object { $_ -notin $new }).Count
        if ($added -gt 0 -or $removed -gt 0) {
            $parts = @()
            if ($added -gt 0) { $parts += "新增 $added 个节点" }
            if ($removed -gt 0) { $parts += "删除 $removed 个节点" }
            "${provider}: $($parts -join ' ')"
        }
    }
    ($msgs -join '; ') -replace '^; ', ''
} else {
    "无变化"
}

# 然后用于通知
if ($hasChanges) {
    Write-Log "✅ 记录已更新。"
    New-BurntToastNotification -Text "Proxies Updated", $summary -AppLogo $IconUpdated -Silent
} else {
    Write-Log "节点未变化。"
    New-BurntToastNotification -Text "Proxies Current", "节点无变动情况。" -AppLogo $IconCurrent -Silent
}