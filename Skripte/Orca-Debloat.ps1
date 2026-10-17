# ==============================================================
#  OrcaShield - Orca-Debloat.ps1
#  App-Entfernung in vier Stufen inkl. Reste-Bereinigung
# ==============================================================
#  SCHUTZLISTE: Diese Pakete werden NIEMALS entfernt, egal in
#  welcher Stufe. Sie tragen das Startmenü, die Shell, die
#  App-Installation und die Laufzeitumgebungen.
# ==============================================================

$Global:OrcaSchutzliste = @(
    'Microsoft.WindowsStore'
    'Microsoft.DesktopAppInstaller'
    'Microsoft.WindowsTerminal'
    'Microsoft.VCLibs'
    'Microsoft.NET'
    'Microsoft.UI.Xaml'
    'Microsoft.Windows.ShellExperienceHost'
    'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.Windows.Search'
    'Microsoft.Windows.SecHealthUI'
    'Microsoft.AAD.BrokerPlugin'
    'Microsoft.Windows.CloudExperienceHost'
    'Microsoft.Windows.ContentDeliveryManager'
    'Microsoft.WindowsNotepad'
    'Microsoft.SecHealthUI'
    'MicrosoftWindows.Client.CBS'
    'MicrosoftWindows.Client.Core'
    'Microsoft.Windows.PeopleExperienceHost'
    'Microsoft.Windows.Apprep.ChxApp'
    'Microsoft.XboxGameCallableUI'
    'Windows.CBSPreview'
    'Microsoft.WindowsAppRuntime'
)

$Global:OrcaApps = @()

function New-OrcaApp {
    param(
        [string]$Id, [string]$Paket, [string]$Anzeige,
        [string]$Stufe, [string]$Erklaerung, [string]$Warnung = '',
        [string[]]$Alternativen = @()
    )
    return [pscustomobject]@{
        Id = $Id; Paket = $Paket; Anzeige = $Anzeige
        Stufe = $Stufe; Erklaerung = $Erklaerung; Warnung = $Warnung
        Alternativen = $Alternativen
    }
}

function Get-OrcaAppNamen {
    param([Parameter(Mandatory)]$App)
    return @(@($App.Paket) + @($App.Alternativen) | Where-Object { $_ })
}

# --------------------------------------------------------------
#  STUFE LIGHT - eindeutiger Ballast ohne jeden Systembezug
# --------------------------------------------------------------
$Global:OrcaApps += New-OrcaApp -Id 'L03' -Paket 'Clipchamp.Clipchamp' -Anzeige 'Clipchamp' -Stufe 'Light' `
    -Erklaerung 'Videoschnitt-App von Microsoft mit Konto-Zwang und Cloud-Anbindung. Für ernsthaften Schnitt gibt es bessere Programme.'
$Global:OrcaApps += New-OrcaApp -Id 'L04' -Paket 'Microsoft.BingNews' -Anzeige 'Microsoft News' -Stufe 'Light' `
    -Erklaerung 'Nachrichten-App, die laufend Inhalte und Werbung von Microsoft-Servern lädt und Lesegewohnheiten auswertet.'
$Global:OrcaApps += New-OrcaApp -Id 'L05' -Paket 'Microsoft.BingWeather' -Anzeige 'Wetter' -Stufe 'Light' `
    -Erklaerung 'Wetter-App mit Standortabfrage und Werbeeinblendungen. Wetter lässt sich genauso gut im Browser nachsehen.' `
    -Alternativen @('Microsoft.MSN.Weather')
$Global:OrcaApps += New-OrcaApp -Id 'L08' -Paket 'Microsoft.MicrosoftSolitaireCollection' -Anzeige 'Solitaire Collection' -Stufe 'Light' `
    -Erklaerung 'Kartenspielsammlung mit Werbung und kostenpflichtigem Abo zur Werbefreiheit.'
$Global:OrcaApps += New-OrcaApp -Id 'L09' -Paket 'Microsoft.Todos' -Anzeige 'Microsoft To Do' -Stufe 'Light' `
    -Erklaerung 'Aufgabenverwaltung mit Zwang zum Microsoft-Konto und Cloud-Synchronisierung.'
$Global:OrcaApps += New-OrcaApp -Id 'L10' -Paket 'MSTeams' -Anzeige 'Microsoft Teams (privat)' -Stufe 'Light' `
    -Erklaerung 'Die private Chat-Variante von Teams, die Windows ungefragt mitinstalliert. Die geschäftliche Version ist davon nicht betroffen.' `
    -Alternativen @('MicrosoftTeams')
