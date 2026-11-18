#!/usr/bin/env python3
"""Clip Auto GTA 6 : crée automatiquement des clips Twitch quand le chat d'un gros live explose.

Fonctionnement :
  1. Toutes les 5 minutes, récupère les plus gros lives GTA VI (FR et/ou US) via l'API officielle Twitch.
  2. Lit leur chat en direct (lecture anonyme, comme un spectateur).
  3. Quand le chat s'emballe d'un coup (MDR, KEKW, 😂, « QUOI »…), crée un clip Twitch officiel avec TON compte.
  4. Écrit chaque clip dans mes_clips.html (à ouvrir dans le navigateur) avec les liens utiles.

Aucune dépendance : Python 3.9+ suffit. Lance LANCER.bat (Windows) ou `python clip_auto.py`.
"""
import collections
import datetime as dt
import html
import json
import os
import re
import socket
import ssl
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG = HERE / "config.json"
LOG_JSON = HERE / "mes_clips.json"
LOG_HTML = HERE / "mes_clips.html"

DEFAULTS = {
    "client_id": "hcypnzhse2127o5lhnxf8xzgfqrdnj",   # ID public de ton appli Twitch « radar-clips-thomas »
    "client_secret": "",                              # demandé au premier lancement, gardé sur ton PC uniquement
    "langues": ["fr", "en"],                          # fr = compte @vicecitoyen, en = compte @neonandwasted
    "lives_par_langue": 6,                            # nombre de lives surveillés par langue
    "chaines_en_plus": [],                            # ex. ["wankilstudio", "xqc"] : toujours surveillées si en live
    "jeu": "Grand Theft Auto VI",
    "sensibilite": 3.0,                               # le chat doit aller X fois plus vite que d'habitude
    "pause_entre_clips_sec": 150,                     # pas deux clips du même live à moins de 2 min 30
}

REDIRECT = "http://localhost"
FUNNY = re.compile(
    r"mdr|ptdr|xptdr|jpp|ahah|haha|hahaha|lol|lmao|lmfao|kekw|omegalul|lul|icant|\bw\b|wtf|quoi+\b|what+\b|"
    r"no way|noway|nooo+|ouf|incroyable|clip|clippe|clip it|😂|🤣|💀|😭|😱|🔥|pog|poggers",
    re.I)


# ---------------------------------------------------------------- utilitaires

def say(msg):
    stamp = dt.datetime.now().strftime("%H:%M:%S")
    try:
        print(f"[{stamp}] {msg}", flush=True)
    except UnicodeEncodeError:
        print(f"[{stamp}] {msg.encode('ascii', 'replace').decode()}", flush=True)


def load_config():
    cfg = dict(DEFAULTS)
    if CONFIG.exists():
        cfg.update(json.loads(CONFIG.read_text(encoding="utf-8")))
    return cfg


def save_config(cfg):
    CONFIG.write_text(json.dumps(cfg, indent=2, ensure_ascii=False), encoding="utf-8")


def http(method, url, headers=None, data=None):
    body = urllib.parse.urlencode(data).encode() if isinstance(data, dict) else data
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            txt = r.read().decode()
            return r.status, (json.loads(txt) if txt else {})
    except urllib.error.HTTPError as e:
        txt = e.read().decode(errors="replace")
        try:
            return e.code, json.loads(txt)
        except ValueError:
            return e.code, {"message": txt[:300]}


# ---------------------------------------------------------------- connexion Twitch (OAuth officiel)

def ask_secret(cfg):
    if cfg["client_secret"]:
        return
    print()
    print("Premier lancement : colle le SECRET CLIENT de ton appli Twitch « radar-clips-thomas »")
    print("(dev.twitch.tv/console -> Applications -> Gérer -> Secret client). Il reste sur ton PC.")
    cfg["client_secret"] = input("Secret client : ").strip()
    save_config(cfg)


