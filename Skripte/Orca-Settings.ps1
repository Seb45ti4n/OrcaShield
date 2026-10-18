
$Global:OrcaEinstellungen = @()

function New-OrcaSetting {
    param(
        [string]$Id, [string]$Name, [string]$Kategorie, [string]$Stufe,
        [string]$Erklaerung, [string]$Typ,
        [string]$Pfad = '', [string]$Wert = '', $Soll = $null, $Standard = $null,
        [string]$RegTyp = 'DWord',
        [bool]$GrautAus = $false,
        [string]$Hinweis = '', [string]$PolicyGrund = '', [string]$Warnung = '',
        [bool]$NurPro = $false, [int]$MindestBuild = 0,
        [bool]$SenktSchutz = $false,
        [string[]]$NurEdition = @(),
        [bool]$NurWennVorhanden = $false,
        $AuchErfuellt = @(),
        [string]$Wirkung = '', [string]$Voraussetzung = '',
        [bool]$NurWaechter = $false,
        [bool]$Ausgemustert = $false, [string[]]$ErsetztDurch = @(),
        [bool]$Abwaegen = $false, [bool]$VorgabeNein = $false,
        [hashtable[]]$BenoetigtVon = @(),
        [string]$NachDemSetzen = '',
        [ValidateSet('', 'Keiner', 'Leicht', 'Tief')][string]$Eingriff = ''
    )

    # Bereich automatisch ableiten - so kann er nicht falsch gesetzt werden.
    # Maßgeblich ist der PFAD, nicht der Typ: auch ein Autostart-Eintrag
    # unter HKCU gehört in den Benutzerkontext. Wer hier auf den Typ
    # abfragt, schiebt solche Punkte stillschweigend zum SYSTEM-Wächter,
    # wo sie ins Profil des Systemkontos liefen.
    $bereich = if ($Pfad -match '^HKCU:\\') { 'Benutzer' } else { 'Maschine' }

    # Wie tief der Punkt in die Bedienung eingreift - für die Anzeige
    # grün / gelb / rot und die Voreinstellungen je Kategorie. Wird er
    # nicht angegeben, folgt er aus den übrigen Feldern. Ob ein Punkt den
    # Schutz senkt, sagt SenktSchutz - das ist eine eigene Frage.
    if (-not $Eingriff) {
        $Eingriff = if ($SenktSchutz) { 'Tief' }
                    elseif ($Stufe -eq 'Zusatz' -and ($VorgabeNein -or $GrautAus)) { 'Tief' }
                    elseif ($GrautAus -or $VorgabeNein -or $Abwaegen -or @($BenoetigtVon).Count -gt 0) { 'Leicht' }
                    else { 'Keiner' }
    }

    return [pscustomobject]@{
        Id = $Id; Name = $Name; Kategorie = $Kategorie; Stufe = $Stufe
        Erklaerung = $Erklaerung; Typ = $Typ; Bereich = $bereich
        Pfad = $Pfad; Wert = $Wert; Soll = $Soll; Standard = $Standard
        RegTyp = $RegTyp; GrautAus = $GrautAus
        Hinweis = $Hinweis; PolicyGrund = $PolicyGrund; Warnung = $Warnung
        NurPro = $NurPro; MindestBuild = $MindestBuild
        SenktSchutz = $SenktSchutz
        NurEdition = $NurEdition; NurWennVorhanden = $NurWennVorhanden
        AuchErfuellt = @($AuchErfuellt)
        Wirkung = $Wirkung; Voraussetzung = $Voraussetzung
        NurWaechter = $NurWaechter
        Ausgemustert = $Ausgemustert; ErsetztDurch = @($ErsetztDurch)
        Abwaegen = $Abwaegen; VorgabeNein = $VorgabeNein
        BenoetigtVon = @($BenoetigtVon)
        NachDemSetzen = $NachDemSetzen
        Eingriff = $Eingriff
    }
}

# ==============================================================
#  1. TELEMETRIE UND DIAGNOSE
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL025' -Name 'Diagnosedaten auf Minimum (ohne Sperre)' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Setzt die Übermittlung von Diagnosedaten auf "nur erforderlich". Windows sendet dann keine optionalen Nutzungs- und Absturzdaten mehr. Der Schalter unter Datenschutz, Diagnose und Feedback bleibt bedienbar - stellst du ihn zwischendurch um, setzt der Wächter ihn beim nächsten Start zurück.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Wert 'AllowTelemetry' -Soll 1 -Standard 3 `
    -AuchErfuellt @(0) `
    -Hinweis 'Dies ist der Ort, an den die Einstellungen-App selbst schreibt. Microsoft dokumentiert ihn nicht ausdrücklich - er sperrt dafür nichts. Wer die Sperre in Kauf nimmt, nimmt stattdessen TEL001.' `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies, nicht im Gruppenrichtlinienzweig. Dort legt die Einstellungen-App ihre eigenen Entscheidungen ab; gesperrt wird dadurch nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL001' -Name 'Diagnosedaten per Richtlinie erzwingen' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Erzwingt die niedrigste Diagnosestufe über die Gruppenrichtlinie, sodass sie sich auch von einem anderen Konto aus nicht mehr anheben lässt. Für dein eigenes Konto genügt der vorige Punkt - dieser hier lohnt sich nur, wenn weitere Konten auf dem Rechner existieren.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'AllowTelemetry' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter unter Einstellungen, Datenschutz und Sicherheit, Diagnose und Feedback wird danach gesperrt und zeigt "Einige Einstellungen werden von Ihrer Organisation verwaltet". WICHTIG: Microsoft setzt den Wert 0 nur auf Enterprise, Education und Server um - auf Pro und Home behandelt Windows ihn wie 1. Du bekommst hier also dasselbe Ergebnis wie beim vorigen Punkt und bezahlst es mit der Sperre. Zusätzlich lässt sich das Windows-Insider-Programm mit gesetzter Richtlinie nicht mehr nutzen.' `
    -PolicyGrund 'Nur der Richtlinienzweig gilt kontoübergreifend und lässt sich nicht aus der Oberfläche heraus anheben.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL027' -Name 'Gerätenamen nicht mitübertragen' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Seit Windows 10 1803 wird der Name deines Rechners zusammen mit den Diagnosedaten übertragen. Das ist der unmittelbarste Personenbezug im ganzen Telemetriepaket, weil Gerätenamen oft den echten Namen enthalten. Dieser Punkt unterbindet das.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'AllowDeviceNameInTelemetry' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: es gibt dazu keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL028' -Name 'Keine zusätzlichen Diagnoseprotokolle' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Microsoft über die Diagnoseschnittstelle zusätzliche Protokolldateien von deinem Rechner nachfordert.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'LimitDiagnosticLogCollection' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter vorhanden.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL029' -Name 'Keine Speicherabbilder übermitteln' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert die Übermittlung von Speicherabbildern. Solche Abbilder können Ausschnitte des Arbeitsspeichers und damit auch entschlüsselte Inhalte enthalten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'LimitDumpCollection' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter vorhanden.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL030' -Name 'OneSettings-Abrufe unterbinden' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows holt sich laufend Konfigurationsdaten vom Microsoft-Dienst OneSettings - ein Kanal, der in beide Richtungen arbeitet und über den Funktionen stillschweigend ein- und ausgeschaltet werden. Dieser Punkt schließt ihn.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'DisableOneSettingsDownloads' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter vorhanden.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL002' -Name 'Dienst DiagTrack deaktivieren' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Dienst' `
    -Erklaerung 'Stoppt den Dienst "Connected User Experiences and Telemetry" (DiagTrack). Das ist der Hauptkanal, über den Windows Nutzungs- und Diagnosedaten sammelt und versendet. Spart zusätzlich Arbeitsspeicher und CPU-Last im Hintergrund.' `
    -Wert 'DiagTrack' -Soll 'Disabled' -Standard 'Automatic'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL003' -Name 'Dienst dmwappushservice deaktivieren' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Dienst' `
    -Erklaerung 'Deaktiviert den WAP-Push-Nachrichtenrouting-Dienst, der als zweiter Telemetriekanal genutzt wird. Wird auf einem privaten Rechner ohne Geräteverwaltung nicht benötigt.' `
    -Wert 'dmwappushservice' -Soll 'Disabled' -Standard 'Manual'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL004' -Name 'Angepasste Erlebnisse abschalten' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows die gesammelten Diagnosedaten nutzt, um personalisierte Tipps, Werbung und Empfehlungen anzuzeigen. Der Schalter in den Einstellungen bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' -Wert 'TailoredExperiencesWithDiagnosticDataEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL005' -Name 'Fehlerberichterstattung deaktivieren' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Windows-Fehlerberichterstattung (WER) ab. Bei Programmabstürzen werden dann keine Absturzberichte samt Speicherausschnitten mehr an Microsoft gesendet. Nachteil: Microsoft erfährt nichts von Fehlern, die dich betreffen - für die Fehlersuche auf dem eigenen Rechner ändert sich nichts, lokale Ereignisprotokolle bleiben erhalten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Wert 'Disabled' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: Zur Fehlerberichterstattung gibt es in Windows 11 keinen sichtbaren Schalter, es wird also nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL011' -Name 'Telemetrie-Datensammler (Autologger)' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Autologger' `
    -Erklaerung 'Schaltet den Ereignissammler ab, der die Telemetriedaten überhaupt erst einsammelt. Das ist die Ebene UNTER dem Dienst DiagTrack: Selbst wenn Microsoft den Dienst per Update wieder einschaltet, bekommt er nichts mehr zu sehen. Für den Dauerschutz die wirksamste Einzelmaßnahme im ganzen Katalog. Kein sichtbarer Schalter betroffen.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener' -Wert 'Start' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL012' -Name 'CEIP-Datensammler (SQMLogger)' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Autologger' `
    -Erklaerung 'Schaltet den zweiten Ereignissammler ab, der Daten für das Programm zur Verbesserung der Benutzerfreundlichkeit aufzeichnet. Auf neueren Windows-Versionen gibt es diesen Sammler nicht mehr - dann wird der Punkt übersprungen statt einen Schlüssel anzulegen, den Windows nie hatte.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SQMLogger' -Wert 'Start' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL013' -Name 'CEIP systemweit abschalten' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Teilnahme am Programm zur Verbesserung der Benutzerfreundlichkeit für den gesamten Rechner ab.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Wert 'CEIPEnable' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: Zum CEIP gibt es in Windows 11 keinen sichtbaren Schalter mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL014' -Name 'Feedback-Anfragen unterbinden' `
    -Kategorie 'Telemetrie' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Setzt die Häufigkeit der Windows-Feedback-Anfragen auf null. Die Einblendungen "Wie zufrieden sind Sie mit ..." bleiben danach aus.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' -Wert 'NumberOfSIUFInPeriod' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL015' -Name 'Feedback-Benachrichtigungen aus' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Unterbindet zusätzlich die Benachrichtigungen, mit denen Windows zur Rückmeldung auffordert.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'DoNotShowFeedbackNotifications' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein eigener sichtbarer Schalter vorhanden.'

# --- Geplante Telemetrie-Aufgaben ---------------------------------
# Eine Aufgabe, die es auf diesem System nicht gibt, meldet
# "nicht vorhanden" und wird übersprungen - nicht als Erfolg
# verbucht. Ältere Einträge schaden deshalb nicht, sie decken
# ältere Windows-Stände mit ab.

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL006' -Name 'CEIP-Aufgabe: Consolidator' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die geplante Aufgabe des Programms zur Verbesserung der Benutzerfreundlichkeit. Diese Aufgabe sammelt periodisch Nutzungsdaten und sendet sie an Microsoft.' `
    -Wert '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL007' -Name 'CEIP-Aufgabe: UsbCeip' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Erfassung von Daten über angeschlossene USB-Geräte.' `
    -Wert '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL020' -Name 'Kernel-CEIP-Aufgabe' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Erfassung von Kernel-Nutzungsdaten für das CEIP. Auf neueren Windows-Versionen nicht mehr vorhanden.' `
    -Wert '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL037' -Name 'CEIP-Aufgabe: PI Sqm-Tasks' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert einen weiteren Sammler des Programms zur Verbesserung der Benutzerfreundlichkeit.' `
    -Wert '\Microsoft\Windows\PI\Sqm-Tasks'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL008' -Name 'Kompatibilitäts-Scan (Appraiser)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert den Microsoft Compatibility Appraiser. Diese Aufgabe scannt regelmäßig deine installierte Software und Hardware und überträgt ein detailliertes Systemverzeichnis an Microsoft. Spart zusätzlich spürbar Festplattenaktivität im Hintergrund.' `
    -Wert '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL009' -Name 'Programmdaten-Updater' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe ProgramDataUpdater, die Anwendungs-Telemetrie für den Kompatibilitäts-Assistenten aufbereitet.' `
    -Wert '\Microsoft\Windows\Application Experience\ProgramDataUpdater'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL018' -Name 'Anwendungstelemetrie (AitAgent)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert den Agenten, der Anwendungsnutzung für den Kompatibilitäts-Assistenten protokolliert. Auf Windows 11 in der Regel nicht mehr vorhanden.' `
    -Wert '\Microsoft\Windows\Application Experience\AitAgent'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL019' -Name 'Autostart-Analyse (StartupAppTask)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe, die deine Autostart-Programme erfasst und bewertet.' `
    -Wert '\Microsoft\Windows\Application Experience\StartupAppTask'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL033' -Name 'Kompatibilitäts-Aufgabe (PcaPatchDbTask)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' -Ausgemustert $true `
    -Erklaerung 'Deaktiviert eine in Windows 11 neu hinzugekommene Aufgabe des Programmkompatibilitäts-Assistenten, die die lokale Kompatibilitätsdatenbank pflegt.' `
    -Wert '\Microsoft\Windows\Application Experience\PcaPatchDbTask'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL038' -Name 'Kompatibilitäts-Scan, Expressfassung' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe "Microsoft Compatibility Appraiser Exp". Laut eigener Beschreibung sammelt sie Programmtelemetrie; sie startet compattelrunner.exe mit dem Appraiser im Expressmodus - dieselbe Bestandsaufnahme wie der Kompatibilitäts-Scan weiter oben, nur über einen eigenen Auslöser.' `
    -Wert '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL034' -Name 'Kompatibilitäts-Aufgabe (MareBackup)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert eine weitere in Windows 11 hinzugekommene Aufgabe der Kompatibilitäts-Telemetrie.' `
    -Wert '\Microsoft\Windows\Application Experience\MareBackup'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL031' -Name 'Geräteinventur (Device Census)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Gerätevolkszählung. Sie erstellt eine vollständige Aufstellung deiner Hardware und der installierten Software und überträgt sie an Microsoft. Von allen geplanten Aufgaben die mit dem größten Datenumfang.' `
    -Wert '\Microsoft\Windows\Device Information\Device'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL032' -Name 'Geräteinventur, benutzerbezogen' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Das benutzerbezogene Gegenstück zur Geräteinventur.' `
    -Wert '\Microsoft\Windows\Device Information\Device User'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL035' -Name 'Nutzungsdaten der Funktionsausrollung' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Übermittlung von Nutzungsdaten, mit denen Microsoft die schrittweise Ausrollung neuer Funktionen steuert.' `
    -Wert '\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL036' -Name 'OneSettings-Abruf (Aufgabe)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe, die die OneSettings-Konfiguration von Microsoft holt. Gegenstück zum Registrypunkt weiter oben.' `
    -Wert '\Microsoft\Windows\Flighting\OneSettings\RefreshCache'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL016' -Name 'Feedback-Aufgabe DmClient' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die geplante Aufgabe, die Feedback-Kampagnen abruft.' `
    -Wert '\Microsoft\Windows\Feedback\Siuf\DmClient'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL017' -Name 'Feedback-Aufgabe DmClientOnScenarioDownload' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die zugehörige Nachladeaufgabe für Feedback-Szenarien.' `
    -Wert '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL021' -Name 'Datentraeger-Diagnosedaten' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe, die Datenträgerzustandsdaten sammelt und übermittelt.' `
    -Wert '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL022' -Name 'Speicherplatz-Analyse (DiskFootprint)' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe, die eine Aufstellung deiner Speicherplatzbelegung erstellt.' `
    -Wert '\Microsoft\Windows\DiskFootprint\Diagnostics'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL023' -Name 'Fehlerbericht-Warteschlange' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe, die gesammelte Fehlerberichte nachträglich an Microsoft überträgt.' `
    -Wert '\Microsoft\Windows\Windows Error Reporting\QueueReporting'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL024' -Name 'Autochk-Proxy-Aufgabe' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert eine Aufgabe, die Daten der Datenträgerprüfung an das CEIP weiterreicht.' `
    -Wert '\Microsoft\Windows\Autochk\Proxy'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL039' -Name 'Handschriftdaten nicht weitergeben' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows Proben deiner Handschrift an Microsoft schickt, um die Handschrifterkennung zu verbessern. Betrifft Stift- und Toucheingabe; ohne Stift ändert sich nichts.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC' -Wert 'PreventHandwritingDataSharing' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL040' -Name 'Keine Fehlerberichte der Handschrifterkennung' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert Fehlerberichte der Handschrifterkennung an Microsoft. Solche Berichte können Ausschnitte des Geschriebenen enthalten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports' -Wert 'PreventHandwritingErrorReports' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL041' -Name 'Programminventur abschalten (Inventory Collector)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Inventory Collector ab. Er listet installierte Programme, Dateien und Geräte auf und überträgt die Liste an Microsoft. Die Kompatibilitätshilfe für alte Programme bleibt erhalten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Wert 'DisableInventory' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL042' -Name 'Anwendungstelemetrie abschalten' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Anwendungstelemetrie ab, die festhält, wie Programme Windows-Funktionen nutzen, und sie an Microsoft meldet. Ergänzt die Aufgabe AitAgent (TEL018) um den Schalter selbst.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Wert 'AITEnable' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL043' -Name 'Schrittaufzeichnung abschalten' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Schrittaufzeichnung ab, die Klicks und Bildschirmfotos für Fehlerberichte mitschneidet. Ab Windows 11 24H2 ist das Programm ohnehin entfallen - der Punkt sorgt dafür, dass es auch über Umwege nicht anspringt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Wert 'DisableUAR' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL044' -Name 'Angepasste Erlebnisse per Richtlinie sperren' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Verbietet über die Richtlinie, dass Windows Diagnosedaten für personalisierte Tipps und Werbung nutzt. TEL004 erledigt dasselbe ohne Sperre.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableTailoredExperiencesWithDiagnosticData' -Soll 1 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Angepasste Benutzererfahrungen" unter Datenschutz, Diagnose und Feedback wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig lässt sich nicht aus der Oberfläche heraus ändern.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL045' -Name 'Keine Auswertung für Desktop Analytics' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verbietet, dass Diagnosedaten dieses Rechners für den Unternehmensdienst Desktop Analytics verarbeitet werden.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'AllowDesktopAnalyticsProcessing' -Soll 0 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL046' -Name 'Keine Cloud-Auswertung für Windows Update for Business' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verbietet die Cloud-Verarbeitung von Diagnosedaten für die Unternehmensverwaltung von Updates.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'AllowWUfBCloudProcessing' -Soll 0 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL047' -Name 'Keine Auswertung für Update Compliance' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verbietet, dass Diagnosedaten für den Dienst Update Compliance verarbeitet werden.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'AllowUpdateComplianceProcessing' -Soll 0 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL048' -Name 'Keine geschäftliche Datenverarbeitung' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verbietet, dass Microsoft gesammelte Diagnosedaten in der geschäftlichen Datenpipeline weiterverarbeitet.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Wert 'AllowCommercialDataPipeline' -Soll 0 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'


$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL050' -Name 'Fehlerberichte: keine Zusatzdaten' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Falls doch ein Fehlerbericht entsteht, werden keine zusätzlichen Daten (etwa Speicherausschnitte) mitgeschickt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Wert 'DontSendAdditionalData' -Soll 1 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL051' -Name 'Fehlerberichte: auch lokal nicht protokollieren' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Die Fehlerberichterstattung schreibt auch keine lokalen Einträge mehr.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Wert 'LoggingDisabled' -Soll 1 -Standard $null `
    -Hinweis 'Abstürze erscheinen dann nicht mehr im Zuverlässigkeitsverlauf - das erschwert die eigene Fehlersuche.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL052' -Name 'Fehlerberichte: vor dem Senden immer fragen' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Legt fest, dass Windows vor jedem Fehlerbericht nachfragt, statt Daten selbsttätig zu senden.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting\Consent' -Wert 'DefaultConsent' -Soll 1 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL053' -Name 'Aufgabe: Datenträgerdiagnose-Meldungen' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Aufgabe' `
    -Erklaerung 'Deaktiviert die Aufgabe, die Ergebnisse der Datenträgerdiagnose auswertet und meldet.' `
    -Wert '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver' -Soll '' -Standard $null


$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL056' -Name 'Dienst: Windows-Fehlerberichterstattung' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Dienst' `
    -Erklaerung 'Deaktiviert den Dienst der Fehlerberichterstattung. Ergänzt TEL005: Selbst wenn die Richtlinie umgangen wird, läuft nichts.' `
    -Wert 'WerSvc' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Programme, die eigene Absturzberichte über Windows verschicken, können das nicht mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL057' -Name 'Dienst: Fehlerbericht-Systemsteuerung' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Dienst' `
    -Erklaerung 'Deaktiviert den Dienst, der Lösungen zu Fehlerberichten in der Systemsteuerung anzeigt.' `
    -Wert 'wercplsupport' -Soll 'Disabled' -Standard 'Manual'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL058' -Name 'Dienst: Diagnoseausführung' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Dienst' `
    -Erklaerung 'Deaktiviert den Dienst, mit dem Microsoft Diagnosen auf dem Rechner ausführen lässt.' `
    -Wert 'diagsvc' -Soll 'Disabled' -Standard 'Manual' `
    -VorgabeNein $true `
    -Hinweis 'Die Problembehandlungen von Windows (etwa für Netzwerk und Audio) funktionieren danach teilweise nicht mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL059' -Name 'Dienst: Diagnose-Hub-Sammler' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Dienst' `
    -Erklaerung 'Deaktiviert den Sammeldienst des Diagnose-Hubs (Leistungs- und Ablaufdaten). Fehlt er, wird nichts angelegt.' `
    -Wert 'diagnosticshub.standardcollector.service' -Soll 'Disabled' -Standard 'Manual' `
    -VorgabeNein $true `
    -Hinweis 'Entwicklungswerkzeuge wie Visual Studio können danach keine Leistungsmessungen mehr aufzeichnen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL060' -Name 'Programmkompatibilitäts-Assistent aus' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Assistenten ab, der nach dem Start alter Programme Kompatibilitätsprobleme erkennt und Daten dazu sammelt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Wert 'DisablePCA' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Ältere Programme und Spiele bekommen keine automatischen Kompatibilitätshilfen mehr.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL061' -Name 'Kompatibilitäts-Engine aus' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Engine ab, die alten Programmen beim Start Kompatibilitätskorrekturen unterschiebt und dafür jeden Programmstart prüft.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Wert 'DisableEngine' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Manche älteren Programme und Installationsprogramme starten danach nicht mehr oder verhalten sich fehlerhaft.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL062' -Name 'Reiter "Kompatibilität" ausblenden' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Blendet in den Eigenschaften von Programmdateien den Reiter "Kompatibilität" aus.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Wert 'DisablePropPage' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Kompatibilitätsmodus und Ausführen als Administrator lassen sich dann nicht mehr über diesen Reiter einstellen.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL063' -Name 'Media Player: keine CD- und DVD-Informationen abrufen' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der klassische Windows Media Player fragt zu eingelegten CDs und DVDs keine Titel- und Albuminformationen mehr im Netz ab.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\WindowsMediaPlayer' -Wert 'PreventCDDVDMetadataRetrieval' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL064' -Name 'Media Player: keine Informationen zu Musikdateien abrufen' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der klassische Windows Media Player ergänzt fehlende Angaben zu Musikdateien nicht mehr aus dem Netz.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\WindowsMediaPlayer' -Wert 'PreventMusicFileMetadataRetrieval' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

# ==============================================================
#  2. WERBUNG UND TRACKING-IDS
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'ADV001' -Name 'Werbe-ID deaktivieren' `
    -Kategorie 'Werbung' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet die geräteweite Werbe-ID ab, mit der Apps dein Nutzungsverhalten über verschiedene Anwendungen hinweg verknüpfen können. Apps zeigen danach unpersonalisierte statt personalisierter Werbung. Der Schalter in den Einstellungen bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Wert 'Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'ADV002' -Name 'Werbe-ID für ALLE Konten sperren' `
    -Kategorie 'Werbung' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Sperrt die Werbe-ID zusätzlich für alle Benutzerkonten des Rechners, auch für künftig angelegte. Für dein eigenes Konto genügt bereits der vorige Punkt - dieser hier lohnt sich nur, wenn weitere Konten auf dem Rechner existieren.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' -Wert 'DisabledByGroupPolicy' -Soll 1 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter unter Einstellungen, Datenschutz und Sicherheit, Allgemein, "Apps das Anzeigen personalisierter Werbung erlauben" wird danach gesperrt. Wenn dir dein eigenes Konto genügt, antworte hier mit Nein - der vorige Punkt erledigt das bereits ohne Sperre.' `
    -PolicyGrund 'Für die kontoübergreifende Sperre gibt es keinen Weg außerhalb des Richtlinienzweigs.'

# ==============================================================
#  3. KI-FUNKTIONEN (COPILOT / RECALL / PAINT)
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI001' -Name 'Windows Copilot deaktivieren' `
    -Kategorie 'KI-Funktionen' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet den KI-Assistenten Copilot über die Richtlinie ab. Eingaben an Copilot werden andernfalls zur Verarbeitung an Microsoft-Server gesendet.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Wert 'TurnOffWindowsCopilot' -Soll 1 -Standard $null `
    -Hinweis 'Microsoft führt diese Richtlinie inzwischen als veraltet: Sie steuert die ältere, in Windows eingebettete Copilot-Oberfläche. Der heutige Copilot ist eine eigene App - sie wird über die App-Entfernung losgeworden (Eintrag S14), und das Symbol blendet der nächste Punkt aus.' `
    -PolicyGrund 'Richtlinienzweig: Microsoft führt diese Vorgabe ausdrücklich als benutzerbezogen, deshalb HKCU. Einen sichtbaren Schalter gibt es dazu nicht.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI002' -Name 'Copilot-Symbol ausblenden' `
    -Kategorie 'KI-Funktionen' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Entfernt die Copilot-Schaltfläche aus der Taskleiste. Der Schalter unter Personalisierung, Taskleiste bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Wert 'ShowCopilotButton' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI003' -Name 'Recall deaktivieren' `
    -Kategorie 'KI-Funktionen' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows fortlaufend Bildschirmaufnahmen anfertigt und durchsuchbar speichert. Recall ist eine der weitreichendsten Datensammelfunktionen überhaupt, weil sie alles erfasst, was auf dem Bildschirm sichtbar war.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Wert 'DisableAIDataAnalysis' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: Microsoft führt diese Vorgabe für Gerät UND Benutzer, HKLM ist hier richtig. Auf Geräten ohne Recall-Unterstützung gibt es dazu keinen sichtbaren Schalter.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI004' -Name 'Click to Do deaktivieren' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die KI-gestützte Bildschirmanalyse "Click to Do" ab, die Bildschirminhalte auswertet, um Kontextaktionen vorzuschlagen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Wert 'DisableClickToDo' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: für Gerät und Benutzer dokumentiert, kein sichtbarer Schalter betroffen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI005' -Name 'Paint: Image Creator abschalten' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die KI-Bilderzeugung in Paint ab, die deine Eingaben zur Verarbeitung an Microsoft-Server sendet.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Wert 'DisableImageCreator' -Soll 1 -Standard $null `
    -PolicyGrund 'Paint liest seine Vorgaben ausschließlich aus diesem Schlüssel. Er liegt unter CurrentVersion\Policies und sperrt nichts in den Windows-Einstellungen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI006' -Name 'Paint: Cocreator abschalten' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Cocreator in Paint ab, der deine Zeichnung samt Texteingabe zur Verarbeitung an Microsoft-Server sendet.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Wert 'DisableCocreator' -Soll 1 -Standard $null `
    -PolicyGrund 'Wie beim vorigen Punkt: Paint liest nur von hier, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI007' -Name 'Paint: Generatives Füllen abschalten' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet das generative Füllen in Paint ab, bei dem Bildausschnitte zur Ergänzung an Microsoft-Server gehen.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Wert 'DisableGenerativeFill' -Soll 1 -Standard $null `
    -PolicyGrund 'Wie bei den beiden vorigen Punkten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI008' -Name 'Recall gar nicht erst bereitstellen' `
    -Kategorie 'KI-Funktionen' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows die Recall-Funktion überhaupt bereitstellt. Ergänzt KI003: Dort wird das Speichern von Bildschirmaufnahmen abgeschaltet, hier die Funktion selbst. Auf Rechnern ohne KI-Chip ohne sichtbare Wirkung.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Wert 'AllowRecallEnablement' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI009' -Name 'Einstellungs-Agent abschalten' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet den KI-Agenten in der Einstellungen-App ab, der Eingaben in natürlicher Sprache auswertet und Einstellungen selbst ändert. Auf Rechnern ohne KI-Chip ohne sichtbare Wirkung.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Wert 'DisableSettingsAgent' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI010' -Name 'Editor: KI-Funktionen abschalten' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die KI-Funktionen im Windows-Editor ab (Umschreiben, Zusammenfassen). Sie schicken den markierten Text zur Verarbeitung an Microsoft-Server.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\WindowsNotepad' -Wert 'DisableAIFeatures' -Soll 1 -Standard $null `
    -PolicyGrund 'Der Editor liest diesen Wert selbst aus dem Richtlinienzweig (gemessen: Wertname in Notepad.exe). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI011' -Name 'Bing-Chat-Berechtigung in Copilot entziehen' `
    -Kategorie 'KI-Funktionen' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows behandelt dein Konto als nicht berechtigt für den Bing-Chat in Copilot.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat' -Wert 'IsUserEligible' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KI012' -Name 'Recall auch pro Benutzer abschalten' `
    -Kategorie 'KI-Funktionen' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet Recall zusätzlich im Benutzerzweig ab. KI003 gilt bereits für den ganzen Rechner; dieser Punkt ist nur eine zweite Sicherung.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Wert 'DisableAIDataAnalysis' -Soll 1 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

