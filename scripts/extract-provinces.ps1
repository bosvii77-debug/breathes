# ดึงขอบเขตจังหวัดรอบกรุงเทพ (นนทบุรี ปทุมธานี สมุทรปราการ สมุทรสาคร นครปฐม ฉะเชิงเทรา)
# จากแหล่งเดียวกับเส้นเขต เส้นขอบจึงต่อกันพอดี แล้วบันทึกเป็น data/bkk-around.geojson
# ที่มา: chingchai/OpenGISData-Thailand (CC BY 4.0)
# วิธีใช้: powershell -File scripts/extract-provinces.ps1
$src = "https://raw.githubusercontent.com/chingchai/OpenGISData-Thailand/master/provinces.geojson"
$root = Split-Path $PSScriptRoot -Parent
$tmp = Join-Path $env:TEMP "th-provinces.geojson"
Invoke-WebRequest $src -OutFile $tmp -UseBasicParsing
$j = Get-Content $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
$codes = @('11','12','13','24','73','74')

function RoundCoords($c) {
  # ปัดทศนิยม 4 ตำแหน่ง (~10 เมตร) พอสำหรับภาพจางๆ รอบเมือง
  if ($c[0] -is [array] -or $c[0] -is [System.Collections.IList]) { return ,@($c | ForEach-Object { ,(RoundCoords $_) }) }
  return ,@([math]::Round([double]$c[0], 4), [math]::Round([double]$c[1], 4))
}

$feats = $j.features | Where-Object { $codes -contains [string]$_.properties.pro_code } | ForEach-Object {
  [ordered]@{
    type = "Feature"
    properties = [ordered]@{ code = $_.properties.pro_code; th = $_.properties.pro_th; en = $_.properties.pro_en }
    geometry = [ordered]@{ type = $_.geometry.type; coordinates = (RoundCoords $_.geometry.coordinates) }
  }
}
$out = [ordered]@{
  type = "FeatureCollection"
  source = "chingchai/OpenGISData-Thailand provinces.geojson (CC BY 4.0), pro_code 11,12,13,24,73,74"
  features = @($feats)
}
$path = Join-Path $root "data\bkk-around.geojson"
[IO.File]::WriteAllText($path, ($out | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding $false))
Write-Output "wrote $($feats.Count) provinces -> $path"
