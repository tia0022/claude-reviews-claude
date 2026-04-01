# Mermaid .mmd -> SVG V3 (圆角+阴影+粗线)
$inputDir  = $PSScriptRoot
$outputDir = Join-Path $PSScriptRoot "svg-v3"
$config    = Join-Path $PSScriptRoot "mermaid-config-v3.json"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$files = Get-ChildItem -Path $inputDir -Filter "*.mmd" | Sort-Object Name
$total = $files.Count
$idx = 0

foreach ($f in $files) {
    $idx++
    $outFile = Join-Path $outputDir ($f.BaseName + ".svg")
    Write-Host "[$idx/$total] $($f.Name) -> svg-v3/$($f.BaseName).svg"
    npx -y @mermaid-js/mermaid-cli -i $f.FullName -o $outFile -c $config -b white --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] fail: $($f.Name)" -ForegroundColor Yellow
    }
}

$svgCount = (Get-ChildItem $outputDir -Filter "*.svg" | Measure-Object).Count
Write-Host "`nDone! $svgCount / $total SVG in svg-v3/" -ForegroundColor Green
