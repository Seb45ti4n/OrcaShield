param(
    [string]$Exe = '',
    [int]$Sekunden = 60
)
if (-not $Exe) {
    $art = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $Exe = Join-Path (Split-Path -Parent $PSScriptRoot) "App\Ausgabe\$art\OrcaShield.exe"
}
if (-not (Test-Path -LiteralPath $Exe)) { Write-Host "EXE nicht gefunden: $Exe" -ForegroundColor Red; exit 2 }

$webview = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application" -Directory -ErrorAction SilentlyContinue |
           Where-Object Name -match '^\d' | Sort-Object { [version]$_.Name } | Select-Object -Last 1
Write-Host "Prüfe $Exe ($Sekunden s), WebView2 $($webview.Name)" -ForegroundColor Cyan

Get-Process OrcaShield -ErrorAction SilentlyContinue | Stop-Process -Force
$p = Start-Process -FilePath $Exe -PassThru
$gesehen = [ordered]@{}
$ende = (Get-Date).AddSeconds($Sekunden)
while ((Get-Date) -lt $ende) {
    $kinder = @(Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $p.Id })
    $enkel = @(); foreach ($k in $kinder) { $enkel += @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($k.ProcessId)") }
    $ids = @($p.Id) + @($kinder.ProcessId) + @($enkel.ProcessId) | Where-Object { $_ }
    foreach ($c in @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $ids -contains $_.OwningProcess -and $_.RemoteAddress -notin @('0.0.0.0', '::', '127.0.0.1', '::1') })) {
        $n = (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        $k = "TCP $($c.RemoteAddress):$($c.RemotePort) ($n, pid $($c.OwningProcess))"
        if (-not $gesehen.Contains($k)) { $gesehen[$k] = (Get-Date -Format 'HH:mm:ss') }
    }
    Start-Sleep -Milliseconds 500
}
$p | Stop-Process -Force -ErrorAction SilentlyContinue
if ($gesehen.Count -eq 0) {
    Write-Host "Keine Netzverbindungen in $Sekunden s." -ForegroundColor Green
    exit 0
}
Write-Host "$($gesehen.Count) Verbindung(en) gesehen:" -ForegroundColor Red
$gesehen.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Value)  $($_.Key)" }
exit 1