$Global:OrcaApps += New-OrcaApp -Id 'L11' -Paket 'Microsoft.549981C3F5F10' -Anzeige 'Cortana (App)' -Stufe 'Light' `
    -Erklaerung 'Das App-Paket des Sprachassistenten Cortana.'
$Global:OrcaApps += New-OrcaApp -Id 'L12' -Paket 'Microsoft.GetHelp' -Anzeige 'Hilfe anfordern' -Stufe 'Light' `
    -Erklaerung 'Support-App, die eine Verbindung zu Microsoft-Supportdiensten herstellt.'
$Global:OrcaApps += New-OrcaApp -Id 'L13' -Paket 'Microsoft.Getstarted' -Anzeige 'Tipps' -Stufe 'Light' `
    -Erklaerung 'Tipps-App, die beworbene Inhalte von Microsoft-Servern nachlädt.'
$Global:OrcaApps += New-OrcaApp -Id 'L14' -Paket 'Microsoft.WindowsFeedbackHub' -Anzeige 'Feedback-Hub' -Stufe 'Light' `
    -Erklaerung 'Feedback-App, über die Nutzungsdaten und Diagnoseinformationen an Microsoft gehen.'
$Global:OrcaApps += New-OrcaApp -Id 'L15' -Paket 'Microsoft.MicrosoftOfficeHub' -Anzeige 'Office-Hub' -Stufe 'Light' `
    -Erklaerung 'Werbe-Kachel für Microsoft 365. Kein echtes Office, nur ein Verweis auf das Abo-Angebot.'

# --------------------------------------------------------------
#  STUFE STANDARD - zusätzlich zu Light
# --------------------------------------------------------------
$Global:OrcaApps += New-OrcaApp -Id 'S01' -Paket 'Microsoft.People' -Anzeige 'Kontakte' -Stufe 'Standard' `
    -Erklaerung 'Kontaktverwaltung, die mit dem Microsoft-Konto synchronisiert. Wird nur von der Mail- und Kalender-App genutzt.'
$Global:OrcaApps += New-OrcaApp -Id 'S02' -Paket 'Microsoft.WindowsMaps' -Anzeige 'Karten' -Stufe 'Standard' `
    -Erklaerung 'Kartenanwendung mit Standortabfrage. Bessere Alternativen gibt es im Browser.'
$Global:OrcaApps += New-OrcaApp -Id 'S03' -Paket 'Microsoft.WindowsSoundRecorder' -Anzeige 'Sprachrekorder' -Stufe 'Standard' `
    -Erklaerung 'Einfache Aufnahme-App. Entfernen nur sinnvoll, wenn du sie nie nutzt.'
$Global:OrcaApps += New-OrcaApp -Id 'S04' -Paket 'Microsoft.WindowsAlarms' -Anzeige 'Wecker und Uhr' -Stufe 'Standard' `
    -Erklaerung 'Wecker-, Timer- und Stoppuhr-App.'
$Global:OrcaApps += New-OrcaApp -Id 'S05' -Paket 'Microsoft.Office.OneNote' -Anzeige 'OneNote (Store-Version)' -Stufe 'Standard' `
    -Erklaerung 'Die Store-Variante von OneNote mit Konto-Zwang. Eine ggf. installierte Office-Desktop-Version bleibt unberührt.'
$Global:OrcaApps += New-OrcaApp -Id 'S06' -Paket 'Microsoft.SkypeApp' -Anzeige 'Skype' -Stufe 'Standard' `
    -Erklaerung 'Vorinstallierte Skype-App mit Konto-Zwang. Auf neueren Windows-Installationen nicht mehr enthalten.'
$Global:OrcaApps += New-OrcaApp -Id 'S07' -Paket 'Microsoft.MicrosoftStickyNotes' -Anzeige 'Kurznotizen' -Stufe 'Standard' `
    -Erklaerung 'Notizzettel-App, die ihre Inhalte mit dem Microsoft-Konto synchronisieren kann.'
$Global:OrcaApps += New-OrcaApp -Id 'S08' -Paket 'Microsoft.ZuneMusic' -Anzeige 'Media Player / Groove' -Stufe 'Standard' `
    -Erklaerung 'Microsofts Musikwiedergabe. Ein Ersatz wie VLC sollte vorher installiert sein.' `
    -Warnung 'Stelle sicher, dass ein anderer Medienplayer installiert ist.'