def login_user(cfg):
    """Connexion à ton compte Twitch avec la page officielle (autorisation « créer des clips »)."""
    got = {}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "code" not in q and "error" not in q:   # favicon, etc.
                self.send_response(204)
                self.end_headers()
                return
            got["code"] = (q.get("code") or [None])[0]
            got["error"] = (q.get("error_description") or q.get("error") or [None])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "Connexion réussie ! Tu peux fermer cette page et revenir à Clip Auto." if got["code"] \
                else f"Connexion refusée : {got['error']}"
            self.wfile.write(f"<h2 style='font-family:sans-serif'>{html.escape(msg)}</h2>".encode())

        def log_message(self, *a):
            pass

    try:
        server = HTTPServer(("localhost", 80), Handler)
    except OSError as e:
        sys.exit(f"Impossible d'écouter sur http://localhost (port 80 occupé ?) : {e}")
    url = "https://id.twitch.tv/oauth2/authorize?" + urllib.parse.urlencode({
        "client_id": cfg["client_id"], "redirect_uri": REDIRECT, "response_type": "code", "scope": "clips:edit"})
    say("Ouverture de la page de connexion Twitch dans ton navigateur…")
    say("Si elle ne s'ouvre pas, copie ce lien dans ton navigateur :")
    print(url, flush=True)
    webbrowser.open(url)
    while "code" not in got:
        server.handle_request()
    server.server_close()
    if not got.get("code"):
        sys.exit(f"Connexion Twitch annulée : {got.get('error')}")
    st, tok = http("POST", "https://id.twitch.tv/oauth2/token", data={
        "client_id": cfg["client_id"], "client_secret": cfg["client_secret"], "code": got["code"],
        "grant_type": "authorization_code", "redirect_uri": REDIRECT})
    if st != 200:
        sys.exit(f"Twitch a refusé la connexion ({st}) : {tok}. Vérifie ton secret client dans config.json.")
    cfg["user_token"], cfg["refresh_token"] = tok["access_token"], tok.get("refresh_token", "")
    save_config(cfg)
    say("Compte Twitch connecté ✔")


def refresh_user(cfg):
    st, tok = http("POST", "https://id.twitch.tv/oauth2/token", data={
        "client_id": cfg["client_id"], "client_secret": cfg["client_secret"],
        "grant_type": "refresh_token", "refresh_token": cfg.get("refresh_token", "")})
    if st != 200:
        say("La connexion Twitch a expiré : reconnexion…")
        login_user(cfg)
        return
    cfg["user_token"], cfg["refresh_token"] = tok["access_token"], tok.get("refresh_token", cfg["refresh_token"])
    save_config(cfg)


def helix(cfg, method, path, params=None, retry=True):
    url = "https://api.twitch.tv/helix/" + path + ("?" + urllib.parse.urlencode(params, doseq=True) if params else "")
    st, data = http(method, url, {"Client-Id": cfg["client_id"], "Authorization": f"Bearer {cfg['user_token']}"})
    if st == 401 and retry:
        refresh_user(cfg)
        return helix(cfg, method, path, params, retry=False)
    return st, data


# ---------------------------------------------------------------- choix des lives à surveiller

def pick_channels(cfg):
    st, g = helix(cfg, "GET", "games", {"name": cfg["jeu"]})
    if st != 200 or not g.get("data"):
        say(f"Jeu « {cfg['jeu']} » introuvable sur Twitch ({st}).")
        return {}
    game_id = g["data"][0]["id"]
    chans = {}
    for lang in cfg["langues"]:
        st, s = helix(cfg, "GET", "streams", {"game_id": game_id, "language": lang, "first": cfg["lives_par_langue"]})
        for x in s.get("data", []):
            chans[x["user_login"]] = {"id": x["user_id"], "name": x["user_name"], "lang": lang,
                                      "viewers": x["viewer_count"]}
    if cfg["chaines_en_plus"]:
        st, s = helix(cfg, "GET", "streams", {"user_login": cfg["chaines_en_plus"], "first": 100})
        for x in s.get("data", []):
            chans.setdefault(x["user_login"], {"id": x["user_id"], "name": x["user_name"],
                                               "lang": x.get("language", ""), "viewers": x["viewer_count"]})
    return chans


# ---------------------------------------------------------------- détection des moments forts

