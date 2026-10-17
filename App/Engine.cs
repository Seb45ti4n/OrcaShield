using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Threading.Tasks;

namespace OrcaShield
{
    internal sealed class Engine : IDisposable
    {
        private readonly string _skripte;
        private readonly SemaphoreSlim _sperre = new SemaphoreSlim(1, 1);
        private readonly HashSet<string> _eigeneVariablen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private Runspace _runspace;
        private Task<bool> _start;

        /// Beim Programmstart aufrufen, damit das Einlesen parallel zum Fensteraufbau läuft.
        public void Vorbereiten() { if (_start == null) _start = StartenAsync(); }

        public bool Simulation { get; }
        public string Fehler { get; private set; }

        public Engine(string skripte, bool simulation)
        {
            _skripte = skripte;
            Simulation = simulation;
        }

        /// Einlesen der Skripte. Gibt false zurück, wenn etwas fehlt oder
        /// sich nicht laden lässt (Grund in Fehler).
        public Task<bool> StartenAsync() => Task.Run(() =>
        {
            try
            {
                foreach (var d in new[] { "Orca-Common.ps1", "Orca-Settings.ps1", "Orca-Engine.ps1", "Orca-Neues.ps1", "Orca-Debloat.ps1", "Orca-Texte-EN.ps1", "Orca-Gui.ps1", "Orca-Attrappen.ps1" })
                    if (!File.Exists(Path.Combine(_skripte, d))) { Fehler = "Programmdatei fehlt: Skripte\\" + d; return false; }

                var iss = InitialSessionState.CreateDefault();
                iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;   // nur für diesen Runspace
                _runspace = RunspaceFactory.CreateRunspace(iss);
                _runspace.ApartmentState = ApartmentState.STA;
                _runspace.ThreadOptions = PSThreadOptions.ReuseThread;
                _runspace.Open();

                // Feste Liste, Pfade aus dem Programmordner – keine Eingabe von außen.
                string q(string n) => "'" + Path.Combine(_skripte, n).Replace("'", "''") + "'";
                Ausfuehren(
                    "$ErrorActionPreference = 'Continue'; $ProgressPreference = 'Continue'\n" +
                    ". " + q("Orca-Common.ps1") + "\n" +
                    ". " + q("Orca-Settings.ps1") + "\n" +
                    ". " + q("Orca-Engine.ps1") + "\n" +
                    ". " + q("Orca-Gui.ps1") + "\n",
                    null, null);

                if (Simulation)
                {
                    var probe = Path.Combine(Path.GetTempPath(), "orcashield-schreibprobe-" + Guid.NewGuid().ToString("N") + ".tmp");
                    var erg = Ausfuehren(
                        ". " + q("Orca-Attrappen.ps1") + "\n" +
                        "Initialize-OrcaSimulation\n" +
                        "$Global:PsimZustand = Get-OrcaState\n" +
                        "$Global:PsimGrundzustand = Get-OrcaBaselineStand\n" +
                        "Enable-OrcaAttrappen\n" +
                        "$Global:OrcaSimulationAktiv = $true\n" +
                        "$weg = @(Get-PsimVerlorene)\n" +
                        "Set-Content -Path $OrcaProbe -Value 'Diese Datei darf nicht entstehen.'\n" +
                        "$stand = if ($weg.Count) { 'FEHLT: ' + ($weg -join ', ') } elseif (Test-Path -LiteralPath $OrcaProbe) { 'GESCHRIEBEN' } else { 'OK' }\n" +
                        // Die Probe selbst gehört nicht in die Liste dessen, was geschrieben worden wäre
                        "[void]$Global:PsimVorgaenge.Clear()\n" +
                        "$stand\n",
                        new Dictionary<string, object> { ["OrcaProbe"] = probe }, null);
                    string stand = erg.Count > 0 ? erg[erg.Count - 1] as string : null;
                    if (stand != "OK")
                    {
                        try { if (File.Exists(probe)) File.Delete(probe); } catch { }
                        Fehler = "Simulationsmodus nicht sicher aktiv (" + (stand ?? "keine Antwort") + ") – aus Vorsicht wird nichts ausgeführt.";
                        return false;
                    }
                }
                return true;
            }
            catch (Exception ex) { Fehler = ex.Message; return false; }
        });

        /// Einen festen Skripttext ausführen. Parameter werden als Variablen
        /// übergeben ($Daten …), Fortschritt per Write-Progress weitergereicht.
        public async Task<List<object>> AufrufenAsync(string skript, IDictionary<string, object> variablen,
                                                      Action<int, string> fortschritt)
        {
            if (_start == null) _start = StartenAsync();
            if (!await _start.ConfigureAwait(false)) throw new InvalidOperationException("Engine nicht bereit: " + Fehler);
            await _sperre.WaitAsync().ConfigureAwait(false);
            try { return await Task.Run(() => Ausfuehren(skript, variablen, fortschritt)).ConfigureAwait(false); }
            finally { _sperre.Release(); }
        }

        private List<object> Ausfuehren(string skript, IDictionary<string, object> variablen, Action<int, string> fortschritt)
        {
            if (variablen != null)
                foreach (var kv in variablen)
                {
                    if (!_eigeneVariablen.Contains(kv.Key) && _runspace.SessionStateProxy.PSVariable.Get(kv.Key) != null)
                        throw new InvalidOperationException("Interner Fehler: $" + kv.Key + " gehört der Engine und wird nicht überschrieben");
                    _eigeneVariablen.Add(kv.Key);
                    _runspace.SessionStateProxy.SetVariable(kv.Key, kv.Value);
                }
            using (var ps = PowerShell.Create())
            {
                ps.Runspace = _runspace;
                ps.AddScript(skript);
                if (fortschritt != null)
                    ps.Streams.Progress.DataAdded += (s, e) =>
                    {
                        var p = ((PSDataCollection<ProgressRecord>)s)[e.Index];
                        if (p.RecordType == ProgressRecordType.Processing)
                            fortschritt(p.PercentComplete, p.StatusDescription);
                    };
                var ergebnis = ps.Invoke();
                if (ps.HadErrors && ergebnis.Count == 0)
                {
                    var f = ps.Streams.Error.FirstOrDefault();
                    throw new InvalidOperationException(f?.Exception?.Message ?? "Unbekannter Fehler in der Engine");
                }
                return ergebnis.Select(o => o?.BaseObject).ToList();
            }
        }

        public void Dispose()
        {
            try { _runspace?.Close(); _runspace?.Dispose(); } catch { }
            _sperre.Dispose();
        }
    }
}