$Global:OrcaApps += New-OrcaApp -Id 'S09' -Paket 'Microsoft.ZuneVideo' -Anzeige 'Filme und TV' -Stufe 'Standard' `
    -Erklaerung 'Videowiedergabe und Verkaufsplattform für Filme.'
$Global:OrcaApps += New-OrcaApp -Id 'S10' -Paket 'Microsoft.YourPhone' -Anzeige 'Phone Link' -Stufe 'Standard' `
    -Erklaerung 'Handy-Anbindung, die Nachrichten, Fotos und Benachrichtigungen über Microsoft-Server synchronisiert.'
$Global:OrcaApps += New-OrcaApp -Id 'S11' -Paket 'Microsoft.PowerAutomateDesktop' -Anzeige 'Power Automate' -Stufe 'Standard' `
    -Erklaerung 'Automatisierungswerkzeug mit Cloud-Anbindung, das die meisten Privatnutzer nie öffnen.'
$Global:OrcaApps += New-OrcaApp -Id 'S12' -Paket 'Microsoft.Windows.DevHome' -Anzeige 'Dev Home' -Stufe 'Standard' `
    -Erklaerung 'Entwickler-Startseite mit GitHub-Anbindung. Von Microsoft inzwischen aufgegeben; auf neueren Installationen nicht mehr enthalten.'
$Global:OrcaApps += New-OrcaApp -Id 'S13' -Paket 'Microsoft.OutlookForWindows' -Anzeige 'Neues Outlook' -Stufe 'Standard' `
    -Erklaerung 'Die neue Outlook-App leitet Mailkonten über Microsoft-Server, auch bei Fremdanbietern. Eine klassische Outlook-Desktop-Version bleibt unberührt.'
$Global:OrcaApps += New-OrcaApp -Id 'S14' -Paket 'Microsoft.Copilot' -Anzeige 'Copilot (App)' -Stufe 'Standard' `
    -Erklaerung 'Das App-Paket des KI-Assistenten. Auf Windows 11 Pro ist das der wirksame Weg, Copilot loszuwerden - die zugehörige Richtlinie steuert nur die ältere, eingebettete Oberfläche.' `
    -Alternativen @('Microsoft.Windows.Ai.Copilot.Provider','MicrosoftWindows.Client.CoPilot')
$Global:OrcaApps += New-OrcaApp -Id 'S16' -Paket 'Microsoft.GamingApp' -Anzeige 'Xbox Gaming App' -Stufe 'Standard' `
    -Erklaerung 'Xbox-Oberfläche für den Game Pass. ACHTUNG: Wenn du Game Pass nutzt, behalte diese App. Für Steam-Spiele wird sie nicht gebraucht.' `
    -Warnung 'Wird für Xbox Game Pass benötigt - bei Steam-Nutzung unproblematisch.'
$Global:OrcaApps += New-OrcaApp -Id 'S17' -Paket 'Microsoft.XboxGamingOverlay' -Anzeige 'Xbox Game Bar' -Stufe 'Standard' `
    -Erklaerung 'Spiel-Overlay mit Aufnahmefunktion. ACHTUNG: Manche Spiele nutzen die Game Bar für Bildschirmaufnahmen.' `
    -Warnung 'Entfernt auch die Aufnahmefunktion per Windows+G.'
$Global:OrcaApps += New-OrcaApp -Id 'M11' -Paket 'MicrosoftWindows.Client.WebExperience' -Anzeige 'Widgets' -Stufe 'Standard' `
    -Erklaerung 'Das Widgets-Panel samt Nachrichten-Feed. Es lädt laufend Nachrichten, Wetter und Werbung von Microsoft-Servern. Die Richtlinie, die es abschalten soll, lässt Windows inzwischen nicht mehr schreiben (siehe UI018) - entfernen ist der Weg, der wirkt. Kommt es mit einem Store-Update zurück, entfernt der Wächter es erneut.'

