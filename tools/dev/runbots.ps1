param([string]$Mode = "--autoplay", [int[]]$Seeds = @(1, 2, 3), [int]$MaxStage = 8, [int]$Timeout = 400, [string]$Proj = "")
# Laesst Bots komplette Fahrten spielen (headless, schnell). Zeigt Ende, mittlere Etappe und Fehlerzeilen.
if ($Proj -eq "") { $Proj = Split-Path (Split-Path $PSScriptRoot) }
$g = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$stages = @(); $errLines = 0; $ended = 0; $timeouts = 0
foreach ($sd in $Seeds) {
  $id = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $o = Join-Path $env:TEMP "bot_out_$id.txt"; $e = Join-Path $env:TEMP "bot_err_$id.txt"
  $a = @("--headless", "--path", $Proj, "--", $Mode, "--log", "--timescale=25", "--seed=$sd", "--maxstage=$MaxStage", "--nosave")
  $p = Start-Process -FilePath $g -ArgumentList $a -RedirectStandardOutput $o -RedirectStandardError $e -PassThru -NoNewWindow
  if (-not $p.WaitForExit($Timeout * 1000)) { try { $p.Kill() } catch {}; $timeouts++; "Seed $sd : TIMEOUT" }
  $out = Get-Content $o -Encoding UTF8
  $end = $out | Where-Object { $_ -match "^ENDE" } | Select-Object -First 1
  if ($end) { $ended++; if ($end -match "Etappe (\d+)") { $stages += [int]$Matches[1] } }
  $errLines += ((Get-Content $e -Encoding UTF8 | Where-Object { $_ -match "ERROR|SCRIPT" }) | Measure-Object).Count
  "Seed {0}: {1}" -f $sd, $end
  Remove-Item $o, $e -ErrorAction SilentlyContinue
}
$mean = if ($stages.Count) { ($stages | Measure-Object -Average).Average } else { 0 }
"{0}: beendet {1}/{2}, mittlere Etappe {3:N1}, Fehlerzeilen {4}, Timeouts {5}" -f $Mode, $ended, $Seeds.Count, $mean, $errLines, $timeouts
