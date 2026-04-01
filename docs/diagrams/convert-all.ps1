# Mermaid .mmd -> SVG 批量转换脚本
# 用法: pwsh -File convert-all.ps1

$inputDir  = $PSScriptRoot
$outputDir = Join-Path $PSScriptRoot "svg"
$config    = Join-Path $PSScriptRoot "mermaid-config.json"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$files = Get-ChildItem -Path $inputDir -Filter "*.mmd" | Sort-Object Name
$total = $files.Count
$idx = 0

foreach ($f in $files) {
    $idx++
    $outFile = Join-Path $outputDir ($f.BaseName + ".svg")
    Write-Host "[$idx/$total] $($f.Name) -> svg/$($f.BaseName).svg"
    npx -y @mermaid-js/mermaid-cli -i $f.FullName -o $outFile -c $config --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] 转换失败: $($f.Name)" -ForegroundColor Yellow
    }
}

$svgCount = (Get-ChildItem $outputDir -Filter "*.svg" | Measure-Object).Count
Write-Host "`n完成! 共生成 $svgCount / $total 个 SVG 文件" -ForegroundColor Green