# --------------------------------------------------------------
#  STUFE MAXIMUM - zusätzlich zu Standard
# --------------------------------------------------------------
$Global:OrcaApps += New-OrcaApp -Id 'M01' -Paket 'Microsoft.WindowsCamera' -Anzeige 'Kamera' -Stufe 'Maximum' `
    -Erklaerung 'Kamera-App. Entfernen nur, wenn keine Webcam genutzt wird oder eine andere Software dafür vorhanden ist.'
$Global:OrcaApps += New-OrcaApp -Id 'M02' -Paket 'Microsoft.Windows.Photos' -Anzeige 'Fotos' -Stufe 'Maximum' `
    -Erklaerung 'Bildbetrachter mit OneDrive-Anbindung und KI-Funktionen. Ein Ersatz sollte vorher installiert sein.' `
    -Warnung 'Danach öffnen Bilddateien ohne Ersatzprogramm nicht mehr per Doppelklick.'
$Global:OrcaApps += New-OrcaApp -Id 'M03' -Paket 'Microsoft.ScreenSketch' -Anzeige 'Snipping Tool' -Stufe 'Maximum' `
    -Erklaerung 'Bildschirmausschnitt-Werkzeug. Neuere Versionen enthalten KI-Texterkennung.' `
    -Warnung 'Danach funktioniert die Tastenkombination Windows+Umschalt+S nicht mehr.'
$Global:OrcaApps += New-OrcaApp -Id 'M04' -Paket 'Microsoft.Paint' -Anzeige 'Paint' -Stufe 'Maximum' `
    -Erklaerung 'Neuere Paint-Versionen enthalten KI-Bildgenerierung mit Cloud-Anbindung. Wer Paint behalten will, schaltet die KI-Funktionen stattdessen über die Punkte KI005 bis KI007 ab.'
$Global:OrcaApps += New-OrcaApp -Id 'M06' -Paket 'Microsoft.RemoteDesktop' -Anzeige 'Remotedesktop' -Stufe 'Maximum' `
    -Erklaerung 'Fernzugriffs-App. Auf einem Rechner ohne Fernwartungsbedarf unnötig - und jede nicht vorhandene Fernzugriffsmöglichkeit ist eine Angriffsfläche weniger. Von Microsoft inzwischen durch "Windows App" abgelöst.'
$Global:OrcaApps += New-OrcaApp -Id 'M07' -Paket 'Microsoft.WindowsCommunicationsApps' -Anzeige 'Mail und Kalender' -Stufe 'Maximum' `
    -Erklaerung 'Die klassische Mail- und Kalender-App. Ende 2024 abgekündigt; auf neueren Installationen nicht mehr enthalten.' `
    -Warnung 'Nur entfernen, wenn ein anderes Mailprogramm eingerichtet ist.'
$Global:OrcaApps += New-OrcaApp -Id 'M08' -Paket 'MicrosoftCorporationII.QuickAssist' -Anzeige 'Schnellhilfe' -Stufe 'Maximum' `
    -Erklaerung 'Fernwartungswerkzeug. Wird häufig bei Support-Betrugsmaschen missbraucht.' `
    -Alternativen @('Microsoft.QuickAssist')
$Global:OrcaApps += New-OrcaApp -Id 'M09' -Paket 'Microsoft.XboxSpeechToTextOverlay' -Anzeige 'Xbox Sprache-zu-Text-Overlay' -Stufe 'Maximum' `
    -Erklaerung 'Sprach-zu-Text-Overlay für Xbox-Spiele.'
$Global:OrcaApps += New-OrcaApp -Id 'M10' -Paket 'Microsoft.MicrosoftEdge.Stable' -Anzeige 'Microsoft Edge' -Stufe 'Maximum' `
    -Erklaerung 'Microsofts Browser, eng mit der Windows-Telemetrie verzahnt. HINWEIS: Edge ist kein gewöhnliches Store-Paket, sondern ein klassisches Programm - die Paketentfernung scheitert auf den meisten Systemen. Im Europäischen Wirtschaftsraum lässt er sich seit dem Digital Markets Act regulär über Einstellungen, Apps, Installierte Apps deinstallieren; das ist der Weg, der funktioniert.' `
    -Warnung 'BROWSER-WARNUNG'

