================================================================
  ORCASHIELD
  Datenschutz und Härtung für Windows 11
  Version 1.1.0 Public Beta
================================================================

  Nimm dir bitte ein paar Minuten für diesen Text. Datenschutz
  ist nichts, was man nebenbei wegklickt. Wenn du weißt, was
  hier passiert, kannst du hinterher jede Änderung einordnen -
  und bei Bedarf gezielt zurückdrehen.


----------------------------------------------------------------
 1. DER GRUNDSATZ: MESSEN, DANN HANDELN - UND WINDOWS FRAGEN
----------------------------------------------------------------

Das ist die wichtigste Eigenschaft dieses Werkzeugs.

OrcaShield weiß nicht, wie dein Rechner aussieht. Es weiß nur,
was gewollt ist. Deshalb misst es nach, bevor es etwas tut:

  VORHER   Existiert dieser Registrierungsschlüssel? Steht der
           Wert schon richtig? Welchen Datentyp hat er? Gibt es
           den Dienst, die Aufgabe, die Windows-Funktion
           überhaupt? Wirkt diese Richtlinie auf deiner
           Windows-Edition?

           Das Ergebnis landet in orca-baseline.json, BEVOR der
           erste Wert geschrieben wird. Genau darauf setzt der
           Rückbau später zurück - nicht auf einen
           angenommenen Windows-Standardwert.

  NACHHER  Nach jedem Schreibvorgang wird erneut gelesen. Erfolg
           wird nur gemeldet, wenn der Wert tatsächlich dort
           steht, mit dem richtigen Datentyp.

  WINDOWS FRAGEN
           Wo Windows selbst sagt, was wirkt, zählt das - nicht
           das, was OrcaShield geschrieben hat. Beim Defender
           über Get-MpComputerStatus, bei der virtualisierungs-
           basierten Sicherheit über Win32_DeviceGuard, beim
           Herunterfahren-Skript über die Richtlinienverarbeitung
           und deren Ausführungszeitpunkt.


----------------------------------------------------------------
 2. WAS ORCASHIELD MACHT
