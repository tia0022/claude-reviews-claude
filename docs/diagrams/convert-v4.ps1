# V4: ELK 布局 + 自动调整方向 + V3 样式
# 1. 复制 .mmd 到临时目录
# 2. 过宽的 LR→TD，过高的 TD→LR
# 3. 所有图都注入 ELK 引擎指令
# 4. 用 V3 的样式配置渲染

$mmdDir  = 'd:\MATRIX\Neo\ClaudeCode-source\claude-code-deep-dive\docs\diagrams'
$tmpDir  = '/tmp/mmd-v4'
$outDir  = Join-Path $mmdDir 'svg-v4'
$config  = Join-Path $mmdDir 'mermaid-config-v4.json'

# 清理
if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# 需要翻转方向的文件列表（基于宽高比分析）
$flipToTD = @(
    '00-overview',
    '01-query-engine-3',
    '02-tool-system-2',
    '02-tool-system-3',
    '03-coordinator-2',
    '04-plugin-system-2',
    '12-startup-bootstrap'
)
$flipToLR = @(
    '01-query-engine-1',
    '07-permission-pipeline-4'
)

# 复制并修改 .mmd 文件
Get-ChildItem -Path $mmdDir -Filter '*.mmd' | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    $base = $_.BaseName

    # 翻转方向
    if ($flipToTD -contains $base) {
        $content = $content -replace '^graph\s+LR', 'graph TD'
        Write-Host "FLIP LR->TD: $base"
    }
    elseif ($flipToLR -contains $base) {
        $content = $content -replace '^(graph\s+T[BD]|flowchart\s+TD)', 'graph LR'
        Write-Host "FLIP TD->LR: $base"
    }

    # 注入 ELK 引擎指令（仅对 graph/flowchart 类型）
    if ($content -match '^(graph|flowchart)\s') {
        $elkDirective = '%%{init: {"flowchart": {"defaultRenderer": "elk"}} }%%'
        $content = $elkDirective + "`n" + $content
        Write-Host "  +ELK: $base"
    }

    $outPath = Join-Path $tmpDir $_.Name
    [System.IO.File]::WriteAllText($outPath, $content, [System.Text.Encoding]::UTF8)
}

# 批量转换
$files = Get-ChildItem -Path $tmpDir -Filter '*.mmd' | Sort-Object Name
$total = $files.Count
$idx = 0

Write-Host "`n--- Converting $total files ---"
foreach ($f in $files) {
    $idx++
    $outFile = Join-Path $outDir ($f.BaseName + '.svg')
    Write-Host "[$idx/$total] $($f.Name)"
    npx -y @mermaid-js/mermaid-cli -i $f.FullName -o $outFile -c $config -b white --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] fail: $($f.Name)" -ForegroundColor Yellow
    }
}

$svgCount = (Get-ChildItem $outDir -Filter '*.svg' -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "`nDone! $svgCount / $total SVG in svg-v4/" -ForegroundColor Green
