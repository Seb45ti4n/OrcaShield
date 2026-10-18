using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;

namespace OrcaShield
{
    internal sealed class Bruecke
    {
        private readonly CoreWebView2 _kern;
        private readonly Engine _engine;
        private readonly Control _ui;
        private readonly Action<string> _protokoll;
        private readonly JavaScriptSerializer _json = new JavaScriptSerializer { MaxJsonLength = 64 * 1024 * 1024 };
        private readonly Dictionary<string, Func<int, Dictionary<string, object>, Task<string>>> _aktionen;
        private readonly bool _ohneBestaetigung;

        public Bruecke(CoreWebView2 kern, Engine engine, Control ui, Action<string> protokoll, bool ohneBestaetigung = false)
        {
            _kern = kern; _engine = engine; _ui = ui; _protokoll = protokoll;
            _ohneBestaetigung = ohneBestaetigung && !Programm.IstInstalliert();
            _aktionen = new Dictionary<string, Func<int, Dictionary<string, object>, Task<string>>>(StringComparer.Ordinal)
            {
                ["modus"] = (id, d) => Task.FromResult(_json.Serialize(new Dictionary<string, object>
                {
                    ["simulation"] = _engine.Simulation,
                    ["version"] = Application.ProductVersion,
                })),
                ["messen"] = Messen,
                ["anwenden"] = Anwenden,
                ["protokoll"] = Protokoll,
                ["oeffnen"] = Oeffnen,
                ["ablage"] = Ablage,
                ["automatik"] = Automatik,
                ["aufnehmen"] = Aufnehmen,
                ["sammler"] = Sammler,
                ["geraetekennung"] = Geraetekennung,
                ["apps"] = Apps,
                ["appsZurueck"] = AppsZurueck,
                ["hosts"] = Hosts,
                ["richtlinie"] = Richtlinie,
                ["sprache"] = Sprache,
                ["orca"] = (id, d) => { _ui.BeginInvoke(new Action(() => OrcaFenster.Zeigen(_ui))); return Task.FromResult("true"); },
            };
            _kern.WebMessageReceived += Empfangen;
        }

        private async void Empfangen(object sender, CoreWebView2WebMessageReceivedEventArgs e)
        {
            // Nur Nachrichten der eigenen Oberfläche annehmen.
            if (!e.Source.StartsWith(Hauptfenster.Ursprung, StringComparison.OrdinalIgnoreCase))
            {
                _protokoll("Nachricht von fremder Quelle abgewiesen: " + e.Source);
                return;
            }
            int id = 0;
            try
            {
                string roh = e.TryGetWebMessageAsString();
                if (roh == null || roh.Length > 4 * 1024 * 1024) throw new InvalidDataException("Nachricht leer oder zu groß");
                var n = _json.Deserialize<Dictionary<string, object>>(roh);
                id = n.TryGetValue("id", out var i) ? Convert.ToInt32(i, CultureInfo.InvariantCulture) : 0;
                string aktion = n.TryGetValue("aktion", out var a) ? a as string : null;
                if (aktion == null || !_aktionen.TryGetValue(aktion, out var ausfuehren))
                {
                    _protokoll("Unbekannte Aktion abgewiesen: " + (aktion ?? "(keine)"));
                    Senden("{\"id\":" + id + ",\"ok\":false,\"fehler\":" + _json.Serialize("Unbekannte Aktion") + "}");
                    return;
                }
                var daten = n.TryGetValue("daten", out var dd) ? dd as Dictionary<string, object> : null;
                var uhr = System.Diagnostics.Stopwatch.StartNew();
                string ergebnis = await ausfuehren(id, daten ?? new Dictionary<string, object>());
                if (aktion != "protokoll") _protokoll($"Aktion {aktion} fertig in {uhr.Elapsed.TotalSeconds:0.0} s ({ergebnis.Length} Zeichen)");
                Senden("{\"id\":" + id + ",\"ok\":true,\"ergebnis\":" + ergebnis + "}");
            }
            catch (Exception ex)
            {
                _protokoll("Fehler bei Aktion " + id + ": " + ex.Message);
                Senden("{\"id\":" + id + ",\"ok\":false,\"fehler\":" + _json.Serialize(ex.Message) + "}");
            }
        }

