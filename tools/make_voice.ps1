# Nimmt die Rohstimmen für den Automaten auf (Windows-Sprachausgabe, Ergebnis: tools/voice/*.wav).
# make_sfx.py verwandelt sie dann in den Schrei "Es lebt!" (tiefer, verzerrt, mit Donner).
# Aufruf: powershell -File tools/make_voice.ps1
Add-Type -AssemblyName System.Speech
$dir = Join-Path $PSScriptRoot "voice"
New-Item -ItemType Directory -Force $dir | Out-Null

function Say($voice, $text, $file, $rate) {
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $s.SelectVoice($voice)
    $s.Rate = $rate
    $s.Volume = 100
    $s.SetOutputToWaveFile((Join-Path $dir $file))
    $s.Speak($text)
    $s.Dispose()
}

Say "Microsoft Hedda Desktop" "Es lebt!" "es_lebt.wav" -3
Say "Microsoft Hedda Desktop" "Es lebt! Es lebt!" "es_lebt2.wav" -2
Say "Microsoft Zira Desktop" "It's alive!" "its_alive.wav" -3
Say "Microsoft Zira Desktop" "It's alive! It's alive!" "its_alive2.wav" -3
Write-Output "Stimmen geschrieben nach $dir"
