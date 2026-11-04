param([string]$Out, [double]$Sec = 3, [string]$Flags = "", [int]$Timeout = 120, [string]$Proj = "")
# Screenshot ohne sichtbares Fenster und ohne Ton (--no-window), Bild in 2881x1921 (Spielfeld 480x320, Faktor 6).
# Beispiel: tools\dev\shot.ps1 -Out C:\temp\a.png -Sec 3 -Flags "--shotfx --hovermouse=1,1"
# -Sec ist die Spielzeit (Waves.time) bis zum Bild. Typische Flags: --shotfight, --shotfight2, --shotfight3, --shotfx, --shotfx2,
# --shotfx3, --shotkraken, --shotkraken2, --shotheroic, --shotsnap, --shotloadout, --hovermouse=x,y (Tooltips aus: 1,1).
if ($Proj -eq "") { $Proj = Split-Path (Split-Path $PSScriptRoot) }
$g = if ($env:GODOT) { $env:GODOT } else { "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" }  # Umgebungsvariable GODOT überschreibt den winget-Pfad
$id = [guid]::NewGuid().ToString("N").Substring(0, 8)
$o = Join-Path $env:TEMP "shot_out_$id.txt"; $e = Join-Path $env:TEMP "shot_err_$id.txt"
$a = @("--no-window", "--resolution", "3120x2080", "--path", $Proj, "--", "--shot=$Out@$Sec", "--nohelp", "--nosave") + @($Flags -split ' ' | Where-Object { $_ -ne "" })
$p = Start-Process -FilePath $g -ArgumentList $a -RedirectStandardOutput $o -RedirectStandardError $e -PassThru -NoNewWindow
if (-not $p.WaitForExit($Timeout * 1000)) { try { $p.Kill() } catch {}; "TIMEOUT" }
Get-Content $o -Encoding UTF8 | Where-Object { $_ -match "Screenshot" } | Select-Object -Last 2
$errs = Get-Content $e -Encoding UTF8 | Where-Object { $_ -match "ERROR|SCRIPT|WARNING: .*gd" }
if ($errs) { "--- Fehler:"; $errs | Select-Object -First 15 }
Remove-Item $o, $e -ErrorAction SilentlyContinue