class Detector:
    """Repère un pic dans le chat : beaucoup plus de messages que d'habitude, souvent des rires."""

    def __init__(self, sensitivity=3.0, cooldown=150, warmup=60):
        self.sens, self.cooldown, self.warmup = sensitivity, cooldown, warmup
        self.msgs = collections.defaultdict(collections.deque)   # chaîne -> (t, drôle?, texte)
        self.base = {}                                            # chaîne -> débit habituel (msg/s)
        self.joined, self.last_clip = {}, {}

    def join(self, chan, now):
        self.joined.setdefault(chan, now)

    def add(self, chan, text, now):
        self.msgs[chan].append((now, bool(FUNNY.search(text)), text))

    def check(self, chan, now, window=10):
        q = self.msgs[chan]
        while q and q[0][0] < now - 60:
            q.popleft()
        recent = [m for m in q if m[0] >= now - window]
        rate = len(recent) / window
        base = self.base.get(chan, rate)
        funny = sum(1 for m in recent if m[1]) / max(1, len(recent))
        ready = now - self.joined.get(chan, now) >= self.warmup
        cooled = now - self.last_clip.get(chan, -1e9) >= self.cooldown
        spike = ready and cooled and len(recent) >= 12 and (
            (rate >= self.sens * max(base, 0.3) and funny >= 0.25) or rate >= 2 * self.sens * max(base, 0.3))
        if not spike:   # le débit habituel n'apprend que hors des pics
            self.base[chan] = base + (rate - base) / 120 if chan in self.base else rate
            return None
        self.last_clip[chan] = now
        words = collections.Counter(w.lower() for m in recent if m[1] for w in FUNNY.findall(m[2]))
        return {"rate": round(rate, 1), "base": round(base, 2), "funny": round(funny * 100),
                "top": [w for w, _ in words.most_common(3)]}


# ---------------------------------------------------------------- chat Twitch (lecture anonyme)

class Chat(threading.Thread):
    def __init__(self, on_msg):
        super().__init__(daemon=True)
        self.on_msg, self.wanted, self.joined, self.sock = on_msg, set(), set(), None
        self.lock = threading.Lock()

    def set_channels(self, chans):
        with self.lock:
            self.wanted = set(chans)

    def _send(self, line):
        self.sock.sendall((line + "\r\n").encode())

    def _sync(self):
        with self.lock:
            add, drop = self.wanted - self.joined, self.joined - self.wanted
        for c in drop:
            self._send(f"PART #{c}")
        for c in add:
            self._send(f"JOIN #{c}")
            time.sleep(0.6)   # Twitch limite les JOIN
        self.joined = set(self.wanted)

    def run(self):
        while True:
            try:
                raw = socket.create_connection(("irc.chat.twitch.tv", 6697), timeout=300)
                self.sock = ssl.create_default_context().wrap_socket(raw, server_hostname="irc.chat.twitch.tv")
                self._send("PASS SCHMOOPIIE")
                self._send(f"NICK justinfan{int(time.time()) % 100000}")
                self.joined = set()
                buf, last_sync = "", 0
                while True:
                    if time.time() - last_sync > 10:
                        self._sync()
                        last_sync = time.time()
                    self.sock.settimeout(10)
                    try:
                        chunk = self.sock.recv(65536).decode(errors="replace")
                    except socket.timeout:
                        continue
                    if not chunk:
                        raise ConnectionError("chat fermé")
                    buf += chunk
                    *lines, buf = buf.split("\r\n")
                    for ln in lines:
                        if ln.startswith("PING"):
                            self._send("PONG" + ln[4:])
                            continue
                        m = re.match(r"^:\S+ PRIVMSG #(\S+) :(.*)$", ln)
                        if m:
                            self.on_msg(m.group(1).lower(), m.group(2))
            except Exception as e:  # noqa: BLE001 - on se reconnecte quoi qu'il arrive
                say(f"Chat déconnecté ({e}), reconnexion dans 5 s…")
                time.sleep(5)


# ---------------------------------------------------------------- journal des clips

