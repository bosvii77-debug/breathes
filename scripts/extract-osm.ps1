# ดึงถนนสายหลัก คลอง แม่น้ำ และรางรถไฟของกรุงเทพและรอบๆ จาก OpenStreetMap (Overpass API) ครั้งเดียว
# แล้วย่อเป็นไฟล์เล็ก data/bkk-osm.json ให้หน้าเว็บวาดแผนที่ฐานแบบกราฟิกเอง (ไม่ใช้ภาพแผนที่จากภายนอก)
# ข้อมูล © ผู้ร่วมสร้าง OpenStreetMap (ODbL) ต้องใส่เครดิตบนหน้าเว็บ
# รูปแบบไฟล์: พิกัดเป็นจำนวนเต็ม (องศา x 1e5) เก็บแบบ "ต่างจากจุดก่อนหน้า" ให้ไฟล์เล็ก
#   {"s":100000,"roads":{"m":[[x0,y0,dx,dy,...],...],"p":[...],"s":[...],"t":[...]},"rivers":[...],"canals":[...],"rail":[...]}

param([string]$Out = "$PSScriptRoot\..\data\bkk-osm.json")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web.Extensions
$bbox = "13.35,100.15,14.10,101.10"   # ใต้,ตะวันตก,เหนือ,ตะวันออก (กว้างกว่าเมืองเล็กน้อย ให้เห็นรอบๆ)
$q = @"
[out:json][timeout:240];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary)$"]($bbox);
  way["waterway"~"^(river|canal)$"]($bbox);
  way["railway"~"^(rail|light_rail|subway)$"]["service"!~"."]($bbox);
);
out geom qt;
"@
$cache = Join-Path $env:TEMP "breathes-osm-raw.json"
$raw = $null
if (Test-Path $cache) { $raw = [IO.File]::ReadAllText($cache); Write-Host "using cached download" } else { Write-Host "querying Overpass..." }
if (-not $raw) { foreach ($try in 1..3) {
  try {
    $raw = (Invoke-WebRequest -UseBasicParsing -Method Post -Uri "https://overpass-api.de/api/interpreter" -Body @{data=$q} -TimeoutSec 300 -UserAgent "breathes-bkk-datamap/1.0 (one-time extract for a non-commercial data-art map)" -Headers @{Accept="application/json"}).Content
    break
  } catch { Write-Host "failed ($try): $($_.Exception.Message) · waiting 30 s"; Start-Sleep 30 }
} }
if (-not $raw) { throw "Overpass failed" }
[IO.File]::WriteAllText($cache, $raw)
Write-Host ("downloaded {0:N1} MB" -f ($raw.Length/1MB))
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue
$data = $js.DeserializeObject($raw)

$S = 100000.0
# ตัดจุดที่ห่างจากจุดที่เก็บล่าสุดไม่ถึง ~ $minM เมตร (ถนนยังโค้งตามจริง แต่ไฟล์เล็กลงมาก)
function Encode($geom, $minM) {
  $lim = $minM / 111000.0
  $out = New-Object System.Collections.Generic.List[int]
  $px = $null; $py = $null; $lx = 0; $ly = 0; $n = $geom.Count
  for ($i = 0; $i -lt $n; $i++) {
    $g = $geom[$i]; $lon = [double]$g["lon"]; $lat = [double]$g["lat"]
    if ($i -gt 0 -and $i -lt $n - 1 -and [math]::Abs($lon - $px) -lt $lim -and [math]::Abs($lat - $py) -lt $lim) { continue }
    $x = [int][math]::Round($lon * $S); $y = [int][math]::Round($lat * $S)
    if ($out.Count -eq 0) { $out.Add($x); $out.Add($y) } else { $out.Add($x - $lx); $out.Add($y - $ly) }
    $lx = $x; $ly = $y; $px = $lon; $py = $lat
  }
  return ,$out.ToArray()
}

$roads = @{ m = New-Object System.Collections.ArrayList; p = New-Object System.Collections.ArrayList; s = New-Object System.Collections.ArrayList; t = New-Object System.Collections.ArrayList }
$rivers = New-Object System.Collections.ArrayList; $canals = New-Object System.Collections.ArrayList; $rail = New-Object System.Collections.ArrayList
$cnt = 0
foreach ($el in $data["elements"]) {
  if ($el["type"] -ne "way" -or -not $el["geometry"]) { continue }
  $tg = $el["tags"]; $geom = $el["geometry"]
  if ($geom.Count -lt 2) { continue }
  $cnt++
  if ($tg.ContainsKey("highway")) {
    $h = $tg["highway"]
    $cls = if ($h -eq "motorway" -or $h -eq "trunk") { "m" } elseif ($h -eq "primary") { "p" } elseif ($h -eq "secondary") { "s" } else { "t" }
    [void]$roads[$cls].Add((Encode $geom 20))
  } elseif ($tg.ContainsKey("waterway")) {
    # แม่น้ำใหญ่จริงเท่านั้น (เจ้าพระยา ท่าจีน บางปะกง) ที่เหลือที่ติดป้าย river เป็นลำน้ำเล็ก นับเป็นคลอง
    $nm = "" + $tg["name"] + " " + $tg["name:en"] + " " + $tg["name:th"]
    if ($tg["waterway"] -eq "river" -and $nm -match "เจ้าพระยา|Chao Phraya|ท่าจีน|Tha Chin|บางปะกง|Bang Pakong") { [void]$rivers.Add((Encode $geom 15)) } else { [void]$canals.Add((Encode $geom 25)) }
  } elseif ($tg.ContainsKey("railway")) {
    [void]$rail.Add((Encode $geom 25))
  }
}
function Arr($list) { $sb = New-Object System.Text.StringBuilder; [void]$sb.Append("["); $first = $true; foreach ($a in $list) { if (-not $first) { [void]$sb.Append(",") }; $first = $false; [void]$sb.Append("[" + ([string]::Join(",", $a)) + "]") }; [void]$sb.Append("]"); return $sb.ToString() }
$src = "OpenStreetMap contributors (ODbL), Overpass API, " + (Get-Date -Format "yyyy-MM-dd")
$json = '{"s":100000,"src":"' + $src + '","roads":{"m":' + (Arr $roads.m) + ',"p":' + (Arr $roads.p) + ',"s":' + (Arr $roads.s) + ',"t":' + (Arr $roads.t) + '},"rivers":' + (Arr $rivers) + ',"canals":' + (Arr $canals) + ',"rail":' + (Arr $rail) + '}'
[IO.File]::WriteAllText((Resolve-Path (Split-Path $Out)).Path + "\" + (Split-Path $Out -Leaf), $json, (New-Object Text.UTF8Encoding $false))
Write-Host ("ways {0} -> roads m{1} p{2} s{3} t{4} · rivers {5} · canals {6} · rail {7} · file {8:N0} KB" -f $cnt, $roads.m.Count, $roads.p.Count, $roads.s.Count, $roads.t.Count, $rivers.Count, $canals.Count, $rail.Count, ($json.Length/1KB))
