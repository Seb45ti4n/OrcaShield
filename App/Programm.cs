using System;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace OrcaShield
{
    internal static class Programm
    {
        [STAThread]
        private static void Main(string[] args)
        {
            bool Schalter(string n) => args.Any(a =>
                a.Equals("/" + n, StringComparison.OrdinalIgnoreCase) ||
                a.Equals("--" + n, StringComparison.OrdinalIgnoreCase));

            bool simulation = Schalter("simulation") || (!IstInstalliert() && !(Schalter("echt") && OrdnerGeschuetzt()));
            bool testanschluss = Schalter("testanschluss") && !IstInstalliert();

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            Ordner.Testprofil = Schalter("testprofil") && !IstInstalliert();

            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += (s, e) => Unbehandelt(e.Exception, weiter: true);
            AppDomain.CurrentDomain.UnhandledException += (s, e) => Unbehandelt(e.ExceptionObject as Exception, weiter: false);
            System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (s, e) => { Protokoll("Unbeobachteter Fehler: " + e.Exception); e.SetObserved(); };

            var fehlt = Voraussetzungen.Fehlt();
            if (fehlt.Count > 0)
            {
                Protokoll("Start abgebrochen, es fehlt: " + string.Join(", ", fehlt));
                if (Schalter("datenordner")) { Environment.ExitCode = 1; return; }
                MessageBox.Show("OrcaShield startet nicht, weil auf diesem Rechner etwas fehlt:\n\n•  " + string.Join("\n•  ", fehlt) +
                    "\n\nBeides gehört zu Windows 11 und lässt sich unter „Windows-Features aktivieren oder deaktivieren“ bzw. über Windows Update nachinstallieren.",
                    "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            if (!Voraussetzungen.IstWindows11() && !Schalter("datenordner"))
                MessageBox.Show("OrcaShield ist für Windows 11 gebaut (gefunden: Build " + Voraussetzungen.WindowsBuild() + "). " +
                    "Es startet trotzdem; Einstellungen, die es hier nicht gibt, zeigt es als „gibt es auf diesem Gerät nicht“.",
                    "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            string browserArgs = IstInstalliert() ? null : args
                .Where(a => a.StartsWith("/browserargs=", StringComparison.OrdinalIgnoreCase))
                .Select(a => a.Substring("/browserargs=".Length)).FirstOrDefault();

            if (Schalter("datenordner"))
            {
                if (!IstInstalliert()) { Environment.ExitCode = 2; return; }
                try { Ordner.Basis(); Environment.ExitCode = 0; }
                catch { Environment.ExitCode = 1; }
                return;
            }

            // Installiert läuft OrcaShield nur einmal: zwei Fenster dürfen nie gleichzeitig
            // schreiben, und Setup und Deinstallation erkennen an dieser Sperre ein offenes
            // Programm (AppMutex in Installer\OrcaShield.iss).
            System.Threading.Mutex einmal = null;
            if (IstInstalliert())
            {
                einmal = new System.Threading.Mutex(true, SperrName, out bool neu);
                if (!neu)
                {
                    MessageBox.Show("OrcaShield ist bereits geöffnet.", "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
            }

            try { Ordner.Basis(); }
            catch (Exception ex)
            {
                MessageBox.Show("OrcaShield startet nicht: " + ex.Message, "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            MeldeBeiseite();
            Application.Run(new Hauptfenster(simulation, testanschluss, browserArgs));
            GC.KeepAlive(einmal);
        }

        private static void MeldeBeiseite()
        {
            try
            {
                string vermerk = Path.Combine(Ordner.Basis(), Ordner.BeiseiteVermerk);
                if (!File.Exists(vermerk)) return;
                string alt = File.ReadAllText(vermerk).Trim();
                Protokoll("Datenordner war ungeschützt und wurde beiseitegelegt: " + alt);
                MessageBox.Show("Der Datenordner von OrcaShield gehörte einem Konto ohne Administratorrechte und war dadurch veränderbar. " +
                    "Er wurde nicht übernommen, sondern beiseitegelegt:\n\n" + alt +
                    "\n\nAusgangszustand, Einstellungen und Sicherungspunkte daraus gelten nicht mehr. OrcaShield misst ab jetzt neu. " +
                    "Hat OrcaShield auf diesem Rechner schon Einstellungen gesetzt, ist der neu gemessene Ausgangszustand bereits der veränderte.",
                    "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                File.Move(vermerk, vermerk + ".gemeldet-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
            }
            catch (Exception ex) { Protokoll("Vermerk zum beiseitegelegten Datenordner nicht lesbar: " + ex.Message); }
        }

        private static void Unbehandelt(Exception ex, bool weiter)
        {
            Protokoll("Unbehandelter Fehler" + (weiter ? "" : " (Programm endet)") + ": " + ex);
            try
            {
                MessageBox.Show("Unerwarteter Fehler: " + (ex?.Message ?? "unbekannt") +
                    (weiter ? "\n\nOrcaShield läuft weiter. Die nächste Messung zeigt den Stand." : "\n\nOrcaShield muss beendet werden.") +
                    "\n\nEinzelheiten stehen im Protokoll (programm.log).",
                    "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            catch { }
        }

        // Ins Programmprotokoll, ohne selbst je eine Ausnahme zu werfen
        internal static void Protokoll(string text)
        {
            try
            {
                File.AppendAllText(Path.Combine(Ordner.Unterordner("Protokoll", entbehrlich: true), "programm.log"),
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " | " + text + Environment.NewLine);
            }
            catch { }
        }

        // Muss mit AppMutex in Installer\OrcaShield.iss übereinstimmen.
        internal const string SperrName = "Global\\OrcaShield.Programm";

        private static bool OrdnerGeschuetzt()
        {
            string ich = AppDomain.CurrentDomain.BaseDirectory;
            string skripte = Path.Combine(ich, "Skripte");
            // Kein Protokoll hier: Es liefe vor Ordner.Testprofil und legte die Basis falsch fest.
            return Ordner.Sicher(ich) && (!Directory.Exists(skripte) || Ordner.Sicher(skripte));
        }

        // Installiert = die EXE liegt unter %ProgramFiles% (dort darf nur ein Administrator schreiben).
        internal static bool IstInstalliert()
        {
            try
            {
                string ich = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory).TrimEnd('\\') + "\\";
                string pf = Path.GetFullPath(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)).TrimEnd('\\') + "\\";
                return ich.StartsWith(pf, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }
    }
}
