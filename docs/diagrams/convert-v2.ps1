# Mermaid .mmd -> SVG 批量转换脚本 (V2 暗色主题)
# 输出到 svg-v2/ 目录，不覆盖旧版 svg/

$inputDir  = $PSScriptRoot
$outputDir = Join-Path $PSScriptRoot "svg-v2"
$config    = Join-Path $PSScriptRoot "mermaid-config-v2.json"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$files = Get-ChildItem -Path $inputDir -Filter "*.mmd" | Sort-Object Name
$total = $files.Count
$idx = 0

foreach ($f in $files) {
    $idx++
    $outFile = Join-Path $outputDir ($f.BaseName + ".svg")
    Write-Host "[$idx/$total] $($f.Name) -> svg-v2/$($f.BaseName).svg"
    npx -y @mermaid-js/mermaid-cli -i $f.FullName -o $outFile -c $config -b transparent --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] fail: $($f.Name)" -ForegroundColor Yellow
    }
}

$svgCount = (Get-ChildItem $outputDir -Filter "*.svg" | Measure-Object).Count
Write-Host "`nDone! $svgCount / $total SVG files in svg-v2/" -ForegroundColor Green