----------------------------------------------------------------

  1. HÄRTEN
     Es schaltet ab, was Windows an Daten über dich an Microsoft
     sendet - Telemetrie, Werbe-IDs, Copilot, Recall,
     Standortdaten, Websuche im Startmenü, Sprach- und
     Tippdatensammlung, Geräteinventur und mehr. Dazu
     verschlüsseltes DNS über Quad9, Schutz vor der Microsoft-Gerätekennung, eine gepflegte Hosts-Datei und ein aufgeräumter Explorer ohne doppelte Laufwerke. 521 Punkte im Katalog, dazu 147 bekannte Optionen ohne Schalter.

  2. ENTSCHLACKEN
     Es entfernt vorinstallierte Apps, die du nicht brauchst,
     und räumt anschließend deren Rückstände weg. 42 Apps im
     Katalog. Kommt eine entfernte App mit einem Update zurück,
     entfernt der Wächter sie erneut - Edge eingeschlossen.

  3. AUFRÄUMEN
     Bei jedem Herunterfahren und Neustart beseitigt es
     Datenspuren: Papierkorb, Miniaturansichten,
     Diagnoseprotokolle, temporäre Dateien, Absturzabbilder,
     Prefetch, zuletzt verwendete Dateien, Explorer-Verläufe und
     die Ordneransichten des Explorers (ShellBags). Die
     Auslagerungsdatei wird beim Herunterfahren geleert. Nach
     der nächsten Anmeldung folgt auf C: ein TRIM-Durchlauf: Die
     SSD erfährt, welche Bereiche frei sind. Wann sie die Daten
     dort tatsächlich löscht, entscheidet das Laufwerk selbst.

     Jeder Schritt lässt sich in der App unter Überwachung &
     Automatik einzeln abschalten; dort steht zu jedem, was er
     löscht und welche Folge das hat.
     Schattenkopien löscht die Bereinigung nur mit einem eigenen
     Schalter (Vorgabe aus) - das nimmt Wiederherstellungspunkte
     und ältere Dateiversionen endgültig.
     Schattenkopien entstehen vor allem durch den Computerschutz
     von Windows: eine pro Tag, mit älteren Fassungen auch
     gelöschter Dateien. SYS001 schaltet ihn für C: ab, dann
     entstehen sie gar nicht erst. Gelöscht wird über die
     Windows-Schnittstelle (Win32_ShadowCopy), nicht über
     vssadmin - den Befehl "vssadmin delete shadows /all /quiet"
     benutzt Erpressersoftware, und Defender beendet ihn zu Recht.

     Gedacht ist das für ein unverschlüsseltes Systemlaufwerk:
     Es beseitigt Spuren, auch solche, die von verschlüsselten
     Laufwerken stammen. Deine normalen Dateien unter
     C:\Users bleiben natürlich lesbar - gegen den Ausbau der
     SSD hilft nur eine Verschlüsselung von C:.

  4. WACHEN
     Ein Wächter nach jeder Anmeldung: sichtbar, mit
     Administratorrechten (die geplante Aufgabe erhöht ohne
     Rückfrage), in deinem Konto. Er prüft und zeigt:

       - Windows-Version - nach einem Funktionsupdate stellt
         Windows erfahrungsgemäß am meisten zurück
       - alle aktiven Einstellungen, Abweichungen werden
         zurückgestellt. Ausnahme: Ein installiertes Programm
         braucht den alten Zustand nachweislich und stellt ihn
         selbst wieder um (Meta Horizon schaltet LLMNR ein,
         Docker Desktop den Hypervisor).
         Dann lässt der Wächter den Punkt in Ruhe, solange das
         Programm installiert ist, und sagt das einmal.
         Muss ein Punkt bei drei Anmeldungen in Folge
         zurückgestellt werden, meldet er auch das einmal.
       - entfernte Apps
       - Defender und Firewall (siehe Abschnitt 4)
       - ob der Herunterfahren-Wächter beim letzten
         Herunterfahren gelaufen ist - gegen das
         Systemprotokoll geprüft
       - die eigene Aufgabe und die Schreibrechte am
         Programmordner
       - Hypervisor und Suchindex
       - was seit dem letzten Lauf neu ist: Autostart-Einträge,
         Richtlinien, die nicht von OrcaShield stammen,
         Stammzertifikate, Proxy, Firewallregeln für eingehende
         Verbindungen und Aufgaben oder Dienste mit den Namen
         bekannter Sammler. Beim ersten Lauf gilt alles
         Vorhandene als bekannt. Neues wird gemeldet, bis du es
         in OrcaShield aufnimmst - geändert wird dabei nichts.
       - nach einem Funktionsupdate: was das Update verstellt
         hat, im Verlauf nachlesbar

     Das Fenster ist grün und schließt nach 5 Sekunden, wenn
     alles sauber ist. Gelb bei Hinweisen, 10 Sekunden. Rot bei
     Alarm - dann bleibt es offen, bis du eine Taste drückst.

     Der zweite Wächter läuft beim Herunterfahren, über die
     lokale Gruppenrichtlinie - genauso eingetragen, wie es
     gpedit.msc tut.


----------------------------------------------------------------
 3. INSTALLATION UND AUFRUF
