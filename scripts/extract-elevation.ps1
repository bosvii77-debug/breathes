# ดึงความสูงพื้นที่เป็นกริดทุก 0.01° (~1.1 กม.) ครอบกรุงเทพ แล้วบันทึกเป็น data/bkk-elevation.json
# ที่มา: Open-Meteo Elevation API (Copernicus DEM GLO-90, 90 ม.)
# หมายเหตุ: Copernicus DEM เป็นแบบจำลองพื้นผิว (DSM) รวมความสูงตึกและต้นไม้ ค่าในเมืองจึงสูงกว่าพื้นดินจริงได้
# วิธีใช้: powershell -File scripts/extract-elevation.ps1
$root = Split-Path $PSScriptRoot -Parent
$lo1 = 100.32; $lo2 = 100.95; $la1 = 13.48; $la2 = 13.97; $step = 0.01
$lons = @(); for ($x = $lo1; $x -le $lo2 + 1e-9; $x += $step) { $lons += [math]::Round($x, 3) }
$lats = @(); for ($y = $la2; $y -ge $la1 - 1e-9; $y -= $step) { $lats += [math]::Round($y, 3) }   # แถวแรก = เหนือสุด
$pts = @(); foreach ($la in $lats) { foreach ($lo in $lons) { $pts += ,@($la, $lo) } }
$elev = New-Object double[] $pts.Count
for ($i = 0; $i -lt $pts.Count; $i += 100) {
  $chunk = $pts[$i..([math]::Min($i + 99, $pts.Count - 1))]
  $q = "latitude=" + (($chunk | ForEach-Object { $_[0] }) -join ",") + "&longitude=" + (($chunk | ForEach-Object { $_[1] }) -join ",")
  # API จำกัดจำนวนครั้งต่อนาที ถ้าโดนจำกัดให้รอ 65 วินาทีแล้วลองใหม่ (สูงสุด 10 ครั้ง)
  $r = $null
  for ($try = 0; $try -lt 10 -and -not $r; $try++) {
    try { $r = Invoke-RestMethod "https://api.open-meteo.com/v1/elevation?$q" -ErrorAction Stop }
    catch { Write-Output "rate limited at $i, waiting..."; Start-Sleep -Seconds 65 }
  }
  if (-not $r) { throw "failed at chunk $i" }
  for ($k = 0; $k -lt $r.elevation.Count; $k++) { $elev[$i + $k] = [double]$r.elevation[$k] }
  Start-Sleep -Seconds 4
}
$out = [ordered]@{
  source = "Open-Meteo Elevation API, Copernicus DEM GLO-90 (DSM: includes buildings/trees)"
  lo1 = $lo1; la2 = $la2; step = $step; cols = $lons.Count; rows = $lats.Count
  elev = @($elev | ForEach-Object { [math]::Round($_, 1) })
}
New-Item -ItemType Directory -Force (Join-Path $root "data") | Out-Null
$path = Join-Path $root "data\bkk-elevation.json"
[IO.File]::WriteAllText($path, ($out | ConvertTo-Json -Depth 5 -Compress), (New-Object Text.UTF8Encoding $false))
$s = $elev | Measure-Object -Minimum -Maximum -Average
Write-Output ("wrote {0}x{1} grid -> {2} | min {3} max {4} avg {5:N2}" -f $lons.Count, $lats.Count, $path, $s.Minimum, $s.Maximum, $s.Average)
