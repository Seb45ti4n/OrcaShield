using System;
using System.Collections.Generic;
using System.Drawing;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace OrcaShield
{
    internal sealed class OrcaFenster : Form
    {
        // Dieselben Pixel wie das Logo (<symbol id="orca"> in OrcaShield.html), 34 × 18
        private static readonly (string Farbe, string Pfad)[] Teile =
        {
            ("#05070a", "M14 2h2v1H14zM15 3h3v1H15zM15 4h4v1H15zM16 5h3v1H16zM14 6h10v1H14zM3 7h1v1H3zM10 7h18v1H10zM4 8h1v1H4zM8 8h22v1H8zM5 9h26v1H5zM5 10h27v1H5zM5 11h27v1H5zM5 12h2v1H5zM8 12h22v1H8zM4 13h2v1H4zM13 13h14v1H13zM3 14h2v1H3z"),
            ("#1d2b38", "M15 2h1v1H15zM16 3h2v1H16zM18 4h1v1H18zM19 6h5v1H19zM11 7h3v1H11zM24 7h4v1H24zM28 8h2v1H28zM30 9h1v1H30z"),
            ("#e9f3ff", "M30 11h2v1H30zM13 12h17v1H13zM17 13h10v1H17z"),
            ("#e9f3ff", "M25 8h3v1H25zM24 9h3v1H24z"),
            ("#4cc3ff", "M29 10h1v1H29z"),
        };
        private static readonly Color Schluessel = Color.FromArgb(1, 2, 3);   // wird durchsichtig
        private static readonly Color Wasser = ColorTranslator.FromHtml("#4cc3ff");
        private static bool _offen;

        private readonly List<(Brush Pinsel, Rectangle Pixel)> _pixel = new List<(Brush, Rectangle)>();
        private readonly Timer _uhr = new Timer { Interval = 16 };
        private readonly DateTime _start = DateTime.Now;
        private const int Groesse = 9;            // Bildschirmpunkte je Logo-Pixel
        private const double Dauer = 4.6;         // Sekunden für einmal quer
        private int _x, _y;

        /// <summary>Zeigt den Orca einmal auf dem Bildschirm, auf dem das Programm steht. Läuft schon einer, passiert nichts.</summary>
        public static void Zeigen(Control besitzer)
        {
            if (_offen) return;
            var f = new OrcaFenster(Screen.FromControl(besitzer).Bounds);
            _offen = true;
            f.FormClosed += (s, e) => { _offen = false; f.Dispose(); };
            f.Show();
        }

        private OrcaFenster(Rectangle bildschirm)
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            Bounds = bildschirm;
            BackColor = Schluessel;
            TransparencyKey = Schluessel;
            DoubleBuffered = true;
            var muster = new Regex(@"M(\d+) (\d+)h(\d+)v1H\d+z");
            foreach (var (farbe, pfad) in Teile)
            {
                var pinsel = new SolidBrush(ColorTranslator.FromHtml(farbe));
                foreach (Match m in muster.Matches(pfad))
                    _pixel.Add((pinsel, new Rectangle(int.Parse(m.Groups[1].Value), int.Parse(m.Groups[2].Value), int.Parse(m.Groups[3].Value), 1)));
            }
            _uhr.Tick += (s, e) => { Schritt(); };
            Shown += (s, e) => { Schritt(); _uhr.Start(); };
        }

        // Nimmt keinen Fokus und keine Mausklicks an, erscheint nicht beim Umschalten mit Alt+Tab
        protected override bool ShowWithoutActivation => true;
        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ExStyle |= 0x80000 /* LAYERED */ | 0x20 /* TRANSPARENT */ | 0x08000000 /* NOACTIVATE */ | 0x80 /* TOOLWINDOW */;
                return cp;
            }
        }

        private void Schritt()
        {
            double t = (DateTime.Now - _start).TotalSeconds;
            if (t > Dauer) { _uhr.Stop(); Close(); return; }
            double anteil = t / Dauer;
            double weich = anteil < .5 ? 2 * anteil * anteil : 1 - Math.Pow(-2 * anteil + 2, 2) / 2;
            int breite = 34 * Groesse;
            _x = (int)(-breite + weich * (ClientSize.Width + breite));
            _y = (int)(ClientSize.Height * .38 + Math.Sin(t * 6) * 18);
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.None;   // klare Pixel, sonst bleiben Ränder in der Schlüsselfarbe stehen
            foreach (var (pinsel, p) in _pixel)
                g.FillRectangle(pinsel, _x + p.X * Groesse, _y + p.Y * Groesse, p.Width * Groesse, Groesse);
            // Fontäne aus dem Blasloch, alle 1,2 s
            double t = (DateTime.Now - _start).TotalSeconds % 1.2;
            if (t < .7)
            {
                int hoehe = (int)(t / .7 * 5 * Groesse);
                using (var w = new SolidBrush(Wasser))
                    foreach (var (dx, dy) in new[] { (0, 0), (-1, -1), (1, -1), (0, -2) })
                        g.FillRectangle(w, _x + (15 + dx) * Groesse, _y + (1 + dy) * Groesse - hoehe, Groesse / 2 + 1, Groesse / 2 + 1);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) { _uhr.Dispose(); foreach (var b in new HashSet<Brush>(_pixel.ConvertAll(x => x.Pinsel))) b.Dispose(); }
            base.Dispose(disposing);
        }
    }
}