----------------------------------------------------------------

  1. OrcaShield-Setup-<Version>.exe starten. Eine Datei für
     normale PCs (x64) und für ARM-Geräte (etwa Snapdragon-
     Laptops); das Setup wählt selbst.
  2. Die Abfrage der Benutzerkontensteuerung mit Ja bestätigen.
  3. Das Programm liegt danach unter C:\Program Files\OrcaShield,
     seine Daten (Ausgangszustand, Sicherungen, Protokolle) unter
     C:\ProgramData\OrcaShield. Beide Ordner sind vor Änderungen
     ohne Administratorrechte geschützt.
  4. Starten über das Startmenü: OrcaShield. Beim Start misst es
     den Zustand des Rechners (Bestandsaufnahme) und ändert dabei
     nichts.

  VORAUSSETZUNGEN: Windows 11, .NET Framework 4.8.1 und die
  WebView2-Laufzeit - alle drei sind in Windows 11 enthalten. Fehlt
  etwas, sagt das Setup es und installiert nichts.

  WARNUNG VON SMARTSCREEN: Das Setup ist nicht mit einem gekauften
  Zertifikat signiert. Windows zeigt deshalb beim ersten Start
  "Der Computer wurde durch Windows geschützt". Das heißt nur:
  Microsoft kennt die Datei noch nicht - nicht, dass sie schädlich
  ist. Zum Starten: "Weitere Informationen", dann "Trotzdem
  ausführen". Wer sichergehen will, vergleicht vorher die
  Prüfsumme (SHA-256) der Datei mit der angegebenen.

  FEHLALARME VON VIRENSCHUTZPROGRAMMEN: OrcaShield ändert
  Datenschutz-Einstellungen, Dienste und geplante Aufgaben - genau
  das, was auch Schadsoftware tut. Manche Virenschutzprogramme
  melden es deshalb. Defender hat das Programm in unseren Tests
  nicht gemeldet. Meldet dein Virenschutz etwas, schick die Datei
  dem Hersteller zur Prüfung, statt den Schutz abzuschalten.

  DEINSTALLIEREN: Einstellungen, Apps, Installierte Apps,
  OrcaShield. Das Programm fragt, ob es vorher alles auf den
  Zustand vor der ersten Änderung zurücksetzen und ob es seine
  Daten löschen soll (Vorgabe beide Male Nein). Wächter und
  Bereinigung beim Herunterfahren werden in jedem Fall ausgetragen.

  Jede Änderung am System bestätigst du zweimal: in der Vorschau
  ("Prüfen & anwenden") und danach in einem eigenen Fenster des
  Programms, das jede Änderung beim Namen nennt.

  SPRACHE: Deutsch oder Englisch, unter "Anpassen". Englisch gilt
  für die ganze Oberfläche samt Erklärungen und für die Rückfrage
  im Programmfenster; Protokolle bleiben deutsch. Das Setup folgt
  der Sprache von Windows.


----------------------------------------------------------------
 4. DEFENDER-WACHE
----------------------------------------------------------------

Ein Alarmsystem, kein Schloss. Das Schloss ist der
Manipulationsschutz von Windows-Sicherheit. OrcaShield passt
auf, dass er an bleibt, und schlägt Alarm, wenn sich jemand am
Schutz zu schaffen macht:

  - Echtzeitschutz, Verhaltensüberwachung, Prüfung beim
    Zugriff und bei Downloads aus
  - Manipulationsschutz aus
  - eine NEUE Ausnahme (Ordner, Programm, Dateiendung). Das ist
    der häufigste Trick: Schadsoftware schaltet Defender nicht
    ab, sondern nimmt sich selbst aus der Prüfung.
  - ein weiteres Virenschutzprogramm meldet sich an - darauf
    nimmt sich Defender von selbst zurück
  - eine Richtlinie schaltet Teile von Defender ab
  - die Firewall ist in einem Profil aus
  - Virensignaturen älter als drei Tage (Hinweis, kein Alarm)
  - jeder NEUE Fund seit dem letzten Lauf, mit Name, Ort und ob
    Defender ihn unschädlich gemacht hat. Beim ersten Lauf
    werden ältere Funde nur gezählt.

OrcaShield repariert hier nichts. Der Manipulationsschutz
verhindert Änderungen an Defender, auch durch OrcaShield, und
das ist richtig so.

Grenze, ehrlich: Schadsoftware mit Administratorrechten kann
auch OrcaShield abschalten. Die Wache meldet, sie verhindert
nicht.


----------------------------------------------------------------
 5. SCHREIBRECHTE