# --------------------------------------------------------------
#  APP ENTFERNEN
# --------------------------------------------------------------
function Remove-OrcaApp {
    param([Parameter(Mandatory)]$App)

    # Schutzliste prüfen
    foreach ($schutz in $Global:OrcaSchutzliste) {
        if ($App.Paket -like "*$schutz*") {
            Write-OrcaLog -Level SKIP -Source 'DEBLOAT' -Message "$($App.Anzeige) steht auf der Schutzliste - nicht entfernt"
            return @{ Erfolg = $true; Entfernt = $false; Grund = 'Schutzliste' }
        }
    }

    $namen    = Get-OrcaAppNamen -App $App
    $gefunden = $false
    $fehler   = ''

    try {
        foreach ($name in $namen) {
            # 1) Für alle aktuellen Benutzer entfernen
            $pakete = Get-AppxPackage -AllUsers -Name "*$name*" -ErrorAction SilentlyContinue
            foreach ($p in $pakete) {
                $gefunden = $true
                try {
                    Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                } catch {
                    $fehler = $_.Exception.Message
                }
            }

            # 2) Aus dem Systemabbild entfernen (verhindert Rückkehr bei neuen Profilen)
            $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -like "*$name*" }
            foreach ($p in $prov) {
                $gefunden = $true
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
                } catch {
                    $fehler = $_.Exception.Message
                }
            }
        }

        if (-not $gefunden) {
            # Gegenprobe: Vielleicht stimmt der Paketname im Katalog nicht.
            foreach ($name in $namen) {
                $kurz = ($name -split '\.')[-1]
                if ($kurz -and $kurz.Length -ge 4) {
                    $treffer = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -like "*$kurz*" } |
                               Select-Object -ExpandProperty Name -Unique
                    if ($treffer) {
                        Write-OrcaLog -Level WARN -Source 'DEBLOAT' `
                            -Message "$($App.Anzeige) - unter '$name' nicht gefunden, ABER installiert als: $($treffer -join ', '). Der Paketname im Katalog ist veraltet."
                        return @{ Erfolg = $false; Entfernt = $false
                                  Grund = "Paketname im Katalog veraltet - tatsächlich: $($treffer -join ', ')" }
                    }
                }
            }
            Write-OrcaLog -Level SKIP -Source 'DEBLOAT' -Message "$($App.Anzeige) - nicht installiert, nichts zu tun"
            return @{ Erfolg = $true; Entfernt = $false; Grund = 'nicht installiert' }
        }

        # Gegenprobe nach dem Entfernen: Erfolg nur melden, wenn wirklich weg.
        $rest = @()
        foreach ($name in $namen) {
            $rest += @(Get-AppxPackage -AllUsers -Name "*$name*" -ErrorAction SilentlyContinue)
        }
        if ($rest.Count -gt 0) {
            $grund = if ($fehler) { $fehler } else { 'weiterhin vorhanden - vermutlich von Windows geschützt' }
            Write-OrcaLog -Level WARN -Source 'DEBLOAT' `
                -Message "$($App.Anzeige) - das Paket ist weiterhin vorhanden. $grund"
            return @{ Erfolg = $false; Entfernt = $false; Grund = $grund }
        }

        Write-OrcaLog -Level OK -Source 'DEBLOAT' -Message "$($App.Anzeige) entfernt"
        return @{ Erfolg = $true; Entfernt = $true; Grund = '' }
    }
    catch {
        Write-OrcaLog -Level FEHLER -Source 'DEBLOAT' -Message "$($App.Anzeige) - FEHLGESCHLAGEN. Grund: $($_.Exception.Message)"
        return @{ Erfolg = $false; Entfernt = $false; Grund = $_.Exception.Message }
    }
}