# ==============================================================
#  4. STARTMENÜ, SPERRBILDSCHIRM, VORSCHLÄGE
#     Alle Punkte hier liegen außerhalb des Richtlinienzweigs
#     (Regel 1) - es wird nichts gesperrt.
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI001' -Name 'Stille App-Installationen unterbinden' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass der Content Delivery Manager im Hintergrund beworbene Apps nachinstalliert. Das ist der Mechanismus, über den Spiele und Testversionen ungefragt im Startmenü auftauchen - und auf Windows 11 Pro der einzige, der ihn wirksam abstellt. Ohne diesen Punkt kehren entfernte Apps nach einem Funktionsupdate zurück.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SilentInstalledAppsEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI002' -Name 'Vorgeschlagene Apps im Startmenü' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass im Startmenü Apps vorgeschlagen werden, die du nicht installiert hast. Ergänzt den vorigen Punkt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SystemPaneSuggestionsEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI003' -Name 'Sperrbildschirm-Inhalte (Spotlight)' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet Windows-Spotlight ab. Damit lädt der Sperrbildschirm keine Bilder mehr von Microsoft-Servern. Folge: Der Sperrbildschirm zeigt stattdessen ein festes Hintergrundbild deiner Wahl.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'RotatingLockScreenEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI004' -Name 'Sperrbildschirm-Einblendungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet zusätzlich die Textüberlagerungen und beworbenen Hinweise auf dem Sperrbildschirm ab. Ergänzt den vorigen Punkt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'RotatingLockScreenOverlayEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI005' -Name 'Sperrbildschirm: Tipps und Fakten' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert die Anzeige von Tipps, Werbung und "Wusstest du schon"-Hinweisen auf dem Sperrbildschirm.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-338387Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI006' -Name 'Tipps und Tricks Benachrichtigungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Benachrichtigungen "Tipps, Tricks und Vorschläge bei der Verwendung von Windows" ab. Diese Inhalte werden serverseitig ausgeliefert.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-338389Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI007' -Name 'Willkommensseite nach Updates' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert die "Willkommen bei Windows"-Seite nach Funktionsupdates, die neue Microsoft-Dienste bewirbt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-310093Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI008' -Name 'Vorschläge in den Einstellungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Entfernt die beworbenen Empfehlungsbanner innerhalb der Einstellungen-App. Erster von drei Kanälen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-338393Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI010' -Name 'Vorschläge in den Einstellungen (zweiter Kanal)' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Zweiter der drei Kanäle für beworbene Empfehlungsbanner in der Einstellungen-App.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-353694Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI011' -Name 'Vorschläge in den Einstellungen (dritter Kanal)' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Dritter und letzter Kanal für Empfehlungsbanner in der Einstellungen-App.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-353696Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI009' -Name 'App-Vorschläge im Startmenü (zweiter Kanal)' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schliesst den zweiten Auslieferungskanal für App-Vorschläge im Startmenü.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-338388Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI012' -Name 'Weiche Landung nach Updates' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Unterbindet die Einblendungen, mit denen Windows nach Updates neue Funktionen bewirbt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SoftLandingEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI013' -Name 'Empfehlungen im Startmenü (Iris)' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Entfernt den Empfehlungsbereich im unteren Teil des Startmenüs, der serverseitig befüllte Vorschläge anzeigt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Wert 'Start_IrisRecommendations' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI014' -Name 'Kontobezogene Hinweise im Startmenü' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Hinweise im Startmenü ab, die zur Einrichtung von Microsoft-Diensten auffordern.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Wert 'Start_AccountNotifications' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI015' -Name 'Kontobenachrichtigungen in den Einstellungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Entfernt die Werbebanner für Microsoft-365-Abonnements aus der Einstellungen-App.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Wert 'EnableAccountNotifications' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI016' -Name 'Einrichtungsseite nach Updates (SCOOBE)' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Unterbindet die ganzseitige Aufforderung "Lass uns dein Gerät vollständig einrichten", die nach größeren Updates erscheint und Microsoft-Dienste bewirbt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\UserProfileEngagement' -Wert 'ScoobeSystemSettingEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI017' -Name 'OneDrive-Werbung im Explorer' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Entfernt die Werbeeinblendungen für OneDrive und Microsoft 365 aus dem Datei-Explorer.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Wert 'ShowSyncProviderNotifications' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI018' -Name 'Widgets / News-Feed deaktivieren' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet das Widgets-Panel ab, das laufend mit Microsoft-Servern kommuniziert, um Nachrichten, Wetter und Werbung zu laden. Folge: Das Widgets-Symbol verschwindet aus der Taskleiste.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Wert 'AllowNewsAndInterests' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Widgets" unter Einstellungen, Personalisierung, Taskleiste wird danach gesperrt. Du kannst die Widgets dann nicht mehr über die Oberfläche wieder einschalten.' `
    -PolicyGrund 'Der Alternativwert blendet nur das Taskleisten-Symbol aus, der Dienst läuft weiter. Nur die Richtlinie schaltet wirklich ab.' `
    -Ausgemustert $true -ErsetztDurch @('APP:M11') `
    -Hinweis 'AUSGEMUSTERT: Windows verweigert das Anlegen des Schlüssels Dsh, auch Administratoren und SYSTEM (gemessen: "nicht autorisierter Vorgang" bei jedem Start). Vermutlich sperrt ihn der Windows-Schutztreiber UCPD. Den Schutz zu umgehen kommt nicht in Frage. Stattdessen wird das Widgets-Paket entfernt (App M11) - dann gibt es nichts mehr zu sperren.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI026' -Name 'Aktivitätsverlauf: Hauptschalter' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Aufzeichnung des Aktivitätsverlaufs insgesamt ab. Das ist der Hauptschalter der Funktion; die beiden folgenden Punkte ergänzen ihn.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'EnableActivityFeed' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: den Aktivitätsverlauf steuert Windows ausschließlich hierüber.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI019' -Name 'Aktivitätsverlauf: Veröffentlichen durch Apps' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Apps ihre Aktivitäten in den Verlauf schreiben.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'PublishUserActivities' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig, gehört zum vorigen Punkt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI027' -Name 'Aktivitätsverlauf: Übertragung ans Konto' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Unterbindet die Übertragung des Aktivitätsverlaufs an dein Microsoft-Konto. Das ist der Punkt, der den Datenabfluss tatsächlich stoppt - die beiden vorigen betreffen nur die lokale Aufzeichnung.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'UploadUserActivities' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig, gehört zu den beiden vorigen Punkten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI020' -Name 'Zuletzt geöffnete Programme nicht merken' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows eine Liste der zuletzt gestarteten Programme führt und im Startmenü anzeigt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Wert 'Start_TrackProgs' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI029' -Name 'Zuletzt geöffnete Dokumente nicht merken' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Gegenstück zum vorigen Punkt für Dateien statt Programme: Windows führt dann keine Liste zuletzt geöffneter Dokumente mehr.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Wert 'Start_TrackDocs' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI030' -Name 'Schnellzugriff: zuletzt verwendete Dateien' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Entfernt die Liste zuletzt verwendeter Dateien aus dem Schnellzugriff des Datei-Explorers. Wer den Rechner mit anderen teilt, verrät damit nicht mehr, woran er zuletzt gearbeitet hat.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Wert 'ShowRecent' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI031' -Name 'Schnellzugriff: häufig verwendete Ordner' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Entfernt die Liste häufig verwendeter Ordner aus dem Schnellzugriff. Ergänzt den vorigen Punkt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Wert 'ShowFrequent' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI032' -Name 'Wechseldatenträger im Explorer nur einmal anzeigen' `
    -Kategorie 'Explorer' -Stufe 'Standard' -Typ 'SchluesselWeg' `
    -Erklaerung 'Windows zeigt USB-Sticks und andere Wechseldatenträger im Navigationsbereich doppelt: unter "Dieser PC" und noch einmal einzeln. Das betrifft auch VeraCrypt-Laufwerke, die als Wechseldatenträger eingehängt sind. Danach erscheinen sie nur noch unter "Dieser PC". Wirkt nach der nächsten Anmeldung.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}' `
    -Soll @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}') `
    -Standard 'Removable Drives' `
    -Hinweis 'Der Eintrag gehört Windows; der Rückbau legt ihn mit seinem ursprünglichen Wert wieder an.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI033' -Name 'OneDrive nicht im Navigationsbereich' `
    -Kategorie 'Explorer' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Blendet den Knoten "OneDrive - Personal" links im Explorer aus, der deine Ordner ein zweites Mal zeigt. OneDrive selbst funktioniert weiter, der Ordner bleibt unter deinem Benutzerordner erreichbar. Wird nur gesetzt, wenn OneDrive den Knoten angelegt hat.' `
    -Pfad 'HKCU:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Wert 'System.IsPinnedToNameSpaceTree' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true `
    -Hinweis 'Ein OneDrive-Update kann den Knoten wieder einblenden; der Wächter blendet ihn dann bei der nächsten Anmeldung wieder aus.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI021' -Name 'Werbe-Nachinstallationen systemweit sperren' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert auf Enterprise- und Education-Systemen, dass Windows nach einem Funktionsupdate selbsttätig beworbene Apps nachinstalliert. Auf Pro und Home setzt Microsoft diese Richtlinie nicht um - dort erledigt das der Punkt "Stille App-Installationen unterbinden".' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableWindowsConsumerFeatures' -Soll 1 -Standard $null `
    -NurEdition @('Enterprise','Education','IoTEnterprise') `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter vorhanden. Microsoft dokumentiert die Richtlinie ausdrücklich ohne Pro.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI022' -Name 'Cloud-optimierte Inhalte sperren' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schliesst den Kanal, über den Windows serverseitig ausgewählte Inhalte und Empfehlungen in die Oberfläche einspielt. Gehört zur selben Richtlinienfamilie wie der vorige Punkt und wird auf Pro und Home ebenfalls nicht durchgesetzt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableCloudOptimizedContent' -Soll 1 -Standard $null `
    -NurEdition @('Enterprise','Education','IoTEnterprise') `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter vorhanden.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI024' -Name 'Sicherungs-Erinnerungen abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Unterbindet die wiederkehrenden Aufforderungen, eine Windows-Sicherung in OneDrive einzurichten.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder' -Wert 'Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI028' -Name 'Sprachliste nicht an Webseiten weitergeben' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows deine Liste bevorzugter Sprachen an Webseiten weiterreicht. Die Sprachliste ist ein verbreitetes Merkmal beim Wiedererkennen von Browsern. Das ist der vierte der vier Schalter unter Datenschutz, Allgemein - er bleibt bedienbar.' `
    -Pfad 'HKCU:\Control Panel\International\User Profile' -Wert 'HttpAcceptLanguageOptOut' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI034' -Name 'Kamera im Sperrbildschirm abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass sich die Kamera vom Sperrbildschirm aus starten lässt, also ohne Anmeldung. Ohne Kamera am Rechner ohne Wirkung.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Wert 'NoLockScreenCamera' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI035' -Name 'Hinweise zum Microsoft-Konto abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Unterbindet Inhalte, die Windows anhand deines Microsoft-Kontos einblendet (Kontostatus, Abo- und Speicherhinweise).' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableConsumerAccountStateContent' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI036' -Name 'Vorschläge in der Zeitachse' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet einen weiteren Werbe- und Vorschlagskanal des Content Delivery Managers ab, ursprünglich für die Zeitachse. Der Schalter bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContent-353698Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI037' -Name 'Explorer: keine Dateien von office.com' `
    -Kategorie 'Explorer' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Startseite des Explorers zeigt keine zuletzt verwendeten Dateien aus der Microsoft-Cloud (office.com, OneDrive) mehr; Windows fragt sie dafür nicht mehr bei Microsoft ab. Der Schalter in den Ordneroptionen bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Wert 'ShowCloudFilesInQuickAccess' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI038' -Name 'Keine Benachrichtigungen im Sperrbildschirm' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Benachrichtigungen erscheinen nicht mehr auf dem Sperrbildschirm, wo sie jeder lesen kann, der vor dem Gerät steht.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' -Wert 'NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI039' -Name 'Hintergrund-Apps verbieten' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Store-Apps laufen nur, solange ihr Fenster offen ist: keine Hintergrund-Synchronisation, keine Live-Benachrichtigungen von Store-Apps. Desktop-Programme sind nicht betroffen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Wert 'GlobalUserDisabled' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI040' -Name 'Alle App-Benachrichtigungen abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Keine App zeigt mehr Benachrichtigungen an - weder Pop-ups noch Einträge in der Mitteilungszentrale.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications' -Wert 'ToastEnabled' -Soll 0 -Standard 1 `
    -VorgabeNein $true `
    -Hinweis 'Auch Windows-Sicherheit meldet einen Virenfund dann nicht mehr per Benachrichtigung; du siehst ihn nur noch in Windows-Sicherheit selbst und im Protokoll des Wächters.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI041' -Name 'Blickpunkt-Symbol auf dem Desktop ausblenden' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Blendet das Symbol "Weitere Informationen zu diesem Bild" aus, das Windows-Blickpunkt auf dem Desktop anlegt. Ohne Blickpunkt-Hintergrund ohne Wirkung.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -Wert '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}' -Soll 1 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI042' -Name 'Windows-Tipps per Richtlinie abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows zeigt keine Tipps mehr an, die es anhand der Diagnosedaten auswählt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableSoftLanding' -Soll 1 -Standard $null `
    -NurEdition @('Enterprise', 'Education', 'IoTEnterprise') `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI043' -Name 'Alle Blickpunkt-Funktionen abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Schaltet Windows-Blickpunkt in einem Schritt ab: Bilder auf dem Sperrbildschirm, Tipps und Vorschläge für Microsoft-Angebote. Weniger Datenverkehr zu Microsoft.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableWindowsSpotlightFeatures' -Soll 1 -Standard $null `
    -Hinweis 'Auf dem Sperrbildschirm erscheinen danach keine wechselnden Blickpunkt-Bilder mehr.' `
    -PolicyGrund 'Nur der Richtlinienzweig schaltet alle Blickpunkt-Funktionen auf einmal ab.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI044' -Name 'Keine App-Benachrichtigungen auf dem Sperrbildschirm' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Auf dem gesperrten Bildschirm erscheinen keine Benachrichtigungen von Apps mehr - wer vor dem gesperrten Rechner sitzt, liest keine Nachrichten mit.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'DisableLockScreenAppNotifications' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI045' -Name '"App im Store suchen" bei unbekannten Dateien ausblenden' `
    -Kategorie 'Explorer' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Beim Öffnen einer Datei ohne passendes Programm bietet Windows nicht mehr an, im Microsoft Store danach zu suchen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'NoUseStoreOpenWith' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI046' -Name 'Häufig genutzte Apps nicht nachverfolgen' `
    -Kategorie 'Explorer' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows merkt sich nicht mehr, welche Apps du am häufigsten nutzt und suchst; Apps erscheinen in Suche und Auswahllisten alphabetisch.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI' -Wert 'DisableMFUTracking' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI047' -Name 'Aufgabe "Abzüge online bestellen" entfernen' `
    -Kategorie 'Explorer' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Entfernt bei Bildern die Aufgabe, Abzüge online zu bestellen; der Assistent lädt dafür eine Anbieterliste aus dem Netz.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoOnlinePrintsWizard' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI048' -Name 'Aufgabe "Im Web veröffentlichen" entfernen' `
    -Kategorie 'Explorer' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Entfernt bei Dateien und Ordnern die Aufgabe, sie im Web zu veröffentlichen.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoPublishingWizard' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI049' -Name 'Keine Anbieterlisten für Web-Assistenten laden' `
    -Kategorie 'Explorer' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Die Assistenten zum Veröffentlichen im Web und zum Bestellen von Abzügen laden keine Anbieterlisten mehr aus dem Netz.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoWebServices' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

# ==============================================================
#  5. APP-BERECHTIGUNGEN
#     Alle Punkte hier nutzen den Zustimmungsspeicher
#     (ConsentStore) - Regel 1. Die Schalter unter
#     Einstellungen, Datenschutz und Sicherheit bleiben
#     vollständig bedienbar. Der Richtlinienweg
#     (AppPrivacy\LetAppsAccess...) würde die ganze Seite
#     sperren und wird deshalb bewusst NICHT verwendet.
#
#     Der Ausgangszustand wird gemessen, nicht geraten: Wer bei
#     der Windows-Einrichtung den Standortzugriff abgelehnt hat,
#     bekommt ihn durch den Rückbau nicht nachträglich erteilt.
# ==============================================================
$Global:OrcaAppBerechtigungen = @(
    @{ Id='APP001'; Schluessel='webcam';                Name='Kamerazugriff für Apps';            Stufe='Standard'; Text='Sperrt den Kamerazugriff für Apps aus dem Microsoft Store. Klassische Desktop-Programme sind davon nicht betroffen und funktionieren weiter.' }
    @{ Id='APP002'; Schluessel='microphone';            Name='Mikrofonzugriff für Apps';          Stufe='Standard'; Text='Sperrt den Mikrofonzugriff für Apps aus dem Microsoft Store. Klassische Desktop-Programme bleiben unberührt.' }
    @{ Id='APP003'; Schluessel='location';              Name='Standortzugriff für Apps';          Stufe='Standard'; Text='Sperrt den Zugriff auf deinen Standort für Apps aus dem Microsoft Store.' }
    @{ Id='APP004'; Schluessel='contacts';              Name='Kontaktzugriff für Apps';           Stufe='Standard'; Text='Sperrt den Zugriff auf deine Kontakte.' }
    @{ Id='APP005'; Schluessel='appointments';          Name='Kalenderzugriff für Apps';          Stufe='Standard'; Text='Sperrt den Zugriff auf deinen Kalender.' }
    @{ Id='APP006'; Schluessel='phoneCallHistory';      Name='Anrufliste für Apps';               Stufe='Standard'; Text='Sperrt den Zugriff auf die Anrufliste.' }
    @{ Id='APP007'; Schluessel='email';                 Name='E-Mail-Zugriff für Apps';           Stufe='Standard'; Text='Sperrt den Zugriff auf deine E-Mails.' }
    @{ Id='APP008'; Schluessel='userDataTasks';         Name='Aufgabenzugriff für Apps';          Stufe='Standard'; Text='Sperrt den Zugriff auf deine Aufgabenlisten.' }
    @{ Id='APP009'; Schluessel='chat';                  Name='Nachrichtenzugriff für Apps';       Stufe='Standard'; Text='Sperrt den Zugriff auf SMS- und Chatnachrichten.' }
    @{ Id='APP010'; Schluessel='radios';                Name='Funkgeräte-Steuerung für Apps';    Stufe='Maximum';  Text='Verhindert, dass Apps Bluetooth und WLAN selbsttätig ein- und ausschalten.' }
    @{ Id='APP011'; Schluessel='bluetoothSync';         Name='Kopplung mit anderen Geräten';      Stufe='Maximum';  Text='Verhindert, dass Apps Daten mit nicht gekoppelten Geräten in der Umgebung austauschen.' }
    @{ Id='APP012'; Schluessel='userAccountInformation';Name='Kontoinformationen für Apps';       Stufe='Standard'; Text='Sperrt den Zugriff auf deinen Namen, dein Bild und andere Kontoangaben.' }
    @{ Id='APP013'; Schluessel='appDiagnostics';        Name='App-Diagnose für Apps';             Stufe='Standard'; Text='Verhindert, dass Apps Diagnoseinformationen über andere laufende Apps auslesen.' }
    @{ Id='APP014'; Schluessel='documentsLibrary';      Name='Dokumentenordner für Apps';         Stufe='Maximum';  Text='Sperrt den Zugriff auf deinen Dokumentenordner für Store-Apps.' }
    @{ Id='APP015'; Schluessel='picturesLibrary';       Name='Bilderordner für Apps';             Stufe='Maximum';  Text='Sperrt den Zugriff auf deinen Bilderordner für Store-Apps.' }
    @{ Id='APP016'; Schluessel='videosLibrary';         Name='Videoordner für Apps';              Stufe='Maximum';  Text='Sperrt den Zugriff auf deinen Videoordner für Store-Apps.' }
    @{ Id='APP017'; Schluessel='systemAIModels';        Name='Generative KI für Apps';            Stufe='Standard'; Text='Verhindert, dass Apps die in Windows eingebauten KI-Modelle nutzen.' }
    @{ Id='APP018'; Schluessel='humanPresence';         Name='Anwesenheitserkennung für Apps';    Stufe='Standard'; Text='Verhindert, dass Apps über einen Anwesenheitssensor erkennen, ob du vor dem Gerät sitzt. Ohne Sensor gibt es den Schalter nicht, dann wird nichts angelegt.' }
    @{ Id='APP019'; Schluessel='userNotificationListener'; Name='Benachrichtigungen lesen';      Stufe='Standard'; Text='Verhindert, dass Apps deine Benachrichtigungen mitlesen.' }
    @{ Id='APP020'; Schluessel='activity';              Name='Bewegungsdaten für Apps';           Stufe='Standard'; Text='Sperrt den Zugriff auf Bewegungs- und Aktivitätsdaten (Schritte, Sitzen, Gehen).' }
    @{ Id='APP021'; Schluessel='phoneCall';             Name='Telefonanrufe für Apps';            Stufe='Standard'; Text='Verhindert, dass Apps Telefonanrufe führen oder verwalten.' }
    @{ Id='APP022'; Schluessel='cellularData';          Name='Mobilfunkdaten für Apps';           Stufe='Maximum';  Text='Sperrt den Zugriff auf die Mobilfunkverbindung. Ohne Mobilfunkmodem ohne Wirkung.' }
    @{ Id='APP023'; Schluessel='gazeInput';             Name='Augenverfolgung für Apps';          Stufe='Standard'; Text='Sperrt den Zugriff auf Geräte zur Augenverfolgung.' }
    @{ Id='APP024'; Schluessel='downloadsFolder';       Name='Downloadordner für Apps';           Stufe='Maximum';  Text='Sperrt den Zugriff auf deinen Downloadordner für Store-Apps.' }
    @{ Id='APP025'; Schluessel='wifiData';              Name='WLAN-Informationen für Apps';       Stufe='Standard'; Text='Verhindert, dass Apps die Namen der WLANs in deiner Umgebung auslesen. Über WLAN-Namen lässt sich dein Standort bestimmen, auch wenn der Standortzugriff gesperrt ist.' }
    @{ Id='APP026'; Schluessel='broadFileSystemAccess'; Name='Dateisystem für Apps';              Stufe='Maximum';  Text='Store-Apps verlieren den Zugriff auf das gesamte Dateisystem und kommen nur noch an Dateien, die du selbst öffnest.' }
    @{ Id='APP027'; Schluessel='musicLibrary';          Name='Musikordner für Apps';              Stufe='Maximum';  Text='Sperrt den Zugriff auf deinen Musikordner für Store-Apps. Der Media Player zeigt deine Musik dann nicht mehr in seiner Bibliothek; einzelne Dateien spielt er weiter ab.' }
    @{ Id='APP028'; Schluessel='graphicsCaptureProgrammatic'; Name='Bildschirmaufnahme für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Das Snipping Tool ist eine Store-App und kann danach keine Ausschnitte mehr aufnehmen.'; Text='Store-Apps dürfen keine Fenster oder den Bildschirm aufnehmen.' }
    @{ Id='APP029'; Schluessel='graphicsCaptureWithoutBorder'; Name='Bildschirmaufnahme ohne Rahmen für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Wie beim vorigen Punkt: betrifft auch das Snipping Tool.'; Text='Store-Apps dürfen keine Aufnahmen ohne den gelben Warnrahmen machen.' }
    @{ Id='APP030'; Schluessel='graphicsCaptureProgrammatic\NonPackaged'; Name='Bildschirmaufnahme für Desktop-Programme'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Bricht die Fensteraufnahme in OBS und die Bildschirmübertragung in Discord, Teams und ähnlichen Programmen.'; Text='Auch klassische Desktop-Programme dürfen keine Fenster oder den Bildschirm über die Windows-Schnittstelle aufnehmen.' }
    @{ Id='APP031'; Schluessel='graphicsCaptureWithoutBorder\NonPackaged'; Name='Bildschirmaufnahme ohne Rahmen für Desktop-Programme'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Wie beim vorigen Punkt.'; Text='Desktop-Programme dürfen keine Aufnahmen ohne Warnrahmen machen.' }
    @{ Id='APP032'; Schluessel='passkeys'; Name='Passkeys für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Kann Passwortmanager abschneiden, die unter Windows als Passkey-Anbieter arbeiten.'; Text='Apps dürfen keine Passkeys verwenden.' }
    @{ Id='APP033'; Schluessel='passkeysEnumeration'; Name='Liste der Passkeys für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Wie beim vorigen Punkt.'; Text='Apps dürfen die Liste deiner gespeicherten Passkeys nicht auslesen.' }
    @{ Id='APP034'; Schluessel='bluetooth'; Name='Bluetooth-Geräte für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Bricht Store-Apps für Zubehör, etwa für Controller oder Kopfhörer.'; Text='Store-Apps dürfen nicht mit gekoppelten Bluetooth-Geräten sprechen.' }
    @{ Id='APP035'; Schluessel='humanInterfaceDevice'; Name='Eingabegeräte (HID) für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Bricht Store-Apps, die Mäuse, Tastaturen oder Controller einstellen.'; Text='Store-Apps dürfen nicht direkt auf Eingabegeräte zugreifen.' }
    @{ Id='APP036'; Schluessel='sensors.custom'; Name='Eigene Sensoren für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis=''; Text='Store-Apps dürfen keine herstellereigenen Sensoren auslesen.' }
    @{ Id='APP037'; Schluessel='serialCommunication'; Name='Serielle Schnittstellen für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Bricht Store-Apps für Mikrocontroller und Messgeräte.'; Text='Store-Apps dürfen nicht über serielle Schnittstellen kommunizieren.' }
    @{ Id='APP038'; Schluessel='usb'; Name='USB-Geräte für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis='Bricht Store-Apps für Zubehör, das über USB eingestellt wird.'; Text='Store-Apps dürfen nicht direkt auf USB-Geräte zugreifen.' }
    @{ Id='APP039'; Schluessel='wiFiDirect'; Name='Wi-Fi Direct für Apps'; Stufe='Zusatz'; VorgabeNein=$true; Hinweis=''; Text='Store-Apps dürfen keine direkten WLAN-Verbindungen zu anderen Geräten aufbauen.' }
)

foreach ($b in $Global:OrcaAppBerechtigungen) {
    $Global:OrcaEinstellungen += New-OrcaSetting -Id $b.Id -Name $b.Name `
        -Kategorie 'App-Berechtigungen' -Stufe $b.Stufe -Typ 'Registry' `
        -Erklaerung "$($b.Text) Der Schalter in den Einstellungen bleibt bedienbar - du kannst die Berechtigung dort jederzeit wieder erteilen, und der Wächter setzt sie beim nächsten Start zurück." `
        -Pfad "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$($b.Schluessel)" `
        -Wert 'Value' -Soll 'Deny' -Standard 'Allow' -RegTyp 'String' `
        -NurWennVorhanden $true -VorgabeNein ([bool]$b.VorgabeNein) -Hinweis ([string]$b.Hinweis)
}

$Global:OrcaAppBerechtigungenRechner = @(
    @{ Id='APP101'; Schluessel='appDiagnostics'; Anzeige='App-Diagnose'; Abschneidend=$false }
    @{ Id='APP102'; Schluessel='appointments'; Anzeige='Kalender'; Abschneidend=$false }
    @{ Id='APP103'; Schluessel='bluetooth'; Anzeige='Bluetooth-Geräte'; Abschneidend=$true }
    @{ Id='APP104'; Schluessel='bluetoothSync'; Anzeige='ungekoppelte Geräte'; Abschneidend=$false }
    @{ Id='APP105'; Schluessel='broadFileSystemAccess'; Anzeige='Dateisystem'; Abschneidend=$true }
    @{ Id='APP106'; Schluessel='cellularData'; Anzeige='Mobilfunkdaten'; Abschneidend=$false }
    @{ Id='APP107'; Schluessel='chat'; Anzeige='Nachrichten'; Abschneidend=$false }
    @{ Id='APP108'; Schluessel='contacts'; Anzeige='Kontakte'; Abschneidend=$false }
    @{ Id='APP109'; Schluessel='documentsLibrary'; Anzeige='Dokumente'; Abschneidend=$false }
    @{ Id='APP110'; Schluessel='downloadsFolder'; Anzeige='Downloads'; Abschneidend=$false }
    @{ Id='APP111'; Schluessel='email'; Anzeige='E-Mail'; Abschneidend=$false }
    @{ Id='APP112'; Schluessel='gazeInput'; Anzeige='Augenverfolgung'; Abschneidend=$false }
    @{ Id='APP113'; Schluessel='graphicsCaptureProgrammatic'; Anzeige='Bildschirmaufnahme'; Abschneidend=$true }
    @{ Id='APP114'; Schluessel='graphicsCaptureWithoutBorder'; Anzeige='Bildschirmaufnahme ohne Rahmen'; Abschneidend=$true }
    @{ Id='APP115'; Schluessel='humanInterfaceDevice'; Anzeige='Eingabegeräte (HID)'; Abschneidend=$true }
    @{ Id='APP116'; Schluessel='humanPresence'; Anzeige='Anwesenheitserkennung'; Abschneidend=$false }
    @{ Id='APP117'; Schluessel='microphone'; Anzeige='Mikrofon'; Abschneidend=$true }
    @{ Id='APP118'; Schluessel='musicLibrary'; Anzeige='Musik'; Abschneidend=$false }
    @{ Id='APP119'; Schluessel='passkeys'; Anzeige='Passkeys'; Abschneidend=$true }
    @{ Id='APP120'; Schluessel='passkeysEnumeration'; Anzeige='Liste der Passkeys'; Abschneidend=$true }
    @{ Id='APP121'; Schluessel='phoneCall'; Anzeige='Telefonanrufe'; Abschneidend=$false }
    @{ Id='APP122'; Schluessel='phoneCallHistory'; Anzeige='Anrufliste'; Abschneidend=$false }
    @{ Id='APP123'; Schluessel='picturesLibrary'; Anzeige='Bilder'; Abschneidend=$false }
    @{ Id='APP124'; Schluessel='radios'; Anzeige='Funkgeräte-Steuerung'; Abschneidend=$false }
    @{ Id='APP125'; Schluessel='sensors.custom'; Anzeige='eigene Sensoren'; Abschneidend=$false }
    @{ Id='APP126'; Schluessel='serialCommunication'; Anzeige='serielle Schnittstellen'; Abschneidend=$true }
    @{ Id='APP127'; Schluessel='systemAIModels'; Anzeige='generative KI'; Abschneidend=$false }
    @{ Id='APP128'; Schluessel='usb'; Anzeige='USB-Geräte'; Abschneidend=$true }
    @{ Id='APP129'; Schluessel='userAccountInformation'; Anzeige='Kontoinformationen'; Abschneidend=$false }
    @{ Id='APP130'; Schluessel='userDataTasks'; Anzeige='Aufgaben'; Abschneidend=$false }
    @{ Id='APP131'; Schluessel='userNotificationListener'; Anzeige='Benachrichtigungen lesen'; Abschneidend=$false }
    @{ Id='APP132'; Schluessel='videosLibrary'; Anzeige='Videos'; Abschneidend=$false }
    @{ Id='APP133'; Schluessel='webcam'; Anzeige='Kamera'; Abschneidend=$true }
    @{ Id='APP134'; Schluessel='wifiData'; Anzeige='WLAN-Informationen'; Abschneidend=$false }
    @{ Id='APP135'; Schluessel='wiFiDirect'; Anzeige='Wi-Fi Direct'; Abschneidend=$false }
)