----------------------------------------------------------------

Ordner unter C:\ProgramData erben von Windows Schreibrechte für
alle Benutzer. Jedes Programm unter deinem Konto könnte dort die
Wächter-Skripte ohne Rückfrage umschreiben - und der Wächter
führte den neuen Inhalt mit Administratorrechten aus. OrcaShield
beschränkt das Schreiben in seinen Ordnern deshalb auf
Administratoren und SYSTEM. Der Wächter prüft das bei jedem
Lauf und repariert es.


----------------------------------------------------------------
 6. HOSTS-DATEI UND GERÄTEKENNUNG
----------------------------------------------------------------

OrcaShield verwaltet genau einen markierten Block am Ende der
Hosts-Datei (# BEGIN OrcaShield ... # END OrcaShield). Alles außerhalb
gehört dir. Einträge, die OrcaShield in seinen Block übernimmt,
nimmt es aus deinem Teil heraus, damit nichts doppelt steht - sie
liegen in Backup\Hosts-uebernommen.txt, der Rückbau gibt sie zurück.
Vor jedem Schreiben wird die ganze Datei gesichert; fehlt danach auch
nur eine deiner Zeilen, wird die Sicherung zurückgelegt.

Drei Abschnitte, jeder ein eigener Punkt mit Einzelabfrage:

  NET005  Gerätekennung - neun Microsoft-Adressen, über die Windows
          eine Gerätekennung (GDID) bekommt und abgleicht
  NET009  Microsoft-Konto-Anmeldung - login.live.com, account.live.com.
          Erst damit kommt sicher keine neue Kennung; dafür geht die
          Anmeldung mit dem Microsoft-Konto nicht mehr. Vorgabe Nein.
  NET007  Werbung und Telemetrie von Microsoft, rund 100 Adressen

Dazu NET006: eine Firewallregel, die dem Konto-Dienst wlidsvc den
Netzzugang sperrt.

Die Sperren verhindern NEUE Gerätekennungen. Eine schon gespeicherte
bleibt liegen, bis du sie auf der Seite "Gerätekennung" entfernst.
Das läuft nur auf Knopfdruck, weil dabei gespeicherte
Microsoft-Zugangsdaten gelöscht werden.


----------------------------------------------------------------
 7. NACH DER EINRICHTUNG
----------------------------------------------------------------

In der App: Beim ersten Anwenden sichert OrcaShield den
Ausgangszustand aller Punkte (orca-baseline.json) und eine Kopie
der betroffenen Registry-Zweige. Danach lassen sich unter
"Überwachung & Automatik" der Wächter und die Bereinigung beim
Herunterfahren einschalten - beides ist aus, bis du es
einschaltest. Einige Punkte wirken erst nach einem Neustart; die
App sagt das bei jedem dieser Punkte und startet nie selbst neu.


Nach der ersten Anmeldung mit eingeschaltetem Wächter zeigt er
einmal die vollständige Bestandsaufnahme. Danach siehst du bei
jeder Anmeldung das kurze Fenster.


----------------------------------------------------------------
 8. ORDNERSTRUKTUR
----------------------------------------------------------------

  C:\Program Files\OrcaShield\     (Programm, nur Administratoren)
  |
  +-- OrcaShield.exe             <- die App
  +-- Readme.txt, LICENSE.txt
  +-- Gui\OrcaShield.html        <- die Oberfläche
  +-- Skripte\                   <- die Engine (siehe unten)

  C:\ProgramData\OrcaShield\       (Daten, nur Administratoren)
  |
  +-- orca-state.json            <- merkt sich, was eingerichtet ist
  +-- orca-baseline.json         <- wie alles VOR dem Eingriff stand
  +-- Ablage\                    <- Sicherungspunkte und Profile
  +-- Logs\, Backup\             <- wie unten beschrieben


  Skripte\
  |   +-- Orca-Common.ps1            Protokoll, Ausgabe, Helfer, Rechte
  |   +-- Orca-Settings.ps1          Katalog aller Einstellungen
  |   +-- Orca-Engine.ps1            Messen, Setzen, Nachprüfen
  |   +-- Orca-Debloat.ps1           App-Katalog und Entfernung
  |   +-- Orca-Waechter.ps1          läuft nach jeder Anmeldung
  |   +-- Orca-Waechter-Shutdown.ps1 läuft bei jedem Herunterfahren
  |   +-- Orca-Hosts.txt             die Hosts-Listen (Daten, kein Code)
  |
  +-- Logs\
  |   +-- 2026\Oktober.txt
  |   +-- Trockenlauf_JJJJ-MM-TT_HHMMSS.txt
  |
  +-- Backup\
      +-- Registry-Sicherung_JJJJ-MM-TT_HHMMSS\
      +-- Hosts_JJJJ-MM-TT_HHMMSS.txt   vor jedem Schreiben der
      |                                 Hosts-Datei, nur bei
      |                                 geändertem Inhalt; es
      |                                 bleiben die älteste und
      |                                 die drei neuesten
      +-- Hosts-uebernommen.txt         was aus deinem Teil in den
                                        OrcaShield-Block wanderte

orca-baseline.json ist die Grundlage jedes Rückbaus. Nicht
löschen, solange OrcaShield eingerichtet ist.


----------------------------------------------------------------
 9. DAS PROTOKOLL
----------------------------------------------------------------

Jeder Lauf schreibt in eine Monatsdatei. Neuer Monat, neue
Datei. Neues Jahr, neuer Ordner.

  Aufbau einer Zeile:
  Datum | Uhrzeit | Quelle | Status | Aktion

  Statuswerte:
    OK      hat funktioniert und wurde nachgeprüft
    SKIP    übersprungen (gibt es hier nicht / wirkt hier nicht)
    WARN    Auffälligkeit, teilweise erledigt, oder: geschrieben
            aber ohne Wirkung
    FEHLER  fehlgeschlagen - mit Angabe des Grundes


----------------------------------------------------------------
 10. DIE DREI HÄRTUNGSSTUFEN
----------------------------------------------------------------

  LIGHT      39 Punkte
  Die Grundlagen. Telemetriedienste und Autologger aus, Werbe-ID
  weg, Copilot und Recall aus, Bing-Vorschläge im Startmenü aus,
  Gerätename nicht in der Telemetrie, kein P2P-Verteilen von
  Updates, SMBv1 aus. Nichts davon ändert, wie du den Rechner
  benutzt.

  STANDARD   237 Punkte (empfohlen)
  Zusätzlich: geplante Telemetrie-Aufgaben inklusive
  Geräteinventur, Standortdienste, Office-Cloudanbindung,
  Kontosynchronisierung, Cloud-Zwischenablage,
  Fehlerberichterstattung, Online-Spracherkennung,
  Aktivitätsverlauf, App-Berechtigungen, Quad9-DNS
  verschlüsselt, Suchindex nur C: und D:, sowie die
  Sicherheitsgrundlagen (SMB-Signierung, LLMNR aus, NetBIOS aus,
  NTLMv1 aus, LSA-Schutz, kein Autorun).

  MAXIMUM    328 Punkte
  Alles, plus die Punkte mit Zielkonflikt: App-Berechtigungen
  bis in die Dateiordner, Defender ohne Cloud-Anbindung,
  Sperre der Edge-Neuinstallation. Die Abschaltung der
  virtualisierungsbasierten Sicherheit steht seit 1.0.1 unter
  Zusatz - sie senkt den Schutz.

  UPDATES: Funktionsupdates bietet Windows von sich aus als
  "Herunterladen und installieren" an und installiert sie nicht
  automatisch - erst kurz vor dem Supportende einer Version.
  Sicherheitsupdates kommen automatisch. OrcaShield setzt
  dafür bewusst KEINE Update-Richtlinie mehr: Eine solche
  Richtlinie kann dazu führen, dass Windows den Rechner als
  verwaltet behandelt und Funktionsupdates nicht mehr anbietet,
  sondern selbst installiert.

  CUSTOM
  Jeden Punkt einzeln mit J/N entscheiden. Punkte, die auf
  deinem System nichts bewirken, werden gar nicht erst
  angeboten.


  IN DER APP heißen die drei Stufen Basis (= Light), Erweitert
  (= Standard) und Maximal (= Maximum) und wählen genau dieselben
  Punkte. Die Karten tragen die Farbe ihrer Stufe: grün Basis,
  gelb Erweitert, rot Maximal; Sicherheitsrisiken zusätzlich ⚠.
  Wie spürbar ein Punkt ist, steht in seinen Details unter
  "Auswirkung". Die Einstufung am Ende dieses Abschnitts gilt
  für die Konsole.

  ZUSATZ     186 Punkte, in keinem Profil
  Alles, was in keine Stufe passt: Punkte, die Programme abschneiden,
  einen Schalter für alle Konten sperren oder den Schutz senken
  (etwa automatische Updates aus, SmartScreen aus, einzelne
  Schutzfunktionen von Defender aus, virtualisierungsbasierte
  Sicherheit aus). Sie lassen
  sich nur einzeln einschalten, jeder mit Vorgabe Nein.

  ZUSAMMEN: 521 Einstellungen = 328 in den Stufen + 186 Zusatz
  + 7 Experimentell. Die 147 Optionen unter "Nicht unterstützt"
  zählen nicht dazu - OrcaShield setzt sie nicht.

  EXPERIMENTELL   7 Punkte, in keinem Profil
  Werte aus dem Bereich Leistung, die Windows nachweislich liest
  (etwa Wartezeit beim Herunterfahren, Menüverzögerung). Jeder
  zeigt den gemessenen Wert vorher und nachher. Ob der Rechner
  dadurch spürbar schneller wird, hängt vom Gerät ab.

  EINSTUFUNG
  Jeder Punkt trägt eine Farbe:
    grün  unbedenklich - ändert nichts an der Bedienung
    gelb  schränkt etwas ein oder sperrt einen Schalter
    rot   Sicherheitsrisiko - macht den Rechner angreifbarer

----------------------------------------------------------------
 11. DIE VIER DEBLOAT-STUFEN
----------------------------------------------------------------

  LIGHT     Nur eindeutiger Ballast (Clipchamp, Bing-Apps,
            Solitaire, Feedback-Hub, Office-Hub, Cortana, Tipps).

  STANDARD  Zusätzlich Karten, Kontakte, Kurznotizen, Skype,
            Phone Link, Media Player, Filme und TV, neues
            Outlook, Copilot, Power Automate, Dev Home,
            Xbox-Apps, Widgets.

  MAXIMUM   Zusätzlich Fotos, Kamera, Paint, Snipping Tool,
            Mail und Kalender, Remotedesktop, Schnellhilfe,
            Teams (privat und geschäftlich), Edge. Hier bitte
            vorher Ersatzprogramme
            installieren.

  CUSTOM    Jede App einzeln mit J/N entscheiden.

SCHUTZLISTE: Startmenü, Store, Shell, App-Installer, .NET- und
VCLibs-Laufzeiten, Windows-Sicherheit und verwandte Pakete
werden NIEMALS entfernt.

EDGE: Vor dem Entfernen von Edge kommt eine doppelte Abfrage.
Edge ist kein Store-Paket, sondern ein klassisches Programm. Im
Europäischen Wirtschaftsraum lässt es sich regulär
deinstallieren. Kehrt es zurück, erkennt der Wächter das an
der Programmdatei und deinstalliert es erneut. WebView2, das
viele Programme brauchen, bleibt unberührt.


----------------------------------------------------------------
 12. RICHTLINIEN UND AUSGRAUEN
----------------------------------------------------------------

Nicht WOMIT geschrieben wird, entscheidet über das Ausgrauen,
sondern WOHIN. Windows sperrt ein Feld, sobald unter

    HKLM\SOFTWARE\Policies\...   oder
    HKCU\Software\Policies\...

ein passender Wert steht - gleich, ob gpedit, eine .reg-Datei
oder PowerShell ihn dort hingeschrieben hat.

Der Zweig HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\
Policies\... gehört NICHT dazu. Werte dort sperren nichts.

STAND: Von 521 Punkten liegen 259 im Richtlinienzweig. 21
sperren einen sichtbaren Schalter, 16 davon stehen nur unter
Zusatz. In den Profilen sperren fünf. Die ersten drei haben eine
nicht sperrende Entsprechung im Katalog, die für dein eigenes
Konto genügt:

  1. Diagnosedaten per Richtlinie erzwingen
  2. Werbe-ID für ALLE Konten sperren
  3. Spielaufzeichnung systemweit sperren

Für die beiden anderen gibt es keinen Weg ohne Sperre:

  4. Übermittlungsoptimierung nur direkt von Microsoft (UPD005)
     - sperrt "Downloads von anderen PCs zulassen"
  5. Biometrie abschalten (SEC012) - sperrt Fingerabdruck und
     Gesicht unter den Anmeldeoptionen


EDITIONEN: Microsoft setzt einige Richtlinien nur auf
Enterprise und Education um. OrcaShield kennt diese Fälle und
setzt solche Punkte auf deinem System gar nicht erst.


----------------------------------------------------------------
 13. RÜCKBAU
----------------------------------------------------------------

In der App:
  - Seite "Wiederherstellung": "Auf Ausgangszustand zurücksetzen"
    merkt alles, was OrcaShield gesetzt hat, zum Zurücksetzen vor;
    Sicherungspunkte stellen einen gespeicherten Stand wieder her.
  - Jede Einstellung einzeln: Schalter aus oder "Zurücksetzen" in
    den Details.
  - Beim Deinstallieren auf Wunsch alles auf einmal (Abschnitt 3).


Grundlage ist immer orca-baseline.json. Gibt es die nicht,
setzt der Rückbau NICHTS zurück und verweist auf die
Registry-Sicherung. Raten wäre an dieser Stelle schlimmer als
nichts tun.

Entfernte Apps kommen durch den Rückbau nicht zurück.


----------------------------------------------------------------
 14. WAS ORCASHIELD NICHT MACHT
----------------------------------------------------------------

  - Es installiert keine Programme.
  - Es ändert deine Hosts-Datei nur im eigenen, markierten Block.
  - Es führt keine fremden Skripte aus.
  - Es schaltet nie von sich aus den Windows Defender, SmartScreen,
    den Cloud-Schutz oder Sicherheitsupdates ab. Wer das will,
    findet die Punkte unter "Zusatz" - jeder einzeln, rot als
    Sicherheitsrisiko gekennzeichnet, mit Vorgabe Nein. Sie
    gehören zu keinem Profil und keiner Schutzstufe.
  - Die Profile setzen keine Richtlinie, die Updates verzögert
    oder abschaltet.
  - Es entfernt kein OneDrive, sondern schaltet nur dessen
    Telemetrie und Autostart ab.
  - Es sendet selbst keinerlei Daten irgendwohin.
  - Es überschreibt keine fremden Einträge in scripts.ini oder
    gpt.ini.


----------------------------------------------------------------
 15. WAS EIN VPN LEISTET - UND WAS NICHT
----------------------------------------------------------------

Ein VPN verschlüsselt den Datenverkehr zwischen deinem Gerät
und dem VPN-Server und verschleiert deine echte IP-Adresse
gegenüber Webseiten und deinem Internetanbieter.

Ein VPN schützt NICHT vor:
  - Tracking über Cookies
  - Browser-Fingerprinting
  - Wiedererkennung über angemeldete Konten
  - geräteseitigen Kennungen

Ein VPN ist ein Baustein, kein Rundumschutz.


================================================================
