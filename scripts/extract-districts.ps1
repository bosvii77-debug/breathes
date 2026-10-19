# ดึงเส้นแบ่ง 50 เขตของกรุงเทพจากไฟล์อำเภอทั้งประเทศ แล้วบันทึกเป็น data/bkk-districts.geojson
# ที่มา: chingchai/OpenGISData-Thailand (CC BY 4.0) https://github.com/chingchai/OpenGISData-Thailand
# วิธีใช้: powershell -File scripts/extract-districts.ps1
$src = "https://raw.githubusercontent.com/chingchai/OpenGISData-Thailand/master/districts.geojson"
$root = Split-Path $PSScriptRoot -Parent
$tmp = Join-Path $env:TEMP "th-districts.geojson"
Invoke-WebRequest $src -OutFile $tmp -UseBasicParsing
$j = Get-Content $tmp -Raw -Encoding UTF8 | ConvertFrom-Json

function RoundCoords($c) {
  # ปัดทศนิยม 5 ตำแหน่ง (~1 เมตร) ให้ไฟล์เล็กลง
  if ($c[0] -is [array] -or $c[0] -is [System.Collections.IList]) { return ,@($c | ForEach-Object { ,(RoundCoords $_) }) }
  return ,@([math]::Round([double]$c[0], 5), [math]::Round([double]$c[1], 5))
}

$feats = $j.features | Where-Object { $_.properties.pro_code -eq '10' } | ForEach-Object {
  [ordered]@{
    type = "Feature"
    properties = [ordered]@{ code = $_.properties.amp_code; th = $_.properties.amp_th; en = $_.properties.amp_en; lat = $_.properties.lat; lon = $_.properties.lon }
    geometry = [ordered]@{ type = $_.geometry.type; coordinates = (RoundCoords $_.geometry.coordinates) }
  }
}
$out = [ordered]@{
  type = "FeatureCollection"
  source = "chingchai/OpenGISData-Thailand districts.geojson (CC BY 4.0), filtered pro_code=10"
  features = @($feats)
}
New-Item -ItemType Directory -Force (Join-Path $root "data") | Out-Null
$path = Join-Path $root "data\bkk-districts.geojson"
[IO.File]::WriteAllText($path, ($out | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding $false))
Write-Output "wrote $($feats.Count) districts -> $path"