function Clear-OrcaAppReste {
    param([Parameter(Mandatory)]$App)

    $geloescht = @()
    $namen = Get-OrcaAppNamen -App $App

    $orcaProfile = @(Get-OrcaBenutzerProfile)
    if ($orcaProfile.Count -eq 0) {
        Write-OrcaLog -Level WARN -Source 'RESTE' `
            -Message "Keine Benutzerprofile ermittelbar - Rückstände von $($App.Anzeige) bleiben liegen"
        return $geloescht
    }

    $alsSystem = Test-OrcaAlsSystem

    foreach ($p in $orcaProfile) {

        # 1) Verwaiste Ordner in den typischen App-Datenpfaden
        $ordnerPfade = @(
            (Join-Path $p.Profilpfad 'AppData\Local\Packages')
            (Join-Path $p.Profilpfad 'AppData\Local\Microsoft\WindowsApps')
        )
        foreach ($basis in $ordnerPfade) {
            if (-not (Test-Path $basis)) { continue }
            try {
                foreach ($name in $namen) {
                    $treffer = Get-ChildItem -Path $basis -Directory -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -like "*$name*" }
                    foreach ($t in $treffer) {
                        $istGeschuetzt = $false
                        foreach ($schutz in $Global:OrcaSchutzliste) {
                            if ($t.Name -like "*$schutz*") { $istGeschuetzt = $true; break }
                        }
                        if ($istGeschuetzt) { continue }

                        if (-not (Test-OrcaWegSicher -Wurzel $p.Profilpfad -Pfad $basis)) { continue }
                        [void](Remove-OrcaPfadSicher -Wurzel $basis -Pfad $t.FullName)
                        if (-not (Test-Path -LiteralPath $t.FullName)) {
                            $geloescht += "Ordner: $($t.FullName)"
                        }
                    }
                }
            } catch { }
        }

        # 2) Verwaiste Registry-Einträge im Profil des Benutzers
        $sid = if ($alsSystem) { $p.Sid } else { '' }
        $regPfade = @(
            'HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages'
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search\JumplistData'
        )
        foreach ($rp in $regPfade) {
            $basis = Resolve-OrcaRegPfad -Pfad $rp -Sid $sid
            if (-not (Test-Path -LiteralPath $basis)) { continue }
            try {
                foreach ($name in $namen) {
                    $treffer = Get-ChildItem -LiteralPath $basis -ErrorAction SilentlyContinue |
                               Where-Object { $_.PSChildName -like "*$name*" }
                    foreach ($t in $treffer) {
                        $istGeschuetzt = $false
                        foreach ($schutz in $Global:OrcaSchutzliste) {
                            if ($t.PSChildName -like "*$schutz*") { $istGeschuetzt = $true; break }
                        }
                        if ($istGeschuetzt) { continue }

                        Remove-Item -LiteralPath $t.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path -LiteralPath $t.PSPath)) {
                            $geloescht += "Registry: $($t.PSChildName)"
                        }
                    }
                }
            } catch { }
        }

        # Nur das eigene Profil, wenn wir nicht als SYSTEM laufen -
        # an fremde Profile kämen wir ohnehin nicht heran.
        if (-not $alsSystem) { break }
    }

    if ($geloescht.Count -gt 0) {
        Write-OrcaLog -Level OK -Source 'RESTE' -Message "$($App.Anzeige): $($geloescht.Count) Rückstände beseitigt"
    }

    return $geloescht
}

# --------------------------------------------------------------
#  APPS NACH STUFE HOLEN
# --------------------------------------------------------------
function Get-OrcaAppsNachStufe {
    param([ValidateSet('Light','Standard','Maximum')][string]$Stufe)
    switch ($Stufe) {
        'Light'    { return $Global:OrcaApps | Where-Object { $_.Stufe -eq 'Light' } }
        'Standard' { return $Global:OrcaApps | Where-Object { $_.Stufe -in @('Light','Standard') } }
        'Maximum'  { return $Global:OrcaApps }
    }
}

# --------------------------------------------------------------
#  APP-BESTAND MESSEN (für den Trockenlauf)
#  Ändert nichts, sagt nur, was tatsächlich installiert ist.
# --------------------------------------------------------------
function Measure-OrcaApps {
    param([Parameter(Mandatory)][array]$Apps)

    $ergebnis = @()
    foreach ($app in $Apps) {
        $namen = Get-OrcaAppNamen -App $app
        $treffer = @()
        foreach ($name in $namen) {
            $treffer += @(Get-AppxPackage -AllUsers -Name "*$name*" -ErrorAction SilentlyContinue |
                          Select-Object -ExpandProperty Name -Unique)
        }
        $ergebnis += [pscustomobject]@{
            Id         = $app.Id
            Anzeige    = $app.Anzeige
            Stufe      = $app.Stufe
            Installiert = ($treffer.Count -gt 0)
            Pakete     = ($treffer | Select-Object -Unique)
        }
    }
    return $ergebnis
}

# --------------------------------------------------------------
#  DEBLOAT-DURCHLAUF
# --------------------------------------------------------------
function Invoke-OrcaDebloat {
    param(
        [Parameter(Mandatory)][array]$Apps,
        [switch]$MitResteBereinigung
    )

    $ergebnis = @{ Entfernt = 0; NichtVorhanden = 0; Fehler = 0; Reste = 0; FehlerListe = @() }
    $i = 0; $n = $Apps.Count

    foreach ($app in $Apps) {
        $i++
        Write-OrcaBalken -Aktuell $i -Gesamt $n -Text $app.Anzeige

        $r = Remove-OrcaApp -App $app

        if ($r.Entfernt) {
            $ergebnis.Entfernt++
            if ($MitResteBereinigung) {
                $reste = Clear-OrcaAppReste -App $app
                $ergebnis.Reste += $reste.Count
            }
        }
        elseif ($r.Erfolg) {
            $ergebnis.NichtVorhanden++
        }

        if (-not $r.Erfolg) {
            $ergebnis.Fehler++
            $ergebnis.FehlerListe += "$($app.Anzeige): $($r.Grund)"
        }
    }

    return $ergebnis
}