def load_log():
    try:
        return json.loads(LOG_JSON.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []


def write_log(items):
    LOG_JSON.write_text(json.dumps(items[-300:], ensure_ascii=False, indent=1), encoding="utf-8")
    rows = []
    for it in reversed(items[-300:]):
        flag = "🇫🇷 @vicecitoyen" if it["lang"] == "fr" else "🇺🇸 @neonandwasted"
        why = f"chat ×{it['rate'] / max(it['base'], 0.3):.0f} ({it['rate']} msg/s), {it['funny']} % de rires"
        top = ", ".join(it.get("top") or [])
        rows.append(f"""
<article><div class="t">{html.escape(it['time'])}</div><div class="b">
<h2>{html.escape(it['name'])} <span>{html.escape(flag)}</span></h2>
<p class="m">{html.escape(why)}{(' · ' + html.escape(top)) if top else ''}</p>
<p class="l"><a href="{html.escape(it['url'])}" target="_blank">▶ Voir le clip</a>
<a href="{html.escape(it['edit_url'])}" target="_blank">✏️ Ajuster le passage et le titre</a>
<a href="https://streamladder.com/" target="_blank">📱 Mettre en vertical (StreamLadder)</a>
<button onclick="navigator.clipboard.writeText('{html.escape(it['url'])}');this.textContent='Copié ✓'">Copier le lien</button></p>
</div></article>""")
    LOG_HTML.write_text(f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="20">
<title>Clip Auto GTA 6</title><style>
:root{{color-scheme:dark}}body{{margin:0;padding:20px 16px;background:#141019;color:#f1ecf5;font:15px/1.5 system-ui,sans-serif}}
main{{max-width:820px;margin:auto;display:grid;gap:12px}}h1{{margin:0 0 4px}}h1 b{{color:#ff5c8d}}
.sub{{color:#a79cb3;margin:0 0 8px}}article{{display:grid;grid-template-columns:5em 1fr;gap:14px;background:#1e1826;
border:1px solid #342b3f;border-radius:10px;padding:12px 14px}}.t{{font-weight:700;color:#ff5c8d}}
h2{{margin:0;font-size:1.05rem}}h2 span{{font-weight:500;color:#a79cb3;font-size:.85rem}}.m{{margin:4px 0;color:#a79cb3}}
.l{{display:flex;flex-wrap:wrap;gap:8px 16px;margin:6px 0 0}}a{{color:#3ccfc6;font-weight:600;text-decoration:none}}
button{{background:#ff5c8d;border:0;border-radius:6px;padding:4px 10px;font-weight:700;cursor:pointer}}
.empty{{color:#a79cb3;border:1px dashed #342b3f;border-radius:10px;padding:18px}}</style></head><body><main>
<h1>Clip Auto <b>GTA 6</b></h1><p class="sub">Clips créés automatiquement quand le chat explose. Page mise à jour toutes les 20 s.
Les clips Twitch font ~30 s : ajuste le passage avec ✏️ si besoin, puis mets-le en vertical.</p>
{''.join(rows) or '<p class="empty">Aucun clip pour l’instant : Clip Auto surveille les lives et créera un clip au prochain moment fort.</p>'}
</main></body></html>""", encoding="utf-8")


def create_clip(cfg, chan, info, stats, items):
    st, data = helix(cfg, "POST", "clips", {"broadcaster_id": info["id"]})
    if st not in (200, 202) or not data.get("data"):
        msg = (data or {}).get("message", "")
        say(f"  ✖ Clip refusé sur {info['name']} ({st}) {msg}")
        return
    clip = data["data"][0]
    item = {"time": dt.datetime.now().strftime("%H:%M"), "name": info["name"], "login": chan, "lang": info["lang"],
            "url": f"https://clips.twitch.tv/{clip['id']}", "edit_url": clip.get("edit_url", ""), **stats}
    items.append(item)
    write_log(items)
    say(f"  ✔ CLIP créé sur {info['name']} : {item['url']}")
    print("\a", end="", flush=True)   # petit bip


# ---------------------------------------------------------------- boucle principale

def main():
    cfg = load_config()
    print("=== Clip Auto GTA 6 ===")
    ask_secret(cfg)
    if not cfg.get("user_token"):
        login_user(cfg)
    items = load_log()
    write_log(items)
    say(f"Ouvre ce fichier dans ton navigateur pour voir les clips : {LOG_HTML}")
    webbrowser.open(LOG_HTML.as_uri())

    det = Detector(cfg["sensibilite"], cfg["pause_entre_clips_sec"])
    lock = threading.Lock()
    chans = {}

    def on_msg(chan, text):
        with lock:
            det.add(chan, text, time.time())

    chat = Chat(on_msg)
    chat.start()
    last_pick = 0
    while True:
        now = time.time()
        if now - last_pick > 300:
            try:
                fresh = pick_channels(cfg)
            except Exception as e:  # noqa: BLE001
                say(f"Liste des lives indisponible ({e}), nouvel essai dans 5 min.")
                fresh = chans
            if fresh:
                chans = fresh
                chat.set_channels(chans.keys())
                for c in chans:
                    det.join(c, now)
                say("Lives surveillés : " + ", ".join(f"{v['name']} ({v['lang']}, {v['viewers']} spect.)"
                                                    for v in chans.values()))
            last_pick = now
        for c, info in list(chans.items()):
            with lock:
                stats = det.check(c, now)
            if stats:
                say(f"Moment fort sur {info['name']} ! chat {stats['rate']} msg/s (habituel {stats['base']}), "
                    f"{stats['funny']} % de rires {stats['top']}")
                create_clip(cfg, c, info, stats, items)
        time.sleep(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nClip Auto arrêté. À bientôt !")
