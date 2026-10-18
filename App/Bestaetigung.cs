using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace OrcaShield
{
    internal static class Bestaetigung
    {
        /// <summary>Fragt im eigenen Fenster nach. true = bestätigt.
        /// Mit Punkten unter „risiken“ (Sicherheitsrisiko, nicht umkehrbar): Warnsymbol, Vorgabeknopf „Nein“.</summary>
        public static bool Fragen(Control ui, bool simulation, string kopf, IList<string> zeilen, IList<string> risiken, bool englisch = false)
        {
            if (ui.IsDisposed) return false;
            if (ui.InvokeRequired)
                return (bool)ui.Invoke(new Func<bool>(() => Fragen(ui, simulation, kopf, zeilen, risiken, englisch)));

            bool risiko = risiken != null && risiken.Count > 0;
            var besitzer = ui.FindForm();
            if (besitzer != null && besitzer.WindowState == FormWindowState.Minimized) besitzer.WindowState = FormWindowState.Normal;
            besitzer?.Activate();
            using (var f = new RueckfrageFenster(kopf, zeilen, risiken ?? new string[0], simulation, englisch))
                return f.ShowDialog(besitzer) == DialogResult.Yes;
        }
    }

    // Rückfrage im Stil der Oberfläche (Farben wie OrcaShield.html, dunkel)
    internal sealed class RueckfrageFenster : Form
    {
        private static readonly Color Grund = ColorTranslator.FromHtml("#121519");
        private static readonly Color Flaeche = ColorTranslator.FromHtml("#171b20");
        private static readonly Color Linie = ColorTranslator.FromHtml("#30363e");
        private static readonly Color Hell = ColorTranslator.FromHtml("#e6eaef");
        private static readonly Color Leise = ColorTranslator.FromHtml("#8b949e");
        private static readonly Color Rot = ColorTranslator.FromHtml("#e5675f");
        private static readonly Color Akzent = ColorTranslator.FromHtml("#4cc3ff");

        [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int wert, int groesse);

        public RueckfrageFenster(string kopf, IList<string> zeilen, IList<string> risiken, bool simulation, bool englisch)
        {
            bool risiko = risiken.Count > 0;
            Text = englisch ? "OrcaShield – please confirm" : "OrcaShield – bitte bestätigen";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false; MinimizeBox = false; ShowInTaskbar = false;
            StartPosition = FormStartPosition.CenterParent;
            BackColor = Grund; ForeColor = Hell;
            Font = new Font("Segoe UI", 10f);
            AutoScaleMode = AutoScaleMode.Dpi;
            Padding = new Padding(22, 18, 22, 16);
            int breite = 600;

            var inhalt = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, Dock = DockStyle.Fill, BackColor = Grund, Padding = new Padding(0, 0, 8, 0) };
            Label zeile(string t, Color farbe, Font schrift = null, int oben = 2) => new Label
            {
                Text = t, ForeColor = farbe, AutoSize = true, MaximumSize = new Size(breite - 30, 0),
                Font = schrift ?? Font, Margin = new Padding(0, oben, 0, 2), UseMnemonic = false,
            };
            inhalt.Controls.Add(zeile(kopf, Hell, new Font("Segoe UI Semibold", 12f), 0));
            // Eingerückte Zeilen sind Folgen der Zeile darüber: leiser und ohne eigenen Punkt
            foreach (var z in zeilen)
                inhalt.Controls.Add(z.StartsWith("   ", StringComparison.Ordinal) ? zeile("      " + z.Trim(), Leise) : zeile("•  " + z, Hell));
            if (risiko)
            {
                inhalt.Controls.Add(zeile(englisch ? "⚠  Please check carefully:" : "⚠  Bitte genau prüfen:", Rot, new Font("Segoe UI Semibold", 10.5f), 14));
                foreach (var r in risiken) inhalt.Controls.Add(zeile("•  " + r, ColorTranslator.FromHtml("#f0a29c")));
            }
            inhalt.Controls.Add(zeile(englisch ? (simulation ? "Simulation: nothing is written. Continue?" : "Continue?")
                                               : (simulation ? "Simulation: Es wird nichts geschrieben. Fortfahren?" : "Fortfahren?"), Leise, null, 14));

            Button knopf(string t, bool voll) => new Button
            {
                Text = t, AutoSize = true, MinimumSize = new Size(110, 36), FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand,
                BackColor = voll ? Akzent : Flaeche, ForeColor = voll ? ColorTranslator.FromHtml("#041018") : Hell,
                Font = new Font("Segoe UI Semibold", 10f), Margin = new Padding(10, 0, 0, 0), UseMnemonic = false,
                FlatAppearance = { BorderColor = voll ? Akzent : Linie, BorderSize = 1 },
            };
            // Bei Sicherheitsrisiken ist „Nein“ hervorgehoben und vorgewählt, sonst „Ja“ (E-040c)
            var ja = knopf(englisch ? "Yes" : "Ja", !risiko);
            var nein = knopf(englisch ? "No" : "Nein", risiko);
            ja.DialogResult = DialogResult.Yes; nein.DialogResult = DialogResult.No;
            var leiste = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, Dock = DockStyle.Bottom, AutoSize = true, BackColor = Grund, Padding = new Padding(0, 14, 0, 0) };
            leiste.Controls.Add(nein); leiste.Controls.Add(ja);
            Controls.Add(inhalt); Controls.Add(leiste);
            AcceptButton = risiko ? nein : ja;
            CancelButton = nein;
            Shown += (s, e) => (risiko ? nein : ja).Focus();

            // Höhe nach Inhalt, höchstens 80 % des Bildschirms; darüber lässt sich rollen
            int hoehe = 0; foreach (Control c in inhalt.Controls) hoehe += c.PreferredSize.Height + c.Margin.Vertical;
            var bereich = Screen.FromPoint(Cursor.Position).WorkingArea;
            ClientSize = new Size(breite + Padding.Horizontal, Math.Min(hoehe + 80 + Padding.Vertical, (int)(bereich.Height * .8)));
        }

        // Dunkle Titelleiste wie die Oberfläche (Windows 11: Attribut 20)
        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            int an = 1;
            try { DwmSetWindowAttribute(Handle, 20, ref an, sizeof(int)); } catch { }
        }
    }
}
