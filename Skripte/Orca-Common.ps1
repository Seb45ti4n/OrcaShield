
$Global:OrcaVersion = '1.1.0 Public Beta'
$Global:OrcaProdukt = $Global:OrcaVersion

$Global:OrcaSkripte = Split-Path -Parent $PSCommandPath
$Global:OrcaRoot    = Split-Path -Parent $Global:OrcaSkripte

$Global:OrcaDaten = $Global:OrcaRoot
$orcaDatenHinweis = Join-Path $Global:OrcaRoot 'orca-datenordner.txt'
if ($Global:OrcaDatenVorgabe) {
    $Global:OrcaDaten = $Global:OrcaDatenVorgabe
} elseif (Test-Path -LiteralPath $orcaDatenHinweis) {
    $orcaDatenZeile = Get-Content -LiteralPath $orcaDatenHinweis -TotalCount 1 -ErrorAction SilentlyContinue
    if ($orcaDatenZeile -and $orcaDatenZeile.Trim()) {
        $Global:OrcaDaten = [Environment]::ExpandEnvironmentVariables($orcaDatenZeile.Trim())
    }
}
$Global:OrcaLogs    = Join-Path $Global:OrcaDaten 'Logs'
$Global:OrcaBackup  = Join-Path $Global:OrcaDaten 'Backup'
$Global:OrcaState   = Join-Path $Global:OrcaDaten 'orca-state.json'
$Global:OrcaBaseline = Join-Path $Global:OrcaDaten 'orca-baseline.json'
# Ordner, deren Schreibrechte OrcaShield prüft und sperrt
$Global:OrcaGeschuetzt = @(@($Global:OrcaRoot, $Global:OrcaDaten) | Select-Object -Unique)

$Global:OrcaMonate = @(
    'Januar','Februar','Maerz','April','Mai','Juni',
    'Juli','August','September','Oktober','November','Dezember'
)

# --------------------------------------------------------------
#  LOGGING
#  Struktur:  <Wurzel>\Logs\<Jahr>\<Monat>.txt
# --------------------------------------------------------------
function Write-OrcaLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','OK','WARN','FEHLER','SKIP')][string]$Level = 'INFO',
        [string]$Source = 'ALLGEMEIN'
    )

    try {
        $now       = Get-Date
        $jahrPfad  = Join-Path $Global:OrcaLogs $now.Year
        if (-not (Test-Path $jahrPfad)) { New-Item -Path $jahrPfad -ItemType Directory -Force -ErrorAction Stop | Out-Null }

        $monatName = $Global:OrcaMonate[$now.Month - 1]
        $logDatei  = Join-Path $jahrPfad "$monatName.txt"

        if (-not (Test-Path $logDatei)) {
            $kopf = @"
================================================================
 OrcaShield Protokoll - $monatName $($now.Year)
 Automatisch erzeugt. Jeder Eintrag: Datum | Uhrzeit | Quelle | Status | Aktion
================================================================

"@
            Set-Content -Path $logDatei -Value $kopf -Encoding UTF8 -ErrorAction Stop
        }

        $zeile = '{0} | {1} | {2,-12} | {3,-6} | {4}' -f `
                 $now.ToString('dd.MM.yyyy'), $now.ToString('HH:mm:ss'), $Source, $Level, $Message
        Add-Content -Path $logDatei -Value $zeile -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Logging darf niemals das Hauptskript zum Absturz bringen
        Write-Host "  [!] Protokoll konnte nicht geschrieben werden: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

# --------------------------------------------------------------
#  AUSGABE-HELFER
# --------------------------------------------------------------
function Write-OrcaHead {
    param([string]$Text)
    Write-Host ''
    Write-Host ('  ' + ('=' * 62)) -ForegroundColor DarkCyan
    Write-Host ("   $Text") -ForegroundColor Cyan
    Write-Host ('  ' + ('=' * 62)) -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-OrcaInfo  { param([string]$T) Write-Host "  $T" -ForegroundColor Gray }
function Write-OrcaOk    { param([string]$T) Write-Host "  [OK]   $T" -ForegroundColor Green }
function Write-OrcaWarn  { param([string]$T) Write-Host "  [WARN] $T" -ForegroundColor Yellow }
function Write-OrcaErr   { param([string]$T) Write-Host "  [FEHL] $T" -ForegroundColor Red }
function Write-OrcaSkip  { param([string]$T) Write-Host "  [--]   $T" -ForegroundColor DarkGray }

# --------------------------------------------------------------
#  ROTE WARNUNG
#  Wird VOR jeder Ja-Nein-Frage ausgegeben, deren Einstellung
#  einen sichtbaren Schalter in den Windows-Einstellungen sperrt.
# --------------------------------------------------------------
function Write-OrcaAchtung {
    param([string[]]$Zeilen)
    Write-Host ''
    Write-Host ('  ' + ('!' * 62)) -ForegroundColor Red
    Write-Host '  ACHTUNG' -ForegroundColor Red
    foreach ($z in $Zeilen) {
        Write-Host "  $z" -ForegroundColor Red
    }
    Write-Host ('  ' + ('!' * 62)) -ForegroundColor Red
    Write-Host ''
}

function Write-OrcaBalken {
    param(
        [int]$Aktuell,
        [int]$Gesamt,
        [string]$Text = '',
        [int]$Breite = 40
    )
    if ($Gesamt -le 0) { return }
    $anteil = [Math]::Min(1.0, $Aktuell / $Gesamt)
    $voll   = [int]($anteil * $Breite)
    $leer   = $Breite - $voll
    $balken = ('#' * $voll) + ('.' * $leer)
    $proz   = [int]($anteil * 100)
    Write-Host ("`r  [$balken] $proz%  $Text".PadRight(100)) -NoNewline -ForegroundColor DarkCyan
    if ($Aktuell -ge $Gesamt) { Write-Host '' }
}

if ($null -eq $Global:OrcaStill) { $Global:OrcaStill = $false }

function Initialize-OrcaKonsole {
    param([string]$Titel = 'OrcaShield')
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    if ($Global:OrcaStill) { return }
    try { $Host.UI.RawUI.WindowTitle = $Titel } catch { }
    try {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        $Host.UI.RawUI.ForegroundColor = 'Gray'
    } catch { }
    try { Clear-Host } catch { }
}