        // --- Aktion: messen (liest nur) -------------------------------------
        private async Task<string> Messen(int id, Dictionary<string, object> daten)
        {
            var erg = await _engine.AufrufenAsync(
                "ConvertTo-OrcaGuiJson -Daten (Get-OrcaGuiDaten -MitFortschritt)", null,
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Messung lieferte kein Ergebnis");
            return json;
        }

        // --- Aktion: anwenden (schreibt – im Simulationsmodus nur aufgezeichnet) -----
        // Erwartet { ein: ["TEL001", …], aus: ["UPD005", …] }. Jede Kennung muss die
        // Form einer Katalogkennung haben (2–4 Großbuchstaben, 3 Ziffern); die Engine
        // prüft sie zusätzlich gegen den Katalog. Höchstens 1000 je Liste.
        private static readonly System.Text.RegularExpressions.Regex KennungMuster =
            new System.Text.RegularExpressions.Regex("^[A-Z]{2,4}[0-9]{3}$");

        private static string[] Kennungen(Dictionary<string, object> daten, string feld)
        {
            if (!daten.TryGetValue(feld, out var roh) || roh == null) return new string[0];
            if (!(roh is System.Collections.IEnumerable liste) || roh is string) throw new InvalidDataException("Feld '" + feld + "' ist keine Liste");
            var aus = new List<string>();
            foreach (var x in liste)
            {
                if (!(x is string s) || !KennungMuster.IsMatch(s)) throw new InvalidDataException("Ungültige Kennung in '" + feld + "'");
                if (!aus.Contains(s)) aus.Add(s);
                if (aus.Count > 1000) throw new InvalidDataException("Zu viele Kennungen");
            }
            return aus.ToArray();
        }

        private async Task<string> Anwenden(int id, Dictionary<string, object> daten)
        {
            string[] ein = Kennungen(daten, "ein"), aus = Kennungen(daten, "aus");
            AutomatikAuftrag auto = null;
            if (daten.TryGetValue("automatik", out var a) && a != null)
            {
                if (!(a is Dictionary<string, object> ad)) throw new InvalidDataException("Feld 'automatik' ist kein Objekt");
                auto = AutomatikLesen(ad);
                if (auto.Leer) auto = null;
            }
            if (ein.Length == 0 && aus.Length == 0 && auto == null) throw new InvalidDataException("Nichts zum Anwenden");

            if (!await Bestaetigen("anwenden", ein, aus, auto, null, null))
                return Abgelehnt();

            _protokoll((_engine.Simulation ? "Simulation: " : "") + "anwenden " + ein.Length + " ein, " + aus.Length + " zurück" + (auto != null ? ", mit Automatik" : ""));
            string json = null;
            if (ein.Length > 0 || aus.Length > 0)
            {
                var erg = await _engine.AufrufenAsync(
                    "ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiAnwenden -Ein $OrcaEin -Aus $OrcaAus)",
                    new Dictionary<string, object> { ["OrcaEin"] = ein, ["OrcaAus"] = aus },
                    (prozent, text) => Fortschritt(id, prozent, text));
                if (erg.Count == 0 || !(erg[erg.Count - 1] is string j)) throw new InvalidOperationException("Anwenden lieferte kein Ergebnis");
                json = j;
            }
            if (auto != null)
            {
                var teil = json == null ? null : _json.Deserialize<Dictionary<string, object>>(json);
                if (teil == null || !(teil.TryGetValue("abgebrochen", out var ab) && ab is string s && s.Length > 0))
                {
                    string autoJson = await AutomatikAusfuehren(id, auto);
                    json = json == null ? autoJson : Zusammenfuehren(teil, _json.Deserialize<Dictionary<string, object>>(autoJson));
                }
            }
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        // Ergebnis von Anwenden und Automatik zu einem: Punkte und Vorgänge hintereinander.
        // Bricht die Automatik ab (z. B. noch nicht eingerichtet), steht der Grund in
        // „automatikAbgebrochen“ – die Einstellungen davor sind trotzdem angewendet.
        private string Zusammenfuehren(Dictionary<string, object> erst, Dictionary<string, object> dann)
        {
            object[] Liste(Dictionary<string, object> d, string f) =>
                d.TryGetValue(f, out var x) && x is System.Collections.IEnumerable e && !(x is string) ? e.Cast<object>().ToArray() : new object[0];
            erst["punkte"] = Liste(erst, "punkte").Concat(Liste(dann, "punkte")).ToArray();
            erst["vorgaenge"] = Liste(erst, "vorgaenge").Concat(Liste(dann, "vorgaenge")).ToArray();
            if (dann.TryGetValue("abgebrochen", out var ab) && ab is string s && s.Length > 0) erst["automatikAbgebrochen"] = s;
            return _json.Serialize(erst);
        }

        private bool _englisch;
        private Task<string> Sprache(int id, Dictionary<string, object> daten)
        {
            string s = daten.TryGetValue("sprache", out var roh) ? roh as string : null;
            if (s != "de" && s != "en") throw new InvalidDataException("Feld 'sprache' muss de oder en sein");
            _englisch = s == "en";
            return Task.FromResult(_json.Serialize(new Dictionary<string, object> { ["sprache"] = s }));
        }

        // Antwort, wenn die Rückfrage im Fenster verneint wurde: es wurde nichts geändert.
        private string Abgelehnt()
        {
            _protokoll("Nicht bestätigt – nichts geändert");
            return _json.Serialize(new Dictionary<string, object>
            {
                ["simulation"] = _engine.Simulation,
                ["abgebrochen"] = _englisch ? "Not confirmed – nothing was changed." : "Nicht bestätigt – es wurde nichts geändert.",
                ["abgelehnt"] = true,
                ["punkte"] = new object[0],
                ["vorgaenge"] = new object[0],
            });
        }

        private async Task<bool> Bestaetigen(string was, string[] ein, string[] aus, AutomatikAuftrag auto,
                                             string[] sammler, string sammlerRichtung,
                                             string[] apps = null, bool geraetekennung = false,
                                             string[] richtlinien = null, string richtlinienRichtung = "",
                                             string aufnehmenArt = "", int aufnehmenAnzahl = 0, bool aufnehmenAlle = false,
                                             string[] gdidOrte = null, bool gdidZwischenspeicher = true, bool gdidZugangsdaten = true,
                                             string[] hostsAusnehmen = null, string[] hostsSperren = null, string[] appsZurueck = null)
        {
            var v = new Dictionary<string, object>
            {
                ["OrcaGdidWahl"] = gdidOrte ?? new string[0], ["OrcaGdidZw"] = gdidZwischenspeicher, ["OrcaGdidZd"] = gdidZugangsdaten,
                ["OrcaHostsAus"] = hostsAusnehmen ?? new string[0], ["OrcaHostsEin"] = hostsSperren ?? new string[0],
                ["OrcaAppsZurueck"] = appsZurueck ?? new string[0],
                ["OrcaAufArt"] = aufnehmenArt ?? "", ["OrcaAufAnzahl"] = aufnehmenAnzahl, ["OrcaAufAlle"] = aufnehmenAlle,
                ["OrcaRichtlinien"] = richtlinien ?? new string[0], ["OrcaRichtlinienRichtung"] = richtlinienRichtung ?? "",
                ["OrcaEin"] = ein ?? new string[0], ["OrcaAus"] = aus ?? new string[0],
                ["OrcaW"] = auto?.Waechter ?? "", ["OrcaB"] = auto?.Bereinigung ?? "", ["OrcaSk"] = auto?.Schattenkopien ?? "",
                ["OrcaBAus"] = auto?.BereicheAus ?? new string[0], ["OrcaBAn"] = auto?.BereicheAn ?? new string[0],
                ["OrcaSchrAus"] = auto?.SchritteAus ?? new string[0], ["OrcaSchrAn"] = auto?.SchritteAn ?? new string[0],
                ["OrcaSammler"] = sammler ?? new string[0], ["OrcaSammlerRichtung"] = sammlerRichtung ?? "",
                // Nicht „OrcaApps“: so heißt der App-Katalog der Engine ($Global:OrcaApps) – Engine.cs weist das ab
                ["OrcaAppKennungen"] = apps ?? new string[0], ["OrcaGdid"] = geraetekennung,
                ["OrcaSprache"] = _englisch ? "en" : "de",
            };
            var erg = await _engine.AufrufenAsync(
                "ConvertTo-OrcaGuiJson -Daten (Get-OrcaGuiBestaetigung -Ein $OrcaEin -Aus $OrcaAus -Waechter $OrcaW -Bereinigung $OrcaB -Schattenkopien $OrcaSk " +
                "-BereicheAus $OrcaBAus -BereicheAn $OrcaBAn -SchritteAus $OrcaSchrAus -SchritteAn $OrcaSchrAn -Sammler $OrcaSammler -SammlerRichtung $OrcaSammlerRichtung -Apps $OrcaAppKennungen -Geraetekennung:$OrcaGdid " +
                "-Richtlinien $OrcaRichtlinien -RichtlinienRichtung $OrcaRichtlinienRichtung " +
                "-AufnehmenArt $OrcaAufArt -AufnehmenAnzahl $OrcaAufAnzahl -AufnehmenAlle:$OrcaAufAlle -Sprache $OrcaSprache " +
                "-GdidOrte $OrcaGdidWahl -GdidZwischenspeicher $OrcaGdidZw -GdidZugangsdaten $OrcaGdidZd " +
                "-HostsAusnehmen $OrcaHostsAus -HostsSperren $OrcaHostsEin -AppsZurueck $OrcaAppsZurueck)",
                v, null);
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Rückfrage lieferte keine Liste");
            var d = _json.Deserialize<Dictionary<string, object>>(json);
            List<string> Texte(string f) =>
                d.TryGetValue(f, out var x) && x is System.Collections.IEnumerable e && !(x is string) ? e.Cast<object>().Select(o => o as string ?? "").ToList() : new List<string>();
            var zeilen = Texte("zeilen"); var risiken = Texte("risiken");
            if (_ohneBestaetigung)
            {
                _protokoll($"Rückfrage übersprungen (Testanschluss): {was}, {zeilen.Count} Änderungen, {risiken.Count} Risiken");
                return true;
            }
            if (_rueckfrageOffen) throw new InvalidOperationException("Es wartet bereits eine Rückfrage im Programmfenster");
            _rueckfrageOffen = true;
            try
            {
                int anzahl = zeilen.Count(z => !z.StartsWith("   ", StringComparison.Ordinal));
                string kopf = _englisch
                    ? (anzahl == 1 ? "This change will be made now:" : $"These {anzahl} changes will be made now:")
                    : (anzahl == 1 ? "Diese Änderung wird jetzt ausgeführt:" : $"Diese {anzahl} Änderungen werden jetzt ausgeführt:");
                bool ja = Bestaetigung.Fragen(_ui, _engine.Simulation, kopf, zeilen, risiken, _englisch);
                _protokoll($"Rückfrage {was}: {(ja ? "bestätigt" : "abgelehnt")} ({zeilen.Count} Änderungen, {risiken.Count} Risiken)");
                return ja;
            }
            finally { _rueckfrageOffen = false; }
        }
        private bool _rueckfrageOffen;

        private static readonly System.Text.RegularExpressions.Regex BereichMuster =
            new System.Text.RegularExpressions.Regex("^[a-z]{2,20}$");

        private static string Schalter(Dictionary<string, object> daten, string feld)
        {
            if (!daten.TryGetValue(feld, out var roh) || roh == null) return "";
            if (!(roh is string s) || (s != "" && s != "ein" && s != "aus")) throw new InvalidDataException("Feld '" + feld + "' muss ein, aus oder leer sein");
            return s;
        }

        private static string[] Bereiche(Dictionary<string, object> daten, string feld)
        {
            if (!daten.TryGetValue(feld, out var roh) || roh == null) return new string[0];
            if (!(roh is System.Collections.IEnumerable liste) || roh is string) throw new InvalidDataException("Feld '" + feld + "' ist keine Liste");
            var aus = new List<string>();
            foreach (var x in liste)
            {
                if (!(x is string s) || !BereichMuster.IsMatch(s)) throw new InvalidDataException("Ungültiger Prüfbereich in '" + feld + "'");
                if (!aus.Contains(s)) aus.Add(s);
                if (aus.Count > 50) throw new InvalidDataException("Zu viele Prüfbereiche");
            }
            return aus.ToArray();
        }

        private sealed class AutomatikAuftrag
        {
            public string Waechter, Bereinigung, Schattenkopien;
            public string[] BereicheAus, BereicheAn, SchritteAus, SchritteAn;
            public bool Leer => Waechter == "" && Bereinigung == "" && Schattenkopien == "" && BereicheAus.Length == 0 && BereicheAn.Length == 0
                                && SchritteAus.Length == 0 && SchritteAn.Length == 0;
        }

        private static AutomatikAuftrag AutomatikLesen(Dictionary<string, object> daten) => new AutomatikAuftrag
        {
            Waechter = Schalter(daten, "waechter"),
            Bereinigung = Schalter(daten, "bereinigung"),
            Schattenkopien = Schalter(daten, "schattenkopien"),
            BereicheAus = Bereiche(daten, "bereicheAus"),
            BereicheAn = Bereiche(daten, "bereicheAn"),
            SchritteAus = Bereiche(daten, "schritteAus"),
            SchritteAn = Bereiche(daten, "schritteAn"),
        };

        private async Task<string> Automatik(int id, Dictionary<string, object> daten)
        {
            var auto = AutomatikLesen(daten);
            if (auto.Leer) throw new InvalidDataException("Nichts zum Umschalten");
            if (!await Bestaetigen("automatik", null, null, auto, null, null)) return Abgelehnt();
            string json = await AutomatikAusfuehren(id, auto);
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        private async Task<string> AutomatikAusfuehren(int id, AutomatikAuftrag a)
        {
            _protokoll((_engine.Simulation ? "Simulation: " : "") + $"automatik Wächter '{a.Waechter}', Bereinigung '{a.Bereinigung}', Schattenkopien '{a.Schattenkopien}', Bereiche aus {a.BereicheAus.Length}, ein {a.BereicheAn.Length}");
            var erg = await _engine.AufrufenAsync(
                "ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiAutomatik -Waechter $OrcaW -Bereinigung $OrcaB -Schattenkopien $OrcaSk -BereicheAus $OrcaAus -BereicheAn $OrcaAn -SchritteAus $OrcaSchrAus -SchritteAn $OrcaSchrAn)",
                new Dictionary<string, object> { ["OrcaW"] = a.Waechter, ["OrcaB"] = a.Bereinigung, ["OrcaSk"] = a.Schattenkopien, ["OrcaAus"] = a.BereicheAus, ["OrcaAn"] = a.BereicheAn, ["OrcaSchrAus"] = a.SchritteAus, ["OrcaSchrAn"] = a.SchritteAn },
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Automatik lieferte kein Ergebnis");
            return json;
        }

        private static readonly HashSet<string> NeuesArten = new HashSet<string>(StringComparer.Ordinal)
            { "autostart", "richtlinien", "zertifikate", "proxy", "firewall", "telemetrie" };

        private async Task<string> Aufnehmen(int id, Dictionary<string, object> daten)
        {
            string art = daten.TryGetValue("art", out var a) ? a as string ?? "" : "";
            if (art != "" && !NeuesArten.Contains(art)) throw new InvalidDataException("Unbekannte Art");
            bool alle = daten.TryGetValue("alle", out var al) && al is bool b && b;
            var schluessel = new List<string>();
            if (daten.TryGetValue("schluessel", out var roh) && roh != null)
            {
                if (!(roh is System.Collections.IEnumerable liste) || roh is string) throw new InvalidDataException("Feld 'schluessel' ist keine Liste");
                foreach (var x in liste)
                {
                    if (!(x is string s) || s.Length == 0 || s.Length > 1000) throw new InvalidDataException("Ungültiger Schlüssel");
                    foreach (char c in s) if (char.IsControl(c)) throw new InvalidDataException("Ungültiger Schlüssel");
                    schluessel.Add(s);
                    if (schluessel.Count > 5000) throw new InvalidDataException("Zu viele Schlüssel");
                }
            }
            if (!alle && (art == "" || schluessel.Count == 0)) throw new InvalidDataException("Nichts zum Aufnehmen");
            if (!await Bestaetigen("aufnehmen", null, null, null, null, null,
                                   aufnehmenArt: art, aufnehmenAnzahl: schluessel.Count, aufnehmenAlle: alle)) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + $"aufnehmen {(art == "" ? "alle Arten" : art)}{(alle ? ", alles" : ", " + schluessel.Count + " Einträge")}");
            var erg = await _engine.AufrufenAsync(
                "ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiAufnehmen -Art $OrcaArt -Schluessel $OrcaSchluessel -Alle:$OrcaAlle)",
                new Dictionary<string, object> { ["OrcaArt"] = art, ["OrcaSchluessel"] = schluessel.ToArray(), ["OrcaAlle"] = alle },
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Aufnehmen lieferte kein Ergebnis");
            return json;
        }

        private async Task<string> Sammler(int id, Dictionary<string, object> daten)
        {
            string richtung = daten.TryGetValue("richtung", out var r) ? r as string : null;
            if (richtung != "aus" && richtung != "zurueck") throw new InvalidDataException("Feld 'richtung' muss aus oder zurueck sein");
            if (!daten.TryGetValue("schluessel", out var roh) || !(roh is System.Collections.IEnumerable liste) || roh is string)
                throw new InvalidDataException("Feld 'schluessel' ist keine Liste");
            var schluessel = new List<string>();
            foreach (var x in liste)
            {
                if (!(x is string s) || s.Length > 1000 || !(s.StartsWith("aufgabe:\\", StringComparison.Ordinal) || s.StartsWith("dienst:", StringComparison.Ordinal)))
                    throw new InvalidDataException("Ungültiger Schlüssel");
                foreach (char c in s) if (char.IsControl(c)) throw new InvalidDataException("Ungültiger Schlüssel");
                if (!schluessel.Contains(s)) schluessel.Add(s);
                if (schluessel.Count > 100) throw new InvalidDataException("Zu viele Schlüssel");
            }
            if (schluessel.Count == 0) throw new InvalidDataException("Nichts ausgewählt");
            if (!await Bestaetigen("sammler", null, null, null, schluessel.ToArray(), richtung)) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + $"sammler {richtung}: {string.Join(", ", schluessel)}");
            var erg = await _engine.AufrufenAsync(
                "ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiSammler -Schluessel $OrcaSchluessel -Richtung $OrcaRichtung)",
                new Dictionary<string, object> { ["OrcaSchluessel"] = schluessel.ToArray(), ["OrcaRichtung"] = richtung },
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Sammler lieferte kein Ergebnis");
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        private static readonly string[] GdidOrte = { "dein Profil", "Vorlageprofil", "Systemkonto" };
        private async Task<string> Geraetekennung(int id, Dictionary<string, object> daten)
        {
            var orte = new List<string>(GdidOrte);
            if (daten.TryGetValue("orte", out var roh) && roh != null)
            {
                if (!(roh is System.Collections.IEnumerable liste) || roh is string) throw new InvalidDataException("Feld 'orte' ist keine Liste");
                orte.Clear();
                foreach (var x in liste)
                {
                    if (!(x is string s) || Array.IndexOf(GdidOrte, s) < 0) throw new InvalidDataException("Unbekannter Ort");
                    if (!orte.Contains(s)) orte.Add(s);
                }
            }
            bool Wahr(string feld) => !daten.TryGetValue(feld, out var w) || w == null || (w is bool b ? b : throw new InvalidDataException("Feld '" + feld + "' muss true oder false sein"));
            bool zw = Wahr("zwischenspeicher"), zd = Wahr("zugangsdaten");
            if (orte.Count == 0 && !zw && !zd) throw new InvalidDataException("Nichts ausgewählt");
            if (!await Bestaetigen("geraetekennung", null, null, null, null, null, geraetekennung: true,
                                   gdidOrte: orte.ToArray(), gdidZwischenspeicher: zw, gdidZugangsdaten: zd)) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + $"Gerätekennung entfernen: {string.Join(", ", orte)}{(zw ? ", Zwischenspeicher" : "")}{(zd ? ", Zugangsdaten" : "")}");
            var erg = await _engine.AufrufenAsync("ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiGeraetekennung -Orte $OrcaOrte -Zwischenspeicher $OrcaZw -Zugangsdaten $OrcaZd)",
                new Dictionary<string, object> { ["OrcaOrte"] = orte.ToArray(), ["OrcaZw"] = zw, ["OrcaZd"] = zd },
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Gerätekennung lieferte kein Ergebnis");
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        private static readonly System.Text.RegularExpressions.Regex AppMuster =
            new System.Text.RegularExpressions.Regex("^[A-Z][0-9]{2}$");

        private async Task<string> Apps(int id, Dictionary<string, object> daten)
        {
            if (!daten.TryGetValue("entfernen", out var roh) || !(roh is System.Collections.IEnumerable liste) || roh is string)
                throw new InvalidDataException("Feld 'entfernen' ist keine Liste");
            var ids = new List<string>();
            foreach (var x in liste)
            {
                if (!(x is string s) || !AppMuster.IsMatch(s)) throw new InvalidDataException("Ungültige App-Kennung");
                if (!ids.Contains(s)) ids.Add(s);
                if (ids.Count > 100) throw new InvalidDataException("Zu viele Apps");
            }
            if (ids.Count == 0) throw new InvalidDataException("Nichts ausgewählt");
            if (!await Bestaetigen("apps", null, null, null, null, null, apps: ids.ToArray())) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + "Apps entfernen: " + string.Join(", ", ids));
            var erg = await _engine.AufrufenAsync("ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiApps -Ids $OrcaIds)",
                new Dictionary<string, object> { ["OrcaIds"] = ids.ToArray() },
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Apps lieferte kein Ergebnis");
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        private async Task<string> AppsZurueck(int id, Dictionary<string, object> daten)
        {
            if (!daten.TryGetValue("ids", out var roh) || !(roh is System.Collections.IEnumerable liste) || roh is string)
                throw new InvalidDataException("Feld 'ids' ist keine Liste");
            var ids = new List<string>();
            foreach (var x in liste)
            {
                if (!(x is string s) || !AppMuster.IsMatch(s)) throw new InvalidDataException("Ungültige App-Kennung");
                if (!ids.Contains(s)) ids.Add(s);
                if (ids.Count > 100) throw new InvalidDataException("Zu viele Apps");
            }
            if (ids.Count == 0) throw new InvalidDataException("Nichts ausgewählt");
            if (!await Bestaetigen("appsZurueck", null, null, null, null, null, appsZurueck: ids.ToArray())) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + "Apps wieder installieren: " + string.Join(", ", ids));
            var erg = await _engine.AufrufenAsync("ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiAppsZurueck -Ids $OrcaIds)",
                new Dictionary<string, object> { ["OrcaIds"] = ids.ToArray() }, (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Apps lieferte kein Ergebnis");
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        private static readonly System.Text.RegularExpressions.Regex HostMuster =
            new System.Text.RegularExpressions.Regex("^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$");
        private async Task<string> Hosts(int id, Dictionary<string, object> daten)
        {
            string[] Namen(string feld)
            {
                if (!daten.TryGetValue(feld, out var roh) || roh == null) return new string[0];
                if (!(roh is System.Collections.IEnumerable liste) || roh is string) throw new InvalidDataException("Feld '" + feld + "' ist keine Liste");
                var aus = new List<string>();
                foreach (var x in liste)
                {
                    if (!(x is string s) || !HostMuster.IsMatch(s)) throw new InvalidDataException("Ungültiger Hostname");
                    if (!aus.Contains(s)) aus.Add(s);
                }
                return aus.ToArray();
            }
            var aus = Namen("ausnehmen"); var ein = Namen("sperren");
            if (aus.Length + ein.Length == 0) throw new InvalidDataException("Nichts ausgewählt");
            if (aus.Length + ein.Length > 500) throw new InvalidDataException("Zu viele Einträge");
            if (!await Bestaetigen("hosts", null, null, null, null, null, hostsAusnehmen: aus, hostsSperren: ein)) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + $"hosts ausnehmen {aus.Length}, sperren {ein.Length}");
            var erg = await _engine.AufrufenAsync("ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiHosts -Ausnehmen $OrcaAus -Sperren $OrcaEin)",
                new Dictionary<string, object> { ["OrcaAus"] = aus, ["OrcaEin"] = ein }, (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Hosts lieferte kein Ergebnis");
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        private async Task<string> Richtlinie(int id, Dictionary<string, object> daten)
        {
            string richtung = daten.TryGetValue("richtung", out var r) ? r as string : null;
            if (richtung != "aus" && richtung != "zurueck") throw new InvalidDataException("Feld 'richtung' muss aus oder zurueck sein");
            if (!daten.TryGetValue("schluessel", out var roh) || !(roh is System.Collections.IEnumerable liste) || roh is string)
                throw new InvalidDataException("Feld 'schluessel' ist keine Liste");
            var schluessel = new List<string>();
            foreach (var x in liste)
            {
                if (!(x is string s) || s.Length > 1200 ||
                    !(s.StartsWith("pol:HKLM:\\SOFTWARE\\Policies", StringComparison.OrdinalIgnoreCase) || s.StartsWith("pol:HKCU:\\SOFTWARE\\Policies", StringComparison.OrdinalIgnoreCase)))
                    throw new InvalidDataException("Ungültiger Schlüssel");
                foreach (char c in s) if (char.IsControl(c)) throw new InvalidDataException("Ungültiger Schlüssel");
                if (!schluessel.Contains(s)) schluessel.Add(s);
                if (schluessel.Count > 100) throw new InvalidDataException("Zu viele Schlüssel");
            }
            if (schluessel.Count == 0) throw new InvalidDataException("Nichts ausgewählt");
            if (!await Bestaetigen("richtlinie", null, null, null, null, null, richtlinien: schluessel.ToArray(), richtlinienRichtung: richtung)) return Abgelehnt();
            _protokoll((_engine.Simulation ? "Simulation: " : "") + $"richtlinie {richtung}: {string.Join(", ", schluessel)}");
            var erg = await _engine.AufrufenAsync(
                "ConvertTo-OrcaGuiJson -Daten (Invoke-OrcaGuiRichtlinie -Schluessel $OrcaSchluessel -Richtung $OrcaRichtung)",
                new Dictionary<string, object> { ["OrcaSchluessel"] = schluessel.ToArray(), ["OrcaRichtung"] = richtung },
                (prozent, text) => Fortschritt(id, prozent, text));
            if (erg.Count == 0 || !(erg[erg.Count - 1] is string json)) throw new InvalidOperationException("Richtlinie lieferte kein Ergebnis");
            if (_engine.Simulation) SimulationAblegen(json);
            return json;
        }

        // --- Aktion: oeffnen (einzige Verbindung nach außen, nur auf Klick) --------
        // Öffnet eine Adresse im Standardbrowser – aber nur Adressen aus dieser festen
        // Liste. Die Oberfläche selbst lädt nie etwas aus dem Netz.
        private static readonly HashSet<string> ErlaubteLinks = new HashSet<string>(StringComparer.Ordinal)
        {
            "https://github.com/Seb45ti4n/OrcaShield",
            "https://librewolf.net", "https://protonvpn.com", "https://telegram.org", "https://www.videolan.org/vlc/",
            "https://notepad-plus-plus.org", "https://rufus.ie", "https://veracrypt.fr", "https://www.revouninstaller.com",
        };
        private static readonly System.Text.RegularExpressions.Regex StoreLink =
            new System.Text.RegularExpressions.Regex(@"^ms-windows-store://pdp/\?PFN=[A-Za-z0-9.\-]{3,100}_[a-z0-9]{13}$");
        private Task<string> Oeffnen(int id, Dictionary<string, object> daten)
        {
            string url = daten.TryGetValue("url", out var u) ? u as string : null;
            if (url == null || !(ErlaubteLinks.Contains(url) || StoreLink.IsMatch(url))) throw new InvalidDataException("Diese Adresse ist nicht freigegeben");
            // Nicht direkt starten: OrcaShield läuft als Administrator, der Browser liefe dann
            // ebenfalls erhöht. Der Explorer öffnet die Adresse im Browser des normalen Kontos.
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "explorer.exe"), "\"" + url + "\"")
                { UseShellExecute = false });
            _protokoll("Link geöffnet: " + url);
            return Task.FromResult("true");
        }

        private static readonly HashSet<string> AblageArten = new HashSet<string>(StringComparer.Ordinal) { "sicherungspunkte", "profile" };
        private static readonly System.Text.RegularExpressions.Regex FarbMuster =
            new System.Text.RegularExpressions.Regex("^#[0-9a-fA-F]{6}$");
        private string _ablageOrdner;

        private async Task<string> AblageOrdner()
        {
            if (_ablageOrdner != null) return _ablageOrdner;
            string ordner;
            if (_engine.Simulation)
                ordner = Ordner.Unterordner("Ablage-Simulation", entbehrlich: true);
            else if (Programm.IstInstalliert())
                ordner = Ordner.Unterordner("Ablage", entbehrlich: false);   // geschützt (S10)
            else
            {
                var erg = await _engine.AufrufenAsync("[string]$Global:OrcaDaten", null, null);
                string daten = erg.Count > 0 ? erg[erg.Count - 1] as string : null;
                if (string.IsNullOrWhiteSpace(daten) || !Path.IsPathRooted(daten)) throw new InvalidOperationException("Datenordner unbekannt");
                ordner = Path.Combine(daten, "Ablage");
            }
            Directory.CreateDirectory(ordner);
            return _ablageOrdner = ordner;
        }

        private static string Text(Dictionary<string, object> e, string feld, int max, bool pflicht)
        {
            if (!e.TryGetValue(feld, out var roh) || roh == null) { if (pflicht) throw new InvalidDataException("Feld '" + feld + "' fehlt"); return null; }
            if (!(roh is string s)) throw new InvalidDataException("Feld '" + feld + "' ist kein Text");
            var sauber = new StringBuilder(s.Length);
            foreach (char c in s) if (!char.IsControl(c)) sauber.Append(c);
            s = sauber.ToString().Trim();
            if (pflicht && s.Length == 0) throw new InvalidDataException("Feld '" + feld + "' ist leer");
            if (s.Length > max) throw new InvalidDataException("Feld '" + feld + "' ist zu lang");
            return s;
        }

        private static List<Dictionary<string, object>> AblagePruefen(object roh)
        {
            if (!(roh is System.Collections.IEnumerable liste) || roh is string || roh is Dictionary<string, object>)
                throw new InvalidDataException("Keine Liste");
            var aus = new List<Dictionary<string, object>>();
            foreach (var x in liste)
            {
                if (aus.Count >= 200) throw new InvalidDataException("Mehr als 200 Einträge");
                if (!(x is Dictionary<string, object> e)) throw new InvalidDataException("Eintrag ist kein Objekt");
                var n = new Dictionary<string, object>(StringComparer.Ordinal)
                {
                    ["name"] = Text(e, "name", 80, true),
                    ["zeit"] = Text(e, "zeit", 40, false) ?? "",
                };
                string version = Text(e, "version", 40, false);
                if (version != null) n["version"] = version;
                string farbe = Text(e, "farbe", 7, false);
                if (farbe != null) { if (!FarbMuster.IsMatch(farbe)) throw new InvalidDataException("Ungültige Farbe"); n["farbe"] = farbe.ToLowerInvariant(); }
                if (!e.TryGetValue("zustand", out var z) || !(z is Dictionary<string, object> zustand)) throw new InvalidDataException("Feld 'zustand' fehlt");
                if (zustand.Count > 2000) throw new InvalidDataException("Zu viele Kennungen");
                var zn = new Dictionary<string, object>(StringComparer.Ordinal);
                foreach (var kv in zustand)
                {
                    if (!KennungMuster.IsMatch(kv.Key)) throw new InvalidDataException("Ungültige Kennung im Zustand");
                    if (!(kv.Value is bool b)) throw new InvalidDataException("Zustand ist nicht Ja/Nein");
                    zn[kv.Key] = b;
                }
                n["zustand"] = zn;
                aus.Add(n);
            }
            return aus;
        }

        private async Task<string> Ablage(int id, Dictionary<string, object> daten)
        {
            string art = daten.TryGetValue("art", out var a) ? a as string : null;
            if (art == null || !AblageArten.Contains(art)) throw new InvalidDataException("Unbekannte Ablage");
            string datei = Path.Combine(await AblageOrdner(), art + ".json");

            if (daten.TryGetValue("liste", out var neu))
            {
                var geprueft = AblagePruefen(neu);
                string json = _json.Serialize(geprueft);
                if (json.Length > 4 * 1024 * 1024) throw new InvalidDataException("Ablage zu groß");
                string zwischen = datei + ".neu";
                File.WriteAllText(zwischen, json, new UTF8Encoding(false));
                if (File.Exists(datei)) File.Replace(zwischen, datei, null); else File.Move(zwischen, datei);
                _protokoll($"Ablage {art}: {geprueft.Count} Einträge gespeichert");
                return json;
            }

            if (!File.Exists(datei)) return "[]";
            try
            {
                var gelesen = AblagePruefen(_json.DeserializeObject(File.ReadAllText(datei, Encoding.UTF8)));
                return _json.Serialize(gelesen);
            }
            catch (Exception ex) when (ex is InvalidDataException || ex is ArgumentException || ex is InvalidOperationException)
            {
                // Beschädigt oder von außen verändert: beiseitelegen statt still zu überschreiben
                string defekt = datei + ".defekt-" + DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
                File.Move(datei, defekt);
                _protokoll($"Ablage {art} unlesbar ({ex.Message}) – beiseitegelegt als {Path.GetFileName(defekt)}");
                throw new InvalidDataException("Die gespeicherte Datei war beschädigt und wurde beiseitegelegt: " + ex.Message);
            }
        }

        private static readonly object Schreibsperre = new object();
        private Task<string> Protokoll(int id, Dictionary<string, object> daten)
        {
            if (!daten.TryGetValue("eintraege", out var roh) || !(roh is System.Collections.IEnumerable liste) || roh is string)
                throw new InvalidDataException("Feld 'eintraege' fehlt");
            var sb = new StringBuilder();
            int n = 0;
            foreach (var x in liste)
            {
                if (++n > 300) break;
                string z = (x as string) ?? "";
                if (z.Length > 600) z = z.Substring(0, 600) + " …";
                var sauber = new StringBuilder(z.Length);
                foreach (char c in z) sauber.Append(char.IsControl(c) ? ' ' : c);
                sb.Append(sauber).Append("\r\n");
            }
            lock (Schreibsperre)
            {
                string datei = Path.Combine(Protokollordner(), "Oberflaeche_" + DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) + ".log");
                var info = new FileInfo(datei);
                if (info.Exists && info.Length > 20L * 1024 * 1024) return Task.FromResult("false");
                File.AppendAllText(datei, sb.ToString(), new UTF8Encoding(false));
            }
            return Task.FromResult("true");
        }

        internal static string Protokollordner() => Ordner.Unterordner("Protokoll", entbehrlich: true);

        // Jedes Simulationsergebnis zusätzlich als Datei (nur im Benutzerprofil, nie im System):
        // %LOCALAPPDATA%\OrcaShield\Simulationen\Simulation_<Zeit>.json – zum Nachlesen und Auswerten.
        private void SimulationAblegen(string json)
        {
            try
            {
                string ordner = Ordner.Unterordner("Simulationen", entbehrlich: true);
                string datei = Path.Combine(ordner, "Simulation_" + DateTime.Now.ToString("yyyy-MM-dd_HHmmss", CultureInfo.InvariantCulture) + ".json");
                File.WriteAllText(datei, json, new UTF8Encoding(false));
                _protokoll("Simulation abgelegt: " + datei);
            }
            catch (Exception ex) { _protokoll("Simulation nicht abgelegt: " + ex.Message); }
        }

        private void Fortschritt(int id, int prozent, string text)
        {
            var sb = new StringBuilder();
            sb.Append("{\"id\":").Append(id).Append(",\"fortschritt\":{\"prozent\":").Append(Math.Max(0, prozent))
              .Append(",\"text\":").Append(_json.Serialize(text ?? "")).Append("}}");
            Senden(sb.ToString());
        }

        private void Senden(string json)
        {
            if (_ui.IsDisposed) return;
            if (_ui.InvokeRequired) { _ui.BeginInvoke(new Action(() => Senden(json))); return; }
            try { _kern.PostWebMessageAsJson(json); } catch (Exception ex) { _protokoll("Senden fehlgeschlagen: " + ex.Message); }
        }
    }
}