# Rechnerschalter: der Hauptschalter oben auf jeder Datenschutzseite
# ("Zugriff auf ... auf diesem Gerät"). Gilt für alle Konten; bei Kamera,
# Mikrofon und Standort auch für Desktop-Programme. Für ein einziges Konto
# genügt der Benutzerschalter, deshalb stehen diese Punkte in keinem Profil.
foreach ($b in $Global:OrcaAppBerechtigungenRechner) {
    $folge = if ($b.Abschneidend) { ' Programme, die darauf angewiesen sind, verlieren den Zugriff - bei Kamera und Mikrofon auch Desktop-Programme wie Discord oder Steam.' } else { '' }
    $Global:OrcaEinstellungen += New-OrcaSetting -Id $b.Id -Name "$($b.Anzeige): für alle Konten sperren" `
        -Kategorie 'App-Berechtigungen' -Stufe 'Zusatz' -Typ 'Registry' `
        -Erklaerung "Schaltet den Zugriff auf $($b.Anzeige) für alle Konten dieses Rechners ab (Hauptschalter oben auf der Datenschutzseite). Der Schalter bleibt für Administratoren bedienbar.$folge" `
        -Pfad "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$($b.Schluessel)" `
        -Wert 'Value' -Soll 'Deny' -Standard 'Allow' -RegTyp 'String' `
        -NurWennVorhanden $true -VorgabeNein ([bool]$b.Abschneidend)
}

# ==============================================================
#  6. SUCHE UND WEB-INTEGRATION
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH002' -Name 'Bing-Vorschläge im Suchfeld abschalten' `
    -Kategorie 'Suche' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass deine Eingaben im Startmenü an Bing gesendet werden, um Web-Ergebnisse und Vorschläge einzublenden. Das ist unter Windows 11 der Wert, der die Websuche tatsächlich stoppt - kein Datenabfluss mehr beim bloßen Tippen.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'DisableSearchBoxSuggestions' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein eigener sichtbarer Schalter vorhanden. Der früher übliche Wert BingSearchEnabled wird seit Windows 10 1909 ignoriert.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH001' -Name 'Websuche im Suchdienst abschalten' `
    -Kategorie 'Suche' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Web-Anbindung des Windows-Suchdienstes ab. Ergänzt den vorigen Punkt auf einer tieferen Ebene; allein genügt dieser Wert unter Windows 11 nicht, um die Bing-Ergebnisse im Startmenü zu unterbinden.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'DisableWebSearch' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: Windows 11 bietet für die Websuche keinen eigenen Schalter mehr, es wird also nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH003' -Name 'Cloud-Suche (Arbeitskonto)' `
    -Kategorie 'Suche' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Deaktiviert die Einbindung von Cloud-Inhalten eines Arbeits- oder Schulkontos in die lokale Windows-Suche.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' -Wert 'IsAADCloudSearchEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH004' -Name 'Cloud-Suche (privates Konto)' `
    -Kategorie 'Suche' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Deaktiviert die Einbindung von OneDrive- und Outlook-Inhalten deines privaten Microsoft-Kontos in die lokale Suche. Für einen privaten Rechner ist das der zutreffende Punkt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' -Wert 'IsMSACloudSearchEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH005' -Name 'Suchverlauf im Gerät deaktivieren' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert das Speichern deines lokalen Suchverlaufs.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' -Wert 'IsDeviceSearchHistoryEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH006' -Name 'Suchhervorhebungen abschalten' `
    -Kategorie 'Suche' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Entfernt die täglich wechselnden, serverseitig geladenen Bilder und Themen aus dem Suchfeld.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' -Wert 'IsDynamicSearchBoxEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH007' -Name 'Cortana deaktivieren' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Sprachassistenten Cortana ab, der Spracheingaben und Kontextdaten an Microsoft überträgt. In aktuellen Windows-11-Versionen ist Cortana bereits weitgehend entfernt - der Punkt wirkt dann vorbeugend.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'AllowCortana' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: nur so abschaltbar, kein sichtbarer Schalter betroffen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH008' -Name 'Cortana-Einwilligung zurücknehmen' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Nimmt die Einwilligung zur Cortana-Nutzung in deinem Benutzerprofil zurück und ergänzt damit den vorigen Punkt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Wert 'CortanaConsent' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH009' -Name 'Suchindex: keine Wechseldatenträger' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows nimmt keine Dateien von USB-Sticks und anderen Wechseldatenträgern in den Suchindex auf. Der Index liegt im Klartext auf C: - wer einen entsperrten verschlüsselten Datenträger indizieren lässt, hinterlässt dessen Inhalte dort.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'DisableRemovableDriveIndexing' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: Dazu gibt es in den Windows-Einstellungen keinen Schalter.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH010' -Name 'Suchindex: nur C: und D:' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Indexsperre' `
    -Erklaerung 'Sperrt alle Laufwerksbuchstaben außer C: und D: für den Suchindex. VeraCrypt hängt seine Laufwerke unter freien Buchstaben ein; ohne diese Sperre könnte deren Inhalt im Klartext-Index auf C: landen, sobald jemand sie hinzufügt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search\PreventIndexingCertainPaths' `
    -Soll @('A','B','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z') `
    -PolicyGrund 'Richtlinienzweig: Einen Weg außerhalb der Richtlinie gibt es für eine Sperre nicht. Ob die Einstellungen-Seite Windows durchsuchen dadurch einen Verwaltungshinweis zeigt, ist nach dem ersten Lauf nachzusehen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH011' -Name 'Suchfeld in der Taskleiste ausblenden' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Blendet das Suchfeld in der Taskleiste aus; die Suche öffnest du weiter mit der Windows-Taste. Das Feld lädt sonst Suchhervorhebungen aus dem Netz. Der Schalter unter Personalisierung, Taskleiste bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Wert 'SearchboxTaskbarMode' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH012' -Name 'Keine Cloud-Suche (OneDrive, SharePoint)' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Windows-Suche durchsucht keine Cloud-Quellen wie OneDrive oder SharePoint mehr.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'AllowCloudSearch' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH013' -Name 'Cortana nicht auf dem Sperrbildschirm' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Cortana nimmt auf dem gesperrten Bildschirm keine Sprachbefehle an.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'AllowCortanaAboveLock' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH014' -Name 'Suchindex: keine verschlüsselten Dateien' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Suchindex nimmt keine verschlüsselten Dateien auf - deren Inhalt landet sonst unverschlüsselt im Index.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'AllowIndexingEncryptedStoresOrItems' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH015' -Name 'Suchindex: keine automatische Spracherkennung' `
    -Kategorie 'Suche' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Der Suchindex erkennt die Sprache von Inhalten nicht immer automatisch. Kein belegter Datenschutzgewinn; der Vollständigkeit halber.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'AlwaysUseAutoLangDetection' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH016' -Name 'Suchindex: keine Abfragen von anderen Rechnern' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Andere Rechner im Netz können den Suchindex dieses Rechners nicht abfragen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'PreventRemoteQueries' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH017' -Name 'Suche ohne Standortdaten' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Suche und Cortana verwenden keine Positionsdaten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'AllowSearchToUseLocation' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH018' -Name 'Suchverlauf nicht speichern' `
    -Kategorie 'Suche' -Stufe 'Maximum' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Windows speichert deine Suchbegriffe nicht mehr und zeigt keinen Suchverlauf an.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'DisableSearchHistory' -Soll 1 -Standard $null `
    -Hinweis 'Zuletzt gesuchte Begriffe werden danach nicht mehr vorgeschlagen.' `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH019' -Name 'Keine Websuche und keine Webergebnisse' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Suche fragt nicht im Web nach und zeigt keine Webergebnisse an. Ergänzt SUCH001.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'ConnectedSearchUseWeb' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SUCH020' -Name 'Suchhervorhebungen per Richtlinie abschalten' `
    -Kategorie 'Suche' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Suche zeigt keine Hervorhebungen mehr an, die Windows aus dem Netz lädt (Feiertage, Jahrestage, Inhalte von Microsoft).' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Wert 'EnableDynamicContentInWSB' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

# ==============================================================
#  7. STANDORT
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC004' -Name 'Standortdienste systemweit abschalten' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Legt den Hauptschalter "Standortdienste" unter Datenschutz und Sicherheit, Standort um. Das ist der Wert, den die Einstellungen-App selbst schreibt - der Schalter bleibt bedienbar, und der Wächter hält ihn.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Wert 'Value' -Soll 'Deny' -Standard 'Allow' -RegTyp 'String' `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC001' -Name 'Standortsensor deaktivieren' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Standortermittlung über den Systemsensor ab und ergänzt damit den Hauptschalter auf einer tieferen Ebene. Folge: Apps wie Wetter oder Karten können deinen Standort nicht mehr automatisch bestimmen - du kannst ihn dort aber weiterhin manuell eingeben.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}' -Wert 'SensorPermissionState' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC002' -Name 'Standortdienst-Dienst stoppen' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Dienst' `
    -Erklaerung 'Deaktiviert den zugehörigen Windows-Dienst zur Geolokalisierung.' `
    -Wert 'lfsvc' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Mit deaktiviertem Dienst funktioniert auch "Zeitzone automatisch festlegen" nicht mehr. Im Alltag zu Hause folgenlos, auf Reisen musst du die Zeitzone dann selbst umstellen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC003' -Name '"Mein Gerät suchen" abschalten' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows regelmäßig Standortdaten an Microsoft sendet, um das Gerät im Verlustfall wiederzufinden. Folge: Die Funktion "Mein Gerät suchen" steht nicht mehr zur Verfügung.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice' -Wert 'LocationSyncEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC005' -Name 'Standort für Skripte sperren' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verbietet Skripten (etwa in alten Webseiten-Steuerelementen), den Standort abzufragen. Ergänzt die systemweite Standortsperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Wert 'DisableLocationScripting' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC006' -Name 'Keine Ausnahme von der Standortsperre' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Möglichkeit ab, dass Apps die Standortsperre über eine Ausnahme umgehen. Der Schalter bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\UserLocationOverridePrivacySetting' -Wert 'Value' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC007' -Name 'Standort per Richtlinie abschalten' `
    -Kategorie 'Standort' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Standortfunktion für alle Konten über die Richtlinie ab. LOC004 erledigt dasselbe ohne Sperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Wert 'DisableLocation' -Soll 1 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die gesamte Seite Datenschutz, Standort wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig gilt kontoübergreifend und lässt sich nicht aus der Oberfläche heraus ändern.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC008' -Name 'Alle Sensoren abschalten' `
    -Kategorie 'Standort' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Sensoren des Geräts ab (Lage, Bewegung, Helligkeit, Standort).' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Wert 'DisableSensors' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Auf Laptops und Tablets fallen danach die automatische Bildschirmdrehung und die Helligkeitsregelung weg.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC009' -Name 'Windows-Standortanbieter abschalten' `
    -Kategorie 'Standort' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Standortanbieter von Windows ab, der den Standort aus WLAN-Netzen und IP-Adresse über Microsoft-Dienste ermittelt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Wert 'DisableWindowsLocationProvider' -Soll 1 -Standard $null `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC010' -Name '"Mein Gerät suchen" per Richtlinie sperren' `
    -Kategorie 'Standort' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Sperrt "Mein Gerät suchen" für alle Konten über die Richtlinie. LOC003 erledigt dasselbe ohne Sperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' -Wert 'AllowFindMyDevice' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Seite Datenschutz, "Mein Gerät suchen" wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig gilt kontoübergreifend.'

# ==============================================================
#  8. EINGABE, SPRACHE, ZWISCHENABLAGE
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN001' -Name 'Eingabe- und Tippvorschläge' `
    -Kategorie 'Eingabe' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows Proben deiner Tastatureingaben und Handschrift sammelt und zur Verbesserung der Vorschläge an Microsoft überträgt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Input\TIPC' -Wert 'Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN002' -Name 'Personalisierung der Freihandeingabe' `
    -Kategorie 'Eingabe' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Schaltet das Sammeln von Freihand- und Eingabedaten zur Personalisierung ab.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Personalization\Settings' -Wert 'AcceptedPrivacyPolicy' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN003' -Name 'Freihanddaten nicht sammeln' `
    -Kategorie 'Eingabe' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Unterbindet das stillschweigende Mitschreiben von Freihandeingaben. Ergänzt den vorigen Punkt, der ohne diesen Wert nur halb wirkt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' -Wert 'RestrictImplicitInkCollection' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN004' -Name 'Texteingaben nicht sammeln' `
    -Kategorie 'Eingabe' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Unterbindet das stillschweigende Mitschreiben von Texteingaben zur Verbesserung der Vorschläge.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' -Wert 'RestrictImplicitTextCollection' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN005' -Name 'Kontakte nicht auswerten' `
    -Kategorie 'Eingabe' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows deine Kontakte ausliest, um Namen in der Texterkennung besser vorzuschlagen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' -Wert 'HarvestContacts' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN006' -Name 'Online-Spracherkennung deaktivieren' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Sprachproben zur Erkennung an Microsoft-Server gesendet werden. Folge: Diktier- und Sprachsteuerungsfunktionen, die auf die Cloud angewiesen sind, funktionieren nicht mehr.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Wert 'HasAccepted' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN009' -Name 'Keine Spracherkennungsmodelle nachladen' `
    -Kategorie 'Eingabe' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Unterbindet das Nachladen von Spracherkennungsmodellen im Hintergrund. Ergänzt den vorigen Punkt.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Speech_OneCore\Preferences' -Wert 'ModelDownloadAllowed' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN007' -Name 'Cloud-Zwischenablage abschalten' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die geräteübergreifende Zwischenablage ab. Kopierte Inhalte - auch Passwörter und Kontonummern - verlassen den Rechner dann nicht mehr. Der lokale Zwischenablage-Verlauf bleibt davon unberührt, und der Schalter unter System, Zwischenablage bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Clipboard' -Wert 'EnableCloudClipboard' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN008' -Name 'Cloud-Zwischenablage: kein automatisches Hochladen' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Zweite Sicherung unter dem vorigen Punkt: Selbst wenn die geräteübergreifende Zwischenablage wieder eingeschaltet wird, lädt sie nichts mehr von selbst hoch.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Clipboard' -Wert 'CloudClipboardAutomaticUpload' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN012' -Name 'Sprachmodelle nicht aktualisieren (Richtlinie)' `
    -Kategorie 'Eingabe' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Windows Spracherkennungs- und Sprachausgabemodelle aus dem Netz nachlädt. Ergänzt EIN009. Folge: Stimmen der Sprachausgabe bekommen keine Aktualisierungen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Speech' -Wert 'AllowSpeechModelUpdate' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN010' -Name 'Keine Textvorschläge auf der Bildschirmtastatur' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Bildschirmtastatur schlägt beim Tippen keine Wörter mehr vor. Der Schalter unter Zeit und Sprache, Eingabe bleibt bedienbar. Ohne Touchbildschirm ohne Wirkung.' `
    -Pfad 'HKCU:\Control Panel\International\User Profile' -Wert 'ShowTextPrediction' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN011' -Name 'Verlauf der Zwischenablage aus' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows merkt sich nicht mehr, was du kopiert hast (Win+V zeigt keinen Verlauf). Kopierte Passwörter und Texte bleiben so nicht im Speicher liegen. Der Schalter unter System, Zwischenablage bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Clipboard' -Wert 'EnableClipboardHistory' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN013' -Name 'Keine Sprachaktivierung für Apps' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Keine App darf mehr dauerhaft auf ein Aktivierungswort hören (etwa "Hey Cortana" oder "Alexa"). Das Mikrofon wird dafür nicht mehr im Hintergrund ausgewertet. Der Schalter unter Datenschutz, Sprachaktivierung bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps' -Wert 'AgentActivationEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN014' -Name 'Keine Sprachaktivierung im Sperrbildschirm' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Auch bei gesperrtem Gerät darf keine App auf ein Aktivierungswort hören.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps' -Wert 'AgentActivationOnLockScreenEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN015' -Name 'Zwischenablage-Verlauf für alle Konten sperren' `
    -Kategorie 'Eingabe' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Sperrt den Verlauf der Zwischenablage für alle Konten. Für dein eigenes Konto genügt EIN011.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'AllowClipboardHistory' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Zwischenablageverlauf" unter System, Zwischenablage wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig gilt für alle Konten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN016' -Name 'Zwischenablage nicht geräteübergreifend (alle Konten)' `
    -Kategorie 'Eingabe' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Sperrt die Übertragung der Zwischenablage über die Cloud auf andere Geräte für alle Konten. Für dein eigenes Konto genügen EIN007 und EIN008.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'AllowCrossDeviceClipboard' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Auf allen Geräten freigeben" unter System, Zwischenablage wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig gilt für alle Konten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN017' -Name 'Online-Spracherkennung für alle Konten sperren' `
    -Kategorie 'Eingabe' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Sperrt die Online-Spracherkennung und die Eingabepersonalisierung für alle Konten. Für dein eigenes Konto genügt EIN006.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' -Wert 'AllowInputPersonalization' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Onlinespracherkennung" unter Datenschutz, Spracherkennung wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig gilt für alle Konten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN018' -Name 'Freihanddaten für alle Konten nicht sammeln' `
    -Kategorie 'Eingabe' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Verbietet für alle Konten, dass Windows Freihandeingaben zum Lernen sammelt. Für dein eigenes Konto genügt EIN003.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' -Wert 'RestrictImplicitInkCollection' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Sperrt keinen Schalter: Unter Windows 11 25H2 gemessen bleibt der Schalter unter Datenschutz, Freihand- und Eingabeanpassung bedienbar.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN019' -Name 'Texteingaben für alle Konten nicht sammeln' `
    -Kategorie 'Eingabe' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Verbietet für alle Konten, dass Windows getippte Texte zum Lernen sammelt. Für dein eigenes Konto genügt EIN004.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' -Wert 'RestrictImplicitTextCollection' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Sperrt keinen Schalter: Unter Windows 11 25H2 gemessen bleibt der Schalter unter Datenschutz, Freihand- und Eingabeanpassung bedienbar.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD001' -Name 'Delivery Optimization: kein P2P' `
    -Kategorie 'Updates' -Stufe 'Light' -Typ 'Registry' -Ausgemustert $true -ErsetztDurch @('UPD005') `
    -Erklaerung 'Verhindert, dass dein Rechner Update-Dateien an andere PCs weiterverteilt und von ihnen empfängt. Ab Werk beschränkt Windows das bereits auf das eigene Netzwerk; dieser Punkt schaltet auch das ab. Spart Upload-Bandbreite. Updates kommen weiterhin ganz normal direkt von Microsoft.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Wert 'DODownloadMode' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD003' -Name 'Optionale Updates selbst wählen' `
    -Kategorie 'Updates' -Stufe 'Standard' -Typ 'Registry' -NurPro $true `
    -Erklaerung 'Du entscheidest selbst, welche optionalen Updates installiert werden, statt dass sie automatisch mitkommen. Sie erscheinen dann unter Windows Update, Erweiterte Optionen, Optionale Updates. Wirkt nur auf Windows 11 Pro und höher.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'SetAllowOptionalContent' -Soll 3 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: nur so steuerbar, kein sichtbarer Schalter betroffen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD005' -Name 'Übermittlungsoptimierung: nur direkt von Microsoft' `
    -Kategorie 'Updates' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Updates kommen nur noch direkt von Microsoft (Modus Einfach): kein Austausch mit anderen PCs, auch nicht im eigenen Netz, und kein Kontakt zum Dienst, der diesen Austausch vermittelt. Windows Update, Store und Defender-Signaturen laufen normal weiter. Beim ersten Setzen wird der Zwischenspeicher der Übermittlungsoptimierung einmal geleert - er dient nur dem Weitergeben.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Wert 'DODownloadMode' -Soll 99 -Standard $null `
    -GrautAus $true -NachDemSetzen 'DoZwischenspeicherLeeren' `
    -Warnung 'Der Schalter unter Windows Update, Erweiterte Optionen, Übermittlungsoptimierung, "Downloads von anderen PCs zulassen" wird danach gesperrt. Der Modus Einfach lässt sich nur über die Richtlinie einstellen.' `
    -PolicyGrund 'Modus Einfach (99) gibt es nur im Richtlinienzweig. Der frühere Ort von UPD001 wird vom Dienst nicht gelesen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD006' -Name 'Keine Hersteller-Apps und -Symbole aus dem Netz' `
    -Kategorie 'Updates' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows lädt zu angeschlossenen Geräten keine Herstellersymbole, Beschreibungen und Begleit-Apps mehr aus dem Netz. Treiber kommen weiter über Windows Update. Entspricht im Dialog "Geräteinstallationseinstellungen" der Antwort Nein; der Dialog bleibt bedienbar.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' -Wert 'PreventDeviceMetadataFromNetwork' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD008' -Name 'Keine Treiber über Windows Update' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows Update liefert keine Treiber mehr aus. Treiber kommen dann nur noch vom Hersteller.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'ExcludeWUDriversInQualityUpdate' -Soll 1 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitskorrekturen in Treibern (WLAN, Bluetooth, Chipsatz) kommen nicht mehr automatisch; du musst sie selbst beim Hersteller holen.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD009' -Name 'Store-Apps nicht automatisch aktualisieren' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Store-Apps werden nicht mehr automatisch aktualisiert.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Wert 'AutoDownload' -Soll 2 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitskorrekturen für Store-Apps (etwa Bildbetrachter, Codecs, Editor) kommen nicht mehr von selbst.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD011' -Name 'Automatische Windows-Updates abschalten' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows sucht und installiert Updates nicht mehr selbsttätig; du startest jedes Update von Hand.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Wert 'NoAutoUpdate' -Soll 1 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitsupdates kommen erst, wenn du selbst nachsiehst. Lücken bleiben bis dahin offen - eines der größten Einzelrisiken für einen Windows-Rechner.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD012' -Name 'Keine Updates für andere Microsoft-Produkte' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows Update liefert keine Updates mehr für andere Microsoft-Produkte (etwa ältere Office-Versionen).' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Wert 'AllowMUUpdateService' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitsupdates für diese Produkte kommen nicht mehr über Windows Update.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD013' -Name 'Updates erst nach Rückfrage herunterladen' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows meldet verfügbare Updates nur noch und lädt sie erst herunter, wenn du zustimmst.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Wert 'AUOptions' -Soll 2 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitsupdates kommen erst, wenn du sie bestätigst. Bis dahin bleiben bekannte Lücken offen.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD014' -Name 'Aufschub für Qualitätsupdates einschalten' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Aufschub für monatliche Qualitäts- und Sicherheitsupdates ein. Die Frist legt UPD015 fest; laut Richtliniendefinition gehören beide zusammen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'DeferQualityUpdates' -Soll 1 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitsupdates kommen später als bei allen anderen. Bekannte Lücken bleiben so lange offen.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD015' -Name 'Qualitätsupdates 30 Tage aufschieben' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Monatliche Qualitäts- und Sicherheitsupdates kommen erst 30 Tage nach ihrem Erscheinen. Wirkt zusammen mit UPD014.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'DeferQualityUpdatesPeriodInDays' -Soll 30 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitslücken bleiben einen Monat länger offen, als sie müssten.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD016' -Name 'Aufschub für Funktionsupdates einschalten' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' -NurPro $true `
    -Erklaerung 'Schaltet den Aufschub für Funktionsupdates ein. Die Frist legt UPD002 fest; laut Richtliniendefinition gehören beide zusammen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'DeferFeatureUpdates' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Neue Windows-Versionen kommen erst nach der Frist aus UPD002. Sicherheitsupdates betrifft das nicht.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD017' -Name 'Neue Geräte: keine Treiber von Windows Update' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schließt du ein neues Gerät an, sucht Windows dessen Treiber nicht mehr über Windows Update. Entspricht "Nein" in den Geräteinstallationseinstellungen.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Wert 'SearchOrderConfig' -Soll 0 -Standard 1 `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Neue Geräte bekommen nur den Treiber, den Windows schon mitbringt, oder den du selbst installierst - auch ohne dessen Sicherheitskorrekturen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD018' -Name 'Treiber-Assistent: nicht bei Windows Update suchen' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Der Assistent zum Aktualisieren von Treibern (Geräte-Manager) sucht nicht mehr über Windows Update.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Wert 'DriverUpdateWizardWuSearchEnabled' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Treiber-Aktualisierungen über den Geräte-Manager finden nur noch Treiber, die schon auf dem Rechner liegen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD004' -Name 'Funktionsupdate-Kanal festlegen' `
    -Kategorie 'Updates' -Stufe 'Maximum' -Typ 'Registry' -NurPro $true `
    -Erklaerung 'Legt den Kanal fest, aus dem Funktionsupdates bezogen werden (allgemeine Verfügbarkeit statt Vorschau). Notwendige Begleiteinstellung zur Verzögerung im nächsten Punkt - ohne sie bleibt die Verzögerung wirkungslos.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'BranchReadinessLevel' -Soll 16 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: gehört zur selben Gruppenrichtlinie wie die Verzögerung.' `
    -Ausgemustert $true `
    -Hinweis 'AUSGEMUSTERT: Der allgemeine Kanal ist ohnehin die Vorgabe, der Wert bringt nichts. Eine Update-Richtlinie kann aber dazu führen, dass Windows den Rechner als verwaltet behandelt und Funktionsupdates nicht mehr anbietet, sondern nach Freigabe selbst installiert. Gewollt ist das Gegenteil: Funktionsupdates sofort als Angebot, nie automatisch, Sicherheitsupdates sofort.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD002' -Name 'Funktionsupdates um ein Jahr verzögern' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' -NurPro $true `
    -Erklaerung 'Große Versionssprunge (z.B. 24H2 auf 25H2) werden 365 Tage lang nicht angeboten. Sicherheitsupdates kommen davon völlig unberührt weiterhin automatisch.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Wert 'DeferFeatureUpdatesPeriodInDays' -Soll 365 -Standard $null `
    -GrautAus $true `
    -Warnung 'ZWEI FOLGEN. Erstens erscheint in den erweiterten Update-Optionen ein gesperrtes Feld, das du nicht mehr bedienen kannst. Zweitens, und wichtiger: Dies ist eine VERZÖGERUNG, kein Angebotsmodus. Ein Jahr lang siehst du keine Funktionsupdates - läuft der Support deiner Windows-Version in dieser Zeit aus, bekommst du auch keine Sicherheitsupdates mehr. Wer diesen Punkt setzt, muss den Supportzeitraum seiner Version selbst im Blick behalten. Die Einstellung wirkt außerdem NUR auf Pro, Enterprise und Education.' `
    -PolicyGrund 'Microsoft bietet die Steuerung der Feature-Updates ausschließlich über Richtlinien an.' `
   

# ==============================================================
#  10. MICROSOFT-KONTO UND SYNCHRONISIERUNG
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO001' -Name 'Einstellungs-Synchronisierung aus' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Deaktiviert die Synchronisierung deiner Windows-Einstellungen und Designs über dein Microsoft-Konto. Betrifft den Mechanismus aus Windows 10; existiert er auf deinem System nicht mehr, wird der Punkt übersprungen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync' -Wert 'SyncPolicy' -Soll 5 -Standard 0 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO002' -Name 'Sync der Anmeldedaten abschalten' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert zusätzlich, dass gespeicherte Anmeldedaten und Passwörter über das Microsoft-Konto auf andere Geräte übertragen werden.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO003' -Name 'OneDrive-Telemetrie abschalten' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Nutzungsdatenerfassung des OneDrive-Clients ab. Das Programm selbst bleibt installiert und nutzbar.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive' -Wert 'DisableTelemetry' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: OneDrive liest diese Einstellung nur von dort, ein sichtbarer Schalter existiert nicht.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO006' -Name 'OneDrive: kein Netzverkehr vor der Anmeldung' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass der OneDrive-Client schon vor deiner Anmeldung Verbindung zu Microsoft aufnimmt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive' -Wert 'PreventNetworkTrafficPreUserSignIn' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: OneDrive liest nur von dort, kein sichtbarer Schalter.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO004' -Name 'OneDrive-Autostart deaktivieren' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Autostart' `
    -Erklaerung 'OneDrive startet nicht mehr automatisch mit Windows. Das Programm bleibt installiert und kann jederzeit manuell geöffnet werden. Verkürzt zusätzlich den Systemstart.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Wert 'OneDrive' -RegTyp 'String' `
    -Ausgemustert $true -ErsetztDurch @('KTO007') `
    -Hinweis 'AUSGEMUSTERT: OneDrive schreibt seinen Autostart-Eintrag bei jedem Start neu. Ihn zu löschen hielt nie. Nachfolger KTO007 schaltet ihn dort ab, wo auch der Task-Manager es tut.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO007' -Name 'OneDrive-Autostart deaktivieren' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'StartupApproved' `
    -Erklaerung 'OneDrive startet nicht mehr automatisch mit Windows. Abgeschaltet wird der Eintrag dort, wo es auch der Task-Manager unter Autostart tut - OneDrive darf seinen Autostart-Eintrag neu schreiben, so oft es will, er bleibt abgeschaltet. Das Programm bleibt installiert und lässt sich jederzeit von Hand starten.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -Wert 'OneDrive' -RegTyp 'Binary' `
    -Hinweis 'Der Schalter im Task-Manager unter Autostart und unter Einstellungen, Apps, Autostart bleibt bedienbar.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO005' -Name 'Telefon-Verknüpfung abschalten' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert die geräteübergreifende Kopplung mit einem Mobiltelefon, über die Nachrichten, Fotos und Benachrichtigungen synchronisiert werden.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'EnableMmx' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter betroffen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO008' -Name 'SMS nicht in der Cloud sichern' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass SMS-Nachrichten eines verbundenen Telefons in der Microsoft-Cloud gesichert werden.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Messaging' -Wert 'AllowMessageSync' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO009' -Name 'PC greift nicht auf Mobilgeräte zu' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Dein PC darf nicht auf verbundene Smartphones zugreifen (Fotos, Nachrichten, Anrufe über die Funktion "Mobile Geräte"). Der Schalter unter Bluetooth und Geräte, Mobile Geräte bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Mobility' -Wert 'CrossDeviceEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO015' -Name 'OneDrive komplett abschalten' `
    -Kategorie 'Konto' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Schaltet OneDrive für alle Konten ab: keine Synchronisierung, kein Explorer-Eintrag, keine Anmeldung.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Wert 'DisableFileSyncNGSC' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Dateien, die nur in OneDrive liegen, sind danach am Rechner nicht mehr erreichbar, bis du den Punkt zurücknimmst.' `
    -PolicyGrund 'OneDrive liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO010' -Name 'Synchronisierung: Design' `
    -Kategorie 'Konto' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Synchronisierung von Design über das Microsoft-Konto ab. Gilt für die alte Synchronisierung; gibt es sie unter dieser Windows-Version nicht, wird nichts angelegt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO011' -Name 'Synchronisierung: Browsereinstellungen' `
    -Kategorie 'Konto' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Synchronisierung von Browsereinstellungen über das Microsoft-Konto ab. Gilt für die alte Synchronisierung; gibt es sie unter dieser Windows-Version nicht, wird nichts angelegt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO012' -Name 'Synchronisierung: Spracheinstellungen' `
    -Kategorie 'Konto' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Synchronisierung von Spracheinstellungen über das Microsoft-Konto ab. Gilt für die alte Synchronisierung; gibt es sie unter dieser Windows-Version nicht, wird nichts angelegt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO013' -Name 'Synchronisierung: erleichterter Bedienung' `
    -Kategorie 'Konto' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Synchronisierung von erleichterter Bedienung über das Microsoft-Konto ab. Gilt für die alte Synchronisierung; gibt es sie unter dieser Windows-Version nicht, wird nichts angelegt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO014' -Name 'Synchronisierung: weiteren Windows-Einstellungen' `
    -Kategorie 'Konto' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Synchronisierung von weiteren Windows-Einstellungen über das Microsoft-Konto ab. Gilt für die alte Synchronisierung; gibt es sie unter dieser Windows-Version nicht, wird nichts angelegt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO016' -Name 'Einstellungs-Synchronisierung per Richtlinie sperren' `
    -Kategorie 'Konto' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Dieser Rechner synchronisiert keine Einstellungen mehr über das Microsoft-Konto. KTO001 erledigt dasselbe ohne Sperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync' -Wert 'DisableSettingSync' -Soll 2 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Synchronisierung der Einstellungen lässt sich danach in den Einstellungen nicht mehr einschalten.' `
    -PolicyGrund 'Nur der Richtlinienzweig sperrt die Synchronisierung für alle Konten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO017' -Name 'Einstellungs-Synchronisierung: kein Einschalten durch Benutzer' `
    -Kategorie 'Konto' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Gehört zu KTO016: Benutzer dürfen die gesperrte Synchronisierung nicht selbst wieder einschalten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync' -Wert 'DisableSettingSyncUserOverride' -Soll 1 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Synchronisierung der Einstellungen lässt sich danach in den Einstellungen nicht mehr einschalten.' `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

# ==============================================================
#  11. OFFICE
#      Office liest seine Datenschutzvorgaben AUSSCHLIESSLICH
#      aus dem Richtlinienzweig. Werte unter
#      HKCU\Software\Microsoft\office\... bleiben folgenlos.
#      Ein sichtbarer Schalter in den WINDOWS-Einstellungen
#      wird dadurch nicht gesperrt - in den Office-Optionen
#      erscheint lediglich ein Verwaltungshinweis. Regel 2.
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF006' -Name 'Verbundene Erlebnisse insgesamt abschalten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Hauptschalter: schaltet sämtliche verbundenen Erlebnisse in Office auf einen Schlag ab. Die folgenden Einzelpunkte bleiben als zweite Sicherung bestehen. Wird nur wirksam, wenn Office installiert ist.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy' -Wert 'disconnectedstate' -Soll 2 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF001' -Name 'Office-Telemetrie deaktivieren' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' -Ausgemustert $true -ErsetztDurch @('OFF007') `
    -Erklaerung 'Schaltet die Diagnosedatenerfassung in Word, Excel, Outlook und den übrigen Office-Programmen auf "weder noch".' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy' -Wert 'sendtelemetry' -Soll 3 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF002' -Name 'Inhaltsanalysierende Verbindungen' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Office deine Dokumentinhalte zur Analyse an Microsoft-Server sendet. Folge: Funktionen wie "Designideen" in PowerPoint und der Textkonsistenz-Check stehen nicht mehr zur Verfügung.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy' -Wert 'usercontentdisabled' -Soll 2 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF003' -Name 'Nachladende Verbindungen' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet Office-Funktionen ab, die Online-Inhalte nachladen (Vorlagen, Bilderdatenbanken, Symbole).' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy' -Wert 'downloadcontentdisabled' -Soll 2 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF004' -Name 'Office-Kundenfeedback abschalten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Deaktiviert das Programm zur Verbesserung der Benutzerfreundlichkeit sowie In-Produkt-Umfragen in Office.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\feedback' -Wert 'enabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF005' -Name 'Optionale Verbindungen abschalten' `
    -Kategorie 'Office' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet alle zusätzlichen optionalen Online-Anbindungen in Office ab (LinkedIn-Daten, 3D-Bibliothek, Übersetzungsdienste).' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy' -Wert 'controllerconnectedservicesenabled' -Soll 2 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF007' -Name 'Office-Diagnosedaten auf Minimum' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Setzt die Diagnosedaten von Office auf die niedrigste Stufe: Office sendet weder erforderliche noch optionale Diagnosedaten. Löst OFF001 ab, das an einen Ort schrieb, den Office nicht liest.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\common\clienttelemetry' -Wert 'sendtelemetry' -Soll 3 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF008' -Name 'Office-Telemetrie abschalten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Telemetrie-Erfassung von Office ab.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\common\clienttelemetry' -Wert 'DisableTelemetry' -Soll 1 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF009' -Name 'Office: Programm zur Verbesserung abschalten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Teilnahme von Office am Programm zur Verbesserung der Benutzerfreundlichkeit ab.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common' -Wert 'qmenable' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF010' -Name 'Office: keine LinkedIn-Informationen' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Office zeigt keine LinkedIn-Profile und -Funktionen mehr an und fragt dafür keine Daten bei LinkedIn ab.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common' -Wert 'linkedin' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF011' -Name 'Office-Umfragen abschalten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Office blendet keine Umfragen mehr ein.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\feedback' -Wert 'surveyenabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF012' -Name 'Telemetrie-Agent: nicht protokollieren' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Office-Telemetrie-Agent zeichnet nichts mehr auf.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\osm' -Wert 'enablelogging' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF013' -Name 'Telemetrie-Agent: nichts übertragen' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Office-Telemetrie-Agent überträgt keine Daten mehr.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\osm' -Wert 'enableupload' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF014' -Name 'Telemetrie-Agent: Dateinamen verschleiern' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Falls der Telemetrie-Agent doch etwas erfasst, werden Dateinamen und Pfade unkenntlich gemacht.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\osm' -Wert 'enablefileobfuscation' -Soll 1 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF015' -Name 'Outlook: Schalter zum neuen Outlook ausblenden' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Blendet im klassischen Outlook den Schalter "Neues Outlook testen" aus. Das neue Outlook leitet Postfachzugänge über Microsoft-Server.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\options\general' -Wert 'hidenewoutlooktoggle' -Soll 1 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF016' -Name 'Outlook: keine automatische Umstellung' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass das klassische Outlook automatisch auf das neue Outlook umgestellt wird.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\preferences' -Wert 'DoNewOutlookAutoMigration' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF017' -Name 'Office nicht automatisch aktualisieren' `
    -Kategorie 'Office' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Office installiert Updates nicht mehr selbsttätig.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Wert 'enableautomaticupdates' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Sicherheitsupdates für Word, Excel, Outlook und Co. kommen erst, wenn du sie selbst startest. Office ist ein häufiges Einfallstor über präparierte Dokumente.' `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF018' -Name 'Anmeldung bei Office abschalten' `
    -Kategorie 'Office' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Office lässt keine Anmeldung mit einem Microsoft- oder Arbeitskonto mehr zu.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\signin' -Wert 'signinoptions' -Soll 3 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Ein Office-Abo (Microsoft 365) braucht die Anmeldung - ohne sie ist Office nicht lizenziert. Speichern in OneDrive geht ebenfalls nicht mehr.' `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (Wertname in den Office-Programmdateien).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF019' -Name 'Outlook: Fehlerprotokoll für E-Mail aus' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Outlook schreibt kein Fehlerprotokoll über den E-Mail-Verkehr. Solche Protokolle enthalten Absender, Empfänger und Betreffzeilen und bleiben sonst auf dem Rechner liegen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\Mail' -Wert 'EnableLogging' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF020' -Name 'Outlook: Fehlerprotokoll für den Kalender aus' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Outlook schreibt kein Fehlerprotokoll über Kalendereinträge.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\Calendar' -Wert 'EnableCalendarLogging' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF021' -Name 'Office: keine ausführliche Telemetrie-Protokollierung' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Office protokolliert seine Telemetrie nicht ausführlich mit.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry' -Wert 'VerboseLogging' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF022' -Name 'Outlook: nicht zum neuen Outlook weiterleiten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Das klassische Outlook startet nicht stattdessen das neue Outlook. Ergänzt OFF015 und OFF016.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences' -Wert 'UseNewOutlook' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF023' -Name 'Outlook: keine Umstellung durch die Benutzereinstellung' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Auch die Benutzereinstellung zur Umstellung auf das neue Outlook bleibt aus. Ergänzt OFF016.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\preferences' -Wert 'NewOutlookMigrationUserSetting' -Soll 0 -Standard $null `
    -PolicyGrund 'Office liest diesen Wert nur aus dem Richtlinienzweig (gemessen: Wertname in den Office-Programmdateien). In den Windows-Einstellungen wird nichts gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF024' -Name 'Outlook: keine Vorschau-Hinweise zum neuen Outlook' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Outlook zeigt keine Hinweise mehr, die neuen Funktionen oder das neue Outlook auszuprobieren.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\General' -Wert 'DisablePreviewPlace' -Soll 1 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'OFF025' -Name 'Outlook: Vorschau-Bereich ausschalten' `
    -Kategorie 'Office' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet den Bereich mit Vorschau-Angeboten in Outlook aus. Ergänzt OFF024.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences' -Wert 'EnablePreviewPlace' -Soll 0 -Standard $null

# ==============================================================
#  12. EDGE (falls installiert)
# ==============================================================
$Global:OrcaEdgeWerte = @(
    @{ Id='EDG001'; Wert='MetricsReportingEnabled';            Name='Edge-Telemetrie abschalten';        Stufe='Standard'; Text='Deaktiviert die Nutzungsdatenübermittlung des Edge-Browsers.' }
    @{ Id='EDG002'; Wert='PersonalizationReportingEnabled';    Name='Edge: personalisierte Werbung aus';  Stufe='Standard'; Text='Verhindert, dass Edge dein Surfverhalten zur Personalisierung von Werbung auswertet.' }
    @{ Id='EDG003'; Wert='DiagnosticData';                     Name='Edge-Diagnosedaten abschalten';     Stufe='Standard'; Text='Setzt die Diagnosedatenübermittlung von Edge auf die niedrigste Stufe.' }
    @{ Id='EDG004'; Wert='UserFeedbackAllowed';                Name='Edge-Feedback abschalten';          Stufe='Standard'; Text='Entfernt die Feedback-Funktion und die zugehörigen Übermittlungen.' }
    @{ Id='EDG005'; Wert='EdgeShoppingAssistantEnabled';       Name='Edge-Einkaufsassistent abschalten'; Stufe='Standard'; Text='Schaltet den Einkaufsassistenten ab, der besuchte Shop-Seiten auswertet und Preisvergleiche nachlädt.' }
    @{ Id='EDG006'; Wert='ShowRecommendationsEnabled';         Name='Edge-Empfehlungen abschalten';      Stufe='Standard'; Text='Entfernt die eingeblendeten Empfehlungen und Hinweisbanner in Edge.' }
    @{ Id='EDG007'; Wert='DefaultBrowserSettingsCampaignEnabled'; Name='Edge-Standardbrowser-Werbung';   Stufe='Light';    Text='Unterbindet die wiederkehrenden Aufforderungen, Edge als Standardbrowser festzulegen.' }
    @{ Id='EDG008'; Wert='NewTabPageContentEnabled';           Name='Edge: Inhalte auf neuer Registerkarte'; Stufe='Standard'; Text='Entfernt den serverseitig befüllten Nachrichten- und Werbebereich von der Seite "Neue Registerkarte".' }
)

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG009' -Name 'Edge-Neuinstallation über den Updater sperren' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Verbietet dem Edge-Updater, den Browser neu zu installieren. Gedacht für Rechner, auf denen Edge entfernt wurde. WebView2, das viele Programme brauchen, ist davon nicht betroffen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Wert 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: Der Edge-Updater liest nur von dort, in den Windows-Einstellungen gibt es dazu keinen Schalter.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG010' -Name 'Edge: Nutzerverfolgung streng blockieren' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Stellt den Tracking-Schutz von Edge auf "Streng". Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'TrackingPrevention' -Soll 3 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG011' -Name 'Edge: "Nicht verfolgen" senden' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge bittet jede Website mit dem Do-Not-Track-Signal, dich nicht zu verfolgen. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'ConfigureDoNotTrack' -Soll 1 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG012' -Name 'Edge: keine Abfrage gespeicherter Zahlungsmethoden' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Websites dürfen nicht abfragen, ob du Zahlungsmethoden gespeichert hast. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'PaymentMethodQueryEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG013' -Name 'Edge: Kreditkarten nicht speichern' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge speichert und füllt keine Kreditkartendaten mehr. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'AutofillCreditCardEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG014' -Name 'Edge: keine Formularvorschläge' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge speichert und füllt keine Adressen und Formulardaten mehr. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'AutofillAddressEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG015' -Name 'Edge: keine Vorschläge lokaler Anbieter' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Die Adressleiste zeigt keine Vorschläge lokaler Anbieter mehr. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'LocalProvidersEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG016' -Name 'Edge: keine Such- und Websitevorschläge' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Eingaben in die Adressleiste gehen nicht mehr während des Tippens an die Suchmaschine. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'SearchSuggestEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG017' -Name 'Edge-Leiste abschalten' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die frei schwebende Edge-Suchleiste auf dem Desktop ab. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'SearchbarAllowed' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG018' -Name 'Edge: Randleiste abschalten' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Randleiste mit Copilot und Microsoft-Diensten ab. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'HubsSidebarEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG019' -Name 'Edge: erweiterte Rechtschreibprüfung aus' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Die erweiterte Rechtschreibprüfung schickt Text zur Prüfung an Microsoft; das entfällt. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'MicrosoftEditorProofingEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG020' -Name 'Edge: Begrüßung beim ersten Start ausblenden' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Überspringt die Einrichtungsseiten beim ersten Start, die zur Anmeldung und Datenfreigabe auffordern. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'HideFirstRunExperience' -Soll 1 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG021' -Name 'Edge: Spotlight-Empfehlungen aus' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Keine Spotlight-Hintergründe, Tipps und Empfehlungen in Edge. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'SpotlightExperiencesAndRecommendationsEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG022' -Name 'Edge: keine automatische Anmeldung' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge meldet dich nicht mehr automatisch mit dem Windows-Konto im Browser an. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'BrowserSignin' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG023' -Name 'Edge: kein Copilot auf der neuen Registerkarte' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Entfernt Copilot (Bing Chat) von der Seite "Neue Registerkarte". Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'NewTabPageBingChatEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG024' -Name 'Edge: keine KI-generierten Designs' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die KI-Erzeugung von Browser-Designs ab. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'AIGenThemesEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG025' -Name 'Edge: kein KI-Schreiben in Textfeldern' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet "Verfassen" ab, das Text in Eingabefeldern per KI erzeugt. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'ComposeInlineEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG026' -Name 'Edge: Copilot liest keine Seiteninhalte' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Copilot darf den Inhalt der geöffneten Seite nicht lesen. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'CopilotPageContext' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG027' -Name 'Edge: Copilot liest keine geschützten Seiteninhalte' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Wie der vorige Punkt, für Seiten mit Unternehmensschutz. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'CopilotCDPPageContext' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG028' -Name 'Edge: keine Aufforderung zum Standardbrowser' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge prüft nicht mehr, ob er Standardbrowser ist, und fragt nicht danach. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'DefaultBrowserSettingEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG029' -Name 'Edge: Microsoft Rewards ausblenden' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Blendet Microsoft Rewards aus. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'ShowMicrosoftRewards' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG030' -Name 'Edge: keine Cloud-Dienste für Registerkarten' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Registerkarten werden nicht über Microsoft-Dienste gruppiert und benannt. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'TabServicesEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG031' -Name 'Edge: keine Textvorhersage' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Textvorhersage in Formularfeldern ab; getippter Text geht dafür nicht mehr an Microsoft. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'TextPredictionEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG032' -Name 'Edge: visuelle Suche aus' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Bilder auf Webseiten werden nicht mehr zur Suche an Bing geschickt. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'VisualSearchEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG033' -Name 'Edge: Navigationsfehler nicht über Webdienst lösen' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Bei Verbindungsfehlern fragt Edge keinen Microsoft-Dienst mehr. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'ResolveNavigationErrorsUseWebService' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG034' -Name 'Edge: keine ähnlichen Seiten bei Fehlern' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Bei nicht gefundenen Seiten schlägt Edge keine ähnlichen Seiten über einen Webdienst vor. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'AlternateErrorPagesEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG035' -Name 'Edge: Seiten nicht vorladen' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge lädt Seiten nicht mehr vorsorglich, bevor du sie anklickst. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'NetworkPredictionOptions' -Soll 2 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG036' -Name 'Edge: keine Kennwörter speichern' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge speichert keine Kennwörter für Websites mehr. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'PasswordManagerEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG037' -Name 'Edge: keine Website-Infos über Microsoft-Dienste' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge holt zu besuchten Seiten keine zusätzlichen Informationen bei Microsoft. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'SiteSafetyServicesEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG038' -Name 'Edge: keine Weiterleitung aus dem Internet Explorer' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Seiten werden nicht mehr automatisch vom Internet Explorer an Edge weitergereicht. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'RedirectSitesFromInternetExplorerRedirectMode' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG039' -Name 'Edge: Schnellstart aus' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge startet nicht mehr unsichtbar mit Windows. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'StartupBoostEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG040' -Name 'Edge: im Hintergrund nicht weiterlaufen' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Edge läuft nach dem Schließen nicht im Hintergrund weiter. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'BackgroundModeEnabled' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG041' -Name 'Edge: Standard-Top-Sites ausblenden' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Blendet die vorbelegten und gesponserten Kacheln auf der neuen Registerkarte aus. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'NewTabPageHideDefaultTopSites' -Soll 1 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG042' -Name 'Edge: Acrobat-Abo-Schaltfläche ausblenden' `
    -Kategorie 'Edge' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Blendet die Werbeschaltfläche für ein Adobe-Acrobat-Abo aus. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'ShowAcrobatSubscriptionButton' -Soll 0 -Standard $null `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG043' -Name 'Edge: SmartScreen abschalten' `
    -Kategorie 'Edge' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Edge prüft Seiten und Downloads nicht mehr mit SmartScreen. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'SmartScreenEnabled' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Keine Warnung mehr vor Betrugsseiten und schädlichen Downloads in Edge.' `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EDG044' -Name 'Edge: Tippfehlerprüfung für Adressen aus' `
    -Kategorie 'Edge' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Edge warnt nicht mehr vor Adressen, die einer bekannten Seite zum Verwechseln ähnlich sehen. Nur wirksam, wenn Edge installiert ist.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert 'TyposquattingCheckerEnabled' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Keine Warnung mehr vor nachgemachten Adressen (etwa paypa1.com statt paypal.com).' `
    -PolicyGrund 'Edge liest seine Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt; ohne installierten Edge ohne Wirkung.'

foreach ($e in $Global:OrcaEdgeWerte) {
    $Global:OrcaEinstellungen += New-OrcaSetting -Id $e.Id -Name $e.Name `
        -Kategorie 'Edge' -Stufe $e.Stufe -Typ 'Registry' `
        -Erklaerung "$($e.Text) Nur wirksam, wenn Edge installiert ist." `
        -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Wert $e.Wert -Soll 0 -Standard $null `
        -PolicyGrund 'Edge liest Vorgaben nur aus dem Richtlinienzweig. In den Windows-Einstellungen wird nichts gesperrt.'
}

# ==============================================================
#  13. DEFENDER-DATENUEBERMITTLUNG
#      Zielkonflikt: Beides senkt die Erkennungsrate bei
#      brandneuer Schadsoftware. Bewusst nur in Maximum.
#
#      WICHTIG: Der Manipulationsschutz von Windows-Sicherheit
#      ist ab Werk eingeschaltet und IGNORIERT Änderungen an
#      geschützten Defender-Einstellungen - auch solche aus
#      dem Richtlinienzweig. Der Registrywert stünde dann
#      korrekt da, ohne dass sich etwas ändert. Deshalb wird
#      der Zustand des Manipulationsschutzes vorher gelesen und
#      der Punkt andernfalls als nicht anwendbar geführt.
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF001' -Name 'Defender: keine Cloud-Meldungen' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Beendet die Teilnahme am Microsoft-Netzwerk zum Schutz vor Schadsoftware (MAPS/SpyNet). ABWÄGUNG: Defender erkennt brandneue Schadsoftware danach spürbar schlechter, weil ihm die Cloud-Einschätzung fehlt. Der Schutz vor bereits bekannter Schadsoftware bleibt unverändert.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' -Wert 'SpynetReporting' -Soll 0 -Standard $null `
    -Hinweis 'FOLGE: Defender erkennt brandneue Schadsoftware messbar schlechter, weil ihm die Cloud-Einschätzung fehlt. Gegen bereits bekannte Schadsoftware schützt er unverändert weiter.' `
    -Voraussetzung 'KeinManipulationsschutz' -Wirkung 'Defender-MAPS' `
    -PolicyGrund 'Richtlinienzweig: Defender liest diese Vorgabe nur von dort. Der Schalter in der Windows-Sicherheit bleibt sichtbar, zeigt aber einen Verwaltungshinweis.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF002' -Name 'Defender: keine Dateiübermittlung' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Verhindert, dass Defender verdächtige Dateien zur Analyse an Microsoft hochlädt. In der Voreinstellung werden auch Dokumente übertragen, wenn sie dem Scanner auffällig erscheinen. ABWÄGUNG: siehe vorigen Punkt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' -Wert 'SubmitSamplesConsent' -Soll 2 -Standard $null `
    -Hinweis 'FOLGE: Eine verdächtige Datei, die Defender nicht selbst einordnen kann, wird nicht mehr zur Analyse hochgeladen - sie bleibt also unbewertet auf deinem Rechner, statt binnen Minuten eingestuft zu werden.' `
    -Voraussetzung 'KeinManipulationsschutz' -Wirkung 'Defender-Samples' `
    -PolicyGrund 'Richtlinienzweig: Defender liest diese Vorgabe nur von dort.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF003' -Name 'Schutz vor unerwünschter Software' `
    -Kategorie 'Defender' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Erzwingt die Blockierung potenziell unerwünschter Software - Adware, Browser-Hijacker und die üblichen Installer-Beipacks. Auf Windows 11 ist dieser Schutz ab Werk bereits aktiv; der Punkt hält ihn dauerhaft fest, falls ihn etwas abschaltet. Der einzige Punkt im Katalog, der etwas einschaltet statt abzuschalten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Wert 'PUAProtection' -Soll 1 -Standard $null `
    -Voraussetzung 'KeinManipulationsschutz' `
    -PolicyGrund 'Richtlinienzweig: nur so dauerhaft setzbar, kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF004' -Name 'Entfernungstool: keine Fundmeldung an Microsoft' `
    -Kategorie 'Defender' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Das Tool zum Entfernen bösartiger Software (MRT), das monatlich über Windows Update läuft, meldet seine Funde nicht mehr an Microsoft. Gesucht und entfernt wird weiter wie bisher - der Schutz bleibt unverändert.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\MRT' -Wert 'DontReportInfectionInformation' -Soll 1 -Standard $null `
    -PolicyGrund 'Das Entfernungstool liest diesen Wert aus dem Richtlinienzweig (gemessen: Wertname in MRT.exe). Es gibt dazu keinen Schalter.'

$orcaDefPfad  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$orcaWscPfad = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center'
$Global:OrcaDefenderWerte = @(
    @{ Id='DEF005'; Pfad="$orcaDefPfad\Reporting"; Wert='DisableGenericRePorts'; Soll=1; MS=$true; Stufe='Maximum'
       Name='Defender: keine Watson-Ereignisberichte'
       Text='Defender schickt keine Watson-Ereignisse (Fehler- und Ereignisberichte) mehr an Microsoft. Erkennen und Entfernen bleiben unverändert.' }
    @{ Id='DEF006'; Pfad="$orcaDefPfad\Spynet"; Wert='DisableBlockAtFirstSeen'; Soll=1; MS=$true; SS=$true
       Name='Defender: "Bei erster Anzeige blockieren" aus'
       Text='Defender fragt bei unbekannten Dateien vor dem Öffnen nicht mehr in Echtzeit bei Microsoft nach.'
       Folge='FOLGE: Brandneue Schadsoftware kann starten, bevor Defender sie erkennt.' }
    @{ Id='DEF007'; Pfad="$orcaDefPfad\Signature Updates"; Wert='RealtimeSignatureDelivery'; Soll=0; MS=$true; SS=$true
       Name='Defender: keine sofortigen Erkennungen aus der Cloud'
       Text='Meldet Defender eine unbekannte Datei und hat Microsoft dafür schon eine Erkennung, wird sie nicht mehr sofort nachgeladen.'
       Folge='FOLGE: Neue Erkennungen kommen erst mit dem nächsten regulären Update der Sicherheitsinformationen.' }
    @{ Id='DEF008'; Pfad="$orcaDefPfad\Signature Updates"; Wert='SignatureDisableNotification'; Soll=0; MS=$true; VN=$true
       Name='Defender: keine Abschaltung von Fehlalarmen aus der Cloud'
       Text='Defender nimmt keine Meldungen von Microsoft mehr an, mit denen einzelne Erkennungen wegen Fehlalarmen sofort abgeschaltet werden. Wirkt nur bei Teilnahme an der Cloud (siehe DEF001).'
       Folge='Ein Fehlalarm bleibt bis zum nächsten regulären Update der Sicherheitsinformationen bestehen.' }
    @{ Id='DEF009'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='DisableRealtimeMonitoring'; Soll=1; MS=$true; SS=$true
       Name='Defender: Echtzeitschutz aus'
       Text='Defender prüft Dateien nicht mehr beim Öffnen, Herunterladen und Ausführen.'
       Folge='FOLGE: Schadsoftware fällt nur noch bei einem Scan auf - wenn sie bis dahin nicht schon Schaden angerichtet hat.'
       GW='Der Schalter "Echtzeitschutz" unter Windows-Sicherheit, Viren- und Bedrohungsschutz wird gesperrt.' }
    @{ Id='DEF010'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='DisableBehaviorMonitoring'; Soll=1; MS=$true; SS=$true
       Name='Defender: Verhaltensüberwachung aus'
       Text='Defender beobachtet laufende Programme nicht mehr auf verdächtiges Verhalten.'
       Folge='FOLGE: Schadsoftware ohne bekannte Signatur, etwa neue Erpressungssoftware, wird an ihrem Verhalten nicht mehr erkannt.' }
    @{ Id='DEF011'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='DisableRawWriteNotification'; Soll=1; MS=$true; SS=$true
       Name='Defender: Schreibzugriffe auf Rohvolumes nicht melden'
       Text='Schreibzugriffe direkt auf Datenträger, am Dateisystem vorbei, werden der Verhaltensüberwachung nicht mehr gemeldet.'
       Folge='FOLGE: Angriffe, die Datenträger direkt beschreiben, etwa den Startbereich, fallen nicht mehr auf.' }
    @{ Id='DEF012'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='DisableIOAVProtection'; Soll=1; MS=$true; SS=$true
       Name='Defender: Downloads und Anhänge nicht prüfen'
       Text='Heruntergeladene Dateien und E-Mail-Anhänge werden nicht mehr geprüft.'
       Folge='FOLGE: Schädliche Downloads und Anhänge werden vor dem Öffnen nicht mehr erkannt.' }
    @{ Id='DEF013'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='IOAVMaxSize'; Soll=1; MS=$true; SS=$true
       Name='Defender: Downloads nur bis 1 KB prüfen'
       Text='Defender prüft heruntergeladene Dateien und Anhänge nur noch bis 1 KB Größe - praktisch keine.'
       Folge='FOLGE: Schädliche Downloads und Anhänge werden vor dem Öffnen nicht mehr erkannt.' }
    @{ Id='DEF014'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='DisableOnAccessProtection'; Soll=1; MS=$true; SS=$true
       Name='Defender: Datei- und Programmaktivität nicht überwachen'
       Text='Zugriffe auf Dateien und gestartete Programme werden nicht mehr geprüft.'
       Folge='FOLGE: Schadsoftware, die schon auf dem Rechner liegt, wird beim Öffnen oder Starten nicht erkannt.' }
    @{ Id='DEF015'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='RealtimeScanDirection'; Soll=1; MS=$true; SS=$true
       Name='Defender: nur eingehende Dateien prüfen'
       Text='Der Echtzeitschutz prüft nur noch Dateien, die neu auf den Rechner kommen, nicht mehr beim Öffnen vorhandener Dateien.'
       Folge='FOLGE: Schadsoftware, die schon auf dem Rechner liegt, wird beim Öffnen nicht erkannt.' }
    @{ Id='DEF016'; Pfad="$orcaDefPfad\Real-Time Protection"; Wert='DisableScanOnRealtimeEnable'; Soll=1; MS=$true; SS=$true
       Name='Defender: kein Prozessscan beim Einschalten des Echtzeitschutzes'
       Text='Wird der Echtzeitschutz eingeschaltet, prüft Defender die schon laufenden Programme nicht mehr.'
       Folge='FOLGE: Schadsoftware, die gestartet ist, während der Echtzeitschutz aus war, läuft unbemerkt weiter.' }
    @{ Id='DEF017'; Pfad=$orcaDefPfad; Wert='DisableRoutinelyTakingAction'; Soll=1; MS=$true; SS=$true
       Name='Defender: keine automatische Maßnahme bei Funden'
       Text='Defender entfernt oder isoliert gefundene Bedrohungen nicht mehr selbst, sondern fragt dich.'
       Folge='FOLGE: Bis du reagierst, bleibt gefundene Schadsoftware auf dem Rechner und kann weiterlaufen.' }
    @{ Id='DEF018'; Pfad="$orcaDefPfad\NIS"; Wert='DisableProtocolRecognition'; Soll=1; MS=$true; SS=$true
       Name='Defender: keine Protokollerkennung im Netzwerkschutz'
       Text='Die Netzwerkprüfung von Defender erkennt Netzwerkprotokolle nicht mehr und kann Datenverkehr nicht mehr auf bekannte Angriffe untersuchen.'
       Folge='FOLGE: Bekannte Angriffe über Netzwerkprotokolle werden nicht mehr abgefangen.' }
    @{ Id='DEF019'; Pfad="$orcaDefPfad\Quarantine"; Wert='PurgeItemsAfterDelay'; Soll=1; MS=$true; VN=$true
       Name='Defender: Quarantäne nach einem Tag leeren'
       Text='Dateien in der Quarantäne werden nach einem Tag endgültig gelöscht. Ohne den Punkt bleiben sie unbegrenzt.'
       Folge='Eine fälschlich isolierte Datei lässt sich nach einem Tag nicht mehr aus der Quarantäne zurückholen.' }
    @{ Id='DEF020'; Pfad="$orcaDefPfad\Scan"; Wert='PurgeItemsAfterDelay'; Soll=1; MS=$true; VN=$true
       Name='Defender: Scanverlauf nach einem Tag löschen'
       Text='Einträge im Scanverlauf werden nach einem Tag gelöscht statt nach 30 Tagen.'
       Folge='Ältere Funde lassen sich danach nicht mehr im Schutzverlauf nachsehen.' }
    @{ Id='DEF021'; Pfad="$orcaDefPfad\Scan"; Wert='MissedScheduledScanCountBeforeCatchup'; Soll=20; MS=$true; SS=$true
       Name='Defender: Nachholscan erst nach 20 verpassten Scans'
       Text='Ein verpasster geplanter Scan wird erst nachgeholt, wenn 20 hintereinander ausgefallen sind (sonst nach zwei).'
       Folge='FOLGE: Ist der Rechner zur Scanzeit oft aus, läuft wochenlang kein geplanter Scan.' }
    @{ Id='DEF022'; Pfad="$orcaDefPfad\Scan"; Wert='DisableCatchupQuickScan'; Soll=1; MS=$true; SS=$true
       Name='Defender: verpasste Schnellscans nicht nachholen'
       Text='Fällt ein geplanter Schnellscan aus, weil der Rechner aus war, wird er nicht nachgeholt.'
       Folge='FOLGE: Verpasste Schnellscans fallen ersatzlos aus.' }
    @{ Id='DEF023'; Pfad="$orcaDefPfad\Scan"; Wert='DisableHeuristics'; Soll=1; MS=$true; SS=$true
       Name='Defender: Heuristik aus'
       Text='Defender erkennt Schadsoftware nur noch an bekannten Signaturen, nicht mehr an verdächtigen Merkmalen.'
       Folge='FOLGE: Abgewandelte und neue Schadsoftware wird deutlich schlechter erkannt.' }
    @{ Id='DEF024'; Pfad="$orcaDefPfad\Scan"; Wert='DisableReparsePointScanning'; Soll=1; MS=$true; SS=$true
       Name='Defender: Analysepunkte nicht scannen'
       Text='Scans folgen keinen Analysepunkten (Verknüpfungen im Dateisystem) mehr.'
       Folge='FOLGE: Dateien, die nur über solche Verknüpfungen erreichbar sind, werden beim Scan nicht geprüft.' }
    @{ Id='DEF025'; Pfad="$orcaDefPfad\Scan"; Wert='DisableScanningMappedNetworkDrivesForFullScan'; Soll=1; MS=$true; SS=$true
       Name='Defender: Netzlaufwerke nicht im vollständigen Scan'
       Text='Vollständige Scans prüfen verbundene Netzlaufwerke nicht mit.'
       Folge='FOLGE: Schadsoftware auf verbundenen Netzlaufwerken wird bei vollständigen Scans nicht gefunden.' }
    @{ Id='DEF026'; Pfad="$orcaDefPfad\Scan"; Wert='DisableScanningNetworkFiles'; Soll=1; MS=$true; SS=$true
       Name='Defender: Netzwerkdateien nicht prüfen'
       Text='Dateien, die du direkt aus dem Netzwerk öffnest, werden nicht geprüft.'
       Folge='FOLGE: Schadsoftware auf Netzwerkfreigaben wird beim Öffnen nicht erkannt.' }
    @{ Id='DEF027'; Pfad="$orcaDefPfad\Scan"; Wert='DisablePackedExeScanning'; Soll=1; MS=$true; SS=$true
       Name='Defender: gepackte Programme nicht scannen'
       Text='Programmdateien, die mit einem Packprogramm verkleinert wurden, werden beim Scan nicht entpackt und geprüft.'
       Folge='FOLGE: Schadsoftware in gepackten Programmdateien wird beim Scan nicht erkannt.' }
    @{ Id='DEF028'; Pfad="$orcaDefPfad\Scan"; Wert='DisableRemovableDriveScanning'; Soll=1; MS=$true; SS=$true
       Name='Defender: Wechseldatenträger nicht im vollständigen Scan'
       Text='Vollständige Scans prüfen USB-Sticks und andere Wechseldatenträger nicht mit.'
       Folge='FOLGE: Schadsoftware auf Wechseldatenträgern wird bei vollständigen Scans nicht gefunden.' }
    @{ Id='DEF029'; Pfad="$orcaDefPfad\Scan"; Wert='DisableArchiveScanning'; Soll=1; MS=$true; SS=$true
       Name='Defender: Archive nicht scannen'
       Text='ZIP-, CAB- und andere Archive werden beim Scan nicht geöffnet und geprüft.'
       Folge='FOLGE: Schadsoftware in Archiven fällt erst beim Entpacken auf, und nur bei eingeschaltetem Echtzeitschutz.' }
    @{ Id='DEF030'; Pfad="$orcaDefPfad\Scan"; Wert='ArchiveMaxSize'; Soll=1; MS=$true; SS=$true
       Name='Defender: nur Archive bis 1 KB scannen'
       Text='Archive werden beim Scan nur noch bis 1 KB Größe geprüft - praktisch keine.'
       Folge='FOLGE: Schadsoftware in Archiven fällt erst beim Entpacken auf, und nur bei eingeschaltetem Echtzeitschutz.' }
    @{ Id='DEF031'; Pfad="$orcaDefPfad\Scan"; Wert='ScheduleDay'; Soll=8; MS=$true; SS=$true
       Name='Defender: keine geplanten Scans'
       Text='Der geplante Scan von Defender läuft nie mehr.'
       Folge='FOLGE: Schadsoftware, die am Echtzeitschutz vorbeigekommen ist, wird nicht mehr durch regelmäßige Scans gefunden.' }
    @{ Id='DEF032'; Pfad=$orcaDefPfad; Wert='RandomizeScheduleTaskTimes'; Soll=0; MS=$true
       Name='Defender: geplante Aufgaben nicht zufällig verschieben'
       Text='Geplante Scans und Updates starten genau zur eingestellten Zeit statt in einem zufälligen Zeitfenster darum herum. Am Schutz ändert sich nichts.' }
    @{ Id='DEF033'; Pfad="$orcaDefPfad\Signature Updates"; Wert='DisableScanOnUpdate'; Soll=1; MS=$true; SS=$true
       Name='Defender: kein Scan nach Update der Sicherheitsinformationen'
       Text='Nach einem Update der Sicherheitsinformationen startet kein Scan mehr.'
       Folge='FOLGE: Neue Erkennungen greifen bei vorhandenen Dateien erst beim nächsten Scan.' }
    @{ Id='DEF034'; Pfad="$orcaDefPfad\Signature Updates"; Wert='DisableScheduledSignatureUpdateOnBattery'; Soll=1; MS=$true; SS=$true
       Name='Defender: keine Updates im Akkubetrieb'
       Text='Im Akkubetrieb holt Defender keine geplanten Updates der Sicherheitsinformationen.'
       Folge='FOLGE: Ein Laptop, der viel im Akkubetrieb läuft, arbeitet mit veralteten Sicherheitsinformationen.' }
    @{ Id='DEF035'; Pfad="$orcaDefPfad\Signature Updates"; Wert='SignatureUpdateInterval'; Soll=24; MS=$true; SS=$true
       Name='Defender: höchstens einmal täglich nach Updates suchen'
       Text='Defender sucht nur noch alle 24 Stunden nach neuen Sicherheitsinformationen.'
       Folge='FOLGE: Neue Erkennungen kommen bis zu einen Tag später.' }
    @{ Id='DEF036'; Pfad="$orcaDefPfad\Signature Updates"; Wert='DisableUpdateOnStartupWithoutEngine'; Soll=1; MS=$true; SS=$true
       Name='Defender: kein Update beim Start ohne Schutzmodul'
       Text='Fehlt das Schutzmodul von Defender, startet beim Hochfahren kein Update der Sicherheitsinformationen.'
       Folge='FOLGE: Ein fehlendes oder beschädigtes Schutzmodul wird beim Start nicht von selbst nachgeladen.' }
    @{ Id='DEF037'; Pfad=$orcaDefPfad; Wert='AllowFastServiceStartup'; Soll=0; MS=$true; SS=$true
       Name='Defender: Dienst mit niedriger Priorität starten'
       Text='Der Defender-Dienst startet beim Hochfahren mit niedriger statt normaler Priorität.'
       Folge='FOLGE: Defender ist nach dem Start später bereit; Programme, die vorher starten, werden erst danach geprüft.' }
    @{ Id='DEF038'; Pfad="$orcaDefPfad\Reporting"; Wert='WppTracingLevel'; Soll=1; MS=$true
       Name='Defender: interne Ablaufverfolgung nur für Fehler'
       Text='Defender schreibt in seine interne Ablaufverfolgung nur noch Fehler. Die Aufzeichnung bleibt auf dem Rechner; am Schutz ändert sich nichts.' }
    @{ Id='DEF039'; Pfad="$orcaDefPfad\UX Configuration"; Wert='UILockdown'; Soll=1; MS=$true; VN=$true
       Name='Defender: Oberfläche des Virenschutzes ausblenden'
       Text='Die Oberfläche des Virenschutzes wird nicht mehr angezeigt.'
       Folge='Funde und Einstellungen des Virenschutzes siehst du danach nicht mehr in der Windows-Sicherheit.' }
    @{ Id='DEF040'; Pfad="$orcaDefPfad\UX Configuration"; Wert='Notification_Suppress'; Soll=1; MS=$true; SS=$true
       Name='Defender: alle Benachrichtigungen unterdrücken'
       Text='Defender zeigt keine Benachrichtigungen mehr an.'
       Folge='FOLGE: Du erfährst nicht mehr, wenn Defender Schadsoftware findet oder etwas blockiert.' }
    @{ Id='DEF041'; Pfad="$orcaDefPfad\UX Configuration"; Wert='SuppressRebootNotification'; Soll=1; MS=$true; SS=$true
       Name='Defender: keine Neustart-Hinweise'
       Text='Defender zeigt keine Hinweise mehr, dass ein Neustart nötig ist.'
       Folge='FOLGE: Braucht Defender zum Entfernen einer Bedrohung einen Neustart, erfährst du es nicht.' }
    @{ Id='DEF042'; Pfad="$orcaDefPfad\Reporting"; Wert='DisableEnhancedNotifications'; Soll=1; MS=$true
       Name='Defender: erweiterte Benachrichtigungen aus'
       Text='Defender zeigt keine erweiterten Benachrichtigungen mehr. Warnungen bei Funden bleiben.' }
    @{ Id='DEF043'; Pfad="$orcaWscPfad\Notifications"; Wert='DisableNotifications'; Soll=1; SS=$true
       Name='Windows-Sicherheit: alle Benachrichtigungen ausblenden'
       Text='Die Windows-Sicherheit zeigt keine Benachrichtigungen mehr an.'
       Folge='FOLGE: Keine Meldungen mehr aus der Windows-Sicherheit, auch nicht bei gefundener Schadsoftware.' }
    @{ Id='DEF044'; Pfad="$orcaWscPfad\Notifications"; Wert='DisableEnhancedNotifications'; Soll=1
       Name='Windows-Sicherheit: nicht kritische Benachrichtigungen ausblenden'
       Text='Die Windows-Sicherheit zeigt nur noch kritische Benachrichtigungen.' }
    @{ Id='DEF045'; Pfad="$orcaWscPfad\Systray"; Wert='HideSystray'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Symbol im Infobereich ausblenden'
       Text='Das Symbol der Windows-Sicherheit im Infobereich der Taskleiste wird ausgeblendet. Wirkt nach dem nächsten Anmelden.'
       Folge='Den Schutzzustand siehst du dann nur noch in der App Windows-Sicherheit.' }
    @{ Id='DEF046'; Pfad="$orcaWscPfad\Virus and threat protection"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Viren- und Bedrohungsschutz" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Funde, Quarantäne und Einstellungen des Virenschutzes sind dann in der Windows-Sicherheit nicht mehr erreichbar.' }
    @{ Id='DEF047'; Pfad="$orcaWscPfad\Virus and threat protection"; Wert='HideRansomwareRecovery'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Ransomware-Datenwiederherstellung" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Der Weg zur Wiederherstellung von Dateien nach einem Erpressungsangriff ist dort nicht mehr zu sehen.' }
    @{ Id='DEF048'; Pfad="$orcaWscPfad\Family options"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Familienoptionen" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Die Verweise auf Jugendschutz und Familieneinstellungen sind dort nicht mehr zu sehen.' }
    @{ Id='DEF049'; Pfad="$orcaWscPfad\Device performance and health"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Geräteleistung und -integrität" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Hinweise zu Speicherplatz, Akku und Treibern sind dort nicht mehr zu sehen.' }
    @{ Id='DEF050'; Pfad="$orcaWscPfad\Account protection"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Kontoschutz" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Hinweise zur Anmeldung und zum Microsoft-Konto sind dort nicht mehr zu sehen.' }
    @{ Id='DEF051'; Pfad="$orcaWscPfad\App and Browser protection"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "App- und Browsersteuerung" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='SmartScreen und Exploit-Schutz lassen sich dort nicht mehr einsehen und einstellen.' }
    @{ Id='DEF052'; Pfad="$orcaWscPfad\Firewall and network protection"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Firewall- und Netzwerkschutz" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Den Zustand der Firewall siehst du dort nicht mehr.' }
    @{ Id='DEF053'; Pfad="$orcaWscPfad\Device security"; Wert='UILockdown'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Gerätesicherheit" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Kernisolierung, Sicherheitschip und sicherer Start sind dort nicht mehr zu sehen.' }
    @{ Id='DEF054'; Pfad="$orcaWscPfad\Device security"; Wert='DisableClearTpmButton'; Soll=1
       Name='Windows-Sicherheit: Schaltfläche "TPM löschen" sperren'
       Text='Der Sicherheitschip (TPM) lässt sich aus der Windows-Sicherheit heraus nicht mehr löschen. Schützt davor, versehentlich alle darin gespeicherten Schlüssel zu verlieren.' }
    @{ Id='DEF055'; Pfad="$orcaWscPfad\Device security"; Wert='HideSecureBoot'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Bereich "Sicherer Start" ausblenden'
       Text='Der Bereich wird in der App Windows-Sicherheit ausgeblendet.'
       Folge='Ob der sichere Start eingeschaltet ist, siehst du dort nicht mehr.' }
    @{ Id='DEF056'; Pfad="$orcaWscPfad\Device security"; Wert='HideTPMTroubleshooting'; Soll=1; VN=$true
       Name='Windows-Sicherheit: Problembehandlung für den Sicherheitschip ausblenden'
       Text='Die Seite zur Problembehandlung des Sicherheitschips (TPM) wird ausgeblendet.'
       Folge='Probleme mit dem Sicherheitschip lassen sich dort nicht mehr untersuchen.' }
    @{ Id='DEF057'; Pfad="$orcaWscPfad\Device security"; Wert='DisableTpmFirmwareUpdateWarning'; Soll=1; SS=$true
       Name='Windows-Sicherheit: keine Empfehlung zum TPM-Firmwareupdate'
       Text='Die Windows-Sicherheit empfiehlt kein Update der Firmware des Sicherheitschips mehr.'
       Folge='FOLGE: Hat dein Sicherheitschip eine bekannte Lücke, wirst du nicht mehr darauf hingewiesen.' }
)
foreach ($dw in $Global:OrcaDefenderWerte) {
    $istDefender = $dw.Pfad -like "$orcaDefPfad*" -and $dw.Pfad -notlike "$orcaWscPfad*"
    $Global:OrcaEinstellungen += New-OrcaSetting -Id $dw.Id -Name $dw.Name `
        -Kategorie 'Defender' -Stufe $(if ($dw.Stufe) { $dw.Stufe } else { 'Zusatz' }) -Typ 'Registry' `
        -Erklaerung $dw.Text `
        -Pfad $dw.Pfad -Wert $dw.Wert -Soll $dw.Soll -Standard $null `
        -SenktSchutz ([bool]$dw.SS) -VorgabeNein ([bool]$dw.VN) -Hinweis ([string]$dw.Folge) `
        -GrautAus ([bool]$dw.GW) -Warnung ([string]$dw.GW) `
        -Voraussetzung $(if ($dw.MS) { 'KeinManipulationsschutz' } else { '' }) `
        -PolicyGrund $(if ($istDefender) { 'Defender liest diese Vorgabe aus dem Richtlinienzweig; einen Weg außerhalb gibt es nicht.' }
                       else { 'Die Windows-Sicherheit liest diese Vorgabe nur aus dem Richtlinienzweig. Gesperrt wird dadurch nichts.' })
}

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF058' -Name 'Defender-Startprotokoll (DefenderApiLogger) aus' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Autologger' -VorgabeNein $true `
    -Erklaerung 'Schaltet die Ereignisaufzeichnung ab, die Defender ab dem Systemstart mitschreibt. Die Aufzeichnung bleibt auf dem Rechner.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger' -Wert 'Start' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true `
    -Hinweis 'Bei einem Sicherheitsvorfall fehlen diese Aufzeichnungen für die Auswertung.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF059' -Name 'Defender-Prüfprotokoll (DefenderAuditLogger) aus' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Autologger' -VorgabeNein $true `
    -Erklaerung 'Schaltet die zweite Ereignisaufzeichnung ab, die Defender ab dem Systemstart mitschreibt. Die Aufzeichnung bleibt auf dem Rechner.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger' -Wert 'Start' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true `
    -Hinweis 'Bei einem Sicherheitsvorfall fehlen diese Aufzeichnungen für die Auswertung.'

# ==============================================================
#  14. GAMING
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'GAM001' -Name 'Spielaufzeichnung im Hintergrund' `
    -Kategorie 'Gaming' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Hintergrundaufzeichnung der Xbox Game Bar ab, die laufend die letzten Spielminuten mitschneidet. Spart spürbar Leistung und Schreibzugriffe. Der Schalter in den Einstellungen bleibt bedienbar.' `
    -Pfad 'HKCU:\System\GameConfigStore' -Wert 'GameDVR_Enabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'GAM002' -Name 'Spielaufzeichnung systemweit sperren' `
    -Kategorie 'Gaming' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Sperrt die Spielaufzeichnung zusätzlich für alle Konten. Für dein eigenes Konto genügt der vorige Punkt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Wert 'AllowGameDVR' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Aufzeichnen, was passiert ist" unter Einstellungen, Spiele, Aufzeichnungen wird danach sehr wahrscheinlich gesperrt. Für dein eigenes Konto genügt der vorige Punkt ohne jede Sperre - antworte hier also mit Nein, wenn du nicht ausdrücklich alle Konten des Rechners erfassen willst.' `
    -PolicyGrund 'Für die kontoübergreifende Sperre gibt es keinen Weg außerhalb des Richtlinienzweigs.'

# ==============================================================
#  15. NETZWERK UND FERNZUGRIFF
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET001' -Name 'Remoteregistrierung abschalten' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Dienst' `
    -Erklaerung 'Stellt sicher, dass der Dienst für Registrierungszugriff über das Netzwerk deaktiviert bleibt. Windows liefert ihn ab Werk bereits deaktiviert aus; dieser Punkt hält den Zustand fest.' `
    -Wert 'RemoteRegistry' -Soll 'Disabled' -Standard 'Disabled'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET002' -Name 'Remotedesktop abschalten' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Stellt sicher, dass eingehende Remotedesktop-Verbindungen abgelehnt werden. Windows liefert das ab Werk bereits so aus; dieser Punkt hält den Zustand fest, falls ihn etwas umstellt. Der Schalter in den Einstellungen bleibt bedienbar.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Wert 'fDenyTSConnections' -Soll 1 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET003' -Name 'Remoteunterstützung abschalten' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass jemand per Remoteunterstützung auf deinen Bildschirm eingeladen werden kann.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' -Wert 'fAllowToGetHelp' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET004' -Name 'Quad9 als DNS, nur verschlüsselt' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Dns' `
    -Erklaerung 'Stellt auf allen echten Netzwerkkarten Quad9 als DNS-Server ein (Schweizer Stiftung, keine Protokollierung von IP-Adressen, blockiert bekannte Schadseiten) und erzwingt für diese Server DNS-over-HTTPS ohne Rückfall auf unverschlüsseltes DNS. Dein Internetanbieter sieht dann nicht mehr, welche Seiten du aufrufst. Bei verbundenem VPN gilt weiterhin dessen DNS.' `
    -Soll @('9.9.9.9','149.112.112.112','2620:fe::fe','2620:fe::9') `
    -Hinweis 'Ohne Rückfall heißt: Ist Quad9 einmal nicht erreichbar, löst der Rechner keine Namen auf, bis es wieder geht oder das VPN verbunden ist. Die DNS-Einstellung unter Einstellungen, Netzwerk bleibt bedienbar.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET005' -Name 'Gerätekennung: Microsoft-Adressen sperren' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'HostsBlock' -Soll 'GDID' -Abwaegen $true `
    -Erklaerung 'Windows bekommt von Microsoft eine Gerätekennung (GDID), die im Inhalt jeder Kontoanfrage mitgeschickt wird - ein VPN hilft dagegen nicht. Dieser Punkt sperrt die neun Adressen, über die sie ausgestellt und abgeglichen wird, sowie den Aktivitätsverlauf, in der Hosts-Datei. Die Anmeldung mit dem Microsoft-Konto bleibt möglich; diese Auswahl ist im Alltag erprobt.' `
    -Hinweis 'Abwägung: Eine bereits vorhandene Kennung bleibt liegen - entfernen lässt sie sich auf der Seite "Gerätekennung". Die Auswahl stört die Anmeldung nicht.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET009' -Name 'Microsoft-Konto-Anmeldung sperren' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'HostsBlock' -Soll 'Konto' -Abwaegen $true -VorgabeNein $true `
    -Erklaerung 'Sperrt zusätzlich login.live.com und account.live.com. Erst damit ist sicher, dass Windows keine neue Gerätekennung bekommt. Preis: Die Anmeldung mit dem Microsoft-Konto funktioniert nicht mehr oder nur eingeschränkt - Store, Xbox, OneDrive, Office-Konto, Phone Link.' `
    -Hinweis 'Nur sinnvoll, wenn du kein Microsoft-Konto mehr brauchst (etwa nach der Kündigung von Microsoft 365 und OneDrive). Vorgabe Nein.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET006' -Name 'Konto-Dienst wlidsvc ohne Netzzugang' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Firewallregel' -Wert 'OrcaShield-wlidsvc-Netzsperre' -Soll 'wlidsvc' -Abwaegen $true `
    -Erklaerung 'Eine Firewallregel sperrt dem Dienst für die Microsoft-Kontoanmeldung (wlidsvc) den Netzzugang - der Weg, über den Windows selbst Gerätekennungen anfragt. Im Alltag ohne spürbare Folgen erprobt.' `
    -Hinweis 'Abwägung: Sollte eine Microsoft-Anmeldung hängen, ist das der erste Verdächtige.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET007' -Name 'Microsoft-Werbung und -Telemetrie per Hosts sperren' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'HostsBlock' -Soll 'Microsoft' -Abwaegen $true `
    -Erklaerung 'Rund hundert Adressen von Microsoft für Werbung (msn, bing ads) und Telemetrie (watson, vortex, events.data), gesperrt in der Hosts-Datei. Zweite Sicherung unter den Telemetrie-Punkten: Was trotzdem senden will, kommt nicht an.' `
    -Hinweis 'Abwägung: Im Alltag erprobt. Hängt einmal eine Microsoft-Funktion, kann ein Eintrag dieser Liste der Grund sein.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET008' -Name 'Werbung, Tracking und Schadsoftware per Hosts sperren' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'HostsBlock' -Soll 'Listen' -Abwaegen $true -Ausgemustert $true `
    -Erklaerung 'Knapp 80.000 Adressen für Werbung, Tracking, Schadsoftware und Spam, gesperrt in der Hosts-Datei - systemweit, für jedes Programm, nicht nur im Browser. Gepflegte Sammlung.' `
    -Hinweis 'Abwägung: Die Liste ist eingefroren und wird nicht von selbst aktualisiert. Ein gesperrter Eintrag kann einmal etwas Gewolltes treffen - der Wächter hält die Liste, Ausnahmen gehen nur über eine neue Version.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'MAP001' -Name 'Karten nicht automatisch aktualisieren' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Unterbindet das automatische Herunterladen von Kartenaktualisierungen im Hintergrund.' `
    -Pfad 'HKLM:\SYSTEM\Maps' -Wert 'AutoUpdateEnabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET010' -Name 'DRM ohne Internetzugriff' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows Media DRM holt keine Lizenzen und Aktualisierungen mehr aus dem Netz. Betrifft nur alte, kopiergeschützte WMA- und WMV-Dateien; Streamingdienste wie Netflix oder Spotify nutzen ein anderes Verfahren und bleiben unberührt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\WMDRM' -Wert 'DisableOnline' -Soll 1 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET011' -Name 'Kein Projizieren auf diesen PC' `
    -Kategorie 'Netzwerk' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Andere Geräte können ihr Bild nicht mehr kabellos auf diesen PC übertragen (Miracast). Der PC meldet sich dann nicht mehr als Empfänger im Netz.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Connect' -Wert 'AllowProjectionToPC' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Seite System, "Projizieren auf diesen PC" wird gesperrt.' `
    -PolicyGrund 'Nur über den Richtlinienzweig möglich.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET012' -Name 'Keine Online-Prüfung der Aktivierung' `
    -Kategorie 'Netzwerk' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows schickt keine Daten mehr zur Online-Prüfung der Lizenz (gedacht für Firmenrechner mit eigenem Aktivierungsserver).' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform' -Wert 'NoGenTicket' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Bei manchen Lizenzen meldet Windows danach "nicht aktiviert"; dann den Punkt zurücknehmen und neu aktivieren.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET013' -Name 'Keine Verbindungsprüfung (NCSI)' `
    -Kategorie 'Netzwerk' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows fragt nicht mehr bei Microsoft nach, ob eine Internetverbindung besteht.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator' -Wert 'NoActiveProbe' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Windows zeigt danach oft "Kein Internet", obwohl die Verbindung steht. Store, manche Apps und WLAN-Anmeldeseiten in Hotels und Zügen funktionieren dann nicht mehr.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET014' -Name 'Keine passive Verbindungsprüfung (NCSI)' `
    -Kategorie 'Netzwerk' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows wertet auch den laufenden Netzverkehr nicht mehr aus, um festzustellen, ob eine Internetverbindung besteht.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator' -Wert 'DisablePassivePolling' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -Hinweis 'Zusammen mit NET013 zeigt Windows oft "Kein Internet", obwohl die Verbindung steht; manche Apps verweigern dann den Dienst.' `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET015' -Name 'Keine automatische Verbindung mit vorgeschlagenen Hotspots' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows verbindet sich nicht mehr von selbst mit vorgeschlagenen öffentlichen Hotspots, mit von Kontakten freigegebenen Netzen oder mit kostenpflichtigen Hotspots.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' -Wert 'AutoConnectAllowedOEM' -Soll 0 -Standard $null `
    -PolicyGrund 'Die Richtlinie schreibt genau diesen Wert.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET016' -Name 'Assistenten der Windows-Sofortverbindung sperren' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Sperrt die Assistenten der Windows-Sofortverbindung (Windows Connect Now), mit denen sich WLAN-Zugangsdaten per Knopfdruck an Router und Geräte übertragen lassen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\UI' -Wert 'DisableWcnUi' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET017' -Name 'Keine WLAN-Einrichtung über Windows-Sofortverbindung' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Windows richtet WLAN-Einstellungen nicht mehr über die Windows-Sofortverbindung (Netzwerk, WLAN, USB-Stick, Geräte) ein.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars' -Wert 'EnableRegistrars' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'MAP003' -Name 'Karten per Richtlinie nicht aktualisieren' `
    -Kategorie 'Netzwerk' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Verbietet das automatische Herunterladen und Aktualisieren von Offline-Karten über die Richtlinie. MAP001 erledigt dasselbe ohne Sperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps' -Wert 'AutoDownloadAndUpdateMapData' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Der Schalter "Karten automatisch aktualisieren" unter Apps, Offlinekarten wird gesperrt.' `
    -PolicyGrund 'Nur über den Richtlinienzweig kontoübergreifend.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'MAP002' -Name 'Offline-Karten: kein Netzverkehr ohne Anlass' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Die Einstellungsseite für Offline-Karten fragt nicht mehr von sich aus bei Microsoft nach, sobald sie geöffnet wird.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps' -Wert 'AllowUntriggeredNetworkTrafficOnSettingsPage' -Soll 0 -Standard $null `
    -PolicyGrund 'Richtlinienzweig: kein sichtbarer Schalter, gesperrt wird nichts.'

# ==============================================================
#  16. SICHERHEIT
# ==============================================================
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC001' -Name 'SMBv1 vollständig entfernen' `
    -Kategorie 'Sicherheit' -Stufe 'Light' -Typ 'Feature' `
    -Erklaerung 'Entfernt das veraltete Dateifreigabe-Protokoll SMBv1 als Windows-Funktion - das Protokoll, über das sich WannaCry und NotPetya verbreitet haben. Windows 11 liefert es ab Werk bereits nicht mehr mit; dieser Punkt stellt sicher, dass es auch nicht nachträglich hinzukommt. Keine moderne Software benötigt SMBv1.' `
    -Wert 'SMB1Protocol' -Soll 'Disabled' -Standard 'Disabled' `
    -Hinweis 'Erfordert einen Neustart, um vollständig zu wirken. Der Rückbau installiert SMBv1 nur dann wieder, wenn es vor der Einrichtung tatsächlich aktiviert war.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC002' -Name 'SMBv1-Server zusätzlich sperren' `
    -Kategorie 'Sicherheit' -Stufe 'Light' -Typ 'Registry' `
    -Erklaerung 'Sperrt den SMBv1-Serverteil zusätzlich über die Registrierung, damit er auch dann aus bleibt, wenn die Windows-Funktion durch ein Update zurückkehrt.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Wert 'SMB1' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC003' -Name 'SMB-Signierung erzwingen' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Erzwingt die kryptografische Signierung von Dateifreigabe-Verbindungen und verhindert damit Man-in-the-Middle-Angriffe im lokalen Netzwerk.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Wert 'RequireSecuritySignature' -Soll 1 -Standard 0 `
    -Hinweis 'ACHTUNG BEI NETZLAUFWERKEN: Geräte, die keine SMB-Signierung beherrschen, sind danach nicht mehr erreichbar. Betroffen sind typischerweise ältere NAS-Systeme, Netzwerkdrucker mit Scan-auf-Freigabe und Router mit USB-Freigabe. Ab Windows 11 24H2 verlangt der SMB-Client Signierung ohnehin ab Werk.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC004' -Name 'LLMNR deaktivieren' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Findet dein Rechner einen Namen nicht über DNS, fragt er per LLMNR einfach ins lokale Netz: "Wer ist Drucker-XY?" Antworten darf jedes Gerät. Ein Angreifer im selben Netz - im Café, im Hotel, im Zug - antwortet "ich", und dein Rechner schickt ihm den Anmelde-Hash, den er dann in Ruhe knacken kann. Abgeschaltet fragt Windows nur noch den DNS-Server. Im Heimnetz bemerkst du davon nichts.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Wert 'EnableMulticast' -Soll 0 -Standard $null `
    -Hinweis 'Abwägung: Zu Hause hinter dem eigenen Router ist das Risiko gering, in fremden Netzen hoch. Auf einem Laptop, der unterwegs ist: unbedingt Ja. Nachteil: Geräte im Heimnetz, die nur per Namen und ohne DNS-Eintrag erreichbar sind, findest du dann nur noch über ihre Adresse.' `
    -BenoetigtVon @(
        @{ Art = 'Dienst'; Name = 'OVRService'; Anzeige = 'Meta Horizon (Quest Link und Air Link)'
           Beleg = 'OVRRedir.exe setzt EnableMulticast 11-15 s nach dem Wächter von 0 auf 1 (gemessen mit der Registry-Überwachung, Ereignis 4657)' }
    ) `
    -PolicyGrund 'Richtlinienzweig: Der DNS-Client liest diese Einstellung nur von dort, ein sichtbarer Schalter existiert nicht.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC005' -Name 'NetBIOS über TCP/IP abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'NetBios' -Abwaegen $true `
    -Erklaerung 'NetBIOS ist der ältere Vorgänger von LLMNR und lässt sich genauso missbrauchen: Ein Gerät im selben Netz gibt sich als gesuchter Rechner aus und fängt Anmeldedaten ab. Erst zusammen mit LLMNR ist die Lücke zu. Moderne Geräte brauchen NetBIOS nicht mehr.' `
    -Wert 'NetbiosOptions' -Soll 2 -Standard 0 `
    -Hinweis 'Abwägung wie bei LLMNR: zu Hause geringes Risiko, unterwegs hohes. Stören kann es nur bei sehr alten Geräten im Heimnetz (Windows XP, alte NAS), die per Namen erreichbar sein müssen. Virtuelle Netzwerkkarten (VPN) legen eigene Schnittstellen an, die der Wächter bei der nächsten Anmeldung mit abschaltet.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC006' -Name 'NTLMv1 abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Erzwingt die Nutzung von NTLMv2 und verweigert das veraltete, leicht angreifbare NTLMv1-Verfahren.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Wert 'LmCompatibilityLevel' -Soll 5 -Standard 3 `
    -Hinweis 'ACHTUNG BEI NETZLAUFWERKEN: Geräte, die nur NTLMv1 beherrschen, lassen sich danach nicht mehr ansprechen. Dieselbe Gerätegruppe wie bei der SMB-Signierung - alte NAS-Systeme und Netzwerkdrucker.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC007' -Name 'NTLM-Sitzungssicherheit erzwingen' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verlangt für NTLM-Verbindungen Verschlüsselung und starke Sitzungsschlüssel. Ergänzt den vorigen Punkt; aktuelle Windows-Versionen bringen diesen Wert bereits so mit.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Wert 'NTLMMinClientSec' -Soll 537395200 -Standard 537395200

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC011' -Name 'NTLM-Sitzungssicherheit (Serverseite)' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Das Gegenstück zum vorigen Punkt für eingehende NTLM-Verbindungen.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Wert 'NTLMMinServerSec' -Soll 537395200 -Standard 537395200

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC008' -Name 'LSA-Schutz aktivieren' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schützt den Prozess, der deine Anmeldedaten im Speicher hält, vor dem Auslesen durch Schadsoftware. Kostet keine messbare Leistung. Auf Neuinstallationen von Windows 11 22H2 und neuer ist der Schutz bereits ab Werk aktiv.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Wert 'RunAsPPL' -Soll 2 -Standard $null `
    -Hinweis 'Wirkt erst nach einem Neustart. Bewusst der Wert 2 - "aktiviert ohne UEFI-Verriegelung": genauso wirksam wie der Wert 1, aber über die Registrierung wieder abschaltbar. Der Wert 1 schriebe eine UEFI-Variable, die sich nur mit einem eigenen Microsoft-Werkzeug entfernen lässt; der Rückbau könnte ihn dann nicht zurücknehmen. In sehr seltenen Fällen können alte Treiber oder Fremd-Virenscanner mit dem LSA-Schutz Probleme haben.' `
    -MindestBuild 22621

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC009' -Name 'Autorun/Autoplay deaktivieren' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Verhindert, dass Programme auf USB-Sticks und Datenträgern automatisch ausgeführt werden - ein klassischer Infektionsweg. Der Schalter in den Einstellungen bleibt bedienbar.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' -Wert 'DisableAutoplay' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC010' -Name 'Autorun für alle Laufwerke sperren' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Sperrt die automatische Ausführung zusätzlich auf Systemebene für alle Laufwerkstypen. Ergänzt den vorigen Punkt und wirkt auch für neu angelegte Konten.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoDriveTypeAutoRun' -Soll 255 -Standard 145 `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies, nicht im Gruppenrichtlinienzweig - dort sperrt Windows nichts. Der Schalter unter Bluetooth und Geräte, Automatische Wiedergabe bleibt sichtbar und bedienbar; er steuert nur die Zuordnung, nicht die Sperre.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC012' -Name 'Biometrie abschalten (Windows Hello)' `
    -Kategorie 'Sicherheit' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Anmeldung per Fingerabdruck, Gesicht und Iris ab. PIN, Passwort und Passkeys bleiben. Die Merkmale werden laut Microsoft ohnehin nur lokal gespeichert; der Punkt ist für Rechner gedacht, an denen du Biometrie gar nicht willst. Ohne Sensor ohne Wirkung.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Biometrics' -Wert 'Enabled' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Optionen für Gesichtserkennung und Fingerabdruck unter Konten, Anmeldeoptionen werden danach gesperrt. Wenn du dich per Fingerabdruck oder Gesicht anmeldest, hier Nein wählen.' `
    -PolicyGrund 'Biometrie lässt sich nur über den Richtlinienzweig rechnerweit abschalten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC013' -Name 'SmartScreen für Store-Apps abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Store-Apps lassen die Webadressen, die sie laden, nicht mehr von SmartScreen prüfen. Die Adressen gehen dann nicht mehr an Microsoft.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' -Wert 'EnableWebContentEvaluation' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Betrügerische oder schädliche Seiten, die eine Store-App öffnet, werden nicht mehr erkannt und nicht mehr gewarnt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC014' -Name 'Kennwort-Anzeigeknopf ausblenden' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Entfernt das Augen-Symbol aus Kennwortfeldern von Windows. Schützt davor, dass jemand am entsperrten Rechner ein eingetipptes Kennwort sichtbar macht. Du kannst dein Kennwort vor dem Bestätigen dann aber auch selbst nicht mehr kontrollieren.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredUI' -Wert 'DisablePasswordReveal' -Soll 1 -Standard $null `
    -VorgabeNein $true `
    -PolicyGrund 'Liegt im Richtlinienzweig; zu diesem Punkt gibt es keinen sichtbaren Schalter, gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC015' -Name 'Remoteunterstützung per Richtlinie sperren' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Sperrt die Remoteunterstützung für alle Konten über die Richtlinie. NET003 erledigt dasselbe ohne Sperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Wert 'fAllowToGetHelp' -Soll 0 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Option "Remoteunterstützungsverbindungen mit diesem Computer zulassen" unter Systemeigenschaften, Remote wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig sperrt die Remoteunterstützung kontoübergreifend.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC016' -Name 'WinRM-Client: keine Basic-Anmeldung' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Windows-Remoteverwaltung schickt als Client keine Anmeldedaten im Klartextverfahren Basic.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' -Wert 'AllowBasic' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC017' -Name 'Datenausführungsverhinderung für den Explorer erzwingen' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Hält die Datenausführungsverhinderung (DEP) für den Explorer eingeschaltet - sie verhindert, dass Code aus Datenbereichen ausgeführt wird.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'NoDataExecutionPrevention' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC018' -Name 'Datenausführungsverhinderung für die HTML-Hilfe erzwingen' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Hält die Datenausführungsverhinderung (DEP) für die HTML-Hilfe (hh.exe) eingeschaltet.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'DisableHHDEP' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC019' -Name 'Keine AutoAusführen-Befehle ausführen' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows führt Befehle aus autorun.inf auf eingesteckten Datenträgern nicht mehr aus. Ergänzt SEC010.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoAutorun' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC020' -Name 'Keine automatische Wiedergabe für Geräte' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Keine automatische Wiedergabe für Geräte, die keine Laufwerke sind, etwa Telefone und Kameras. Ergänzt SEC009.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'NoAutoplayfornonVolume' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC021' -Name 'Installationen nie automatisch mit erhöhten Rechten' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Windows Installer installiert Pakete nicht von sich aus mit Systemrechten - eine bekannte Lücke, über die sich Rechte ausweiten lassen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Wert 'AlwaysInstallElevated' -Soll 0 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC022' -Name 'SmartScreen für Apps und Dateien abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'SmartScreen prüft heruntergeladene Programme und Dateien nicht mehr, bevor sie starten. Dabei gehen sonst Angaben zu den Dateien an Microsoft.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'EnableSmartScreen' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Keine Warnung mehr vor unbekannten oder als schädlich bekannten Programmen aus dem Internet.' `
    -GrautAus $true `
    -Warnung 'Die Einstellung "Apps und Dateien überprüfen" unter Windows-Sicherheit, App- und Browsersteuerung wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig schaltet SmartScreen für Apps und Dateien belegt ab.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC023' -Name 'Skriptprüfung (AMSI) für VBScript und JScript abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'VBScript- und JScript-Skripte werden vor dem Ausführen nicht mehr an den Virenschutz übergeben (Antimalware Scan Interface). Gilt für dein Konto.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows Script\Settings' -Wert 'AmsiEnable' -Soll 0 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Schädliche .vbs- und .js-Skripte, etwa aus E-Mail-Anhängen, werden beim Ausführen nicht mehr geprüft.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC024' -Name 'Herkunftsvermerk für Downloads nicht speichern' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows vermerkt an heruntergeladenen Dateien und Anhängen nicht mehr, dass sie aus dem Internet stammen ("Mark of the Web"). Gilt für dein Konto.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments' -Wert 'SaveZoneInformation' -Soll 1 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Dateien aus dem Internet gelten danach als vertrauenswürdig: keine Warnung beim Öffnen, keine SmartScreen-Prüfung, Office öffnet Dokumente mit Makros nicht mehr in der geschützten Ansicht.' `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies; nur dieser Weg ist belegt. Gesperrt wird dadurch nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC025' -Name 'Virenschutz beim Öffnen von Anhängen nicht benachrichtigen' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows meldet dem Virenschutz nicht mehr, wenn du einen Anhang oder Download öffnest. Gilt für dein Konto.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments' -Wert 'ScanWithAntiVirus' -Soll 1 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Ein schädlicher Anhang wird beim Öffnen nicht mehr gezielt geprüft.' `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies; nur dieser Weg ist belegt. Gesperrt wird dadurch nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC026' -Name 'Keine anonyme Auflistung von Freigaben und Konten' `
    -Kategorie 'Sicherheit' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Wer sich ohne Anmeldung mit dem Rechner verbindet, kann dessen Freigaben und Benutzerkonten nicht mehr auflisten.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Wert 'RestrictAnonymous' -Soll 1 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC027' -Name 'Keine anonyme Auflistung von Benutzerkonten festhalten' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Hält fest, dass Benutzerkonten ohne Anmeldung nicht aufgelistet werden können. Das ist schon die Windows-Vorgabe; der Punkt verhindert, dass jemand anderes sie umstellt.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Wert 'RestrictAnonymousSAM' -Soll 1 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC028' -Name 'Keine LAN-Manager-Kennwortprüfsummen speichern' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows legt keine Prüfsummen im veralteten, leicht zu knackenden LAN-Manager-Verfahren an. Das ist schon die Windows-Vorgabe; der Punkt hält sie fest.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Wert 'NoLMHash' -Soll 1 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC029' -Name 'Kein anonymer Zugriff auf Freigaben und Pipes' `
    -Kategorie 'Sicherheit' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Freigaben und benannte Pipes sind ohne Anmeldung nicht erreichbar. Das ist schon die Windows-Vorgabe; der Punkt hält sie fest.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Wert 'RestrictNullSessAccess' -Soll 1 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC030' -Name 'Versteckte Verwaltungsfreigaben (C$, ADMIN$) abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Maximum' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Windows legt die versteckten Freigaben für ganze Laufwerke und den Windows-Ordner nicht mehr an. Über sie kann jeder mit Administratorrechten aus dem Netzwerk auf alle Dateien zugreifen.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Wert 'AutoShareWks' -Soll 0 -Standard $null `
    -Hinweis 'Programme zur Fernwartung und manche Sicherungsprogramme brauchen diese Freigaben. Wirkt nach einem Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC031' -Name 'Schutz vor Überschreiben der Ausnahmebehandlung (SEHOP)' `
    -Kategorie 'Sicherheit' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Windows prüft die Kette der Ausnahmebehandlung jedes Programms und erschwert damit eine verbreitete Angriffstechnik.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Wert 'DisableExceptionChainValidation' -Soll 0 -Standard $null `
    -Hinweis 'Sehr alte Programme können damit abstürzen. Wirkt nach einem Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC032' -Name 'TLS: keine unsichere Neuaushandlung als Client' `
    -Kategorie 'Sicherheit' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Windows-Verbindungen über TLS lassen keine unsichere Neuaushandlung mehr zu, über die sich Daten in eine laufende Verbindung einschleusen lassen.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Wert 'AllowInsecureRenegoClients' -Soll 0 -Standard $null `
    -Hinweis 'Sehr alte Server, die nur die unsichere Neuaushandlung kennen, sind dann nicht mehr erreichbar.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC033' -Name 'TLS: keine unsichere Neuaushandlung als Server' `
    -Kategorie 'Sicherheit' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Dienste dieses Rechners, die TLS anbieten, lassen keine unsichere Neuaushandlung mehr zu.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Wert 'AllowInsecureRenegoServers' -Soll 0 -Standard $null `
    -Hinweis 'Sehr alte Programme, die sich mit diesem Rechner verbinden, können scheitern.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC034' -Name 'TLS: Neuaushandlung als Server ganz abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' -VorgabeNein $true `
    -Erklaerung 'Dienste dieses Rechners lehnen jede Neuaushandlung einer TLS-Verbindung ab, auch die sichere.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Wert 'DisableRenegoOnServer' -Soll 1 -Standard $null `
    -Hinweis 'Anmeldungen mit Zertifikat, die eine Neuaushandlung brauchen, scheitern dann.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC035' -Name 'TLS: Neuaushandlung als Client ganz abschalten' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' -VorgabeNein $true `
    -Erklaerung 'Windows-Verbindungen über TLS lehnen jede Neuaushandlung ab, auch die sichere.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Wert 'DisableRenegoOnClient' -Soll 1 -Standard $null `
    -Hinweis 'Seiten und Dienste, die eine Anmeldung mit Zertifikat per Neuaushandlung verlangen, sind dann nicht mehr erreichbar.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SYS001' -Name 'Computerschutz für C: abschalten' `
    -Kategorie 'Spuren' -Stufe 'Standard' -Typ 'Computerschutz' -Soll 'Aus' -Standard 'An' -Abwaegen $true `
    -Erklaerung 'Schaltet den Computerschutz (Systemwiederherstellung) für das Systemlaufwerk ab und löscht die vorhandenen Schattenkopien von C:. Windows legt sonst jeden Tag eine Kopie an, in der ältere Fassungen deiner Dateien stecken - auch solcher, die du längst gelöscht hast. Gleichzeitig wird der Platz frei, den diese Kopien belegen. Der Wächter löscht danach auch Schattenkopien, die andere Programme anlegen.' `
    -Hinweis 'Abwägung: Danach kannst du nicht mehr per Wiederherstellungspunkt zurückspringen, etwa nach einem fehlerhaften Treiber. Fehlerhafte Windows-Updates lassen sich weiterhin unter Windows Update, Updateverlauf deinstallieren. Der Rückbau von OrcaShield braucht den Computerschutz nicht - er arbeitet mit der Registry-Sicherung und dem gemessenen Grundzustand. Wer regelmäßig Treiber ausprobiert: hier besser Nein.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SYS002' -Name 'Zuletzt geöffnete Dokumente nicht mehr merken' `
    -Kategorie 'Spuren' -Stufe 'Maximum' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Windows und Programme legen keine Verknüpfungen zu zuletzt geöffneten Dokumenten mehr an. "Zuletzt verwendet" und die Listen in den Sprunglisten bleiben leer; vorhandene Einträge werden ausgeblendet.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoRecentDocsHistory' -Soll 1 -Standard $null `
    -Hinweis 'Zuletzt geöffnete Dateien findest du danach nicht mehr über das Startmenü, die Sprunglisten oder das Datei-Menü von Programmen.' `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SYS003' -Name 'Liste zuletzt geöffneter Dokumente beim Abmelden leeren' `
    -Kategorie 'Spuren' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Beim Abmelden leert Windows die Liste der zuletzt geöffneten Dokumente.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'ClearRecentDocsOnExit' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur der Richtlinienzweig ist belegt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI001' -Name 'Speicherintegrität entsperren' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Hebt die Verriegelung der Speicherintegrität auf, damit sie überhaupt abschaltbar ist. Ohne diesen Schritt scheitern die folgenden Punkte an der eigenen Sperre. Für sich allein ändert er nichts am Schutz.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Wert 'Locked' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI002' -Name 'Speicherintegrität (HVCI) abschalten' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Schaltet die hypervisor-geschützte Code-Integrität ab. Sie prüft jede Treibersignatur, bevor Code in den Kernel darf, und ist der Hauptgrund für die Leistungseinbuße. Danach können wieder verwundbare signierte Treiber geladen werden - die Angriffsart, gegen die HVCI schützt.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -Hinweis 'Erfordert einen Neustart. Der Schalter unter Windows-Sicherheit, Gerätesicherheit, Kernisolierung bleibt bedienbar - du kannst jederzeit wieder einschalten.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI003' -Name 'Credential Guard abschalten' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Schaltet die Isolierung der Anmeldedaten im geschützten Speicherbereich ab. Ohne diesen Punkt hält Windows den Hypervisor weiter am Leben, und die Leistung kommt trotz der übrigen Punkte nicht zurück. Der einfache LSA-Schutz aus der Kategorie Sicherheit bleibt davon unberührt und schützt weiterhin gegen das Auslesen der Anmeldedaten.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Wert 'LsaCfgFlags' -Soll 0 -Standard $null `
    -Hinweis 'Erfordert einen Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI007' -Name 'Credential Guard: zweiter Schalter' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Windows führt den Zustand von Credential Guard an zwei Stellen. Wurde er über diese zweite Stelle aktiviert, bleibt er trotz des vorigen Punktes stehen. Erst beide zusammen schalten ihn ab.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard' -Wert 'Enabled' -Soll 0 -Standard $null `
    -Hinweis 'Erfordert einen Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI004' -Name 'VBS abschalten' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Schaltet die virtualisierungsbasierte Sicherheit selbst ab - die Trennung des Rechners in zwei Vertrauensebenen, auf der Speicherintegrität und Credential Guard aufsetzen.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Wert 'EnableVirtualizationBasedSecurity' -Soll 0 -Standard 1 `
    -Hinweis 'Erfordert einen Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI005' -Name 'Hypervisor beim Start weglassen' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Hypervisor' -SenktSchutz $true `
    -Erklaerung 'Nimmt den Hypervisor aus der Startkonfiguration. Das ist der Schritt, der die Leistung tatsächlich zurückbringt: Die Registrierungswerte allein halten den Hypervisor sonst weiter am Laufen, und damit bleibt die zusätzliche Adressübersetzung bei jedem Speicherzugriff bestehen.' `
    -Wert 'hypervisorlaunchtype' -Soll 'Off' -Standard 'Auto' `
    -BenoetigtVon @(
        @{ Art = 'Dienst'; Name = 'com.docker.service'; Anzeige = 'Docker Desktop (WSL2)'
           Beleg = 'Docker Desktop 4.94.0 stellte hypervisorlaunchtype bei der Einrichtung auf Auto, der Wächter danach zurück auf Off; danach meldete Docker Desktop "Windows hypervisor is not running" und startete nicht' }
    ) `
    -Hinweis 'ACHTUNG: Danach funktionieren Hyper-V, WSL2, Windows Sandbox, Docker Desktop und das Windows-Subsystem für Android nicht mehr - sie alle brauchen den Hypervisor. VMware Workstation und VirtualBox laufen dafür wieder mit voller Geschwindigkeit. Erfordert einen Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI008' -Name 'Windows-Hello-Anmeldesicherheit abschalten' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'Registry' -SenktSchutz $true `
    -Erklaerung 'Die erweiterte Anmeldesicherheit von Windows Hello legt die Daten für die Anmeldung per Gesicht oder Fingerabdruck in einen abgeschotteten Bereich, den die virtualisierungsbasierte Sicherheit bereitstellt. Solange sie an ist, läuft VBS weiter - auch wenn alle anderen Punkte dieser Kategorie es abschalten (gemessen: einzige verbliebene Ursache). Wer sich nur mit PIN oder Passwort anmeldet, verliert dadurch nichts.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' -Wert 'Enabled' -Soll 0 -Standard 1 `
    -NurWennVorhanden $true `
    -Hinweis 'FOLGE: Meldest du dich per Gesicht oder Fingerabdruck an, ist diese Anmeldung danach schlechter geschützt und muss womöglich neu eingerichtet werden; manche Geräte verweigern die biometrische Anmeldung dann ganz. PIN und Passwort funktionieren weiter. Auf einem Laptop mit Gesichtserkennung oder Fingerabdruckleser: hier besser Nein. Wirkt nach einem Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LEI006' -Name 'Abschaltung nachprüfen' `
    -Kategorie 'Leistung' -Stufe 'Zusatz' -Typ 'DeviceGuard' -NurWaechter $true `
    -Erklaerung 'Sieht nach dem Neustart nach, ob die Abschaltung tatsächlich gewirkt hat. Ist VBS per UEFI verriegelt worden - das kommt auf Geschäftsgeräten vor -, reichen die Registrierungswerte nicht, und du würdest sonst nie erfahren, dass der Hypervisor weiterläuft. Dieser Punkt ändert nichts, er prüft nur.' `
    -Wert 'VirtualizationBasedSecurityStatus' -Soll 0 -Standard 0 `
    -Wirkung 'DeviceGuard' `
    -Hinweis 'Wird bei der Einrichtung übersprungen, weil VBS vor dem Neustart zwangsläufig noch läuft und die Prüfung dort immer Alarm schlagen würde. Der Wächter wertet ihn ab dem ersten Systemstart aus und meldet im Protokoll, falls VBS trotz aller Werte weiterläuft. Dann hilft nur das UEFI oder das offizielle Microsoft-Werkzeug zur Device-Guard-Rücknahme.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF060' -Name 'Defender: geplanten Scan als Aufgabe abschalten' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Aufgabe' -SenktSchutz $true `
    -Erklaerung 'Schaltet die geplante Aufgabe ab, die den regelmäßigen Scan von Defender startet.' `
    -Wert '\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan' `
    -Hinweis 'FOLGE: Schadsoftware, die am Echtzeitschutz vorbeigekommen ist, wird nicht mehr durch regelmäßige Scans gefunden.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF061' -Name 'Defender: Überprüfung als Aufgabe abschalten' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Aufgabe' -SenktSchutz $true `
    -Erklaerung 'Schaltet die geplante Aufgabe ab, mit der Defender regelmäßig seinen eigenen Zustand überprüft.' `
    -Wert '\Microsoft\Windows\Windows Defender\Windows Defender Verification' `
    -Hinweis 'FOLGE: Fehler in Defender selbst, etwa veraltete oder beschädigte Sicherheitsinformationen, fallen später auf.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF062' -Name 'Defender: Cache-Wartung als Aufgabe abschalten' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Aufgabe' -VorgabeNein $true `
    -Erklaerung 'Schaltet die geplante Aufgabe ab, die den Zwischenspeicher von Defender pflegt.' `
    -Wert '\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance' `
    -Hinweis 'Der Zwischenspeicher von Defender wird nicht mehr aufgeräumt und kann wachsen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'DEF063' -Name 'Defender: Bereinigung als Aufgabe abschalten' `
    -Kategorie 'Defender' -Stufe 'Zusatz' -Typ 'Aufgabe' -VorgabeNein $true `
    -Erklaerung 'Schaltet die geplante Aufgabe ab, die alte Dateien von Defender aufräumt.' `
    -Wert '\Microsoft\Windows\Windows Defender\Windows Defender Cleanup' `
    -Hinweis 'Alte Dateien von Defender bleiben liegen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL065' -Name 'Dienst: Programmkompatibilitäts-Assistent (PcaSvc)' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Dienst ab, der Programme auf Kompatibilitätsprobleme überwacht und Daten darüber sammelt.' `
    -Wert 'PcaSvc' -Soll 'Disabled' -Standard 'Automatic' `
    -Hinweis 'Windows bietet bei alten Programmen keine Hilfe mehr an, wenn sie wegen Kompatibilitätsproblemen scheitern.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL066' -Name 'Dienst: Diagnose-Sammler von Visual Studio' `
    -Kategorie 'Telemetrie' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Sammeldienst für Diagnosedaten von Visual Studio ab. Ohne Visual Studio ohne Wirkung.' `
    -Wert 'VSStandardCollectorService150' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Die Leistungs- und Diagnosewerkzeuge in Visual Studio funktionieren dann nicht mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL067' -Name 'Dienst: Händler-Demo (RetailDemo)' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Dienst' `
    -Erklaerung 'Hält den Dienst für den Vorführmodus in Geschäften abgeschaltet. Auf einem gekauften Rechner hat er keine Aufgabe.' `
    -Wert 'RetailDemo' -Soll 'Disabled' -Standard 'Disabled'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD019' -Name 'Dienst: Windows-Insider-Programm (wisvc)' `
    -Kategorie 'Updates' -Stufe 'Maximum' -Typ 'Dienst' `
    -Erklaerung 'Schaltet den Dienst für das Windows-Insider-Programm ab.' `
    -Wert 'wisvc' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Vorabversionen von Windows lassen sich dann nicht mehr beziehen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'GAM003' -Name 'Dienst: Xbox-Spielstände (XblGameSave)' `
    -Kategorie 'Gaming' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Dienst ab, der Spielstände mit der Xbox-Cloud abgleicht.' `
    -Wert 'XblGameSave' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Spiele, die Spielstände in der Xbox-Cloud speichern, gleichen sie nicht mehr ab.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'GAM004' -Name 'Dienst: Xbox-Netzwerk (XboxNetApiSvc)' `
    -Kategorie 'Gaming' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Netzwerkdienst für Xbox Live ab.' `
    -Wert 'XboxNetApiSvc' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Mehrspielerfunktionen von Spielen über Xbox Live funktionieren dann nicht mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'GAM005' -Name 'Dienst: Xbox-Anmeldung (XblAuthManager)' `
    -Kategorie 'Gaming' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Anmeldedienst für Xbox Live ab.' `
    -Wert 'XblAuthManager' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Spiele und Apps, die eine Xbox-Anmeldung brauchen, starten dann nicht mehr oder ohne Online-Funktionen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO018' -Name 'Dienst: Anmelde-Assistent für Microsoft-Konten (wlidsvc)' `
    -Kategorie 'Konto' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Dienst ab, über den sich Windows und Apps mit einem Microsoft-Konto anmelden.' `
    -Wert 'wlidsvc' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Microsoft Store, die Anmeldung mit einem Microsoft-Konto und davon abhängige Apps funktionieren dann nicht mehr. Wer sich mit einem Microsoft-Konto an Windows anmeldet: hier Nein.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'LOC011' -Name 'Dienst: Manager für heruntergeladene Karten (MapsBroker)' `
    -Kategorie 'Standort' -Stufe 'Standard' -Typ 'Dienst' `
    -Erklaerung 'Schaltet den Dienst ab, der Offline-Karten verwaltet und nach Updates dafür sucht.' `
    -Wert 'MapsBroker' -Soll 'Disabled' -Standard 'Automatic'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET018' -Name 'Dienst: Medienfreigabe des Windows Media Players' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Dienst' `
    -Erklaerung 'Schaltet den Dienst ab, der Musik und Videos des Windows Media Players im Netzwerk freigibt.' `
    -Wert 'WMPNetworkSvc' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Andere Geräte im Netzwerk können dann nicht mehr auf die Mediathek des Media Players zugreifen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI050' -Name 'Dienst: Pushbenachrichtigungen (WpnService)' `
    -Kategorie 'Vorschlaege' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Dienst für Pushbenachrichtigungen von Windows ab.' `
    -Wert 'WpnService' -Soll 'Disabled' -Standard 'Automatic' `
    -Hinweis 'Benachrichtigungen von Windows und Apps, auch Kalendererinnerungen und Sicherheitsmeldungen, erscheinen dann nicht mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SYS004' -Name 'Dienst: Volumeschattenkopie (VSS)' `
    -Kategorie 'Spuren' -Stufe 'Zusatz' -Typ 'Dienst' -VorgabeNein $true `
    -Erklaerung 'Schaltet den Dienst ab, mit dem Windows und Programme Schattenkopien anlegen. Ergänzt SYS001.' `
    -Wert 'VSS' -Soll 'Disabled' -Standard 'Manual' `
    -Hinweis 'Windows-Sicherung, Wiederherstellungspunkte und viele Sicherungsprogramme funktionieren dann nicht mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI051' -Name 'Keine vorinstallierten Werbe-Apps nachladen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows lädt keine von Microsoft oder Partnern vorgesehenen Apps mehr nach, die ungefragt im Startmenü auftauchen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'PreInstalledAppsEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI052' -Name 'Vorinstallierte Werbe-Apps auch künftig nicht nachladen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Ergänzt UI051: merkt sich, dass solche Apps nie gewünscht waren, damit Windows sie nach einem Update nicht doch nachlädt.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'PreInstalledAppsEverEnabled' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI053' -Name 'Keine Funktionsverwaltung über Werbeinhalte' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Dienst für Werbe- und Vorschlagsinhalte schaltet keine Funktionen mehr selbst ein oder aus. Hier schon ausgeschaltet; der Punkt hält das fest.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'FeatureManagementEnabled' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI054' -Name 'Werbe- und Vorschlagsinhalte ganz abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Hauptschalter für alle Inhalte, die Windows von Microsoft nachlädt: Tipps, Vorschläge, Werbe-Apps und Bilder auf dem Sperrbildschirm.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'ContentDeliveryAllowed' -Soll 0 -Standard 1 `
    -Hinweis 'Auch Windows-Blickpunkt auf dem Sperrbildschirm zeigt dann keine neuen Bilder mehr.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI055' -Name 'Abonnierte Vorschlagsinhalte abschalten' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Schaltet die Gesamtheit der abonnierten Vorschlagsinhalte ab; die einzelnen Kanäle regeln UI-Punkte darüber.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Wert 'SubscribedContentEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI056' -Name 'Keine App-Vorschläge im Stiftbereich' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Der Windows-Ink-Arbeitsbereich schlägt keine Apps aus dem Store mehr vor. Ohne Stift ohne Wirkung.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace' -Wert 'PenWorkspaceAppSuggestionsEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI057' -Name 'Blickpunkt: keine Inhalte von Drittanbietern' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows-Blickpunkt schlägt keine Apps und Inhalte von anderen Anbietern vor.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableThirdPartySuggestions' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (CloudContent.admx, Benutzerrichtlinie). Kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI058' -Name 'Keine Willkommensseite nach Updates' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows zeigt nach Updates keine Seite mehr, die neue Funktionen und Microsoft-Dienste bewirbt.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableWindowsSpotlightWindowsWelcomeExperience' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (CloudContent.admx, Benutzerrichtlinie). Kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI059' -Name 'Kein Blickpunkt in den Einstellungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Einstellungen-App zeigt keine Blickpunkt-Vorschläge mehr.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableWindowsSpotlightOnSettings' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (CloudContent.admx, Benutzerrichtlinie). Kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI060' -Name 'Kein Blickpunkt in den Benachrichtigungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Im Benachrichtigungsbereich erscheinen keine Blickpunkt-Vorschläge mehr.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableWindowsSpotlightOnActionCenter' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (CloudContent.admx, Benutzerrichtlinie). Kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI061' -Name 'Keine Blickpunkt-Bilder auf dem Desktop' `
    -Kategorie 'Vorschlaege' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Entfernt die Möglichkeit, täglich wechselnde Bilder von Microsoft als Desktophintergrund zu laden.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Wert 'DisableSpotlightCollectionOnDesktop' -Soll 1 -Standard $null `
    -Hinweis 'Die Auswahl „Windows-Blickpunkt“ verschwindet aus den Hintergrund-Einstellungen.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (CloudContent.admx, Benutzerrichtlinie).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI062' -Name 'Keine Online-Tipps in den Einstellungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Die Einstellungen-App lädt keine Tipps und Hilfeinhalte mehr von Microsoft-Servern.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'AllowOnlineTips' -Soll 0 -Standard $null `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies (ControlPanel.admx); gesperrt wird dadurch nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI063' -Name 'Startmenü: keine personalisierten Website-Empfehlungen' `
    -Kategorie 'Vorschlaege' -Stufe 'Standard' -Typ 'Registry' -MindestBuild 22621 `
    -Erklaerung 'Der Bereich „Empfohlen“ im Startmenü zeigt keine Websites mehr, die Microsoft für dich auswählt.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'HideRecommendedPersonalizedSites' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (StartMenu.admx, ab Windows 11 22H2). Kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI064' -Name 'Startmenü: „Zuletzt hinzugefügt“ per Richtlinie ausblenden' `
    -Kategorie 'Vorschlaege' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Das Startmenü zeigt keine Liste der zuletzt installierten Apps mehr, für alle Konten.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'HideRecentlyAddedApps' -Soll 1 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Einstellung „Zuletzt hinzugefügte Apps anzeigen“ unter Personalisierung, Start wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig blendet die Liste für alle Konten aus (StartMenu.admx).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI065' -Name 'Startmenü: „Meistverwendet“ per Richtlinie ausblenden' `
    -Kategorie 'Vorschlaege' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Das Startmenü zeigt die am häufigsten verwendeten Apps nicht mehr, für alle Konten. UI020 erledigt das für dein Konto ohne Sperre.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'ShowOrHideMostUsedApps' -Soll 2 -Standard $null `
    -GrautAus $true `
    -Warnung 'Die Einstellung „Meistverwendete Apps anzeigen“ unter Personalisierung, Start wird gesperrt.' `
    -PolicyGrund 'Nur der Richtlinienzweig blendet die Liste für alle Konten aus (StartMenu.admx, Wert 2 = Ausblenden).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI066' -Name 'Verknüpfungen nicht über die Nachverfolgung reparieren' `
    -Kategorie 'Explorer' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Findet eine Verknüpfung ihr Ziel nicht mehr, sucht Windows es nicht über die Verknüpfungsnachverfolgung von NTFS.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoResolveTrack' -Soll 1 -Standard $null `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies (StartMenu.admx, Benutzerrichtlinie); gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UI067' -Name 'Verknüpfungen nicht per Suche reparieren' `
    -Kategorie 'Explorer' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Findet eine Verknüpfung ihr Ziel nicht mehr, durchsucht Windows nicht die Laufwerke danach.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Wert 'NoResolveSearch' -Soll 1 -Standard $null `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies (StartMenu.admx, Benutzerrichtlinie); gesperrt wird nichts.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SYS005' -Name 'Sprunglisten: keine Elemente von anderen Rechnern merken' `
    -Kategorie 'Spuren' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Sprunglisten in der Taskleiste zeigen und merken sich keine Dateien, die auf anderen Rechnern oder Netzlaufwerken liegen.' `
    -Pfad 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Wert 'NoRemoteDestinations' -Soll 1 -Standard $null `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (Taskbar.admx, Benutzerrichtlinie). Kein sichtbarer Schalter wird gesperrt.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SYS006' -Name 'Richtlinienergebnis nicht protokollieren' `
    -Kategorie 'Spuren' -Stufe 'Zusatz' -Typ 'Registry' -VorgabeNein $true `
    -Erklaerung 'Windows schreibt nicht mehr mit, welche Richtlinien beim Start gewirkt haben.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Wert 'RSoPLogging' -Soll 0 -Standard $null `
    -Hinweis 'Werkzeuge wie gpresult zeigen danach keine Ergebnisse mehr; bei Fehlersuche fehlt diese Auskunft.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (GroupPolicy.admx, Wert 0 = Protokollierung aus).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EIN020' -Name 'Keine Auswertung des Tippverhaltens' `
    -Kategorie 'Eingabe' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows wertet nicht mehr aus, wie du tippst (Tippstatistik und Vorschläge zur Tippgenauigkeit).' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Input\Settings' -Wert 'InsightsEnabled' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO019' -Name 'Kein „Fortsetzen“ vom Telefon' `
    -Kategorie 'Konto' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows bietet nicht an, auf dem Telefon begonnene Tätigkeiten am PC fortzusetzen; dafür wird der Verlauf zwischen den Geräten abgeglichen.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration' -Wert 'IsResumeAllowed' -Soll 0 -Standard 1

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'KTO020' -Name 'Keine Microsoft-Konten hinzufügen' `
    -Kategorie 'Konto' -Stufe 'Zusatz' -Typ 'Registry' -VorgabeNein $true `
    -Erklaerung 'Auf diesem Rechner lassen sich keine neuen Microsoft-Konten mehr anlegen oder verknüpfen. Bestehende Anmeldungen bleiben.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Wert 'NoConnectedUser' -Soll 1 -Standard $null `
    -Hinweis 'Apps, die ein Microsoft-Konto anbinden wollen (Store, Office, OneDrive), können das danach nicht mehr.' `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies (Sicherheitsoption „Konten: Microsoft-Konten blockieren“); gesperrt wird kein Schalter.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET019' -Name 'Nahfreigabe aus' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Dein PC ist für die Nahfreigabe (Dateien per Bluetooth/WLAN an Geräte in der Nähe) nicht sichtbar. Hier schon aus; der Punkt hält das fest.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP' -Wert 'NearShareChannelUserAuthzPolicy' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET020' -Name 'Geräteübergreifende Erfahrungen aus' `
    -Kategorie 'Netzwerk' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Apps auf anderen Geräten können keine Sitzungen auf diesem PC öffnen oder fortsetzen. Hier schon aus; der Punkt hält das fest.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP' -Wert 'CdpSessionUserAuthzPolicy' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET021' -Name 'Im Standby kein Netz (Akku)' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Im Standby hält der Rechner im Akkubetrieb keine WLAN-Verbindung; Apps können dann nichts im Hintergrund senden oder abholen.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9' -Wert 'DCSettingIndex' -Soll 0 -Standard $null `
    -Hinweis 'E-Mails und Nachrichten kommen erst nach dem Aufwachen. Nur bei Geräten mit modernem Standby wirksam.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (Power.admx).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'NET022' -Name 'Im Standby kein Netz (Netzbetrieb)' `
    -Kategorie 'Netzwerk' -Stufe 'Maximum' -Typ 'Registry' -Abwaegen $true `
    -Erklaerung 'Wie NET021, im Netzbetrieb.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9' -Wert 'ACSettingIndex' -Soll 0 -Standard $null `
    -Hinweis 'E-Mails und Nachrichten kommen erst nach dem Aufwachen. Nur bei Geräten mit modernem Standby wirksam.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (Power.admx).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD020' -Name 'Neue Funktionen nicht sofort erhalten' `
    -Kategorie 'Updates' -Stufe 'Maximum' -Typ 'Registry' `
    -Erklaerung 'Schaltet „Die neuesten Updates erhalten, sobald sie verfügbar sind“ aus: Windows schaltet neue Funktionen nicht vorab für dich frei. Sicherheitsupdates kommen unverändert.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Wert 'IsContinuousInnovationOptedIn' -Soll 0 -Standard 0

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'UPD021' -Name 'Kein automatischer Neustart bei Anmeldung' `
    -Kategorie 'Updates' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Solange jemand angemeldet ist, startet Windows nach Updates nicht von selbst neu.' `
    -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Wert 'NoAutoRebootWithLoggedOnUsers' -Soll 1 -Standard $null `
    -Hinweis 'Updates werden erst mit dem nächsten Neustart wirksam, den du selbst auslöst.' `
    -PolicyGrund 'Nur über den Richtlinienzweig belegt (WindowsUpdate.admx).'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL068' -Name 'Keine Leistungsdiagnose-Aufzeichnung' `
    -Kategorie 'Telemetrie' -Stufe 'Maximum' -Typ 'Registry' -Ausgemustert $true `
    -Erklaerung 'Windows zeichnet keine Diagnosedaten über Start- und Leistungsprobleme mehr auf.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance' -Wert 'DisableDiagnosticTracing' -Soll 1 -Standard 0 `
    -Hinweis 'Die Leistungsdiagnose in der Ereignisanzeige bleibt dann leer.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL069' -Name 'Keine lokale Abschrift der Diagnosedaten' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Windows legt keine zusätzliche Abschrift der Diagnosedaten für die Diagnosedatenanzeige an. Ab Werk aus; der Punkt hält das fest.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' -Wert 'EnableEventTranscript' -Soll 0 -Standard $null

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'TEL070' -Name 'Telemetrie des .NET SDK aus' `
    -Kategorie 'Telemetrie' -Stufe 'Standard' -Typ 'Registry' `
    -Erklaerung 'Das .NET SDK (Befehl dotnet) sendet keine Nutzungsdaten mehr an Microsoft. Wirkt für Programme, die danach starten; ohne .NET SDK ohne Wirkung.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Wert 'DOTNET_CLI_TELEMETRY_OPTOUT' -Soll '1' -Standard $null -RegTyp 'String'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC036' -Name 'Keine automatische Geräteverschlüsselung' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Windows verschlüsselt das Systemlaufwerk nicht mehr von selbst, wenn du dich mit einem Microsoft-Konto anmeldest. Schon verschlüsselte Laufwerke bleiben verschlüsselt.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' -Wert 'PreventDeviceEncryption' -Soll 1 -Standard $null `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Wird der Rechner gestohlen, lassen sich die Daten auf einem unverschlüsselten Laufwerk lesen. Der Vorteil: Der Wiederherstellungsschlüssel landet nicht automatisch im Microsoft-Konto.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'SEC037' -Name 'Benutzerkontensteuerung nicht auf dem sicheren Desktop' `
    -Kategorie 'Sicherheit' -Stufe 'Zusatz' -Typ 'Registry' `
    -Erklaerung 'Die Rückfrage der Benutzerkontensteuerung erscheint auf dem normalen Desktop statt auf dem abgedunkelten, geschützten Desktop.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Wert 'PromptOnSecureDesktop' -Soll 0 -Standard 1 `
    -SenktSchutz $true `
    -Hinweis 'FOLGE: Schadprogramme können die Rückfrage dann leichter vortäuschen oder fernsteuern.' `
    -PolicyGrund 'Liegt unter CurrentVersion\Policies (Sicherheitsoption der Benutzerkontensteuerung); gesperrt wird kein Schalter.'

# --- Experimentell: in keinem Profil. Die Erklärung sagt, was sich ändert -
#     nicht, dass es schneller wird; OrcaShield zeigt den Wert vorher und nachher.
$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP001' -Name 'Menüs ohne Verzögerung öffnen' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Untermenüs öffnen sich sofort statt nach 400 Millisekunden.' `
    -Pfad 'HKCU:\Control Panel\Desktop' -Wert 'MenuShowDelay' -Soll '0' -Standard '400' -RegTyp 'String' `
    -Hinweis 'Wirkt nach dem nächsten Anmelden. Wer mit der Maus über Menüs fährt, öffnet sie dann auch versehentlich.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP002' -Name 'Autostart-Programme ohne Wartezeit starten' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Der Explorer startet Programme aus dem Autostart sofort nach der Anmeldung, statt einige Sekunden zu warten.' `
    -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Wert 'StartupDelayInMSec' -Soll 0 -Standard $null `
    -Hinweis 'Mit vielen Autostart-Programmen kann die Anmeldung dadurch zäher wirken.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP003' -Name 'Dienste beim Herunterfahren kürzer abwarten' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Beim Herunterfahren wartet Windows auf jeden Dienst höchstens 2 statt 5 Sekunden.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control' -Wert 'WaitToKillServiceTimeout' -Soll '2000' -Standard '5000' -RegTyp 'String' `
    -Hinweis 'Ein Dienst, der beim Beenden noch Daten schreibt, kann dabei unterbrochen werden.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP004' -Name 'Weniger Rechenzeit für Hintergrund-Multimedia reservieren' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Der Multimedia-Planer hält für Hintergrundaufgaben 10 statt 20 Prozent der Rechenzeit frei.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Wert 'SystemResponsiveness' -Soll 10 -Standard 20 `
    -Hinweis 'Bei gleichzeitiger Audio- oder Videowiedergabe kann es dadurch eher zu Aussetzern kommen.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP005' -Name 'Vordergrund-Programm bevorzugen' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Der Prozessorplaner gibt dem Programm im Vordergrund längere und mehr Zeitscheiben (Wert 38 statt 2).' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Wert 'Win32PrioritySeparation' -Soll 38 -Standard 2 `
    -Hinweis 'Hintergrundaufgaben wie Downloads oder Kompilieren laufen dafür langsamer.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP006' -Name 'Kernel nicht auslagern' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Windows lagert Treiber und Teile des Kernels nicht in die Auslagerungsdatei aus, sondern hält sie im Arbeitsspeicher.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Wert 'DisablePagingExecutive' -Soll 1 -Standard 0 `
    -Hinweis 'Braucht etwas mehr Arbeitsspeicher. Wirkt nach einem Neustart.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP007' -Name 'Netzlaufwerke nicht drosseln' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' `
    -Erklaerung 'Der Client für Dateifreigaben drosselt große Übertragungen über langsame Verbindungen nicht mehr.' `
    -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Wert 'DisableBandwidthThrottling' -Soll 1 -Standard $null `
    -Hinweis 'Andere Anwendungen im selben Netz bekommen während großer Kopiervorgänge weniger Bandbreite.'

$Global:OrcaEinstellungen += New-OrcaSetting -Id 'EXP008' -Name 'Suchindex richtet sich nach dem Energiemodus' `
    -Kategorie 'Experimentell' -Stufe 'Experimentell' -Typ 'Registry' -Ausgemustert $true `
    -Erklaerung 'Der Suchindex arbeitet im Energiesparmodus zurückhaltender und schont so den Akku.' `
    -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex' -Wert 'RespectPowerModes' -Soll 1 -Standard 0 `
    -Hinweis 'Neue Dateien tauchen im Akkubetrieb später in der Suche auf.'

# ==============================================================
#  HILFSFUNKTIONEN FÜR DEN KATALOG
# ==============================================================
function Get-OrcaSettingsNachStufe {
    param([ValidateSet('Light','Standard','Maximum')][string]$Stufe)
    switch ($Stufe) {
        'Light'    { return $Global:OrcaEinstellungen | Where-Object { -not $_.Ausgemustert -and $_.Stufe -eq 'Light' } }
        'Standard' { return $Global:OrcaEinstellungen | Where-Object { -not $_.Ausgemustert -and $_.Stufe -in @('Light','Standard') } }
        'Maximum'  { return $Global:OrcaEinstellungen | Where-Object { -not $_.Ausgemustert -and $_.Stufe -in @('Light','Standard','Maximum') } }
    }
}

function Get-OrcaSettingById {
    param([string]$Id)
    return $Global:OrcaEinstellungen | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

function Get-OrcaSettingsNachBereich {
    param([ValidateSet('Maschine','Benutzer')][string]$Bereich)
    return $Global:OrcaEinstellungen | Where-Object { $_.Bereich -eq $Bereich }
}

$Global:OrcaOhneSperre = @{
    TEL001 = 'TEL025'; TEL044 = 'TEL004'; ADV002 = 'ADV001'; LOC007 = 'LOC004'; LOC010 = 'LOC003'
    EIN015 = 'EIN011'; EIN016 = 'EIN007'; EIN017 = 'EIN006'; KTO016 = 'KTO001'; KTO017 = 'KTO001'
    GAM002 = 'GAM001'; SEC015 = 'NET003'; MAP003 = 'MAP001'; UI065 = 'UI020'
}

$Global:OrcaBekannteWirkungen      = @('Defender-MAPS','Defender-Samples','DeviceGuard')
$Global:OrcaBekannteVoraussetzungen = @('KeinManipulationsschutz')
$Global:OrcaBekannteAbhaengigkeiten = @('Dienst','Programm','Geraet')
$Global:OrcaBekannteTypen = @('Registry','Dienst','Aufgabe','Feature','Autologger','Autostart','NetBios',
                               'Hypervisor','DeviceGuard','StartupApproved','Dns','Indexsperre','SchluesselWeg',
                               'HostsBlock','Firewallregel','Computerschutz')

# ==============================================================
#  KATEGORIEN
#  Anzeigename und Erklärung je Kategorie - für das Dashboard der
#  Oberfläche und die Einrichtung.
# ==============================================================
$Global:OrcaKategorien = @(
    @{ Name = 'Telemetrie'; Anzeige = 'Telemetrie & Diagnose'; Erklaerung = 'Was Windows über die Nutzung deines Rechners sammelt und an Microsoft schickt: Diagnosedaten, Fehlerberichte, Programm- und Geräteinventur, geplante Sammelaufgaben.' }
    @{ Name = 'Werbung'; Anzeige = 'Werbung & Tracking'; Erklaerung = 'Die Werbe-ID, mit der Apps dein Verhalten über Programme hinweg verknüpfen.' }
    @{ Name = 'KI-Funktionen'; Anzeige = 'KI, Copilot & Recall'; Erklaerung = 'KI-Funktionen, die Bildschirminhalte, Texte oder Eingaben auswerten - teils lokal, teils auf Microsoft-Servern.' }
    @{ Name = 'Vorschlaege'; Anzeige = 'Vorschläge & Sperrbildschirm'; Erklaerung = 'Werbung, Tipps und vorgeschlagene Apps im Startmenü, in den Einstellungen und auf dem Sperrbildschirm.' }
    @{ Name = 'Explorer'; Anzeige = 'Explorer'; Erklaerung = 'Cloud-Inhalte und Zusatzeinträge im Datei-Explorer.' }
    @{ Name = 'App-Berechtigungen'; Anzeige = 'App-Berechtigungen'; Erklaerung = 'Worauf Apps zugreifen dürfen: Kamera, Mikrofon, Standort, Kontakte, Dateien und Geräte.' }
    @{ Name = 'Suche'; Anzeige = 'Suche'; Erklaerung = 'Websuche, Cloud-Suche und Suchverlauf im Startmenü und in der Taskleiste.' }
    @{ Name = 'Standort'; Anzeige = 'Standort'; Erklaerung = 'Standortdienste, Sensoren und "Mein Gerät suchen".' }
    @{ Name = 'Eingabe'; Anzeige = 'Eingabe, Sprache & Zwischenablage'; Erklaerung = 'Was Windows aus Tastatur, Stift, Sprache und Zwischenablage lernt oder in die Cloud schickt.' }
    @{ Name = 'Updates'; Anzeige = 'Updates & Übermittlung'; Erklaerung = 'Wie Updates auf den Rechner kommen und mit wem er sie teilt.' }
    @{ Name = 'Konto'; Anzeige = 'Konto, OneDrive & Mobilgeräte'; Erklaerung = 'Microsoft-Konto, Synchronisierung, OneDrive und verbundene Smartphones.' }
    @{ Name = 'Office'; Anzeige = 'Microsoft Office'; Erklaerung = 'Telemetrie, Cloud-Funktionen und Werbung in Word, Excel, Outlook und Co.' }
    @{ Name = 'Edge'; Anzeige = 'Edge'; Erklaerung = 'Datenschutzvorgaben für den Edge-Browser. Wirken nur, wenn Edge installiert ist.' }
    @{ Name = 'Defender'; Anzeige = 'Defender'; Erklaerung = 'Was der Virenschutz an Microsoft meldet - und zusätzlicher Schutz vor unerwünschter Software. Einzelne Schutzfunktionen lassen sich auf Wunsch abschalten; jede davon ist als Sicherheitsrisiko gekennzeichnet.' }
    @{ Name = 'Gaming'; Anzeige = 'Gaming'; Erklaerung = 'Spielaufzeichnung im Hintergrund und Game Bar.' }
    @{ Name = 'Netzwerk'; Anzeige = 'Netzwerk & Fernzugriff'; Erklaerung = 'Fernzugriff, DNS, Gerätekennung, Hosts-Sperren und Verbindungsprüfungen.' }
    @{ Name = 'Sicherheit'; Anzeige = 'Sicherheit'; Erklaerung = 'Veraltete Netzwerkprotokolle, Anmeldesicherheit und Autostart von Datenträgern.' }
    @{ Name = 'Spuren'; Anzeige = 'Spuren'; Erklaerung = 'Was auf dem Datenträger an Kopien und Resten liegen bleibt.' }
    @{ Name = 'Leistung'; Anzeige = 'Leistung (VBS)'; Erklaerung = 'Virtualisierungsbasierte Sicherheit: kostet Leistung, schützt erst, wenn ein Angreifer schon Administrator ist.' }
    @{ Name = 'Experimentell'; Anzeige = 'Experimentell'; Erklaerung = 'Einstellungen, die den Rechner schneller machen sollen - zum Ausprobieren, jede mit klarer Einstufung.' }
)

# ==============================================================
#  WÄCHTER-BEREICHE
#  Was der Wächter nach der Anmeldung prüft. Jeder Bereich lässt
#  sich einzeln abschalten (orca-state.json, Feld WaechterAus).
#  Welche Einstellungen er hält, steht in AktiveEinstellungen.
# ==============================================================
$Global:OrcaWaechterBereiche = @(
    @{ Name = 'einstellungen';  Anzeige = 'Einstellungen';        Text = 'Prüft alle aktiven Punkte und stellt zurück, was Windows oder ein Programm verstellt hat.' }
    @{ Name = 'apps';           Anzeige = 'Entfernte Apps';       Text = 'Erkennt entfernte Apps, die ein Update zurückgebracht hat, und entfernt sie erneut.' }
    @{ Name = 'defender';       Anzeige = 'Defender und Firewall'; Text = 'Meldet abgeschaltete Schutzfunktionen, neue Ausnahmen und neue Virenfunde.' }
    @{ Name = 'kennung';        Anzeige = 'Gerätekennung';        Text = 'Meldet eine gespeicherte Microsoft-Gerätekennung, solange deren Sperre aktiv ist.' }
    @{ Name = 'herunterfahren'; Anzeige = 'Herunterfahren-Wächter'; Text = 'Prüft, ob die Bereinigung beim Herunterfahren eingetragen ist und zuletzt lief, und trägt sie bei Bedarf neu ein.' }
    @{ Name = 'trim';           Anzeige = 'TRIM nach der Bereinigung'; Text = 'Schickt nach einer Bereinigung einen TRIM-Durchlauf an die SSD, damit gelöschte Daten wirklich weg sind.' }
    @{ Name = 'rechte';         Anzeige = 'Schreibrechte';        Text = 'Prüft, dass nur Administratoren und SYSTEM die OrcaShield-Dateien ändern dürfen, und korrigiert das.' }
    @{ Name = 'hypervisor';     Anzeige = 'Hypervisor';           Text = 'Meldet, wenn der Hypervisor trotz Abschaltung läuft.' }
    @{ Name = 'suchindex';      Anzeige = 'Suchindex';            Text = 'Meldet Laufwerke im Suchindex, die dort nicht hingehören.' }
    @{ Name = 'autostart';      Anzeige = 'Autostart';            Text = 'Meldet neue Autostart-Einträge: Run-Schlüssel, Autostart-Ordner und Aufgaben, die bei Anmeldung oder Start laufen.' }
    @{ Name = 'richtlinien';    Anzeige = 'Fremde Richtlinien';   Text = 'Meldet neue oder geänderte Richtlinien, die nicht von OrcaShield stammen.' }
    @{ Name = 'zertifikate';    Anzeige = 'Stammzertifikate';     Text = 'Meldet neue Stammzertifikate. Mit einem fremden Stammzertifikat lassen sich verschlüsselte Verbindungen mitlesen.' }
    @{ Name = 'proxy';          Anzeige = 'Proxy';                Text = 'Meldet, wenn ein Proxy eingetragen oder geändert wurde - für dein Konto, für das System oder als Umgebungsvariable.' }
    @{ Name = 'firewall';       Anzeige = 'Firewall eingehend';   Text = 'Meldet neue Firewallregeln, die eingehende Verbindungen erlauben.' }
    @{ Name = 'telemetrie';     Anzeige = 'Neue Telemetrie';      Text = 'Meldet Aufgaben und Dienste mit den Namen bekannter Sammler, die neu dazugekommen sind und noch nicht in OrcaShield stehen.' }
    @{ Name = 'update';         Anzeige = 'Bericht nach Update';  Text = 'Hält nach einem Funktionsupdate fest, was das Update verstellt hat und was neu dazugekommen ist.' }
)

# ==============================================================
#  BEKANNTE OPTIONEN OHNE SCHALTER
#  Optionen aus anderen Werkzeugen, die OrcaShield kennt, aber
#  (noch) nicht setzt - weil der Wert nicht belegt ist, es sie in
#  dieser Windows-Version nicht mehr gibt oder ein anderer Punkt
#  sie abdeckt. Die Oberfläche zeigt sie, damit nichts fehlt.
# ==============================================================
$Global:OrcaBekannt = @(
    @{ Name='Werbung über Bluetooth abschalten'; Kategorie='Werbung'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen.' }
    @{ Name='Standard-App für den Sprechgarnitur-Knopf abschalten'; Kategorie='Eingabe'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen.' }
    @{ Name='NFC abschalten'; Kategorie='Netzwerk'; Art='Wert offen'; Grund='Wird über die Geräteverwaltung (MDM) gesteuert; ein belegter Registrywert fehlt.' }
    @{ Name='Mobilfunk-Breitband (WWAN) abschalten'; Kategorie='Netzwerk'; Art='Wert offen'; Grund='Wird über die Geräteverwaltung (MDM) gesteuert; ein belegter Registrywert fehlt.' }
    @{ Name='Wi-Fi Direct abschalten'; Kategorie='Netzwerk'; Art='Wert offen'; Grund='Wird über die Geräteverwaltung (MDM) gesteuert; ein belegter Registrywert fehlt.' }
    @{ Name='Bluetooth-Kopplung einschränken'; Kategorie='Netzwerk'; Art='Wert offen'; Grund='Wird über die Geräteverwaltung (MDM) gesteuert; ein belegter Registrywert fehlt.' }
    @{ Name='Edge: Autovervollständigen von Webadressen unterbinden'; Kategorie='Edge'; Art='Wert offen'; Grund='Zuordnung zur Edge-Richtlinie nicht eindeutig.' }
    @{ Name='Edge: integrierte KI-Schnittstellen für Websites abschalten'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtlinienname nicht belegt.' }
    @{ Name='Edge: Symbol für Microsoft 365 Copilot Chat ausblenden'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtlinienname nicht belegt.' }
    @{ Name='Edge: KI-gestützte Verlaufssuche abschalten'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtlinienname nicht belegt.' }
    @{ Name='Edge: Edge Secure Network (VPN) abschalten'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtlinienname nicht belegt.' }
    @{ Name='Edge: Benutzerkontrolle über lokale KI-Funktionen'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtlinienname nicht belegt.' }
    @{ Name='Edge: Anmeldesymbol für das Microsoft-Konto ausblenden'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtlinienname nicht belegt.' }
    @{ Name='Edge alt (EdgeHTML): 13 Einstellungen, darunter Browserverlauf in den Diagnosedaten'; Kategorie='Edge'; Art='nur Windows 10'; Grund='Den alten Edge gibt es unter Windows 11 nicht mehr.' }
    @{ Name='Office: Startfilm abschalten'; Kategorie='Office'; Art='Wert offen'; Grund='Wertname nicht in den Office-Programmdateien gefunden.' }
    @{ Name='Office: Datenschutzhinweis beim ersten Start ausblenden'; Kategorie='Office'; Art='Wert offen'; Grund='Wertname nicht in den Office-Programmdateien gefunden.' }
    @{ Name='Outlook: automatische Textvorschläge abschalten'; Kategorie='Office'; Art='Wert offen'; Grund='Wertname nicht in den Office-Programmdateien gefunden.' }
    @{ Name='Office: Nachverfolgen von Feedback abschalten'; Kategorie='Office'; Art='Wert offen'; Grund='Zuordnung nicht eindeutig.' }
    @{ Name='Cortana und Suche: Standort verbieten'; Kategorie='Suche'; Art='in diesem Windows entfallen'; Grund='Die Richtlinie fehlt in den Vorlagen dieser Windows-Version.' }
    @{ Name='Suche in der Cloud für alle Konten sperren'; Kategorie='Suche'; Art='in diesem Windows entfallen'; Grund='Die Richtlinie fehlt in den Vorlagen dieser Windows-Version; SUCH003/SUCH004 wirken pro Konto.' }
    @{ Name='Suchhighlights für alle Konten sperren'; Kategorie='Suche'; Art='in diesem Windows entfallen'; Grund='Die Richtlinie fehlt in den Vorlagen dieser Windows-Version; SUCH006 wirkt pro Konto.' }
    @{ Name='Cortana im Sperrbildschirm'; Kategorie='Suche'; Art='in diesem Windows entfallen'; Grund='Cortana gibt es nicht mehr.' }
    @{ Name='Suche mit KI im Suchfeld abschalten'; Kategorie='Suche'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen.' }
    @{ Name='Bing-Erweiterung der Suche für alle Konten'; Kategorie='Suche'; Art='nur pro Konto'; Grund='Die Richtlinie gibt es nur benutzerbezogen; das deckt SUCH002 ab.' }
    @{ Name='Windows Copilot für alle Konten'; Kategorie='KI-Funktionen'; Art='nur pro Konto'; Grund='Die Richtlinie gibt es nur benutzerbezogen; das deckt KI001 ab.' }
    @{ Name='KI-Aktionen im Datei-Explorer abschalten'; Kategorie='KI-Funktionen'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen.' }
    @{ Name='Phone-Link-Anwendung abschalten'; Kategorie='Konto'; Art='Wert offen'; Grund='Der genaue Wert ließ sich nicht belegen; die App selbst entfernt die App-Liste (S10).' }
    @{ Name='Hinweise zur Nutzung von Mobilgeräten'; Kategorie='Konto'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen.' }
    @{ Name='Neuigkeiten und interessante Themen in der Taskleiste'; Kategorie='Vorschlaege'; Art='gesperrter Schlüssel'; Grund='Windows verweigert den Schreibzugriff auf den Schlüssel; die Widgets-App wird stattdessen entfernt (M11).' }
    @{ Name='"Jetzt besprechen" in der Taskleiste'; Kategorie='Vorschlaege'; Art='nur Windows 10'; Grund='Gibt es unter Windows 11 nicht mehr.' }
    @{ Name='Kontakte-Symbol in der Taskleiste'; Kategorie='Vorschlaege'; Art='nur Windows 10'; Grund='Gibt es unter Windows 11 nicht mehr.' }
    @{ Name='Feedback-Aufforderungen (zweiter Wert pro Konto)'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen; TEL014 und TEL015 wirken.' }
    @{ Name='Diagnosedaten des Windows Media Players'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Wertname nicht in den Programmdateien gefunden.' }
    @{ Name='Dynamische Windows-Konfiguration und Update-Rollouts'; Kategorie='Updates'; Art='Wert offen'; Grund='Der genaue Wert ließ sich auf diesem System nicht belegen.' }
    @{ Name='Optionale Updates ganz abschalten'; Kategorie='Updates'; Art='widerspricht UPD003'; Grund='UPD003 lässt dich optionale Updates selbst wählen; beides zugleich geht nicht.' }
    @{ Name='Copilot-Funktionalität (ein Sammelschalter)'; Kategorie='KI-Funktionen'; Art='Sammelfunktion'; Grund='Ein einzelner Schalter, der viele Einzelwerte auf einmal setzt; in OrcaShield sind das die einzelnen KI-Punkte.' }
    @{ Name='Copilot-Apps entfernen'; Kategorie='KI-Funktionen'; Art='App-Entfernung'; Grund='Erledigt die App-Entfernung (S14).' }
    @{ Name='Kompatibilitäts-Datenbank zusammenführen (SdbinstMergeDbTask)'; Kategorie='Telemetrie'; Art='bewusst nicht'; Grund='Pflegt nur die lokale Kompatibilitätsdatenbank; Windows schaltet solche Aufgaben selbst wieder ein (wie bei PcaPatchDbTask gemessen).' }
    @{ Name='CEIP-Aufgaben Bluetooth-Nutzungsdaten (BthSQM) und Hochladen (Uploader)'; Kategorie='Telemetrie'; Art='in diesem Windows entfallen'; Grund='Beide Aufgaben gibt es unter Windows 11 nicht mehr.' }
    @{ Name='CEIP-Aufgaben für Server (ServerCeipAssistant, ServerRoleCollector, ServerRoleUsageCollector)'; Kategorie='Telemetrie'; Art='nur Windows Server'; Grund='Gibt es nur auf Windows Server.' }
    @{ Name='Lokale Recall-Daten sicher löschen'; Kategorie='KI-Funktionen'; Art='geplant'; Grund='Ohne Recall entstehen keine Daten; eine Löschfunktion ist vorgemerkt.' }
    @{ Name='Suche: freizugebende Informationen festlegen (ConnectedSearchPrivacy)'; Kategorie='Suche'; Art='nur Windows 8.1'; Grund='Gilt laut Richtliniendefinition nur für Windows 8.1, nicht für Windows 10 oder neuer.' }
    @{ Name='Suche: keine Webergebnisse bei getakteten Verbindungen'; Kategorie='Suche'; Art='nur Windows 8.1'; Grund='Gilt laut Richtliniendefinition nur für Windows 8.1. SUCH019 schaltet Webergebnisse ganz ab.' }
    @{ Name='Vorabversionen (Insider-Builds) per Richtlinie sperren'; Kategorie='Updates'; Art='in diesem Windows entfallen'; Grund='Gilt laut Richtliniendefinition nur bis Windows 10 Version 1703.' }
    @{ Name='Media Player: keine vordefinierten Radiosender abrufen'; Kategorie='Telemetrie'; Art='in diesem Windows entfallen'; Grund='Gilt laut Richtliniendefinition nur bis Windows XP.' }
    @{ Name='Internet-Dateizuordnungsdienst abschalten'; Kategorie='Explorer'; Art='in diesem Windows entfallen'; Grund='Gilt laut Richtliniendefinition nur bis Windows 7.' }
    @{ Name='Kachelbenachrichtigungen abschalten'; Kategorie='Vorschlaege'; Art='in diesem Windows entfallen'; Grund='Das Startmenü von Windows 11 hat keine Live-Kacheln.' }
    @{ Name='Zuletzt verwendete Apps an der Bildschirmecke, Wechseln zwischen Apps (EdgeUI)'; Kategorie='Explorer'; Art='in diesem Windows entfallen'; Grund='Betrifft die Bildschirmränder von Windows 8 und 8.1, die es unter Windows 11 nicht gibt.' }
    @{ Name='Anmeldung per Biometrie per Richtlinie sperren'; Kategorie='Sicherheit'; Art='bewusst nicht'; Grund='Abgedeckt durch SEC012: Ist Biometrie ganz aus, gibt es auch keine Anmeldung damit.' }
    @{ Name='Synchronisierung einzelner Gruppen per Richtlinie, keine Synchronisierung bei getakteten Verbindungen'; Kategorie='Konto'; Art='bewusst nicht'; Grund='Abgedeckt durch KTO016: Ist die Synchronisierung ganz gesperrt, synchronisiert keine Gruppe.' }
    @{ Name='Windows-Sofortverbindung: einzelne Übertragungswege'; Kategorie='Netzwerk'; Art='bewusst nicht'; Grund='Abgedeckt durch NET017: Ist die Einrichtung ganz abgeschaltet, gilt das für alle Wege.' }
    @{ Name='Defender: erweiterte Cloudprüfung abschalten'; Kategorie='Defender'; Art='umgekehrte Wirkung'; Grund='Der vorgeschlagene Wert 50 verlängert laut Richtliniendefinition die Cloudprüfung auf 60 Sekunden, statt sie abzuschalten.' }
    @{ Name='Defender: Cloudschutzebene, Wartungsscan, Prüfung vor dem Scan, Wiederherstellungspunkt, vollständige Nachholscans, Scan nur im Leerlauf, E-Mail-Scan, Archivtiefe, Scantyp, Update-Tag, Dienst dauerhaft, Dateihash, MAPS-Überschreibung, überwachter Ordnerzugriff, App Install Control'; Kategorie='Defender'; Art='Windows-Vorgabe'; Grund='Die vorgeschlagenen Werte schreiben laut Richtliniendefinition nur fest, was Windows ohnehin tut - der Punkt würde nichts ändern.' }
    @{ Name='Defender: Update beim Start, Schnellscan-Abstand, Updates über Microsoft Update, Netzwerkschutz'; Kategorie='Defender'; Art='umgekehrte Wirkung'; Grund='Die vorgeschlagenen Werte schalten die Funktion laut Richtliniendefinition ein, statt sie abzuschalten.' }
    @{ Name='Defender Antivirus per Richtlinie ganz abschalten (DisableAntiSpyware)'; Kategorie='Defender'; Art='in diesem Windows entfallen'; Grund='Microsoft wertet die Richtlinie seit der Defender-Plattform 4.18.2007.8 (2020) nicht mehr aus.' }
    @{ Name='Defender: Schutz vor unerwünschter Software abschalten (MpEnablePus)'; Kategorie='Defender'; Art='widerspricht DEF003'; Grund='Alter Wertname ohne Richtliniendefinition; DEF003 hält diesen Schutz eingeschaltet.' }
    @{ Name='Defender: automatische Ausschlüsse abschalten'; Kategorie='Defender'; Art='nur Windows Server'; Grund='Gilt laut Richtliniendefinition nur für Windows Server.' }
    @{ Name='Defender: Aufhebung veralteter Netzwerkdefinitionen abschalten'; Kategorie='Defender'; Art='Wirkung offen'; Grund='Die Richtliniendefinition sagt nicht, ob das den Schutz senkt oder nur mehr Definitionen aktiv hält.' }
    @{ Name='Defender: Angriffserkennung (IPS), Informationsschutz (IPC), Drosselung der Netzwerkereignisse'; Kategorie='Defender'; Art='Wert offen'; Grund='Die Werte stehen in keiner Richtliniendefinition dieser Windows-Version.' }
    @{ Name='Defender: Standardaktion je Bedrohungsstufe auf "keine Aktion"'; Kategorie='Defender'; Art='Sammelwert'; Grund='Liste aus fünf Werten in einem eigenen Schlüssel. DEF017 (keine automatische Maßnahme bei Funden) bewirkt dasselbe mit einem Wert.' }
    @{ Name='Defender: CPU-Grenze beim Scan auf 1 Prozent'; Kategorie='Defender'; Art='ungültiger Wert'; Grund='Gültig sind laut Richtliniendefinition 5 bis 100 Prozent.' }
    @{ Name='Defender: Sicherheitsinformationen erst nach 4294967295 Tagen als veraltet werten, Nachhol-Update nach 0 Tagen'; Kategorie='Defender'; Art='Wert offen'; Grund='Der Höchstwert lässt sich nicht sicher als Zahl setzen und nachprüfen; was 0 Tage bedeutet, sagt die Richtliniendefinition nicht.' }
    @{ Name='Defender: Telemetrie und Fernkonfiguration des Kerndiensts'; Kategorie='Defender'; Art='gesperrter Schlüssel'; Grund='Die Wertnamen stehen in den Programmdateien des Defender-Kerndiensts, aber nur für dessen eigenen Schlüssel, den Administratoren nicht beschreiben dürfen. Ein Weg über den Richtlinienzweig ist nicht belegt.' }
    @{ Name='Defender: Manipulationsschutz, Dienststart, Cloudmeldungen und weitere Werte im Defender-eigenen Schlüssel'; Kategorie='Defender'; Art='gesperrter Schlüssel'; Grund='Den Schlüssel HKLM\SOFTWARE\Microsoft\Windows Defender dürfen Administratoren nur lesen. Den Manipulationsschutz schaltest du selbst in der Windows-Sicherheit ab.' }
    @{ Name='Keine Leistungsdiagnose-Aufzeichnung'; Kategorie='Telemetrie'; Art='gesperrter Schlüssel'; Grund='Den Schlüssel HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance dürfen Administratoren nur lesen; schreiben darf nur der Diagnosedienst von Windows.' }
    @{ Name='Suchindex richtet sich nach dem Energiemodus'; Kategorie='Experimentell'; Art='gesperrter Schlüssel'; Grund='Den Schlüssel des Suchindex dürfen Administratoren nur lesen; schreiben dürfen nur SYSTEM und der Suchdienst.' }
    @{ Name='Microsoft Antimalware: Dienst dauerhaft, schneller Start, Cloud-Benachrichtigungen'; Kategorie='Defender'; Art='in diesem Windows entfallen'; Grund='Betrifft das frühere System Center Endpoint Protection, nicht Defender in Windows 11.' }
    @{ Name='Defender-Ereignisprotokolle (Operational, WHC) abschalten'; Kategorie='Defender'; Art='Wert offen'; Grund='Dass ein Registrywert allein diese Protokolle abschaltet, ist nicht belegt.' }
    @{ Name='Entfernungstool nicht mehr über Windows Update anbieten'; Kategorie='Defender'; Art='Wert offen'; Grund='Wertname weder in einer Richtliniendefinition noch in den Update-Programmdateien gefunden.' }
    @{ Name='Firewall ganz abschalten'; Kategorie='Sicherheit'; Art='bewusst nicht'; Grund='Die Richtlinie kennt nur die alten Profile "Standard" und "Domäne"; wie sie auf die heutigen Profile Privat und Öffentlich wirkt, ist nicht belegt. Abschalten kannst du die Firewall in der Windows-Sicherheit.' }
    @{ Name='SmartScreen: Warnungen übergehbar (ShellSmartScreenLevel)'; Kategorie='Sicherheit'; Art='Teilwert'; Grund='Wirkt nur bei eingeschaltetem SmartScreen; SEC022 schaltet SmartScreen ganz ab.' }
    @{ Name='SmartScreen über den Explorer-Wert und für Store-Apps rechnerweit'; Kategorie='Sicherheit'; Art='bewusst nicht'; Grund='SEC022 schaltet SmartScreen belegt über die Richtlinie ab, SEC013 für Store-Apps in deinem Konto; die übrigen Werte sind nicht belegt.' }
    @{ Name='Erweiterter Phishingschutz: Warnungen und Telemetrie'; Kategorie='Sicherheit'; Art='Wert offen'; Grund='Interne Funktionsschalter ohne Richtliniendefinition.' }
    @{ Name='SmartScreen im Internet Explorer'; Kategorie='Sicherheit'; Art='in diesem Windows entfallen'; Grund='Den Internet Explorer gibt es unter Windows 11 nicht mehr.' }
    @{ Name='Application Guard abschalten'; Kategorie='Sicherheit'; Art='in diesem Windows entfallen'; Grund='Application Guard ist seit Windows 11 Version 24H2 entfernt; die Richtliniendefinition fehlt.' }
    @{ Name='Virtualisierungsbasierte Sicherheit und System Guard per Richtlinie'; Kategorie='Leistung'; Art='bewusst nicht'; Grund='Abgedeckt durch LEI001 bis LEI008: Sie schalten ohne Richtlinie ab und lassen den Schalter in der Windows-Sicherheit bedienbar.' }
    @{ Name='Updates bis zum Jahr 2963 pausieren'; Kategorie='Updates'; Art='Wert offen'; Grund='Pausen sind Datumswerte, die Windows selbst begrenzt; dass ein Enddatum weit in der Zukunft gilt, ist nicht belegt. Pausieren kannst du in den Windows-Update-Einstellungen.' }
    @{ Name='Pause und Aufschub über den Speicher der Geräteverwaltung (PolicyManager)'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Diesen Speicher füllt Windows selbst aus Richtlinien und Geräteverwaltung; direkt hineingeschriebene Werte sind nicht belegt.' }
    @{ Name='Pause per Richtlinie (Pause, PauseFeatureUpdates, PauseQualityUpdates)'; Kategorie='Updates'; Art='Wert offen'; Grund='Die Werte stehen in keiner Richtliniendefinition dieser Windows-Version.' }
    @{ Name='Updates aufschieben auf älteren Windows-Versionen (DeferUpdate, DeferUpgrade)'; Kategorie='Updates'; Art='nur Windows 10'; Grund='Gilt nur für Windows 10 bis Version 1607.' }
    @{ Name='Treibersuche: Windows Update als Rückfallquelle, Suchpfade'; Kategorie='Updates'; Art='in diesem Windows entfallen'; Grund='Gilt laut Richtliniendefinition nur bis Windows Vista.' }
    @{ Name='Treibersuche: nur auf einem verwalteten Server'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Verweist auf einen Update-Server einer Firma, den es auf einem privaten Rechner nicht gibt. UPD017 schaltet die Suche über Windows Update ohne Richtlinie ab.' }
    @{ Name='Treibersuche per Richtlinie, Treiber über die Update-Einstellungen ausschließen'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Abgedeckt durch UPD008, UPD017 und UPD018.' }
    @{ Name='Gerätemetadaten per Richtlinie, eigene Metadaten-Adresse'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Abgedeckt durch UPD006 ohne Richtlinie; eine umgeleitete Adresse ist nicht belegt.' }
    @{ Name='Ereignisprotokoll der Geräteeinrichtung abschalten'; Kategorie='Updates'; Art='Wert offen'; Grund='Dass ein Registrywert allein das Protokoll abschaltet, ist nicht belegt.' }
    @{ Name='Automatische Installation des Chromium-Edge verhindern'; Kategorie='Edge'; Art='in diesem Windows entfallen'; Grund='Betraf den Wechsel vom alten zum neuen Edge unter Windows 10.' }
    @{ Name='SMBv1-Server per Wert "SMBv1" abschalten'; Kategorie='Sicherheit'; Art='Wert offen'; Grund='Der Wertname kommt in den Serverdateien nur in Meldungstexten vor. SEC002 sperrt den SMBv1-Server über den Wert SMB1, SEC001 entfernt SMBv1 ganz.' }
    @{ Name='TLS: Schutz vor Herabstufung (UseScsvForTls)'; Kategorie='Sicherheit'; Art='Wert offen'; Grund='Wertname nicht in schannel.dll gefunden.' }
    @{ Name='Schutz vor Spectre und Meltdown per FeatureSettingsOverride'; Kategorie='Sicherheit'; Art='bewusst nicht'; Grund='Die richtigen Werte hängen vom Prozessor ab; Windows schaltet die Schutzmaßnahmen auf Arbeitsplatzrechnern selbst ein. Ein falscher Wert kann sie abschalten.' }
    @{ Name='Schutz vor Spectre und Meltdown für virtuelle Maschinen (Hyper-V)'; Kategorie='Sicherheit'; Art='bewusst nicht'; Grund='Betrifft nur Rechner, die selbst virtuelle Maschinen mit Hyper-V bereitstellen.' }
    @{ Name='Remoteunterstützung nur zum Zusehen'; Kategorie='Netzwerk'; Art='bewusst nicht'; Grund='Abgedeckt durch NET003 und SEC015: Ist die Remoteunterstützung aus, gibt es auch keine Fernsteuerung.' }
    @{ Name='Remotedesktop: keine Basic-Anmeldung (Terminal Services)'; Kategorie='Sicherheit'; Art='Wert offen'; Grund='Der Wert steht in keiner Richtliniendefinition dieser Windows-Version; SEC016 regelt Basic für die Windows-Remoteverwaltung.' }
    @{ Name='Cortana: Aktivierung, Startmenü, Symbol, Verlauf, Tastenkürzel, Sprachaktivierung, Umgebungsmodus'; Kategorie='Suche'; Art='in diesem Windows entfallen'; Grund='Cortana gibt es unter Windows 11 nicht mehr. Die Sprachaktivierung für Apps regeln die App-Berechtigungen.' }
    @{ Name='Spracherkennung bei der Windows-Einrichtung'; Kategorie='Eingabe'; Art='bewusst nicht'; Grund='Wirkt nur während der Ersteinrichtung von Windows, also bevor OrcaShield installiert ist.' }
    @{ Name='Suche: Standort, Bing und Suchvorschläge pro Konto (alte Werte)'; Kategorie='Suche'; Art='bewusst nicht'; Grund='Abgedeckt durch SUCH002 und SUCH017; der alte Wert BingSearchEnabled wird seit Windows 10 20H2 nicht mehr gelesen.' }
    @{ Name='Suche: unerwünschte Indexerweiterungen verhindern (PreventUnwantedAddIns)'; Kategorie='Suche'; Art='Wert offen'; Grund='Der Wert steht in keiner Richtliniendefinition dieser Windows-Version, und der Vorschlag setzt ihn ohne Wert.' }
    @{ Name='KI-Datenanalyse (Recall) für alle Konten'; Kategorie='KI-Funktionen'; Art='nur pro Konto'; Grund='Der rechnerweite Wert ist nicht belegt; KI003 und KI012 wirken pro Konto.' }
    @{ Name='WLAN-Optimierung, Experimente und Cortana über den Speicher der Geräteverwaltung (PolicyManager)'; Kategorie='Telemetrie'; Art='bewusst nicht'; Grund='Diesen Speicher füllt Windows selbst aus Richtlinien und Geräteverwaltung; direkt hineingeschriebene Werte sind nicht belegt.' }
    @{ Name='Funktionsexperimente und Konfigurations-Flighting per Richtlinie (PreviewBuilds)'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Die Werte stehen in keiner Richtliniendefinition dieser Windows-Version.' }
    @{ Name='Seite "Windows-Insider-Programm" in den Einstellungen ausblenden'; Kategorie='Updates'; Art='Wert offen'; Grund='Wertname nicht belegt.' }
    @{ Name='Standortdienst über Dienst- und Sensorwerte abschalten'; Kategorie='Standort'; Art='bewusst nicht'; Grund='Abgedeckt durch die Standort-Punkte (LOC), die den belegten Weg nehmen.' }
    @{ Name='CEIP-Hochladen (UploadDisableFlag)'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Der vorgeschlagene Wert 0 schaltet dem Namen nach das Hochladen gerade nicht ab; TEL013 schaltet CEIP ab.' }
    @{ Name='Edge-Browserdaten für Desktop Analytics'; Kategorie='Telemetrie'; Art='in diesem Windows entfallen'; Grund='Desktop Analytics hat Microsoft eingestellt; die Richtlinie fehlt in den Vorlagen.' }
    @{ Name='Fehlerberichte: Richtlinien-Zustimmung hat Vorrang (DefaultOverrideBehavior)'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Wertname nicht belegt; TEL005 schaltet die Fehlerberichterstattung ganz ab.' }
    @{ Name='Verbindungsprüfung über NlaSvc-Werte'; Kategorie='Netzwerk'; Art='bewusst nicht'; Grund='Abgedeckt durch die belegte Richtlinie NoActiveProbe im Katalog.' }
    @{ Name='Übermittlungsoptimierung pro Konto und für den Netzwerkdienst'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Abgedeckt durch UPD005 für den ganzen Rechner.' }
    @{ Name='Visual Studio: Kundenprogramm, Telemetrie, Feedback, IntelliCode'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Die Pfade stehen in den Visual-Studio-Programmdateien, der Wertname OptIn nicht; wohin TurnOffSwitch gehört, ist nicht eindeutig; Feedback- und IntelliCode-Werte nicht gefunden.' }
    @{ Name='NVIDIA-Telemetrie, CCleaner-Datensammlung, Firefox-Telemetrie'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Die Programme sind auf dem Prüfrechner nicht installiert; die Wertnamen lassen sich so nicht belegen.' }
    @{ Name='Office 2013 (15.0) und Word: Protokolle, Telemetrie, Feedback'; Kategorie='Office'; Art='Wert offen'; Grund='Für Office 2013 und für Word nicht in den Programmdateien belegt; für Office 16.0 decken OFF004, OFF008, OFF012 und OFF019 bis OFF021 ab.' }
    @{ Name='Neues Outlook nicht automatisch installieren (BlockedOobeUpdaters)'; Kategorie='Office'; Art='Wert offen'; Grund='Ein Listenwert im Windows-Update-Orchestrator ohne Beleg; die App-Entfernung entfernt das neue Outlook.' }
    @{ Name='Internet Explorer: Standort, InPrivate-Protokoll, Kundenprogramm, SSL-3-Rückfall, Zertifikatsfehler'; Kategorie='Explorer'; Art='in diesem Windows entfallen'; Grund='Den Internet Explorer gibt es unter Windows 11 nicht mehr.' }
    @{ Name='OneDrive per Richtlinie für Windows 8.1 sperren'; Kategorie='Konto'; Art='nur Windows 8.1'; Grund='Gilt laut Richtliniendefinition nur für Windows 8.1; für Windows 10/11 sperrt der Katalog OneDrive mit DisableFileSyncNGSC.' }
    @{ Name='Kamera-Einblendung beim Ein- und Ausschalten'; Kategorie='App-Berechtigungen'; Art='Wert offen'; Grund='Wertname NoPhysicalCameraLED nicht belegt.' }
    @{ Name='Widgets-Symbol, Copilot-Autostart, Edge-Deinstallation per Registry'; Kategorie='Vorschlaege'; Art='App-Entfernung'; Grund='Erledigt die App-Entfernung (Widgets, Copilot, Edge), statt Schalter zu setzen, die Windows teils gegen Änderungen sperrt.' }
    @{ Name='Altes Snipping Tool sperren, Druck-Taste für das Snipping Tool'; Kategorie='Explorer'; Art='bewusst nicht'; Grund='Betrifft Bedienung, nicht Datenschutz; das Snipping Tool lässt sich über die App-Entfernung entfernen.' }
    @{ Name='Sprachausgabe: Schnellstart überspringen'; Kategorie='Eingabe'; Art='bewusst nicht'; Grund='Betrifft nur die Begrüßung der Sprachausgabe, nicht den Datenschutz.' }
    @{ Name='Reservierter Speicher für Updates, DISM-Bereinigung (ResetBase)'; Kategorie='Updates'; Art='Wert offen'; Grund='Windows verwaltet diese Werte selbst; dass sie per Registry wirken, ist nicht belegt.' }
    @{ Name='Defender-, Firewall- und Sicherheitsdienste und -treiber abschalten'; Kategorie='Defender'; Art='gesperrter Dienst'; Grund='Windows lässt Administratoren diese Dienste nicht umstellen (gemessen am Defender-Dienst). Abschalten geht nur in der Windows-Sicherheit.' }
    @{ Name='Windows-Update-Dienste und Aufgaben des Update-Orchestrators abschalten'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Die Aufgaben dürfen Administratoren nicht ändern (gemessen), die Dienste stellt der Reparaturdienst von Windows Update wieder her. UPD011 schaltet automatische Updates belegt ab.' }
    @{ Name='Edge-Updatedienste und -aufgaben abschalten'; Kategorie='Edge'; Art='bewusst nicht'; Grund='Über sie aktualisiert sich auch WebView2, das OrcaShield und viele andere Programme brauchen. Ohne Updates bleiben dort Sicherheitslücken offen.' }
    @{ Name='Netzwerklisten-Dienst und Verbindungsstatus abschalten'; Kategorie='Netzwerk'; Art='bewusst nicht'; Grund='Windows erkennt Netzwerke dann nicht mehr als privat oder öffentlich; die Firewall wendet die falschen Regeln an. Die Verbindungsprüfung schaltet NoActiveProbe im Katalog ab.' }
    @{ Name='Übermittlungsoptimierung und Biometrie als Dienst abschalten'; Kategorie='Updates'; Art='bewusst nicht'; Grund='Abgedeckt durch UPD005 und SEC012, die den belegten Weg nehmen.' }
    @{ Name='Aufgaben und Dienste von NVIDIA, Firefox, Google, Adobe, Razer, Logitech und Dropbox'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Die Programme sind auf dem Prüfrechner nicht installiert; Namen und Wirkung lassen sich so nicht belegen.' }
    @{ Name='Office-Telemetrie-Aufgaben und Abo-Heartbeat (Office 2013/2016)'; Kategorie='Office'; Art='in diesem Windows entfallen'; Grund='Die Aufgaben gibt es bei aktuellem Office nicht mehr; OFF012 und OFF013 schalten den Telemetrie-Agenten ab.' }
    @{ Name='OneDrive-Aufgaben abschalten'; Kategorie='Konto'; Art='bewusst nicht'; Grund='Die Aufgaben halten OneDrive nur aktuell. OrcaShield entfernt OneDrive nicht, sondern schaltet Telemetrie, Netzverkehr vor der Anmeldung und Autostart ab (KTO003, KTO006, KTO007).' }
    @{ Name='Fehlerdetails-Update, SMBv1-Treiber, System Guard, Datenverlust-Schutz'; Kategorie='Sicherheit'; Art='in diesem Windows entfallen'; Grund='Die Aufgabe bzw. die Dienste gibt es auf diesem Windows nicht; SMBv1 entfernt SEC001.' }
    @{ Name='ExploitGuard: Aktualisierung der Geräteverwaltungsrichtlinie'; Kategorie='Defender'; Art='bewusst nicht'; Grund='Gehört zur Geräteverwaltung in Firmen und sammelt keine Daten.' }
    @{ Name='Bedienung und Aussehen: Taskleiste (Ausrichtung, Gruppierung, Suchfeld, Aufgabenansicht, Chat), Startmenü-Anordnung, Dunkelmodus, Transparenz, Animationen, Kontextmenüs, Ordner unter „Dieser PC“, Explorer-Ansicht, Mausbeschleunigung, Tastenkürzel der Bedienungshilfen, Systemklänge, Fenster andocken, Speicheroptimierung'; Kategorie='Explorer'; Art='bewusst nicht'; Grund='Betrifft Bedienung und Aussehen, nicht Datenschutz oder Sicherheit.' }
    @{ Name='Startmenü: Abschnitt „Empfohlen“ ganz ausblenden'; Kategorie='Vorschlaege'; Art='Wirkung offen'; Grund='Die Richtlinie steht in den Vorlagen; ob Windows Pro und Home sie umsetzen, ist nicht belegt. UI063 entfernt die Website-Empfehlungen daraus.' }
    @{ Name='Liste häufig verwendeter Programme (ältere Richtlinie)'; Kategorie='Vorschlaege'; Art='nur Windows 10'; Grund='Gilt laut Richtliniendefinition nur bis Windows 10; unter Windows 11 regelt das UI065.' }
    @{ Name='Benutzerüberwachung deaktivieren (NoInstrumentation)'; Kategorie='Telemetrie'; Art='in diesem Windows entfallen'; Grund='Gilt laut Richtliniendefinition nur bis Windows Vista.' }
    @{ Name='Treiberinstallation: keine Fehlerberichte'; Kategorie='Telemetrie'; Art='in diesem Windows entfallen'; Grund='Beide Richtlinien gelten laut Definition nur bis Windows 10 Version 1709; TEL005 schaltet die Fehlerberichterstattung ganz ab.' }
    @{ Name='Fehlerberichte über ältere Werte (PCHealth, Wartung, Fehlerdialog)'; Kategorie='Telemetrie'; Art='bewusst nicht'; Grund='Abgedeckt durch TEL005 und TEL050 bis TEL052.' }
    @{ Name='Geräteintegritätsnachweis (Device Health Attestation)'; Kategorie='Telemetrie'; Art='Windows-Vorgabe'; Grund='Eine Funktion für Firmengeräte, die nur auf ausdrücklichen Wunsch eingeschaltet wird.' }
    @{ Name='Datenschutzabfrage für neue Konten überspringen'; Kategorie='Telemetrie'; Art='bewusst nicht'; Grund='Die Abfrage lässt neue Konten selbst entscheiden; OrcaShield setzt die Werte ohnehin selbst.' }
    @{ Name='Kundenprogramm von App-V, Telemetrie der Programmkompatibilität per Richtlinie, Leistungsszenario PerfTrack'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='Nicht in den Vorlagen dieser Windows-Version; App-V gibt es nur in Firmenumgebungen. TEL065 schaltet den Kompatibilitätsassistenten ab.' }
    @{ Name='Höchste erlaubte Diagnosestufe und Hinweis zur Diagnosestufe'; Kategorie='Telemetrie'; Art='bewusst nicht'; Grund='Abgedeckt durch TEL025 und TEL001.' }
    @{ Name='Recall: Schnappschüsse nicht speichern (TurnOffSavingSnapshots)'; Kategorie='KI-Funktionen'; Art='in diesem Windows entfallen'; Grund='Ältere Richtlinie, in den aktuellen Vorlagen ersetzt durch DisableAIDataAnalysis (KI003, KI012).' }
    @{ Name='KI-Dienst nur bei Bedarf starten (WSAIFabricSvc)'; Kategorie='KI-Funktionen'; Art='Wert offen'; Grund='Der Dienst ist nicht belegt; Recall und die KI-Funktionen schalten KI003 bis KI012 ab.' }
    @{ Name='Chrome und Brave: KI- und Zusatzfunktionen'; Kategorie='Edge'; Art='Wert offen'; Grund='Die Browser sind auf dem Prüfrechner nicht installiert; die Richtlinien lassen sich so nicht belegen.' }
    @{ Name='Edge: lokale KI-Modelle, Copilot-Symbol und -Seitenzugriff, KI-Verlaufssuche, Spendenhinweis'; Kategorie='Edge'; Art='Wert offen'; Grund='Richtliniennamen nicht in den Edge-Programmdateien gefunden.' }
    @{ Name='Paint: KI-Funktionen, Phone Link im Startmenü'; Kategorie='KI-Funktionen'; Art='Wert offen'; Grund='Die Apps liegen in einem geschützten Ordner; die Wertnamen lassen sich nicht belegen.' }
    @{ Name='Letzten Dateizugriff nicht mehr vermerken (NTFS)'; Kategorie='Spuren'; Art='Wert offen'; Grund='Der Wert liegt außerhalb dessen, was OrcaShield sicher setzen und nachprüfen kann. Von Hand: fsutil behavior set disablelastaccess 1.' }
    @{ Name='Telemetrie von PowerShell 7'; Kategorie='Telemetrie'; Art='Wert offen'; Grund='PowerShell 7 ist auf dem Prüfrechner nicht installiert. Windows PowerShell 5.1 sendet keine Telemetrie.' }
    @{ Name='Alle Schutzmaßnahmen gegen Angriffe abschalten, Netzwerkbindungen lösen, Zeitdienst umstellen'; Kategorie='Sicherheit'; Art='bewusst nicht'; Grund='Schaltet Dutzende Schutzmaßnahmen auf einmal ab bzw. bricht Dateifreigabe und Zeitabgleich; nicht einzeln nachprüfbar.' }
    @{ Name='Game-Bar-Verknüpfungen umleiten'; Kategorie='Gaming'; Art='bewusst nicht'; Grund='Verbiegt Systemverknüpfungen; die Game Bar entfernt die App-Entfernung.' }
    @{ Name='Einmalige Aktionen eines Installationspakets (Designs, Energiepläne, Dateizuordnungen, Leistungszähler, Startmenü-Layout)'; Kategorie='Explorer'; Art='bewusst nicht'; Grund='Gehören zur Einrichtung eines eigenen Windows-Abbilds, nicht zu einer Einstellung, die sich halten und zurücknehmen lässt.' }
)

function Test-OrcaKatalog {
    $probleme = @()
    $gesehen  = @{}

    foreach ($s in $Global:OrcaEinstellungen) {
        if ($gesehen.ContainsKey($s.Id)) {
            $probleme += "Doppelte Kennung: $($s.Id)"
        }
        $gesehen[$s.Id] = $true

        if ($s.GrautAus -and [string]::IsNullOrWhiteSpace($s.Warnung)) {
            $probleme += "$($s.Id): GrautAus gesetzt, aber keine Warnung hinterlegt"
        }
        if ($s.SenktSchutz -and [string]::IsNullOrWhiteSpace($s.Hinweis)) {
            $probleme += "$($s.Id): senkt den Schutz, nennt aber keine Folge im Hinweis"
        }
        # Die Kaskadenregel gilt für jeden Typ, der in die
        # Registrierung schreibt - nicht nur für 'Registry'.
        if ($s.Typ -in @('Registry','Autologger','Autostart') -and
            $s.Pfad -match '\\Policies\\' -and
            [string]::IsNullOrWhiteSpace($s.PolicyGrund)) {
            $probleme += "$($s.Id): liegt im Richtlinienzweig, nennt aber keinen PolicyGrund"
        }
        if ($s.Typ -in @('Registry','Autologger','Autostart') -and [string]::IsNullOrWhiteSpace($s.Pfad)) {
            $probleme += "$($s.Id): Typ $($s.Typ) ohne Pfad"
        }
        if ($s.Wirkung -and $s.Wirkung -notin $Global:OrcaBekannteWirkungen) {
            $probleme += "$($s.Id): unbekannte Wirkungsprüfung '$($s.Wirkung)'"
        }
        if ($s.Voraussetzung -and $s.Voraussetzung -notin $Global:OrcaBekannteVoraussetzungen) {
            $probleme += "$($s.Id): unbekannte Voraussetzung '$($s.Voraussetzung)'"
        }
        if ("$($s.Pfad)$($s.Wert)" -match '[\x00-\x1f]') {
            $probleme += "$($s.Id): Steuerzeichen in Pfad oder Wertname"
        }
        if ($s.Stufe -notin @('Light','Standard','Maximum','Zusatz','Experimentell')) {
            $probleme += "$($s.Id): unbekannte Stufe '$($s.Stufe)'"
        }
        if ($s.Stufe -eq 'Zusatz' -and $s.Eingriff -eq 'Tief' -and -not ($s.VorgabeNein -or $s.SenktSchutz -or $s.GrautAus)) {
            $probleme += "$($s.Id): Zusatzpunkt mit Einschränkung braucht Vorgabe Nein"
        }
        if ($s.NachDemSetzen -and $s.NachDemSetzen -notin @('DoZwischenspeicherLeeren')) {
            $probleme += "$($s.Id): unbekannte Folgeaktion '$($s.NachDemSetzen)'"
        }
        if ($s.Typ -notin $Global:OrcaBekannteTypen) {
            $probleme += "$($s.Id): unbekannter Typ '$($s.Typ)'"
        }
        foreach ($n in @($s.ErsetztDurch)) {
            if (-not $s.Ausgemustert) { $probleme += "$($s.Id): ErsetztDurch ohne Ausgemustert" }
            if ($n -notlike 'APP:*' -and -not ($Global:OrcaEinstellungen | Where-Object { $_.Id -eq $n })) {
                $probleme += "$($s.Id): Nachfolger '$n' gibt es nicht"
            }
        }
        if ($s.NurWennVorhanden -and $s.Typ -notin @('Registry','Autologger','Autostart')) {
            $probleme += "$($s.Id): NurWennVorhanden gilt nur für Registrytypen"
        }
        foreach ($b in @($s.BenoetigtVon)) {
            if ($b.Art -notin $Global:OrcaBekannteAbhaengigkeiten) {
                $probleme += "$($s.Id): BenoetigtVon mit unbekannter Art '$($b.Art)'"
            }
            if ([string]::IsNullOrWhiteSpace($b.Name) -or [string]::IsNullOrWhiteSpace($b.Anzeige) -or [string]::IsNullOrWhiteSpace($b.Beleg)) {
                $probleme += "$($s.Id): BenoetigtVon braucht Name, Anzeige und Beleg"
            }
        }
    }
    # Ohne Sperre: beide Punkte müssen existieren, der erste sperrt, der zweite nicht
    foreach ($k in $Global:OrcaOhneSperre.Keys) {
        $a = $Global:OrcaEinstellungen | Where-Object { $_.Id -eq $k } | Select-Object -First 1
        $b = $Global:OrcaEinstellungen | Where-Object { $_.Id -eq $Global:OrcaOhneSperre[$k] } | Select-Object -First 1
        if (-not $a -or -not $b) { $probleme += "OhneSperre ${k}: Punkt fehlt"; continue }
        if (-not $a.GrautAus -or $b.GrautAus -or $b.Ausgemustert) { $probleme += "OhneSperre ${k}: passt nicht (sperrt nicht bzw. Ersatz sperrt oder ist ausgemustert)" }
    }
    return $probleme
}