function Get-OrcaWalZeilen {
    param([ValidateSet('Sprung','Kompakt','Schwimmend')][string]$Form = 'Sprung')
    switch ($Form) {
        'Sprung' { return @(
            '                                    ▄▄▄████▄▄'
            '                       ▄█▄      ▄▄████████████▄'
            '                      ████▄  ▄██████████░░░████▌'
            '                     ▐█████▄███████████░░░░░████'
            '                      ▀███████████████████████▀▀'
            '                    ▄▄████████████░░░░░░░░▀▀'
            '           ▄▄▄▄▄█████████████░░░░░░░▀▀'
            '      ▄██▄▄████████████░░░░░░▀▀'
            '     ▐███████████▀▀▀▀▀'
            '      ▀█▀   ▀▀'
            '  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        ) }
        'Kompakt' { return @(
            '              ▄▄'
            '             ███▌'
            '   ▄      ▄▄██████▄▄▄▄'
            '   ▀██▄▄████████████░░██▄'
            '     ███████████████████▙'
            '   ▄██▀▀███▄▄░░░░░░░░████▀'
            '   ▀▀     ▀▀▀▀░░░░░░▀▀▀'
        ) }
        default { return @(
            '                                  ▄▄'
            '                                ▄███'
            '                              ▄█████'
            '                             ▟██████▌'
            '  ▄▄                 ▄▄▄▄▄▄▄███████████▄▄▄▄▄▄'
            '   ▀██▄▄       ▄▄▄████████████████████████████████▄▄▄'
            '     ▀████▄▄▄█████████████████████████████████WWWWWW████▄▄'
            '       ▀████████████████████████████████████WWWWWWWWW███████▄'
            '       ▄██████▀▀█████████████████████████████████████████████▄'
            '     ▄███▀▀       ▀▀███████████▄▄DDDDDDDDDDDDDDDDDDDDD██████████▌'
            '    ▀▀▀               ▀▀▀WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW▀▀▀▀'
            '                              ▀UUUUUUUUUUUUUUUUUUUUUUUUU▀'
        ) }
    }
}
# --------------------------------------------------------------
#  ZEICHENWEISE AUSGABE
#  Jedes Zeichen einzeln, als tippe jemand live. Leerzeichen
#  kosten keine Zeit. Start-Sleep ist unter Windows nur auf rund
#  15 Millisekunden genau - deshalb wird nicht pro Zeichen
#  gewartet, sondern gegen eine Uhr: geschlafen wird nur, wenn
#  die Ausgabe der Uhr voraus ist. Eine Taste überspringt.
# --------------------------------------------------------------
$script:OrcaTippAbbruch = $false

function Test-OrcaTaste {
    try {
        if ($Host.UI.RawUI.KeyAvailable) {
            [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return $true
        }
    } catch { }
    return $false
}

function Clear-OrcaTastenpuffer {
    try { while ($Host.UI.RawUI.KeyAvailable) { [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,IncludeKeyUp') } } catch { }
}

function Write-OrcaTipp {
    param(
        [string]$Text = '',
        [System.ConsoleColor]$Farbe = [System.ConsoleColor]::Gray,
        [int]$ZeichenProSekunde = 400,
        [switch]$OhneUmbruch
    )
    if ($Global:OrcaStill -or $script:OrcaTippAbbruch -or $Text.Length -eq 0) {
        Write-Host $Text -ForegroundColor $Farbe -NoNewline:$OhneUmbruch
        return
    }
    $uhr = [System.Diagnostics.Stopwatch]::StartNew()
    $n = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        Write-Host $c -ForegroundColor $Farbe -NoNewline
        if ($c -eq ' ') { continue }
        $n++
        $voraus = ($n * 1000.0 / $ZeichenProSekunde) - $uhr.Elapsed.TotalMilliseconds
        if ($voraus -ge 15) { Start-Sleep -Milliseconds ([int]$voraus) }
        if (Test-OrcaTaste) { $script:OrcaTippAbbruch = $true }
        if ($script:OrcaTippAbbruch) {
            # Den Rest der Zeile auf einmal
            if ($i + 1 -lt $Text.Length) { Write-Host $Text.Substring($i + 1) -ForegroundColor $Farbe -NoNewline }
            break
        }
    }
    if (-not $OhneUmbruch) { Write-Host '' }
}

function Write-OrcaWal {
    param(
        [ValidateSet('Sprung','Kompakt','Schwimmend')][string]$Form = 'Sprung',
        [System.ConsoleColor]$Koerper = [System.ConsoleColor]::Cyan,
        [int]$ZeichenProSekunde = 900,
        [string]$Einzug = '  '
    )
    $uhr = [System.Diagnostics.Stopwatch]::StartNew()
    $n = 0
    foreach ($zeile in (Get-OrcaWalZeilen -Form $Form)) {
        Write-Host $Einzug -NoNewline
        foreach ($c in $zeile.ToCharArray()) {
            switch -CaseSensitive ($c) {
                'W'     { Write-Host '█' -ForegroundColor White -NoNewline }
                '░'     { Write-Host '█' -ForegroundColor White -NoNewline }
                '~'     { Write-Host '~' -ForegroundColor DarkBlue -NoNewline }
                'D'     { Write-Host '▄' -ForegroundColor White -BackgroundColor $Koerper -NoNewline }
                'U'     { Write-Host '▀' -ForegroundColor White -BackgroundColor $Koerper -NoNewline }
                ' '     { Write-Host ' ' -NoNewline }
                default { Write-Host $c -ForegroundColor $Koerper -NoNewline }
            }
            if ($c -eq ' ' -or $Global:OrcaStill -or $script:OrcaTippAbbruch) { continue }
            $n++
            $voraus = ($n * 1000.0 / $ZeichenProSekunde) - $uhr.Elapsed.TotalMilliseconds
            if ($voraus -ge 15) { Start-Sleep -Milliseconds ([int]$voraus) }
            if (Test-OrcaTaste) { $script:OrcaTippAbbruch = $true }
        }
        Write-Host ''
    }
}

function Write-OrcaTitel {
    param([switch]$Schnell)
    Initialize-OrcaKonsole -Titel "OrcaShield $($Global:OrcaVersion)"
    $script:OrcaTippAbbruch = [bool]$Schnell
    Clear-OrcaTastenpuffer
    Write-Host ''
    Write-OrcaWal
    Write-Host ''
    Write-OrcaTipp -Text "   O R C A S H I E L D   $($Global:OrcaVersion)" -Farbe White
    Write-OrcaTipp -Text '   Datenschutz und Härtung für Windows 11' -Farbe DarkCyan
    Write-Host ''
    $script:OrcaTippAbbruch = $false
    Clear-OrcaTastenpuffer
}

function Wait-OrcaTaste {
    param([string]$Text = 'Taste drücken zum Schließen')
    if ($Global:OrcaStill) { return }
    Write-Host ''
    Write-Host "  $Text" -ForegroundColor DarkGray
    Clear-OrcaTastenpuffer
    try { [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep -Seconds 30 }
}

function Wait-OrcaCountdown {
    param([int]$Sekunden = 5)
    if ($Global:OrcaStill) { return }
    Clear-OrcaTastenpuffer
    for ($i = $Sekunden; $i -ge 1; $i--) {
        Write-Host ("`r  schließe in $i ·  (Taste hält an)".PadRight(50)) -ForegroundColor DarkGray -NoNewline
        $ende = (Get-Date).AddSeconds(1)
        while ((Get-Date) -lt $ende) {
            if (Test-OrcaTaste) {
                Write-Host ("`r".PadRight(50)) -NoNewline
                Write-Host "`r" -NoNewline
                Wait-OrcaTaste -Text 'angehalten - Taste drücken zum Schließen'
                return
            }
            Start-Sleep -Milliseconds 50
        }
    }
    Write-Host ''
}

# --------------------------------------------------------------
#  EINGABE-HELFER
#  Vor jeder Abfrage wird der Tastaturpuffer geleert. Tasten, die
#  während einer Ausgabe gedrückt wurden, landeten sonst in der
#  nächsten Abfrage - ein Enter zu viel beantwortete sie mit der
#  Vorgabe, bevor man sie überhaupt gelesen hatte.
# --------------------------------------------------------------
function Read-OrcaJaNein {
    param(
        [string]$Frage,
        [string]$Zaehler = '',
        [switch]$StandardJa
    )
    while ($true) {
        if ($Zaehler) { Write-Host "  ($Zaehler) " -NoNewline -ForegroundColor DarkGray }
        Write-Host "$Frage " -NoNewline -ForegroundColor White
        # [J/N], beide groß. Die Vorgabe ist farbig hervorgehoben
        # und wird zusätzlich ausgeschrieben.
        $jFarbe = if ($StandardJa) { 'Cyan' } else { 'Gray' }
        $nFarbe = if ($StandardJa) { 'Gray' } else { 'Cyan' }
        Write-Host '[' -NoNewline -ForegroundColor DarkGray
        Write-Host 'J' -NoNewline -ForegroundColor $jFarbe
        Write-Host '/' -NoNewline -ForegroundColor DarkGray
        Write-Host 'N' -NoNewline -ForegroundColor $nFarbe
        Write-Host ']' -NoNewline -ForegroundColor DarkGray
        $vorgabe = if ($StandardJa) { 'Ja' } else { 'Nein' }
        Write-Host " (Enter = $vorgabe) " -NoNewline -ForegroundColor DarkGray
        Clear-OrcaTastenpuffer
        $a = Read-Host
        if ([string]::IsNullOrWhiteSpace($a)) { return [bool]$StandardJa }
        switch ($a.Trim().ToLower()) {
            'j'    { return $true }
            'ja'   { return $true }
            'y'    { return $true }
            'yes'  { return $true }
            'n'    { return $false }
            'nein' { return $false }
            'no'   { return $false }
            default { Write-OrcaWarn 'Bitte J oder N eingeben.' }
        }
    }
}

function Read-OrcaAuswahl {
    param(
        [string]$Frage,
        [string[]]$Optionen
    )
    while ($true) {
        Write-Host ''
        Write-Host "  $Frage" -ForegroundColor White
        Write-Host ''
        for ($i = 0; $i -lt $Optionen.Count; $i++) {
            Write-Host '    ' -NoNewline
            Write-Host ('{0}' -f ($i + 1)) -NoNewline -ForegroundColor Cyan
            Write-Host ("  {0}" -f $Optionen[$i]) -ForegroundColor Gray
        }
        Write-Host ''
        Write-Host '  > ' -NoNewline -ForegroundColor Cyan
        Clear-OrcaTastenpuffer
        $a = Read-Host
        $n = 0
        if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $Optionen.Count) {
            return $n
        }
        Write-OrcaWarn "Bitte eine Zahl zwischen 1 und $($Optionen.Count) eingeben."
    }
}

# --------------------------------------------------------------
#  RECHTE / UMGEBUNG
# --------------------------------------------------------------
function Test-OrcaAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-OrcaAdmin {
    if (-not (Test-OrcaAdmin)) {
        Write-OrcaErr 'Dieses Skript benötigt Administratorrechte.'
        Write-OrcaInfo 'Bitte PowerShell als Administrator starten und erneut ausführen.'
        Write-OrcaLog -Level FEHLER -Source 'START' -Message 'Abbruch: keine Administratorrechte'
        Read-Host '  [Enter] zum Beenden'
        exit 1
    }
}

function Get-OrcaSchattenkopien {
    param([string]$Laufwerk = '')
    $alle = @(Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop)
    if (-not $Laufwerk) { return $alle }
    $vol = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='$Laufwerk'" -ErrorAction Stop | Select-Object -First 1
    if (-not $vol) { return @() }
    return @($alle | Where-Object { $_.VolumeName -eq $vol.DeviceID })
}

function Test-OrcaIstVerknuepfung {
    param([string]$Pfad)
    try { return (([IO.File]::GetAttributes($Pfad) -band [IO.FileAttributes]::ReparsePoint) -ne 0) } catch { return $true }
}

function Test-OrcaWegSicher {
    # $true, wenn $Pfad unterhalb von $Wurzel liegt und weder er noch ein
    # Ordner dazwischen (einschließlich $Wurzel) eine Verknüpfung ist.
    param([Parameter(Mandatory)][string]$Wurzel, [Parameter(Mandatory)][string]$Pfad)
    try {
        $w = [IO.Path]::GetFullPath($Wurzel).TrimEnd('\')
        $p = [IO.Path]::GetFullPath($Pfad).TrimEnd('\')
        if (-not $p.StartsWith($w + '\', [StringComparison]::OrdinalIgnoreCase) -and $p -ne $w) { return $false }
        $teil = $p
        while ($true) {
            if (Test-OrcaIstVerknuepfung $teil) { return $false }
            if ($teil.Length -le $w.Length) { break }
            $teil = [IO.Path]::GetDirectoryName($teil)
            if (-not $teil) { return $false }
        }
        return $true
    } catch { return $false }
}

function Initialize-OrcaHandleLoeschen {
    if ('OrcaShield.HandleLoeschen' -as [type]) { return }
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
namespace OrcaShield {
    public static class HandleLoeschen {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern uint GetFinalPathNameByHandleW(SafeFileHandle h, StringBuilder buf, uint len, uint flags);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GetFileInformationByHandleEx(SafeFileHandle h, int cls, out AttributTag info, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool SetFileInformationByHandle(SafeFileHandle h, int cls, ref uint info, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool SetFileInformationByHandle(SafeFileHandle h, int cls, ref byte info, uint size);
        [StructLayout(LayoutKind.Sequential)] struct AttributTag { public uint Attribute; public uint Tag; }

        // 0 = gelöscht, 1 = nicht vorhanden, 2 = übersprungen (Verknüpfung oder liegt woanders), 3 = Fehler
        public static int Loeschen(string pfad) {
            string voll = System.IO.Path.GetFullPath(pfad).TrimEnd('\\');
            string lang = voll.StartsWith(@"\\") ? voll : @"\\?\" + voll;
            // DELETE | FILE_READ_ATTRIBUTES; alle Freigaben; OPEN_EXISTING;
            // FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS (auch Ordner)
            using (var h = CreateFileW(lang, 0x00010000 | 0x80, 7, IntPtr.Zero, 3, 0x00200000 | 0x02000000, IntPtr.Zero)) {
                if (h.IsInvalid) {
                    int e = Marshal.GetLastWin32Error();
                    return (e == 2 || e == 3) ? 1 : 3;
                }
                AttributTag t;
                if (!GetFileInformationByHandleEx(h, 9, out t, 8)) return 3;      // FileAttributeTagInfo
                if ((t.Attribute & 0x400) != 0) return 2;                          // selbst eine Verknüpfung: liegen lassen
                var sb = new StringBuilder(32768);
                uint n = GetFinalPathNameByHandleW(h, sb, (uint)sb.Capacity, 0);
                if (n == 0 || n >= sb.Capacity) return 3;
                string echt = sb.ToString();
                if (echt.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) return 2;
                if (echt.StartsWith(@"\\?\")) echt = echt.Substring(4);
                if (!string.Equals(echt.TrimEnd('\\'), voll, StringComparison.OrdinalIgnoreCase)) return 2;
                // FileDispositionInfoEx: DELETE | POSIX_SEMANTICS | IGNORE_READONLY_ATTRIBUTE
                uint ex = 0x1 | 0x2 | 0x10;
                if (SetFileInformationByHandle(h, 21, ref ex, 4)) return 0;
                byte alt = 1;                                                      // FileDispositionInfo (älteres Windows)
                return SetFileInformationByHandle(h, 4, ref alt, 1) ? 0 : 3;
            }
        }
    }
}
'@
}

function Remove-OrcaEintragSicher {
    param([Parameter(Mandatory)][string]$Pfad)
    try { Initialize-OrcaHandleLoeschen; return [OrcaShield.HandleLoeschen]::Loeschen($Pfad) } catch { return 3 }
}

function Get-OrcaDateienSicher {
    # Dateien unterhalb von $Wurzel (optional rekursiv, mit Muster), ohne
    # Verknüpfungen zu folgen. Rückgabe: Liste voller Pfade.
    param([Parameter(Mandatory)][string]$Wurzel, [string]$Filter = '*', [switch]$Rekursiv)
    $aus = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $Wurzel -PathType Container) -or (Test-OrcaIstVerknuepfung $Wurzel)) { return ,$aus }
    $offen = New-Object System.Collections.Stack
    $offen.Push([IO.DirectoryInfo]$Wurzel)
    while ($offen.Count -gt 0) {
        $d = $offen.Pop()
        try {
            foreach ($f in $d.EnumerateFiles($Filter)) {
                if (($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { [void]$aus.Add($f.FullName) }
            }
            if ($Rekursiv) {
                foreach ($u in $d.EnumerateDirectories()) {
                    if (($u.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { $offen.Push($u) }
                }
            }
        } catch { }   # nicht lesbare Ordner überspringen (in Benutzung, keine Rechte)
    }
    return ,$aus
}

function Remove-OrcaPfadSicher {
    # Löscht eine Datei oder einen Ordner samt Inhalt unterhalb von $Wurzel,
    # ohne einer Verknüpfung zu folgen. Verknüpfungen bleiben liegen.
    # Rückgabe: $true, wenn der Eintrag danach weg ist.
    param([Parameter(Mandatory)][string]$Wurzel, [Parameter(Mandatory)][string]$Pfad)
    if (-not (Test-Path -LiteralPath $Pfad)) { return $true }
    if (-not (Test-OrcaWegSicher -Wurzel $Wurzel -Pfad $Pfad)) { return $false }
    if (Test-Path -LiteralPath $Pfad -PathType Container) {
        foreach ($f in (Get-OrcaDateienSicher -Wurzel $Pfad -Rekursiv)) {
            if (Test-OrcaWegSicher -Wurzel $Wurzel -Pfad $f) { [void](Remove-OrcaEintragSicher -Pfad $f) }
        }
        # Leere Ordner von unten nach oben; ein Ordner mit Verknüpfung darin bleibt (nicht leer)
        $ordner = New-Object System.Collections.ArrayList
        $offen = New-Object System.Collections.Stack; $offen.Push([IO.DirectoryInfo]$Pfad)
        while ($offen.Count -gt 0) {
            $d = $offen.Pop(); [void]$ordner.Add($d.FullName)
            try { foreach ($u in $d.EnumerateDirectories()) { if (($u.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { $offen.Push($u) } } } catch { }
        }
        foreach ($o in @($ordner | Sort-Object { $_.Length } -Descending)) {
            if ((Test-OrcaWegSicher -Wurzel $Wurzel -Pfad $o) -and @(Get-ChildItem -LiteralPath $o -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                [void](Remove-OrcaEintragSicher -Pfad $o)
            }
        }
    } else {
        [void](Remove-OrcaEintragSicher -Pfad $Pfad)
    }
    return -not (Test-Path -LiteralPath $Pfad)
}

function Remove-OrcaSchattenkopien {
    param([string]$Laufwerk = '')
    $vorher = @(Get-OrcaSchattenkopien -Laufwerk $Laufwerk)
    $grund = ''
    foreach ($k in $vorher) {
        try { Remove-CimInstance -InputObject $k -ErrorAction Stop }
        catch { $grund = $_.Exception.Message }
    }
    $nachher = if ($vorher.Count -gt 0) { @(Get-OrcaSchattenkopien -Laufwerk $Laufwerk).Count } else { 0 }
    return @{ Vorher = $vorher.Count; Nachher = $nachher; Grund = $grund }
}

function Invoke-OrcaProgramm {
    param(
        [Parameter(Mandatory)][string]$Datei,
        [string]$Argumente = ''
    )
    try {
        $aufruf = @{ FilePath = $Datei; Wait = $true; PassThru = $true; WindowStyle = 'Hidden'; ErrorAction = 'Stop' }
        if ($Argumente) { $aufruf['ArgumentList'] = $Argumente }
        $p = Start-Process @aufruf
        return [int]$p.ExitCode
    } catch {
        return -1
    }
}

$Global:OrcaSchreibrechte = [System.Security.AccessControl.FileSystemRights](
    'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership')

# Administratoren, SYSTEM, TrustedInstaller, Ersteller-Besitzer
$Global:OrcaErlaubteSchreiber = @(
    'S-1-5-32-544'
    'S-1-5-18'
    'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
    'S-1-3-0'
)

function Test-OrcaOrdnerRechte {
    param([string[]]$Pfad = $Global:OrcaGeschuetzt)
    if (@($Pfad).Count -gt 1) {
        $alle = @()
        foreach ($p in $Pfad) { $alle += @((Test-OrcaOrdnerRechte -Pfad $p).Befund) }
        $alle = @($alle | Where-Object { $_ } | Select-Object -Unique)
        return @{ Sicher = ($alle.Count -eq 0); Befund = $alle }
    }
    $Pfad = [string](@($Pfad)[0])
    $befund = @()
    try {
        $ziele = @(Get-Item -LiteralPath $Pfad -Force -ErrorAction Stop)
        $ziele += @(Get-ChildItem -LiteralPath $Pfad -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.PSIsContainer -or $_.Extension -in @('.ps1','.cmd','.json') })
        foreach ($z in $ziele) {
            $acl = Get-Acl -LiteralPath $z.FullName -ErrorAction Stop
            $besitzer = ''
            try { $besitzer = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value } catch { }
            if ($besitzer -notin @('S-1-5-32-544', 'S-1-5-18', 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')) {
                $rel = $z.FullName.Substring([Math]::Min($z.FullName.Length, $Pfad.Length)).TrimStart('\')
                if (-not $rel) { $rel = '(Programmordner)' }
                $befund += "$rel : Besitzer ist $($acl.Owner)"
            }
            foreach ($ace in $acl.Access) {
                if ($ace.AccessControlType -ne 'Allow') { continue }
                if (($ace.FileSystemRights -band $Global:OrcaSchreibrechte) -eq 0) { continue }
                $sid = ''
                try { $sid = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $sid = [string]$ace.IdentityReference }
                if ($sid -in $Global:OrcaErlaubteSchreiber) { continue }
                $rel = $z.FullName.Substring([Math]::Min($z.FullName.Length, $Pfad.Length)).TrimStart('\')
                if (-not $rel) { $rel = '(Programmordner)' }
                $befund += "$rel : $($ace.IdentityReference) darf schreiben"
            }
        }
    } catch {
        $befund += "Rechte nicht lesbar: $($_.Exception.Message)"
    }
    $befund = @($befund | Select-Object -Unique)
    return @{ Sicher = ($befund.Count -eq 0); Befund = $befund }
}

function Set-OrcaOrdnerRechte {
    param([string[]]$Pfad = $Global:OrcaGeschuetzt)
    if (@($Pfad).Count -gt 1) {
        $gruende = @()
        foreach ($p in $Pfad) { $r = Set-OrcaOrdnerRechte -Pfad $p; if (-not $r.Erfolg) { $gruende += "${p}: $($r.Grund)" } }
        return @{ Erfolg = ($gruende.Count -eq 0); Grund = ($gruende -join '; ') }
    }
    $Pfad = [string](@($Pfad)[0])
    # Kennungen statt Namen: "Administratoren" heißt auf einem
    # englischen System anders, die Kennung nicht.
    # Schritt 1: Vererbung von C:\ kappen, eigene Rechte setzen.
    $rc1 = Invoke-OrcaProgramm -Datei 'icacls.exe' `
            -Argumente "`"$Pfad`" /inheritance:r /grant:r *S-1-5-32-544:(OI)(CI)F *S-1-5-18:(OI)(CI)F *S-1-5-32-545:(OI)(CI)RX /C /Q"
    # Schritt 2: alles darunter auf die geerbten Rechte zurücksetzen.
    $rc2 = Invoke-OrcaProgramm -Datei 'icacls.exe' -Argumente "`"$Pfad\*`" /reset /T /C /Q"
    [void](Invoke-OrcaProgramm -Datei 'icacls.exe' -Argumente "`"$Pfad`" /setowner *S-1-5-32-544 /T /C /Q")
    $stand = Test-OrcaOrdnerRechte -Pfad $Pfad
    $grund = if ($stand.Sicher) { '' } else { "icacls meldete $rc1/$rc2; " + ($stand.Befund -join '; ') }
    return @{ Erfolg = $stand.Sicher; Grund = $grund }
}

# --------------------------------------------------------------
#  REGISTRY-HELFER
# --------------------------------------------------------------
function Test-OrcaRegSchluessel {
    param([string]$Pfad)
    try { return [bool](Test-Path -LiteralPath $Pfad) } catch { return $false }
}

function Get-OrcaRegWert {
    param([string]$Pfad, [string]$Name)
    try {
        if (-not (Test-Path -LiteralPath $Pfad)) { return $null }
        $p = Get-ItemProperty -LiteralPath $Pfad -Name $Name -ErrorAction Stop
        return $p.$Name
    } catch { return $null }
}

# --------------------------------------------------------------
#  WERT MIT DATENTYP LESEN
#  Ein Richtlinienwert mit falschem Datentyp wird von Windows
#  ignoriert. Wer nur den Inhalt vergleicht, hält ein REG_SZ "0"
#  für ein korrektes REG_DWORD 0 und korrigiert es nie.
#  Rückgabe: @{ SchluesselDa; WertDa; Wert; Typ }
# --------------------------------------------------------------
function Get-OrcaRegWertUndTyp {
    param([string]$Pfad, [string]$Name)

    $leer = @{ SchluesselDa = $false; WertDa = $false; Wert = $null; Typ = $null }
    try {
        if (-not (Test-Path -LiteralPath $Pfad)) { return $leer }
        $schluessel = Get-Item -LiteralPath $Pfad -ErrorAction Stop
        $namen = @($schluessel.GetValueNames())
        if ($namen -notcontains $Name) {
            return @{ SchluesselDa = $true; WertDa = $false; Wert = $null; Typ = $null }
        }
        return @{
            SchluesselDa = $true
            WertDa       = $true
            Wert         = $schluessel.GetValue($Name)
            Typ          = $schluessel.GetValueKind($Name).ToString()
        }
    } catch {
        return $leer
    }
}

function Set-OrcaRegWert {
    param(
        [string]$Pfad,
        [string]$Name,
        $Wert,
        [string]$Typ = 'DWord'
    )
    try {
        if (-not (Test-Path -LiteralPath $Pfad)) { New-Item -Path $Pfad -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -LiteralPath $Pfad -Name $Name -Value $Wert -PropertyType $Typ -Force -ErrorAction Stop | Out-Null
        return @{ Erfolg = $true; Grund = '' }
    } catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

function Remove-OrcaRegWert {
    param([string]$Pfad, [string]$Name)
    try {
        if (Test-Path -LiteralPath $Pfad) {
            $k = Get-Item -LiteralPath $Pfad -ErrorAction Stop
            if (@($k.GetValueNames()) -contains $Name) {
                Remove-ItemProperty -LiteralPath $Pfad -Name $Name -Force -ErrorAction Stop
            }
        }
        return @{ Erfolg = $true; Grund = '' }
    } catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

function Remove-OrcaRegSchluesselWennLeer {
    param([string]$Pfad)
    try {
        if (-not (Test-Path -LiteralPath $Pfad)) { return @{ Entfernt = $false; Grund = 'nicht vorhanden' } }
        $k = Get-Item -LiteralPath $Pfad -ErrorAction Stop
        if ($k.ValueCount -gt 0 -or $k.SubKeyCount -gt 0) { return @{ Entfernt = $false; Grund = 'nicht leer' } }
        Remove-Item -LiteralPath $Pfad -Force -ErrorAction Stop
        return @{ Entfernt = -not (Test-Path -LiteralPath $Pfad); Grund = '' }
    } catch {
        return @{ Entfernt = $false; Grund = $_.Exception.Message }
    }
}

# --------------------------------------------------------------
#  ALLE WERTE EINES SCHLÜSSELS AUF EINMAL LESEN
#  Ein einziger Registrierungszugriff statt eines pro Wert.
#  Rückgabe: @{ Da = <bool>; Werte = <Hashtabelle Name -> Wert> }
#  'Da' unterscheidet "Schlüssel fehlt" von "Schlüssel leer" -
#  ohne diese Unterscheidung legt der Wächter Schlüssel an,
#  die Windows nie hatte.
# --------------------------------------------------------------
function Get-OrcaRegSchluessel {
    param([string]$Pfad)
    $tabelle = @{}
    try {
        if (-not (Test-Path -LiteralPath $Pfad)) { return @{ Da = $false; Werte = $tabelle } }
        $p = Get-ItemProperty -LiteralPath $Pfad -ErrorAction Stop
        foreach ($e in $p.PSObject.Properties) {
            if ($e.Name -like 'PS*') { continue }
            $tabelle[$e.Name] = $e.Value
        }
        return @{ Da = $true; Werte = $tabelle }
    } catch {
        return @{ Da = $false; Werte = $tabelle }
    }
}

# ==============================================================
#  BENUTZERKONTEXT
#  Kernproblem: Der Wächter läuft beim Systemstart als SYSTEM.
#  Für einen SYSTEM-Prozess zeigt HKCU auf das Profil des
#  Systemkontos, NICHT auf das des angemeldeten Benutzers.
# ==============================================================
function Test-OrcaAlsSystem {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return ($id.User.Value -eq 'S-1-5-18')
    } catch { return $false }
}

function Get-OrcaEigeneSid {
    try { return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
    catch { return $null }
}

# --------------------------------------------------------------
#  ALLE ECHTEN BENUTZERPROFILE ERMITTELN
#  Liefert Kennung, Name und Profilpfad. Systemkonten
#  (S-1-5-18/19/20) und Dienstprofile werden ausgelassen.
# --------------------------------------------------------------
function Get-OrcaBenutzerProfile {
    $liste = @()
    $basis = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    try {
        foreach ($k in (Get-ChildItem -Path $basis -ErrorAction Stop)) {
            $sid = Split-Path $k.Name -Leaf

            # Nur echte Benutzerkonten: S-1-5-21-... mit mindestens vier Teilen
            if ($sid -notmatch '^S-1-5-21-\d+-\d+-\d+-\d+$') { continue }

            $pfad = (Get-ItemProperty -Path $k.PSPath -Name 'ProfileImagePath' -ErrorAction SilentlyContinue).ProfileImagePath
            if ([string]::IsNullOrWhiteSpace($pfad)) { continue }
            if (-not (Test-Path $pfad)) { continue }

            $name = Split-Path $pfad -Leaf
            $liste += [pscustomobject]@{
                Sid        = $sid
                Name       = $name
                Profilpfad = $pfad
                NtUserDat  = (Join-Path $pfad 'NTUSER.DAT')
                Geladen    = (Test-Path "Registry::HKEY_USERS\$sid")
            }
        }
    } catch {
        Write-OrcaLog -Level WARN -Source 'KONTEXT' `
            -Message "Benutzerprofile konnten nicht ermittelt werden. Grund: $($_.Exception.Message)"
    }
    return $liste
}

# --------------------------------------------------------------
#  REGISTRIERUNGSPFAD IN EINEN BENUTZERKONTEXT ÜBERSETZEN
#  'HKCU:\SOFTWARE\...'  ->  'Registry::HKEY_USERS\<SID>\SOFTWARE\...'
# --------------------------------------------------------------
function Resolve-OrcaRegPfad {
    param(
        [Parameter(Mandatory)][string]$Pfad,
        [string]$Sid = ''
    )
    if ([string]::IsNullOrWhiteSpace($Sid)) { return $Pfad }
    if ($Pfad -notmatch '^HKCU:\\') { return $Pfad }

    $rest = $Pfad -replace '^HKCU:\\', ''
    return "Registry::HKEY_USERS\$Sid\$rest"
}

# --------------------------------------------------------------
#  BENUTZERPROFIL VORÜBERGEHEND LADEN
#  Nur nötig, wenn ein SYSTEM-Prozess an das Profil eines
#  gerade nicht angemeldeten Benutzers muss.
# --------------------------------------------------------------
function Mount-OrcaBenutzerHive {
    param([Parameter(Mandatory)]$Profil)

    if (Test-Path "Registry::HKEY_USERS\$($Profil.Sid)") {
        return @{ Erfolg = $true; MussEntladen = $false; Grund = 'bereits geladen' }
    }
    if (-not (Test-Path $Profil.NtUserDat)) {
        return @{ Erfolg = $false; MussEntladen = $false; Grund = 'NTUSER.DAT nicht gefunden' }
    }

    $p = Start-Process -FilePath 'reg.exe' `
            -ArgumentList "load `"HKU\$($Profil.Sid)`" `"$($Profil.NtUserDat)`"" `
            -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) {
        return @{ Erfolg = $true; MussEntladen = $true; Grund = '' }
    }
    return @{ Erfolg = $false; MussEntladen = $false; Grund = "reg load meldete Rückgabewert $($p.ExitCode)" }
}

# --------------------------------------------------------------
#  BENUTZERPROFIL WIEDER AUSHÄNGEN
#  Mit Wiederholungen: Ein noch nicht freigegebener Verweis
#  lässt reg unload scheitern. Bleibt die Datei eingehängt,
#  kann sich der Benutzer unter Umständen nicht mehr regulär
#  anmelden - deshalb wird hier hartnäckig aufgeräumt und der
#  Fehlschlag notfalls deutlich protokolliert.
# --------------------------------------------------------------
function Dismount-OrcaBenutzerHive {
    param(
        [Parameter(Mandatory)]$Profil,
        [int]$Versuche = 5
    )
    for ($i = 1; $i -le $Versuche; $i++) {
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        $p = Start-Process -FilePath 'reg.exe' -ArgumentList "unload `"HKU\$($Profil.Sid)`"" `
                -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -eq 0) { return $true }
        if (-not (Test-Path "Registry::HKEY_USERS\$($Profil.Sid)")) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

# ==============================================================
#  WINDOWS-EDITION
# ==============================================================
function Get-OrcaWindowsEdition {
    if ($Global:OrcaEditionCache) { return $Global:OrcaEditionCache }

    $ergebnis = [pscustomobject]@{
        Name       = 'Unbekannt'
        Kanon      = 'Unbekannt'
        IstHome    = $false
        IstPro     = $false
        Build      = 0
        Anzeige    = 'Unbekannte Windows-Edition'
    }
    try {
        $cv = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $edition = (Get-ItemProperty -Path $cv -Name 'EditionID'      -ErrorAction SilentlyContinue).EditionID
        $produkt = (Get-ItemProperty -Path $cv -Name 'ProductName'    -ErrorAction SilentlyContinue).ProductName
        $build   = (Get-ItemProperty -Path $cv -Name 'CurrentBuildNumber' -ErrorAction SilentlyContinue).CurrentBuildNumber

        $ergebnis.Name    = if ($edition) { $edition } else { 'Unbekannt' }
        $ergebnis.Build   = if ($build) { [int]$build } else { 0 }
        $ergebnis.IstHome = ($edition -match '^Core')          # Core, CoreN, CoreSingleLanguage
        $ergebnis.IstPro  = ($edition -match '^(Professional|Enterprise|Education|ServerRdsh)')
        $ergebnis.Anzeige = if ($produkt) { $produkt } else { $edition }

        # Windows 11 trägt im Wert ProductName bis heute "Windows 10"
        # ein. Ab Build 22000 ist es Windows 11 - sonst steht im
        # Bericht eine Angabe, die niemandem weiterhilft.
        if ($ergebnis.Build -ge 22000 -and $ergebnis.Anzeige -match 'Windows 10') {
            $ergebnis.Anzeige = ($ergebnis.Anzeige -replace 'Windows 10', 'Windows 11')
        }

        # Kanonischer Name für die Editionsprüfung im Katalog.
        # Microsoft setzt einige Richtlinien nur auf bestimmten
        # Editionen um und ignoriert sie sonst stillschweigend.
        $ergebnis.Kanon = switch -Regex ($edition) {
            '^Core'                 { 'Home' ; break }
            '^Professional'         { 'Pro' ; break }
            '^Enterprise'           { 'Enterprise' ; break }
            '^Education'            { 'Education' ; break }
            '^IoTEnterprise'        { 'IoTEnterprise' ; break }
            '^ServerRdsh'           { 'Enterprise' ; break }
            default                 { 'Unbekannt' }
        }
    } catch { }

    $Global:OrcaEditionCache = $ergebnis
    return $ergebnis
}

# --------------------------------------------------------------
#  MANIPULATIONSSCHUTZ VON WINDOWS-SICHERHEIT
#  Ist er aktiv - und das ist er auf Windows 11 ab Werk -,
#  ignoriert Defender Änderungen an geschützten Einstellungen,
#  auch solche aus dem Richtlinienzweig. Der Registrywert stünde
#  dann korrekt da, ohne dass sich etwas ändert. Genau deshalb
#  wird er gelesen, bevor ein Defender-Punkt gesetzt wird.
#  Rückgabe: $true | $false | $null (nicht ermittelbar)
# --------------------------------------------------------------
function Get-OrcaManipulationsschutz {
    if ($null -ne $Global:OrcaTamperCache) { return $Global:OrcaTamperCache }
    $ergebnis = $null
    try {
        $st = Get-MpComputerStatus -ErrorAction Stop
        if ($null -ne $st -and $null -ne $st.IsTamperProtected) {
            $ergebnis = [bool]$st.IsTamperProtected
        }
    } catch { $ergebnis = $null }
    $Global:OrcaTamperCache = $ergebnis
    return $ergebnis
}

# --------------------------------------------------------------
#  IST DIESE EINSTELLUNG AUF DIESEM SYSTEM ÜBERHAUPT WIRKSAM?
#  Rückgabe: @{ Anwendbar=$bool; Grund=<string> }
#
#  Vier Prüfungen, alle mit demselben Zweck: lieber ehrlich
#  "wirkt hier nicht" melden als einen Wert setzen, den niemand
#  liest, und dafür Erfolg behaupten.
# --------------------------------------------------------------
function Test-OrcaAnwendbar {
    param(
        [Parameter(Mandatory)]$Setting,
        [string]$Sid = ''
    )

    # 1. Windows Home ignoriert mehrere Richtlinien vollständig
    if ($Setting.NurPro) {
        $ed = Get-OrcaWindowsEdition
        if ($ed.IstHome) {
            return @{ Anwendbar = $false
                      Grund = 'Diese Richtlinie wird von Windows Home ignoriert' }
        }
    }

    # 2. Manche Richtlinien setzt Microsoft nur auf bestimmten
    #    Editionen um - auf Pro stehen sie wirkungslos herum.
    if ($Setting.NurEdition -and @($Setting.NurEdition).Count -gt 0) {
        $ed = Get-OrcaWindowsEdition
        if ($ed.Kanon -notin @($Setting.NurEdition)) {
            return @{ Anwendbar = $false
                      Grund = "Microsoft setzt diese Richtlinie nur auf $(@($Setting.NurEdition) -join ', ') um - auf $($ed.Kanon) bleibt sie folgenlos" }
        }
    }

    # 3. Zu alte Windows-Version
    if ($Setting.MindestBuild -and $Setting.MindestBuild -gt 0) {
        $ed = Get-OrcaWindowsEdition
        if ($ed.Build -gt 0 -and $ed.Build -lt $Setting.MindestBuild) {
            return @{ Anwendbar = $false
                      Grund = "Erst ab Build $($Setting.MindestBuild) vorhanden (hier: $($ed.Build))" }
        }
    }

    # 4. Voraussetzung, ohne die der Punkt nicht wirken kann
    if ($Setting.Voraussetzung -eq 'KeinManipulationsschutz') {
        $tamper = Get-OrcaManipulationsschutz
        if ($tamper -eq $true) {
            return @{ Anwendbar = $false
                      Grund = 'Der Manipulationsschutz von Windows-Sicherheit ist aktiv und ignoriert Änderungen an dieser Defender-Einstellung. Zum Setzen müsste er zuvor in der Windows-Sicherheit abgeschaltet werden' }
        }
    }

    # 5. Der Schlüssel existiert auf diesem System gar nicht.
    #    Nur für Punkte, deren Schlüssel Windows selbst
    #    mitbringt, wenn es die Funktion überhaupt gibt.
    if ($Setting.NurWennVorhanden -and $Setting.Pfad) {
        $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid
        if (-not (Test-OrcaRegSchluessel -Pfad $pfad)) {
            return @{ Anwendbar = $false
                      Grund = 'Der zugehörige Registrierungsschlüssel existiert auf diesem System nicht - die Funktion gibt es hier nicht' }
        }
    }

    return @{ Anwendbar = $true; Grund = '' }
}

$Global:OrcaZustandSperre  = 'Global\OrcaShield.Zustand'
$Global:OrcaStateUnlesbar  = $false

function Invoke-OrcaMitSperre {
    # Führt $Aktion unter der benannten Sperre aus. Die Sperre ist
    # wiedereintrittsfähig (Set-OrcaStateFeld ruft Save-OrcaState
    # darin auf). Zugriff haben nur Administratoren und SYSTEM, weil
    # App/Wächter erhöht und die Bereinigung als SYSTEM laufen.
    param([Parameter(Mandatory)][scriptblock]$Aktion, [int]$Sekunden = 15)
    $orcaSperreM = $null; $orcaSperreHab = $false
    try {
        try {
            $orcaSperreSich = New-Object System.Security.AccessControl.MutexSecurity
            foreach ($orcaSperreSid in @('S-1-5-32-544', 'S-1-5-18')) {
                $orcaSperreSich.AddAccessRule((New-Object System.Security.AccessControl.MutexAccessRule(
                    (New-Object System.Security.Principal.SecurityIdentifier $orcaSperreSid),
                    [System.Security.AccessControl.MutexRights]::FullControl,
                    [System.Security.AccessControl.AccessControlType]::Allow)))
            }
            $orcaSperreNeu = $false
            $orcaSperreM = New-Object System.Threading.Mutex($false, $Global:OrcaZustandSperre, [ref]$orcaSperreNeu, $orcaSperreSich)
        } catch {
            $orcaSperreM = [System.Threading.Mutex]::OpenExisting($Global:OrcaZustandSperre)
        }
        try { $orcaSperreHab = $orcaSperreM.WaitOne([TimeSpan]::FromSeconds($Sekunden)) }
        catch [System.Threading.AbandonedMutexException] { $orcaSperreHab = $true }   # Vorbesitzer abgebrochen - Sperre gehört jetzt uns
        if (-not $orcaSperreHab) { throw "Zustandsdatei ist seit $Sekunden Sekunden von einem anderen Teil von OrcaShield gesperrt" }
        return (& $Aktion)
    } finally {
        if ($orcaSperreHab) { try { $orcaSperreM.ReleaseMutex() } catch { } }
        if ($orcaSperreM) { $orcaSperreM.Dispose() }
    }
}

function Move-OrcaDateiErsetzt {
    param([Parameter(Mandatory)][string]$Ziel)
    $neu = "$Ziel.neu"
    if (Test-Path -LiteralPath $Ziel) { [IO.File]::Replace($neu, $Ziel, "$Ziel.vorher") }
    else { [IO.File]::Move($neu, $Ziel) }
}

function Write-OrcaJsonDatei {
    # JSON in eine Nebendatei schreiben, dann austauschen.
    param([Parameter(Mandatory)][string]$Ziel, [Parameter(Mandatory)]$Inhalt)
    $Inhalt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$Ziel.neu" -Encoding UTF8 -ErrorAction Stop
    Move-OrcaDateiErsetzt -Ziel $Ziel
}

function Get-OrcaState {
    # $null heißt: nicht vorhanden ODER unlesbar. Welcher Fall,
    # steht danach in $Global:OrcaStateUnlesbar.
    $Global:OrcaStateUnlesbar = $false
    if (-not (Test-Path -LiteralPath $Global:OrcaState)) { return $null }
    try {
        $roh = Get-Content -LiteralPath $Global:OrcaState -Raw -ErrorAction Stop
        if (-not $roh -or -not $roh.Trim()) { throw 'die Datei ist leer' }
        $st = $roh | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $st) { throw 'kein Inhalt lesbar' }
        return $st
    } catch {
        $Global:OrcaStateUnlesbar = $true
        Write-OrcaLog -Level FEHLER -Source 'STATE' `
            -Message "Zustandsdatei vorhanden, aber nicht lesbar ($($_.Exception.Message)). Sie wird nicht überschrieben. Letzte gute Fassung: '$($Global:OrcaState).vorher' - von Hand zurücklegen."
        return $null
    }
}

function Save-OrcaState {
    param($State)
    try {
        Invoke-OrcaMitSperre { Write-OrcaJsonDatei -Ziel $Global:OrcaState -Inhalt $State } | Out-Null
        return $true
    } catch {
        Write-OrcaLog -Level FEHLER -Source 'STATE' -Message "Zustandsdatei nicht speicherbar: $($_.Exception.Message)"
        return $false
    }
}

function Set-OrcaStateFeld {
    param(
        [Parameter(Mandatory)][string]$Name,
        $Wert
    )
    try {
        return (Invoke-OrcaMitSperre {
            $state = Get-OrcaState
            if (-not $state) {
                if ($Global:OrcaStateUnlesbar) {
                    Write-OrcaLog -Level FEHLER -Source 'STATE' `
                        -Message "Feld '$Name' nicht geschrieben: Die Zustandsdatei ist unlesbar und wird nicht durch eine leere ersetzt."
                    return $false
                }
                $state = [pscustomobject]@{}
            }
            $state | Add-Member -NotePropertyName $Name -NotePropertyValue $Wert -Force
            return (Save-OrcaState -State $state)
        })
    } catch {
        Write-OrcaLog -Level WARN -Source 'STATE' -Message "Feld '$Name' nicht speicherbar: $($_.Exception.Message)"
        return $false
    }
}

# --------------------------------------------------------------
#  ZEITSTEMPEL MIT FESTER KULTUR
#  SYSTEM und angemeldeter Benutzer können unterschiedliche
#  Datumsformate haben. Ohne feste Kultur schlägt das Einlesen
#  still fehl.
# --------------------------------------------------------------
function ConvertTo-OrcaZeitstempel {
    param([datetime]$Zeit = (Get-Date))
    return $Zeit.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertFrom-OrcaZeitstempel {
    param([string]$Text, [datetime]$Ersatz = [datetime]'2000-01-01')
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Ersatz }
    try { return [datetime]::Parse($Text, [Globalization.CultureInfo]::InvariantCulture) }
    catch { return $Ersatz }
}

# --------------------------------------------------------------
#  Einstufung eines Katalogpunkts in einer Zeile:
#  grün = keine spürbare Änderung, gelb = leichter Eingriff,
#  rot = tiefer Eingriff; dazu, ob der Punkt den Schutz senkt.
# --------------------------------------------------------------
function Write-OrcaRisiko {
    param([Parameter(Mandatory)]$Setting)
    switch ($Setting.Eingriff) {
        'Tief'   { Write-Host '  Eingriff: tief' -ForegroundColor Red -NoNewline }
        'Leicht' { Write-Host '  Eingriff: leicht' -ForegroundColor Yellow -NoNewline }
        default  { Write-Host '  Eingriff: keine spürbare Änderung' -ForegroundColor Green -NoNewline }
    }
    if ($Setting.SenktSchutz) { Write-Host '  ·  SICHERHEITSRISIKO' -ForegroundColor Red } else { Write-Host '' }
}
