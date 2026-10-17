// ==============================================================
//  OrcaShield – Hauptfenster.cs
//  Das Fenster um die Oberfläche (WebView2).
//
//  Grundsatz „OrcaShield sendet keine Daten“ gilt auch hier:
//  - Die Oberfläche kommt ausschließlich aus dem Ordner Gui neben der
//    EXE, über einen virtuellen Hostnamen (kein Netz, kein file://).
//  - Jede andere Anfrage wird im Programm abgewiesen und mitgezählt
//    (%LOCALAPPDATA%\OrcaShield\gesperrt.log), damit nachprüfbar ist,
//    dass nichts nach außen geht.
//  - Navigation weg von der Oberfläche und neue Fenster sind gesperrt.
// ==============================================================
using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace OrcaShield
{
    internal sealed class Hauptfenster : Form
    {
        // Hostname aus der für Beispiele reservierten Endung .example –
        // kann nie mit einer echten Adresse zusammenfallen.
        internal const string Host = "orcashield.example";
        internal static readonly string Ursprung = "https://" + Host + "/";

        private readonly bool _simulation;
        private readonly WebView2 _ansicht;
        private readonly string _benutzerDaten;
        private readonly Engine _engine;
        private Bruecke _bruecke;

        private readonly bool _testanschluss;
        private readonly string _testBrowserArgs;

        public Hauptfenster(bool simulation, bool testanschluss = false, string testBrowserArgs = null)
        {
            _simulation = simulation;
            _testanschluss = testanschluss;
            _testBrowserArgs = testBrowserArgs;
            _benutzerDaten = Ordner.Basis();

            string version = Application.ProductVersion;
            Text = "OrcaShield " + version + (simulation ? " – Simulation" : "");
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            // Dunkler Grund, bis die Oberfläche geladen ist – kein weißes Aufblitzen.
            BackColor = Color.FromArgb(11, 15, 20);
            MinimumSize = new Size(960, 640);
            StartPosition = FormStartPosition.Manual;
            Fensterlage.Wiederherstellen(this, _benutzerDaten);

            _ansicht = new WebView2 { Dock = DockStyle.Fill, DefaultBackgroundColor = BackColor };
            Controls.Add(_ansicht);

            // Protokolle älter als 30 Tage wegräumen (nur eigene Dateien im eigenen Ordner)
            try
            {
                foreach (var alt in new DirectoryInfo(Bruecke.Protokollordner()).GetFiles("*.log"))
                    if (alt.LastWriteTime < DateTime.Now.AddDays(-30)) alt.Delete();
            }
            catch { }
            Protokolliere($"Start {Application.ProductVersion}, {(simulation ? "Simulation" : "echt")}, " +
                          $"{System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}, {Environment.OSVersion.VersionString}", "programm.log");

            // Die Engine liest ihre Skripte schon ein, während das Fenster aufgebaut wird.
            _engine = new Engine(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Skripte"), simulation);
            _engine.Vorbereiten();

            Load += async (s, e) => await StarteOberflaeche();
            FormClosing += (s, e) => Fensterlage.Merken(this, _benutzerDaten);
            FormClosed += (s, e) => _engine.Dispose();
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            DunkleTitelleiste(Handle);
        }

        private async System.Threading.Tasks.Task StarteOberflaeche()
        {
            string gui = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Gui");
            if (!File.Exists(Path.Combine(gui, "OrcaShield.html")))
            {
                Melde("Die Oberfläche fehlt (Ordner Gui neben OrcaShield.exe). Bitte OrcaShield neu installieren.");
                Close();
                return;
            }

            try
            {
                Directory.CreateDirectory(_benutzerDaten);
                var optionen = new CoreWebView2EnvironmentOptions
                {
                    // Der eingebettete Browser braucht kein Netz: Die Oberfläche kommt aus
                    // dem Programmordner. Hintergrundverbindungen (Komponenten-Updates,
                    // Konfigurationsabrufe, Vorabrufe) werden abgeschaltet, und alles, was
                    // trotzdem ins Netz will, läuft gegen einen Proxy, den es nicht gibt.
                    AdditionalBrowserArguments = string.Join(" ",
                        "--disable-background-networking",
                        "--disable-component-update",
                        "--disable-domain-reliability",
                        "--disable-client-side-phishing-detection",
                        "--disable-sync",
                        "--no-pings",
                        "--proxy-server=http://127.0.0.1:9",
                        "--proxy-bypass-list=<-loopback>",
                        "--disable-features=" + string.Join(",",
                            "msSmartScreenProtection",
                            "msOneAuthWAM",
                            "msEdgeOSAccountInfoSubstrate",
                            "msImplicitSignin",
                            "msPrimaryOSAccountInfoCache",
                            "msEdgeOSAccountInfoManagerCache"))
                        + (_testanschluss ? " --remote-debugging-address=127.0.0.1 --remote-debugging-port=9333" : "")
                        + (string.IsNullOrEmpty(_testBrowserArgs) ? "" : " " + _testBrowserArgs)
                };
                var umgebung = await CoreWebView2Environment.CreateAsync(
                    null, WebViewOrdner(), optionen);
                await _ansicht.EnsureCoreWebView2Async(umgebung);
            }
            catch (WebView2RuntimeNotFoundException)
            {
                Melde("Für die Oberfläche fehlt die Microsoft-Edge-WebView2-Laufzeit. Sie gehört zu Windows 11; "
                    + "unter Windows 10 lässt sie sich bei Microsoft kostenlos nachinstallieren.");
                Close();
                return;
            }
            catch (Exception ex)
            {
                Protokolliere("Oberfläche nicht gestartet: " + ex, "programm.log");
                Melde("Die Oberfläche ließ sich nicht starten: " + ex.Message);
                Close();
                return;
            }

            var kern = _ansicht.CoreWebView2;
            var e2 = kern.Settings;
            e2.IsStatusBarEnabled = false;
            e2.IsPasswordAutosaveEnabled = false;
            e2.IsGeneralAutofillEnabled = false;
            e2.IsReputationCheckingRequired = false;   // keine SmartScreen-Abfrage für die eigene Oberfläche
#if DEBUG
            e2.AreDevToolsEnabled = true;
#else
            e2.AreDevToolsEnabled = false;
            e2.AreDefaultContextMenusEnabled = false;
            e2.AreBrowserAcceleratorKeysEnabled = false;
#endif
            kern.SetVirtualHostNameToFolderMapping(Host, gui, CoreWebView2HostResourceAccessKind.Deny);

            kern.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
            kern.WebResourceRequested += (s, a) =>
            {
                string uri = a.Request.Uri ?? "";
                if (uri.StartsWith(Ursprung, StringComparison.OrdinalIgnoreCase)) return;
                a.Response = kern.Environment.CreateWebResourceResponse(null, 403, "Gesperrt", "");
                Protokolliere("Anfrage gesperrt: " + uri);
            };
            kern.NavigationStarting += (s, a) =>
            {
                if (a.Uri.StartsWith(Ursprung, StringComparison.OrdinalIgnoreCase)) return;
                if (a.Uri.StartsWith("data:", StringComparison.OrdinalIgnoreCase)) return;
                a.Cancel = true;
                Protokolliere("Navigation gesperrt: " + a.Uri);
            };
            kern.NewWindowRequested += (s, a) => { a.Handled = true; Protokolliere("Neues Fenster gesperrt: " + a.Uri); };
            _bruecke = new Bruecke(kern, _engine, this, t => Protokolliere(t, "programm.log"), ohneBestaetigung: _testanschluss);

            kern.Navigate(Ursprung + "OrcaShield.html" + (_simulation ? "?simulation=1" : ""));
        }

        private string WebViewOrdner() => Programm.IstInstalliert()
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OrcaShield", "WebView2-Programm")
            : Ordner.Unterordner("WebView2", entbehrlich: true);

        private void Protokolliere(string text) => Protokolliere(text, "gesperrt.log");
        private void Protokolliere(string text, string datei)
        {
            try
            {
                File.AppendAllText(Path.Combine(Bruecke.Protokollordner(), datei),
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " | " + text + Environment.NewLine);
            }
            catch { }
        }

        private void Melde(string text) =>
            MessageBox.Show(this, text, "OrcaShield", MessageBoxButtons.OK, MessageBoxIcon.Information);

        // Windows 11: Titelleiste im dunklen Stil (passt zur dunklen Vorgabe der Oberfläche).
        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribut, ref int wert, int groesse);
        private static void DunkleTitelleiste(IntPtr hwnd)
        {
            int an = 1;
            if (DwmSetWindowAttribute(hwnd, 20, ref an, sizeof(int)) != 0)   // DWMWA_USE_IMMERSIVE_DARK_MODE
                DwmSetWindowAttribute(hwnd, 19, ref an, sizeof(int));        // ältere Windows-10-Builds
        }
    }
}
