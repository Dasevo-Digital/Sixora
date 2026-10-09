import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The page at `/`: tells visitors that this is a Sixora server and which
/// address to enter in the apps. Static HTML and CSS, no JavaScript, no
/// external resources; the Content-Security-Policy allows exactly the one
/// inline style block (by hash) and the inline SVG favicon.
class LandingPage {
  LandingPage(this.serverName);
  final String serverName;

  static final _styleHash = base64.encode(
    sha256.convert(utf8.encode(_css)).bytes,
  );

  static String get contentSecurityPolicy =>
      "default-src 'none'; style-src 'sha256-$_styleHash'; img-src data:; "
      "base-uri 'none'; form-action 'none'; frame-ancestors 'none'";

  String render({required String address}) {
    final name = _escape(serverName);
    final url = _escape(address);
    return '''<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="color-scheme" content="light dark">
<title>${serverName == 'Sixora' ? 'Sixora-Server' : '$name · Sixora'}</title>
<link rel="icon" href="data:image/svg+xml,${Uri.encodeComponent(_favicon)}">
<style>$_css</style>
</head>
<body>
<main>
  <div class="mark" aria-hidden="true">
    <svg viewBox="0 0 120 120">
      <defs>
        <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#818cf8"/>
          <stop offset="1" stop-color="#4338ca"/>
        </linearGradient>
      </defs>
      <circle class="track" cx="60" cy="60" r="56"/>
      <circle class="ring" cx="60" cy="60" r="56"/>
      <path class="shield" fill="url(#g)" d="M60 20 92 32v27c0 21-15 34-32 41C43 93 28 80 28 59V32Z"/>
      <g class="dots">
        <circle cx="47" cy="52" r="5"/><circle cx="60" cy="52" r="5"/><circle cx="73" cy="52" r="5"/>
        <circle cx="47" cy="68" r="5"/><circle cx="60" cy="68" r="5"/><circle cx="73" cy="68" r="5"/>
      </g>
    </svg>
  </div>
  <h1>Sixora</h1>
  <p class="status"><span class="pulse"></span>$name ist bereit</p>
  <p class="lead">Einmal-Codes für die Zwei-Faktor-Anmeldung, Ende-zu-Ende-verschlüsselt.
  Dieser Server speichert nur verschlüsselte Daten und kennt keine Geheimnisse.</p>
  <section>
    <h2>So geht es weiter</h2>
    <ol>
      <li>Die Sixora-App öffnen (Android, iOS, macOS, Windows, Linux).</li>
      <li>Diese Server-Adresse eingeben:<code>$url</code></li>
      <li>Anmelden – oder mit einem Einladungscode ein Konto erstellen.</li>
    </ol>
  </section>
  <footer>Die Codes entstehen auf deinen Geräten. Ohne dein Master-Passwort kann sie niemand lesen – auch nicht der Betreiber dieses Servers.</footer>
</main>
</body>
</html>
''';
  }

  static String _escape(String s) => const HtmlEscape().convert(s);

  static const _favicon =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
      '<rect width="64" height="64" rx="15" fill="#4f46e5"/>'
      '<path d="M32 11 49 17v14c0 11-8 18-17 22C23 49 15 42 15 31V17Z" fill="#fff"/>'
      '<g fill="#4338ca"><circle cx="25" cy="28" r="2.7"/><circle cx="32" cy="28" r="2.7"/>'
      '<circle cx="39" cy="28" r="2.7"/><circle cx="25" cy="37" r="2.7"/>'
      '<circle cx="32" cy="37" r="2.7"/><circle cx="39" cy="37" r="2.7"/></g></svg>';

  static const _css = '''
:root{--bg:#f5f5fb;--card:#fff;--text:#1e1b4b;--muted:#5b5b7a;--accent:#4f46e5;--line:#e4e4f0;--code:#eef0ff}
@media (prefers-color-scheme:dark){:root{--bg:#0d0c1d;--card:#17162b;--text:#ecebff;--muted:#a6a5c4;--accent:#a5b4fc;--line:#2a2946;--code:#221f45}}
*{box-sizing:border-box}
html,body{margin:0;min-height:100%}
body{font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:var(--text);
background:radial-gradient(1200px 600px at 50% -10%,rgba(99,102,241,.28),transparent 70%),var(--bg);
display:flex;align-items:center;justify-content:center;padding:32px 16px}
main{width:100%;max-width:560px;background:var(--card);border:1px solid var(--line);border-radius:28px;
padding:40px 32px 28px;text-align:center;box-shadow:0 30px 80px -40px rgba(67,56,202,.55);animation:rise .7s ease-out both}
.mark{width:132px;height:132px;margin:0 auto 12px}
.mark svg{width:100%;height:100%;overflow:visible}
.track{fill:none;stroke:var(--line);stroke-width:4}
.ring{fill:none;stroke:var(--accent);stroke-width:4;stroke-linecap:round;stroke-dasharray:352;
transform:rotate(-90deg);transform-origin:60px 60px;animation:countdown 30s linear infinite}
.shield{filter:drop-shadow(0 6px 10px rgba(67,56,202,.35))}
.dots circle{fill:#fff;opacity:.25;animation:digit 3s ease-in-out infinite}
.dots circle:nth-child(2){animation-delay:.15s}.dots circle:nth-child(3){animation-delay:.3s}
.dots circle:nth-child(4){animation-delay:.45s}.dots circle:nth-child(5){animation-delay:.6s}
.dots circle:nth-child(6){animation-delay:.75s}
h1{margin:4px 0 6px;font-size:2.2rem;letter-spacing:.02em}
.status{display:inline-flex;align-items:center;gap:8px;margin:0 0 18px;padding:6px 14px;border-radius:999px;
background:var(--code);color:var(--accent);font-weight:600;font-size:.95rem}
.pulse{width:10px;height:10px;border-radius:50%;background:#22c55e;box-shadow:0 0 0 0 rgba(34,197,94,.6);animation:pulse 2s infinite}
.lead{color:var(--muted);margin:0 auto 24px;max-width:440px}
section{text-align:left;border-top:1px solid var(--line);padding-top:20px}
h2{font-size:1rem;margin:0 0 10px}
ol{margin:0;padding-left:22px}
li{margin:6px 0}
code{display:block;margin:6px 0 2px;padding:10px 12px;border-radius:12px;background:var(--code);color:var(--accent);
font:600 .95rem ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;word-break:break-all;user-select:all}
footer{margin-top:24px;color:var(--muted);font-size:.85rem}
@keyframes countdown{from{stroke-dashoffset:0}to{stroke-dashoffset:352}}
@keyframes digit{0%,100%{opacity:.25;transform:translateY(0)}35%,65%{opacity:1;transform:translateY(-1.5px)}}
@keyframes pulse{70%{box-shadow:0 0 0 10px rgba(34,197,94,0)}100%{box-shadow:0 0 0 0 rgba(34,197,94,0)}}
@keyframes rise{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}
@media (prefers-reduced-motion:reduce){*{animation:none!important}.dots circle{opacity:1}}
''';
}
