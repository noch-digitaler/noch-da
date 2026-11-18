<# : noch da by noch-digitaler.de - portabel, keine Installation, keine Admin-Rechte. Einfach doppelklicken.
@echo off
set "MJ_SELF=%~f0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "iex ([IO.File]::ReadAllText('%~f0'))"
exit /b
#>

# ---------- ab hier PowerShell ----------

$code = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class NochDaForm : Form
{
    // ---------- Windows-API (alles ohne Admin-Rechte) ----------
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X; public int Y; }
    [DllImport("user32.dll")] static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO i);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("kernel32.dll")] static extern uint SetThreadExecutionState(uint s);
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);

    // ---------- noch-digitaler Farben ----------
    static readonly Color Teal     = Color.FromArgb(79, 176, 176);   // #4FB0B0 aus dem Logo
    static readonly Color TealDark = Color.FromArgb(58, 145, 145);
    static readonly Color TealSoft = Color.FromArgb(206, 232, 232);
    static readonly Color Ink      = Color.FromArgb(31, 42, 46);
    static readonly Color Muted    = Color.FromArgb(110, 124, 130);
    static readonly Color Line     = Color.FromArgb(222, 231, 231);
    static readonly Color Card     = Color.FromArgb(243, 248, 248);
    static readonly Color Amber    = Color.FromArgb(222, 158, 46);
    static readonly Color Grey     = Color.FromArgb(160, 170, 173);
    static readonly Color Disabled = Color.FromArgb(200, 209, 211);

    const uint ES_CONT = 0x80000000, ES_AWAKE = 0x80000003;
    const int RADIUS = 3, STEPS = 24;           // Kreis: 3 px Radius, 24 Schritte
    const float W = 360, H = 490;
    static readonly int[] AUTO = { 0, 15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480, 600 };  // Auto-Aus in Minuten, 0 = aus

    float S = 1f;
    GraphicsPath nochPath = BuildNoch();   // Schriftzug "noch" als Vektorgrafik
    Font fBrand, fTitle, fSub, fStatus, fSmall, fLabel, fFooter;
    Timer timer = new Timer();
    Stopwatch watch = new Stopwatch();
    int state = 0;                               // 0 gestoppt, 1 laeuft, 2 pausiert
    bool circling, onTop, virtualMode, autoStopped;
    int autoIdx = 0;
    uint ourTick;
    double angle;
    int cx, cy, rounds, uiTick, idleSec = 30;
    string hover = "";

    RectangleF rMin    = new RectangleF(284, 18, 28, 28);
    RectangleF rClose  = new RectangleF(316, 18, 28, 28);
    RectangleF rMinus  = new RectangleF(232, 216, 26, 26);
    RectangleF rPlus   = new RectangleF(314, 216, 26, 26);
    RectangleF rVirtRow  = new RectangleF(16, 246, 328, 34);
    RectangleF rAutoMinus = new RectangleF(232, 288, 26, 26);
    RectangleF rAutoPlus  = new RectangleF(314, 288, 26, 26);
    RectangleF rTopRow = new RectangleF(16, 318, 328, 34);
    PointF cStop = new PointF(110, 392), cPlay = new PointF(180, 392), cPause = new PointF(250, 392);
    const float RBIG = 30, RSMALL = 22;

    public NochDaForm()
    {
        using (Graphics g = CreateGraphics()) S = g.DpiX / 96f;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size((int)(W * S), (int)(H * S));
        BackColor = Color.White;
        Text = "noch da";
        DoubleBuffered = true;

        fBrand  = new Font("Segoe UI Semibold", 14f, FontStyle.Regular, GraphicsUnit.Pixel);
        fTitle  = new Font("Segoe UI Semibold", 20f, FontStyle.Regular, GraphicsUnit.Pixel);
        fSub    = new Font("Segoe UI", 13f, FontStyle.Regular, GraphicsUnit.Pixel);
        fStatus = new Font("Segoe UI Semibold", 15f, FontStyle.Regular, GraphicsUnit.Pixel);
        fSmall  = new Font("Segoe UI", 13f, FontStyle.Regular, GraphicsUnit.Pixel);
        fLabel  = new Font("Segoe UI", 12f, FontStyle.Regular, GraphicsUnit.Pixel);
        fFooter = new Font("Segoe UI", 11f, FontStyle.Regular, GraphicsUnit.Pixel);

        Bitmap ico = new Bitmap(64, 64, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(ico)) { g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(Color.Transparent); DrawLogo(g, 0, 0, 64, Teal, Color.Transparent); }
        Icon = Icon.FromHandle(ico.GetHicon());

        timer.Interval = 30;
        timer.Tick += Tick;
    }

    // Umriss des Schriftzugs "noch" als Logo-Grafik (keine Schriftdatei). Grundlinie bei y=0,
    // Groesse bezogen auf 100 px Schrifthoehe. Je Punkt: x*10, y*10, Punkttyp.
    const string NOCH = "-2 13 0 -7 13 3 -8 10 3 -6 6 3 -4 2 3 0 -7 3 5 -22 3 10 -36 3 16 -53 3 23 -73 3 30 -93 3 38 -114 3 45 -135 3 52 -157 3 59 -177 3 65 -195 3 72 -214 3 77 -229 3 81 -239 3 82 -243 3 84 -249 3 85 -257 3 86 -264 3 89 -271 3 93 -278 3 98 -284 3 105 -287 3 116 -287 3 136 -287 3 146 -283 3 146 -273 3 146 -270 3 144 -264 3 141 -256 3 133 -238 3 124 -218 3 115 -194 3 106 -171 3 97 -149 3 90 -128 3 83 -108 3 77 -92 3 73 -80 3 80 -90 3 90 -103 3 105 -120 3 120 -138 3 137 -156 3 156 -176 3 175 -196 3 194 -216 3 214 -234 3 235 -253 3 254 -268 3 271 -280 3 289 -291 3 304 -297 3 317 -297 3 333 -297 3 341 -289 3 341 -271 3 341 -265 3 339 -256 3 336 -244 3 330 -228 3 322 -211 3 313 -196 3 304 -180 3 295 -164 3 288 -146 3 275 -115 3 268 -90 3 266 -70 3 265 -68 3 265 -65 3 265 -63 3 265 -60 3 265 -58 3 265 -55 3 265 -29 3 274 -15 3 292 -15 3 302 -15 3 315 -21 3 332 -33 3 349 -45 3 366 -60 3 383 -76 3 401 -93 3 417 -109 3 431 -125 3 445 -140 3 455 -152 3 460 -160 3 462 -162 3 464 -163 3 466 -163 3 469 -163 3 471 -162 3 472 -160 3 474 -158 3 474 -156 3 473 -152 3 467 -141 3 457 -127 3 442 -110 3 428 -93 3 412 -76 3 395 -59 3 378 -42 3 361 -27 3 344 -15 3 334 -9 3 322 -3 3 307 3 3 292 8 3 278 10 3 263 10 3 244 8 3 231 1 3 223 -10 3 215 -21 3 211 -34 3 211 -49 3 211 -67 3 214 -86 3 221 -107 3 228 -127 3 236 -146 3 245 -164 3 254 -182 3 261 -196 3 266 -205 3 271 -216 3 274 -224 3 274 -230 3 274 -236 3 272 -238 3 267 -238 3 262 -238 3 255 -235 3 246 -229 3 237 -223 3 224 -213 3 208 -198 3 193 -186 3 178 -169 3 161 -149 3 144 -128 3 128 -108 3 112 -86 3 97 -65 3 83 -47 3 71 -31 3 60 -16 3 52 -7 3 47 -4 3 44 -2 3 36 1 3 24 6 3 13 10 3 4 13 3 -2 13 163 522 11 0 503 11 3 487 6 3 473 -2 3 449 -16 3 438 -42 3 438 -78 3 438 -94 3 440 -111 3 446 -131 3 450 -148 3 459 -166 3 471 -186 3 483 -205 3 497 -224 3 513 -242 3 530 -260 3 547 -275 3 567 -286 3 586 -298 3 605 -303 3 625 -303 3 633 -303 3 640 -302 3 646 -300 3 654 -298 3 661 -293 3 666 -286 3 672 -279 3 675 -270 3 675 -259 3 675 -248 3 672 -242 3 666 -240 3 661 -239 3 658 -240 3 658 -244 3 658 -246 3 658 -247 3 658 -248 3 659 -250 3 659 -251 3 659 -251 3 659 -257 3 657 -261 3 654 -266 3 651 -270 3 646 -272 3 638 -272 3 627 -272 3 614 -267 3 598 -255 3 583 -244 3 567 -229 3 550 -210 3 534 -191 3 520 -170 3 507 -147 3 495 -125 3 487 -102 3 483 -79 3 482 -76 3 482 -73 3 481 -70 3 481 -67 3 481 -64 3 481 -60 3 481 -45 3 484 -32 3 491 -22 3 498 -11 3 509 -6 3 525 -6 3 543 -6 3 561 -13 3 579 -28 3 596 -42 3 612 -59 3 625 -79 3 639 -99 3 649 -117 3 656 -132 3 661 -144 3 665 -155 3 667 -163 3 669 -172 3 670 -179 3 670 -185 3 670 -191 3 669 -195 3 668 -199 3 667 -203 3 666 -207 3 665 -209 3 663 -213 3 663 -216 3 663 -218 3 663 -224 3 665 -228 3 669 -231 3 674 -235 3 678 -236 3 683 -236 3 687 -236 3 691 -235 3 696 -232 3 701 -231 3 708 -230 3 718 -229 3 727 -229 3 737 -228 3 748 -228 3 759 -228 3 771 -229 3 782 -229 3 794 -230 3 804 -231 3 813 -233 3 814 -234 3 816 -234 3 819 -234 3 823 -234 3 826 -233 3 826 -230 3 826 -228 3 823 -225 3 819 -223 3 795 -213 3 775 -207 3 756 -206 3 738 -206 3 722 -205 3 709 -205 3 710 -189 3 706 -171 3 698 -152 3 689 -133 3 680 -116 3 671 -101 3 659 -85 3 646 -68 3 632 -50 3 617 -33 3 601 -18 3 583 -7 3 565 5 3 544 11 3 522 11 163 909 11 0 897 13 3 885 14 3 873 14 3 844 14 3 819 7 3 800 -7 3 781 -21 3 771 -42 3 771 -68 3 771 -84 3 776 -104 3 785 -126 3 792 -142 3 804 -159 3 822 -179 3 840 -199 3 861 -219 3 885 -238 3 909 -257 3 933 -272 3 958 -285 3 983 -297 3 1005 -303 3 1025 -303 3 1032 -303 3 1039 -302 3 1045 -300 3 1052 -298 3 1059 -294 3 1064 -289 3 1069 -285 3 1072 -278 3 1072 -268 3 1072 -266 3 1072 -264 3 1072 -262 3 1072 -260 3 1071 -258 3 1070 -255 3 1070 -253 3 1068 -249 3 1065 -242 3 1062 -236 3 1059 -230 3 1055 -225 3 1052 -220 3 1049 -219 3 1046 -221 3 1043 -223 3 1042 -226 3 1042 -229 3 1042 -233 3 1043 -236 3 1044 -241 3 1046 -245 3 1047 -249 3 1047 -252 3 1047 -257 3 1046 -261 3 1043 -266 3 1041 -270 3 1037 -272 3 1032 -272 3 1019 -272 3 1003 -267 3 983 -255 3 963 -244 3 942 -229 3 921 -210 3 900 -191 3 882 -170 3 865 -147 3 848 -125 3 837 -102 3 830 -79 3 828 -74 3 827 -69 3 826 -64 3 825 -59 3 825 -54 3 825 -49 3 825 -35 3 830 -24 3 839 -18 3 849 -11 3 861 -8 3 875 -8 3 890 -8 3 906 -11 3 922 -15 3 967 -29 3 1004 -47 3 1032 -70 3 1061 -94 3 1089 -124 3 1118 -160 3 1121 -164 3 1123 -165 3 1125 -164 3 1127 -164 3 1129 -163 3 1130 -163 3 1132 -163 3 1133 -161 3 1133 -157 3 1133 -156 3 1133 -154 3 1132 -152 3 1131 -150 3 1131 -149 3 1130 -147 3 1101 -109 3 1070 -75 3 1035 -46 3 1000 -17 3 958 2 3 909 11 163 1111 13 0 1106 13 3 1104 10 3 1107 6 3 1108 2 3 1112 -8 3 1117 -24 3 1123 -40 3 1130 -60 3 1138 -82 3 1146 -105 3 1154 -128 3 1163 -152 3 1172 -175 3 1180 -197 3 1187 -215 3 1182 -209 3 1175 -201 3 1165 -189 3 1156 -178 3 1146 -166 3 1135 -153 3 1124 -141 3 1114 -130 3 1105 -120 3 1103 -118 3 1102 -117 3 1101 -117 3 1099 -117 3 1098 -119 3 1098 -123 3 1098 -131 3 1100 -139 3 1104 -145 3 1119 -164 3 1133 -181 3 1146 -198 3 1160 -214 3 1173 -230 3 1184 -244 3 1177 -248 3 1174 -253 3 1174 -259 3 1174 -269 3 1179 -273 3 1188 -273 3 1192 -273 3 1195 -273 3 1197 -271 3 1198 -271 3 1198 -270 3 1199 -270 3 1200 -270 3 1200 -270 3 1201 -268 3 1204 -273 3 1207 -277 3 1209 -281 3 1212 -285 3 1214 -290 3 1216 -294 3 1219 -300 3 1224 -312 3 1232 -329 3 1241 -346 3 1251 -366 3 1264 -389 3 1277 -413 3 1291 -437 3 1307 -462 3 1324 -487 3 1341 -510 3 1360 -532 3 1379 -553 3 1399 -571 3 1419 -584 3 1440 -598 3 1461 -604 3 1482 -604 3 1485 -604 3 1487 -604 3 1490 -604 3 1493 -603 3 1495 -603 3 1498 -602 3 1515 -599 3 1526 -593 3 1533 -585 3 1540 -576 3 1543 -567 3 1543 -555 3 1543 -547 3 1541 -539 3 1538 -530 3 1535 -521 3 1531 -512 3 1526 -503 3 1513 -480 3 1495 -456 3 1473 -433 3 1451 -409 3 1426 -386 3 1399 -363 3 1372 -340 3 1345 -317 3 1318 -296 3 1291 -274 3 1266 -254 3 1243 -234 3 1227 -200 3 1215 -170 3 1206 -144 3 1197 -117 3 1191 -96 3 1186 -80 3 1193 -90 3 1204 -103 3 1219 -120 3 1234 -138 3 1250 -156 3 1269 -176 3 1288 -196 3 1307 -215 3 1327 -234 3 1347 -252 3 1366 -267 3 1384 -279 3 1402 -290 3 1417 -296 3 1430 -296 3 1446 -296 3 1454 -288 3 1454 -271 3 1454 -255 3 1448 -238 3 1437 -218 3 1426 -199 3 1416 -183 3 1409 -169 3 1400 -150 3 1392 -131 3 1386 -114 3 1381 -96 3 1377 -82 3 1376 -70 3 1375 -68 3 1375 -65 3 1375 -63 3 1375 -60 3 1375 -58 3 1375 -55 3 1375 -29 3 1384 -15 3 1403 -15 3 1413 -15 3 1426 -21 3 1443 -33 3 1460 -45 3 1477 -60 3 1494 -76 3 1511 -93 3 1527 -109 3 1541 -125 3 1556 -140 3 1566 -152 3 1571 -160 3 1573 -162 3 1575 -163 3 1578 -163 3 1581 -163 3 1583 -162 3 1584 -160 3 1585 -158 3 1585 -156 3 1584 -152 3 1577 -141 3 1567 -127 3 1553 -110 3 1539 -93 3 1523 -76 3 1506 -59 3 1489 -42 3 1472 -27 3 1455 -15 3 1446 -9 3 1435 -3 3 1421 2 3 1408 7 3 1394 10 3 1381 10 3 1370 10 3 1360 7 3 1350 2 3 1340 -4 3 1333 -14 3 1328 -28 3 1326 -34 3 1325 -43 3 1325 -53 3 1325 -57 3 1325 -60 3 1325 -64 3 1325 -67 3 1325 -71 3 1326 -75 3 1329 -97 3 1336 -119 3 1347 -143 3 1359 -166 3 1370 -188 3 1380 -206 3 1383 -212 3 1385 -216 3 1386 -220 3 1388 -224 3 1389 -228 3 1389 -230 3 1389 -236 3 1387 -238 3 1382 -238 3 1377 -238 3 1370 -235 3 1360 -229 3 1350 -223 3 1337 -213 3 1320 -198 3 1305 -186 3 1290 -169 3 1273 -149 3 1257 -128 3 1241 -108 3 1225 -86 3 1210 -65 3 1196 -47 3 1184 -31 3 1173 -16 3 1165 -7 3 1160 -4 3 1157 -2 3 1149 1 3 1137 6 3 1125 10 3 1116 13 3 1111 13 131 1262 -279 0 1289 -297 3 1318 -320 3 1349 -347 3 1380 -374 3 1410 -403 3 1437 -434 3 1465 -465 3 1486 -494 3 1501 -522 3 1509 -538 3 1513 -550 3 1513 -560 3 1513 -572 3 1508 -577 3 1498 -577 3 1493 -577 3 1488 -576 3 1482 -574 3 1476 -571 3 1469 -567 3 1461 -561 3 1416 -527 3 1379 -485 3 1348 -438 3 1317 -390 3 1289 -337 3 1262 -279 163";
    const float NOCH_ADVANCE = 151.8f;

    static GraphicsPath BuildNoch()
    {
        string[] v = NOCH.Split(' ');
        int n = v.Length / 3;
        PointF[] pts = new PointF[n]; byte[] types = new byte[n];
        for (int i = 0; i < n; i++) {
            pts[i] = new PointF(int.Parse(v[i * 3]) / 10f, int.Parse(v[i * 3 + 1]) / 10f);
            types[i] = byte.Parse(v[i * 3 + 2]);
        }
        return new GraphicsPath(pts, types, FillMode.Winding);
    }

    protected override CreateParams CreateParams
    {
        get { CreateParams cp = base.CreateParams; cp.Style |= 0x20000; cp.ClassStyle |= 0x20000; return cp; } // Minimieren + Schatten
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        try { int round = 2; DwmSetWindowAttribute(Handle, 33, ref round, 4); } catch { }   // runde Ecken ab Windows 11
    }

    // ---------- noch-da-Logik ----------
    static uint LastInput() { LASTINPUTINFO i = new LASTINPUTINFO(); i.cbSize = (uint)Marshal.SizeOf(i); GetLastInputInfo(ref i); return i.dwTime; }
    static uint IdleMs() { return unchecked((uint)Environment.TickCount - LastInput()); }

    static void MoveTo(int x, int y)
    {
        int l = GetSystemMetrics(76), t = GetSystemMetrics(77), w = GetSystemMetrics(78), h = GetSystemMetrics(79);
        int nx = (int)(((x - l) * 2L + 1) * 32768L / Math.Max(1, w));
        int ny = (int)(((y - t) * 2L + 1) * 32768L / Math.Max(1, h));
        mouse_event(0x0001 | 0x8000 | 0x4000, nx, ny, 0, UIntPtr.Zero);
    }

    void Step()
    {
        angle += 2 * Math.PI / STEPS;
        if (angle >= 2 * Math.PI) { angle -= 2 * Math.PI; rounds++; }
        MoveTo((int)Math.Round(cx + RADIUS * Math.Cos(angle)), (int)Math.Round(cy + RADIUS * Math.Sin(angle)));
        ourTick = LastInput();
    }

    // Virtual Wiggle: Mausbewegung um 0 Pixel - Windows zaehlt sie als Aktivitaet, der Zeiger bleibt stehen
    void Pulse() { mouse_event(0x0001, 0, 0, 0, UIntPtr.Zero); rounds++; }

    void Tick(object sender, EventArgs e)
    {
        int autoMin = AUTO[autoIdx];
        if (autoMin > 0 && watch.Elapsed.TotalMinutes >= autoMin) {
            state = 0; Halt(); autoStopped = true; Invalidate(); return;
        }
        if (virtualMode) {
            circling = false;
            if (IdleMs() >= (uint)idleSec * 1000) { Pulse(); Invalidate(); }
        }
        else if (circling) {
            if (LastInput() != ourTick) { circling = false; Invalidate(); }   // echte Eingabe -> aufhoeren
            else Step();
        } else if (IdleMs() >= (uint)idleSec * 1000) {
            POINT p; GetCursorPos(out p);
            cx = p.X - RADIUS; cy = p.Y; angle = 0; circling = true;
            Step(); Invalidate();
        }
        if (++uiTick >= 15) { uiTick = 0; SetThreadExecutionState(ES_AWAKE); Invalidate(); }
    }

    void Play()  { if (state == 0) { watch.Reset(); rounds = 0; } autoStopped = false; state = 1; watch.Start(); SetThreadExecutionState(ES_AWAKE); timer.Start(); Invalidate(); }
    void Halt()  { timer.Stop(); circling = false; watch.Stop(); SetThreadExecutionState(ES_CONT); }
    void Pause() { state = 2; Halt(); Invalidate(); }
    void Stop()  { state = 0; Halt(); watch.Reset(); rounds = 0; autoStopped = false; Invalidate(); }

    protected override void OnFormClosing(FormClosingEventArgs e) { Halt(); base.OnFormClosing(e); }

    int StepSize(int v) { return v < 60 ? 5 : (v < 300 ? 15 : 60); }

    // ---------- Maus ----------
    PointF L(Point p) { return new PointF(p.X / S, p.Y / S); }
    static float Dist(PointF a, PointF b) { return (float)Math.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Y - b.Y) * (a.Y - b.Y)); }

    string Hit(PointF p)
    {
        if (rClose.Contains(p)) return "close";
        if (rMin.Contains(p)) return "min";
        if (Dist(p, cPlay) <= RBIG && state != 1) return "play";
        if (Dist(p, cPause) <= RSMALL && state == 1) return "pause";
        if (Dist(p, cStop) <= RSMALL && state != 0) return "stop";
        if (rMinus.Contains(p)) return "minus";
        if (rPlus.Contains(p)) return "plus";
        if (rAutoMinus.Contains(p)) return "aminus";
        if (rAutoPlus.Contains(p)) return "aplus";
        if (rVirtRow.Contains(p)) return "virt";
        if (rTopRow.Contains(p)) return "top";
        return "";
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        string h = Hit(L(e.Location));
        Cursor = h != "" ? Cursors.Hand : Cursors.Default;
        if (h != hover) { hover = h; Invalidate(); }
    }
    protected override void OnMouseLeave(EventArgs e) { hover = ""; Invalidate(); }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        PointF p = L(e.Location);
        if (e.Button == MouseButtons.Left && p.Y < 64 && Hit(p) == "") {   // Kopfzeile = Fenster verschieben
            ReleaseCapture(); SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero);
        }
    }

    protected override void OnMouseClick(MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        switch (Hit(L(e.Location))) {
            case "close": Close(); break;
            case "min":   WindowState = FormWindowState.Minimized; break;
            case "play":  Play(); break;
            case "pause": Pause(); break;
            case "stop":  Stop(); break;
            case "minus": idleSec = Math.Max(5, idleSec - StepSize(idleSec - 1)); Invalidate(); break;
            case "plus":  idleSec = Math.Min(3600, idleSec + StepSize(idleSec)); Invalidate(); break;
            case "top":   onTop = !onTop; TopMost = onTop; Invalidate(); break;
            case "virt":  virtualMode = !virtualMode; circling = false; rounds = 0; Invalidate(); break;
            case "aminus": autoIdx = Math.Max(0, autoIdx - 1); Invalidate(); break;
            case "aplus":  autoIdx = Math.Min(AUTO.Length - 1, autoIdx + 1); Invalidate(); break;
        }
    }

    // ---------- Zeichnen ----------
    static GraphicsPath RR(RectangleF r, float rad)
    {
        GraphicsPath p = new GraphicsPath(); float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure(); return p;
    }

    // noch-digitaler "N" mit Pixeln, nachgezeichnet nach dem Logo (Box 100x100)
    static void DrawLogo(Graphics g, float x, float y, float size, Color c, Color bg)
    {
        GraphicsState st = g.Save();
        g.TranslateTransform(x, y); g.ScaleTransform(size / 100f, size / 100f);
        using (Pen p = new Pen(c, 18.5f)) {
            p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; p.LineJoin = LineJoin.Round;
            g.DrawLines(p, new PointF[] { new PointF(33.7f, 85.5f), new PointF(33.7f, 15f), new PointF(91f, 85.5f), new PointF(91f, 15f) });
        }
        using (SolidBrush b = new SolidBrush(c)) {
            float[][] px = { new float[]{11,18.7f,3.8f,4}, new float[]{19,25.5f,5.5f,5.5f}, new float[]{0,33,3.8f,3.8f}, new float[]{13.7f,35.5f,4.7f,4.7f},
                             new float[]{4.8f,45.4f,3.8f,3.8f}, new float[]{19,45.2f,5.3f,5.3f}, new float[]{11,50.5f,3.8f,3.8f}, new float[]{0,56.7f,3.8f,3.8f},
                             new float[]{18.9f,56,5.3f,5.3f}, new float[]{11,64.6f,3.8f,3.8f}, new float[]{18.9f,67,5.3f,5.3f} };
            foreach (float[] r in px) g.FillRectangle(b, r[0], r[1], r[2], r[3]);
        }
        using (SolidBrush b = new SolidBrush(bg)) {
            // bei transparentem Hintergrund (Icon) die Luecken wirklich ausstanzen statt zu uebermalen
            if (bg.A < 255) g.CompositingMode = CompositingMode.SourceCopy;
            float[][] holes = { new float[]{24.4f,25.5f,5.6f,5.5f}, new float[]{28.3f,36.9f,3.8f,3.8f}, new float[]{24.4f,45.2f,3.9f,5.3f},
                                new float[]{24.4f,56,3.9f,5.3f}, new float[]{32,56,3.7f,3.7f}, new float[]{24.4f,67,5.6f,5.5f} };
            foreach (float[] r in holes) g.FillRectangle(b, r[0], r[1], r[2], r[3]);
        }
        g.Restore(st);
    }

    // Icon-Datei (.ico) aus dem gezeichneten N erzeugen: mehrere Groessen, je als PNG, transparenter Hintergrund
    public static byte[] BuildIcon()
    {
        int[] sizes = { 16, 20, 24, 32, 40, 48, 64, 128, 256 };
        byte[][] pngs = new byte[sizes.Length][];
        for (int i = 0; i < sizes.Length; i++) {
            int s = sizes[i];
            using (Bitmap bmp = new Bitmap(s, s, System.Drawing.Imaging.PixelFormat.Format32bppArgb))
            using (Graphics g = Graphics.FromImage(bmp))
            using (System.IO.MemoryStream ms = new System.IO.MemoryStream()) {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.Clear(Color.Transparent);
                DrawLogo(g, 0, 0, s, Teal, Color.Transparent);
                bmp.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                pngs[i] = ms.ToArray();
            }
        }
        using (System.IO.MemoryStream o = new System.IO.MemoryStream())
        using (System.IO.BinaryWriter w = new System.IO.BinaryWriter(o)) {
            w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)sizes.Length);
            int off = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++) {
                byte dim = (byte)(sizes[i] >= 256 ? 0 : sizes[i]);
                w.Write(dim); w.Write(dim); w.Write((byte)0); w.Write((byte)0);
                w.Write((ushort)1); w.Write((ushort)32); w.Write((uint)pngs[i].Length); w.Write((uint)off);
                off += pngs[i].Length;
            }
            foreach (byte[] p in pngs) w.Write(p);
            w.Flush();
            return o.ToArray();
        }
    }

    static float Ascent(Font f)
    {
        FontFamily ff = f.FontFamily;
        return f.Size * ff.GetCellAscent(f.Style) / ff.GetEmHeight(f.Style);
    }

    void CircleButton(Graphics g, PointF c, float r, string kind, bool enabled, bool primary)
    {
        bool hov = hover == kind;
        RectangleF rc = new RectangleF(c.X - r, c.Y - r, r * 2, r * 2);
        Color icon;
        if (primary) {
            using (SolidBrush b = new SolidBrush(!enabled ? TealSoft : (hov ? TealDark : Teal))) g.FillEllipse(b, rc);
            icon = Color.White;
        } else {
            using (SolidBrush b = new SolidBrush(hov ? Card : Color.White)) g.FillEllipse(b, rc);
            using (Pen p = new Pen(hov ? Teal : Line, 1.5f)) g.DrawEllipse(p, rc);
            icon = enabled ? Ink : Disabled;
        }
        using (SolidBrush b = new SolidBrush(icon)) {
            if (kind == "play") {
                g.FillPolygon(b, new PointF[] { new PointF(c.X - r * 0.22f, c.Y - r * 0.36f), new PointF(c.X - r * 0.22f, c.Y + r * 0.36f), new PointF(c.X + r * 0.38f, c.Y) });
            } else if (kind == "pause") {
                float bw = r * 0.2f, bh = r * 0.72f, gap = r * 0.16f;
                using (GraphicsPath p1 = RR(new RectangleF(c.X - gap - bw, c.Y - bh / 2, bw, bh), 1.5f)) g.FillPath(b, p1);
                using (GraphicsPath p2 = RR(new RectangleF(c.X + gap, c.Y - bh / 2, bw, bh), 1.5f)) g.FillPath(b, p2);
            } else {
                float s = r * 0.62f;
                using (GraphicsPath p = RR(new RectangleF(c.X - s / 2, c.Y - s / 2, s, s), 2.5f)) g.FillPath(b, p);
            }
        }
        StringFormat sf = new StringFormat(); sf.Alignment = StringAlignment.Center;
        string label = kind == "play" ? "Play" : (kind == "pause" ? "Pause" : "Stopp");
        using (SolidBrush b = new SolidBrush(enabled ? Muted : Disabled)) g.DrawString(label, fLabel, b, c.X, c.Y + RBIG + 8, sf);
    }

    void SmallRound(Graphics g, RectangleF r, string kind, bool plus)
    {
        bool hov = hover == kind;
        using (SolidBrush b = new SolidBrush(hov ? Card : Color.White)) g.FillEllipse(b, r);
        using (Pen p = new Pen(hov ? Teal : Line, 1.2f)) g.DrawEllipse(p, r);
        using (Pen p = new Pen(Ink, 1.6f)) {
            float mx = r.X + r.Width / 2, my = r.Y + r.Height / 2;
            g.DrawLine(p, mx - 5, my, mx + 5, my);
            if (plus) g.DrawLine(p, mx, my - 5, mx, my + 5);
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        using (Pen bp = new Pen(Line)) g.DrawRectangle(bp, 0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
        g.ScaleTransform(S, S);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        StringFormat center = new StringFormat(); center.Alignment = StringAlignment.Center; center.LineAlignment = StringAlignment.Center;

        // Kopfzeile: Logo + Wortmarke
        // beide Schriften auf dieselbe Grundlinie setzen (Abstand Oberkante -> Grundlinie = Ascent)
        const float baseline = 40;
        DrawLogo(g, 20, 21, 21, Teal, Color.White);
        StringFormat typo = StringFormat.GenericTypographic;
        const float nochSize = 30f;   // wie 30 px Schriftgroesse
        GraphicsState gs = g.Save();
        g.TranslateTransform(48, baseline); g.ScaleTransform(nochSize / 100f, nochSize / 100f);
        using (SolidBrush b = new SolidBrush(Teal)) g.FillPath(b, nochPath);
        g.Restore(gs);
        float wNoch = NOCH_ADVANCE * nochSize / 100f;
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString("-digitaler", fBrand, b, 50 + wNoch, baseline - Ascent(fBrand), typo);

        foreach (string k in new string[] { "min", "close" }) {
            RectangleF r = k == "min" ? rMin : rClose;
            if (hover == k) using (SolidBrush b = new SolidBrush(Card)) using (GraphicsPath p = RR(r, 7)) g.FillPath(b, p);
            using (Pen p = new Pen(hover == k ? Ink : Muted, 1.4f)) {
                float mx = r.X + 14, my = r.Y + 14;
                if (k == "min") g.DrawLine(p, mx - 5, my, mx + 5, my);
                else { g.DrawLine(p, mx - 5, my - 5, mx + 5, my + 5); g.DrawLine(p, mx - 5, my + 5, mx + 5, my - 5); }
            }
        }
        using (Pen p = new Pen(Line)) g.DrawLine(p, 0, 64, W, 64);

        // Titel
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString("noch da", fTitle, b, 18, 78);
        using (SolidBrush b = new SolidBrush(Muted)) g.DrawString("Hält dich am Platz – ohne Installation.", fSub, b, 20, 105);

        // Statuskarte
        Color dot; string status;
        long rest = Math.Max(0, idleSec - (long)(IdleMs() / 1000));
        if (state == 1 && virtualMode) { dot = Teal; status = "Aktiv – unsichtbar, Impuls in " + rest + " s"; }
        else if (state == 1 && circling) { dot = TealDark; status = "Aktiv – Maus kreist"; }
        else if (state == 1) { dot = Teal; status = "Aktiv – kreist in " + rest + " s"; }
        else if (state == 2) { dot = Amber; status = "Pausiert"; }
        else if (autoStopped) { dot = Grey; status = "Automatisch gestoppt"; }
        else { dot = Grey; status = "Bereit"; }
        using (SolidBrush b = new SolidBrush(Card)) using (GraphicsPath p = RR(new RectangleF(20, 134, 320, 66), 12)) g.FillPath(b, p);
        if (state == 1) using (SolidBrush b = new SolidBrush(Color.FromArgb(50, dot))) g.FillEllipse(b, 32, 145, 16, 16);
        using (SolidBrush b = new SolidBrush(dot)) g.FillEllipse(b, 36, 149, 8, 8);
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString(status, fStatus, b, 54, 142);
        TimeSpan ts = watch.Elapsed;
        string unit = virtualMode ? (rounds == 1 ? "Impuls" : "Impulse") : (rounds == 1 ? "Runde" : "Runden");
        string sub = string.Format("{0:00}:{1:00}:{2:00}  ·  {3} {4}", (int)ts.TotalHours, ts.Minutes, ts.Seconds, rounds, unit);
        int autoMin = AUTO[autoIdx];
        if (autoMin > 0 && state != 0) {
            int left = (int)Math.Ceiling(autoMin - ts.TotalMinutes);
            sub += "  ·  Aus in " + (left < 60 ? left + " min" : (left / 60) + ":" + (left % 60).ToString("00") + " h");
        }
        using (SolidBrush b = new SolidBrush(Muted)) g.DrawString(sub, fSmall, b, 55, 167);

        // Einstellung: Wartezeit
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString(virtualMode ? "Impuls nach Inaktivität" : "Kreisen nach Inaktivität", fSub, b, 20, 220);
        SmallRound(g, rMinus, "minus", false);
        SmallRound(g, rPlus, "plus", true);
        string val = idleSec < 60 ? idleSec + " s" : (idleSec % 60 == 0 ? (idleSec / 60) + " min" : (idleSec / 60) + ":" + (idleSec % 60).ToString("00") + " min");
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString(val, fStatus, b, new RectangleF(258, 216, 56, 26), center);

        // Einstellung: Virtual Wiggle
        Toggle(g, "Unsichtbar (Zeiger bleibt stehen)", 252, virtualMode, "virt");

        // Einstellung: Auto-Aus
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString("Automatisch stoppen nach", fSub, b, 20, 292);
        SmallRound(g, rAutoMinus, "aminus", false);
        SmallRound(g, rAutoPlus, "aplus", true);
        string aval = autoMin == 0 ? "Aus" : (autoMin < 60 ? autoMin + " min" : (autoMin % 60 == 0 ? (autoMin / 60) + " h" : (autoMin / 60) + ":" + (autoMin % 60).ToString("00") + " h"));
        using (SolidBrush b = new SolidBrush(autoMin == 0 ? Muted : Ink)) g.DrawString(aval, fStatus, b, new RectangleF(258, 288, 56, 26), center);

        // Einstellung: Vordergrund
        Toggle(g, "Immer im Vordergrund", 324, onTop, "top");

        using (Pen p = new Pen(Line)) g.DrawLine(p, 20, 360, 340, 360);

        // Steuerung
        CircleButton(g, cStop, RSMALL, "stop", state != 0, false);
        CircleButton(g, cPlay, RBIG, "play", state != 1, true);
        CircleButton(g, cPause, RSMALL, "pause", state == 1, false);

        using (SolidBrush b = new SolidBrush(Grey)) g.DrawString("noch-digitaler.de", fFooter, b, new RectangleF(0, 462, W, 16), center);
    }

    void Toggle(Graphics g, string text, float y, bool on, string key)
    {
        using (SolidBrush b = new SolidBrush(Ink)) g.DrawString(text, fSub, b, 20, y + 1);
        RectangleF tg = new RectangleF(300, y, 40, 22);
        bool hov = hover == key;
        using (SolidBrush b = new SolidBrush(on ? (hov ? TealDark : Teal) : (hov ? Disabled : Line))) using (GraphicsPath p = RR(tg, 11)) g.FillPath(b, p);
        using (SolidBrush b = new SolidBrush(Color.White)) g.FillEllipse(b, on ? tg.Right - 19 : tg.X + 3, tg.Y + 3, 16, 16);
    }
}
'@

Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $code
[void][NochDaForm]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- N-Icon + Verknuepfung "noch da" neben dieser Datei ----------
# Eine .cmd-Datei kann kein eigenes Icon haben. Deshalb legt das Skript eine Verknuepfung mit dem N-Icon an
# und passt sie an, falls der Ordner verschoben oder auf einen anderen PC kopiert wurde.
$self = $env:MJ_SELF
if ($self) {
    try {
        $here    = Split-Path -Parent $self
        $icoPath = Join-Path $here 'noch-digitaler-N.ico'
        $lnkPath = Join-Path $here 'noch da.lnk'
        if (-not (Test-Path $icoPath)) { [IO.File]::WriteAllBytes($icoPath, [NochDaForm]::BuildIcon()) }
        $sh = New-Object -ComObject WScript.Shell
        $ok = $false
        if (Test-Path $lnkPath) {
            $l  = $sh.CreateShortcut($lnkPath)
            $ok = $l.Arguments.Contains($self) -and $l.IconLocation.StartsWith($icoPath)
        }
        if (-not $ok) {
            $l = $sh.CreateShortcut($lnkPath)
            $l.TargetPath       = "$env:windir\System32\cmd.exe"
            $l.Arguments        = "/c `"`"$self`"`""
            $l.WorkingDirectory = $here
            $l.IconLocation     = "$icoPath,0"
            $l.WindowStyle      = 7
            $l.Description      = 'noch da by noch-digitaler.de'
            $l.Save()
        }
    } catch { }
}

[System.Windows.Forms.Application]::Run([NochDaForm]::new())
