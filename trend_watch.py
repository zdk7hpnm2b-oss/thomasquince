#!/usr/bin/env python3
"""Veille tendances GTA 6 : YouTube + Twitch.

Lance une passe de veille et écrit un rapport Markdown (reports/latest.md + reports/AAAA-MM-JJ_HHhMM.md).

Clés (jamais écrites dans ce fichier) :
  - YouTube : en-tête X-goog-api-key. Soit la variable YOUTUBE_API_KEY, soit injectée par le proxy de l'environnement cloud.
  - Twitch  : en-tête Authorization: Bearer <jeton d'application>. Soit TWITCH_APP_TOKEN, soit injecté par le proxy.
              + variable TWITCH_CLIENT_ID (identifiant public de l'application Twitch, pas secret).

Usage : python3 trend_watch.py [--hours 24] [--lang fr]
"""
import argparse
import datetime as dt
import json
import math
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

KEYWORDS = "GTA 6 | GTA VI"
TWITCH_GAME_NAMES = ["Grand Theft Auto VI", "GTA VI", "Grand Theft Auto 6"]
REPORT_DIR = Path(__file__).resolve().parent / "reports"


class ApiError(Exception):
    pass


def http_get(url, headers):
    req = urllib.request.Request(url, headers={"User-Agent": "trend-watch/1.0", **headers})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:400]
        raise ApiError(f"HTTP {e.code} sur {urllib.parse.urlsplit(url).netloc} : {body}") from None
    except urllib.error.URLError as e:
        raise ApiError(f"Hôte injoignable ({urllib.parse.urlsplit(url).netloc}) : {e.reason}") from None


def parse_iso_duration(s):
    import re
    m = re.fullmatch(r"P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", s or "")
    if not m:
        return 0
    d, h, mi, se = (int(x or 0) for x in m.groups())
    return d * 86400 + h * 3600 + mi * 60 + se


def fmt_num(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f} M".replace(".", ",")
    if n >= 1_000:
        return f"{n / 1_000:.0f} k" if n >= 10_000 else f"{n / 1_000:.1f} k".replace(".", ",")
    return str(int(n))


def fmt_dur(sec):
    sec = int(sec)
    h, m, s = sec // 3600, sec % 3600 // 60, sec % 60
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


# ---------------- YouTube ----------------

def yt(endpoint, **params):
    key = os.environ.get("YOUTUBE_API_KEY", "proxy-injected")
    if key == "proxy-injected" and not os.environ.get("CCR_AGENT_PROXY_ENABLED"):
        raise ApiError("YouTube pas encore connecté : il manque YOUTUBE_API_KEY dans les réglages de l'environnement.")
    url = "https://www.googleapis.com/youtube/v3/" + endpoint + "?" + urllib.parse.urlencode(
        {k: v for k, v in params.items() if v not in (None, "")})
    try:
        return http_get(url, {"X-goog-api-key": key})
    except ApiError as e:
        if "API key not valid" in str(e) or "API_KEY_INVALID" in str(e):
            raise ApiError("Clé YouTube absente ou invalide : ajoute YOUTUBE_API_KEY dans les réglages de l'environnement « thomasquince ».") from None
        if "quotaExceeded" in str(e):
            raise ApiError("Quota YouTube du jour dépassé : la veille reprend après 9 h (heure de Paris).") from None
        raise


def youtube_trends(hours, lang):
    after = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
    region = "FR" if lang == "fr" else ""
    ids, live_ids = [], set()
    # 1) vidéos publiées récemment, triées par vues ; 2) lives en cours. ~200 unités de quota au total.
    for extra in ({"order": "viewCount", "publishedAfter": after}, {"order": "viewCount", "eventType": "live"}):
        data = yt("search", part="id", type="video", q=KEYWORDS, maxResults=50,
                  relevanceLanguage=lang, regionCode=region, **extra)
        for it in data.get("items", []):
            vid = it["id"]["videoId"]
            if vid not in ids:
                ids.append(vid)
            if extra.get("eventType") == "live":
                live_ids.add(vid)
    if not ids:
        return []
    data = {"items": []}
    for i in range(0, min(len(ids), 100), 50):
        part = yt("videos", part="snippet,statistics,contentDetails,liveStreamingDetails", id=",".join(ids[i:i + 50]))
        data["items"] += part.get("items", [])
    now = dt.datetime.now(dt.timezone.utc)
    out = []
    for it in data.get("items", []):
        sn, st = it["snippet"], it.get("statistics", {})
        if sn.get("liveBroadcastContent") == "upcoming":
            continue
        dur = parse_iso_duration(it.get("contentDetails", {}).get("duration"))
        if sn.get("liveBroadcastContent") != "live" and 0 < dur <= 70:
            continue  # Shorts : rien à clipper
        published = dt.datetime.fromisoformat(sn["publishedAt"].replace("Z", "+00:00"))
        age_h = max(1.0, (now - published).total_seconds() / 3600)
        views = int(st.get("viewCount", 0))
        likes = int(st.get("likeCount", 0))
        comments = int(st.get("commentCount", 0))
        live = sn.get("liveBroadcastContent") == "live"
        watching = int(it.get("liveStreamingDetails", {}).get("concurrentViewers", 0) or 0)
        out.append({
            "id": it["id"], "title": sn["title"], "channel": sn["channelTitle"],
            "channelId": sn.get("channelId", ""),
            "thumb": (sn.get("thumbnails", {}).get("medium") or sn.get("thumbnails", {}).get("default") or {}).get("url", ""),
            "url": f"https://www.youtube.com/watch?v={it['id']}",
            "age_h": age_h, "views": views, "likes": likes, "comments": comments,
            "velocity": views / age_h, "live": live, "watching": watching,
            "duration": parse_iso_duration(it.get("contentDetails", {}).get("duration")),
            "engagement": (likes + 3 * comments) / views if views else 0,
        })
    # Score : vitesse (vues/heure, échelle log) pondérée par l'engagement ; un live en cours compte ses spectateurs.
    for v in out:
        base = v["watching"] * 6 if v["live"] else v["velocity"]
        v["score"] = math.log10(1 + base) * (1 + min(v["engagement"], 0.2) * 5)
    out.sort(key=lambda v: v["score"], reverse=True)
    return out


# ---------------- Temps forts (horodatages dans les commentaires) ----------------

TS_RE = __import__("re").compile(r"(?<![\d:])(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?![\d:])")
FUNNY_RE = __import__("re").compile(
    r"mdr|ptdr|jpp|😂|🤣|💀|😭|mort de rire|incroyable|l[ée]gendaire|meilleur moment|wtf|culte|j'ai pleur|jsuis mort|je suis mort",
    __import__("re").I)


def extract_timestamps(text, max_sec):
    out = []
    for m in TS_RE.finditer(text):
        h = int(m.group(1)) if m.group(1) else 0
        mi, se = int(m.group(2)), int(m.group(3))
        if se >= 60 or (m.group(1) and mi >= 60):
            continue
        t = h * 3600 + mi * 60 + se
        if max_sec and t > max_sec:
            continue
        if t not in out:
            out.append(t)
    return out


def find_moments(comments, max_sec, gap=20):
    hits = []
    for c in comments:
        w = (1 + math.log2(1 + c["likes"])) * (1.5 if FUNNY_RE.search(c["text"]) else 1)
        for t in extract_timestamps(c["text"], max_sec):
            hits.append((t, w, c))
    hits.sort(key=lambda h: h[0])
    groups = []
    for h in hits:
        if groups and h[0] - groups[-1]["first"] <= gap:
            groups[-1]["items"].append(h)
            groups[-1]["last"] = h[0]
        else:
            groups.append({"first": h[0], "last": h[0], "items": [h]})
    out = []
    for g in groups:
        best = max(g["items"], key=lambda i: i[2]["likes"])[2]
        start = max(0, g["first"] - 5)
        end = max(g["last"] + 25, start + 30)
        if max_sec:
            end = min(end, max_sec)
        out.append({"start": start, "end": end, "at": g["first"],
                    "mentions": len({i[2]["author"] for i in g["items"]}),
                    "weight": round(sum(i[1] for i in g["items"]), 2),
                    "quote": best["text"][:240], "likes": best["likes"]})
    return sorted(out, key=lambda m: m["weight"], reverse=True)


def youtube_moments(videos, top=5):
    """Lit jusqu'à 200 commentaires des `top` meilleures vidéos (hors lives) et renvoie les meilleurs moments."""
    allm = []
    for v in [v for v in videos if not v["live"] and v["comments"] > 0][:top]:
        comments, token = [], ""
        for _ in range(2):
            try:
                data = yt("commentThreads", part="snippet", videoId=v["id"], order="relevance",
                          maxResults=100, textFormat="plainText", pageToken=token)
            except ApiError:
                break  # commentaires désactivés, etc.
            for it in data.get("items", []):
                sn = it["snippet"]["topLevelComment"]["snippet"]
                comments.append({"text": sn.get("textDisplay", ""), "likes": int(sn.get("likeCount", 0)),
                                 "author": sn.get("authorDisplayName", "?")})
            token = data.get("nextPageToken")
            if not token:
                break
        for m in find_moments(comments, v["duration"])[:3]:
            allm.append({**m, "videoId": v["id"], "title": v["title"], "channel": v["channel"]})
    allm.sort(key=lambda m: m["weight"], reverse=True)
    return allm[:12]


# ---------------- Twitch ----------------

_twitch_token = None


def twitch_token(client_id):
    """Jeton d'application Twitch : TWITCH_APP_TOKEN s'il existe, sinon obtenu avec TWITCH_CLIENT_SECRET."""
    global _twitch_token
    if _twitch_token:
        return _twitch_token
    if os.environ.get("TWITCH_APP_TOKEN"):
        _twitch_token = os.environ["TWITCH_APP_TOKEN"]
        return _twitch_token
    secret = os.environ.get("TWITCH_CLIENT_SECRET")
    if not secret:
        return "proxy-injected"
    body = urllib.parse.urlencode({"client_id": client_id, "client_secret": secret,
                                   "grant_type": "client_credentials"}).encode()
    req = urllib.request.Request("https://id.twitch.tv/oauth2/token", data=body, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            _twitch_token = json.load(r)["access_token"]
    except urllib.error.HTTPError as e:
        raise ApiError(f"Twitch refuse l'ID client ou le secret client (HTTP {e.code}). Vérifie-les dans les réglages.") from None
    except urllib.error.URLError as e:
        raise ApiError(f"Hôte injoignable (id.twitch.tv) : {e.reason}") from None
    return _twitch_token


def tw(endpoint, **params):
    client_id = os.environ.get("TWITCH_CLIENT_ID")
    if not client_id:
        raise ApiError("Twitch pas encore connecté : il manque TWITCH_CLIENT_ID et TWITCH_CLIENT_SECRET dans les réglages de l'environnement.")
    token = twitch_token(client_id)
    q = urllib.parse.urlencode([(k, x) for k, v in params.items() if v not in (None, "")
                                for x in (v if isinstance(v, list) else [v])])
    return http_get(f"https://api.twitch.tv/helix/{endpoint}?{q}",
                    {"Client-Id": client_id, "Authorization": f"Bearer {token}"})


def twitch_game_id():
    data = tw("games", name=TWITCH_GAME_NAMES)
    if data.get("data"):
        return data["data"][0]["id"], data["data"][0]["name"]
    data = tw("search/categories", query="Grand Theft Auto VI", first=5)
    for g in data.get("data", []):
        if "VI" in g["name"] or "6" in g["name"]:
            return g["id"], g["name"]
    return None, None


def twitch_trends(hours, lang):
    game_id, game_name = twitch_game_id()
    if not game_id:
        return {"game": None, "streams": [], "clips": []}
    streams = tw("streams", game_id=game_id, language=lang, first=20).get("data", [])
    started = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
    clips = tw("clips", game_id=game_id, started_at=started, first=100).get("data", [])
    if lang:
        clips = [c for c in clips if (c.get("language") or "").startswith(lang)]
    clips.sort(key=lambda c: c.get("view_count", 0), reverse=True)
    return {"game": game_name, "streams": streams, "clips": clips[:12]}


# ---------------- Rapport ----------------

def build_report(yt_items, yt_err, twd, tw_err, hours, lang):
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=1)))  # heure de Paris (hiver)
    L = [f"# Veille GTA 6 — {now:%d/%m/%Y %Hh%M}", ""]
    L.append(f"Fenêtre : dernières {hours} h · langue : {lang or 'toutes'}")
    L.append("")
    L.append("## YouTube — vidéos qui décollent")
    if yt_err:
        L.append(f"⚠️ {yt_err}")
    elif not yt_items:
        L.append("Aucune vidéo trouvée.")
    else:
        for i, v in enumerate(yt_items[:10], 1):
            if v["live"]:
                stat = f"🔴 EN DIRECT · {fmt_num(v['watching'])} spectateurs"
            else:
                stat = (f"{fmt_num(v['views'])} vues en {int(v['age_h'])} h "
                        f"({fmt_num(v['velocity'])} vues/h) · {fmt_dur(v['duration'])}")
            L.append(f"{i}. **{v['title']}** — {v['channel']}  ")
            L.append(f"   {stat} · {fmt_num(v['likes'])} j'aime · {fmt_num(v['comments'])} commentaires  ")
            L.append(f"   {v['url']}")
    L.append("")
    L.append(f"## Twitch — streams en direct{' (' + twd['game'] + ')' if twd and twd.get('game') else ''}")
    if tw_err:
        L.append(f"⚠️ {tw_err}")
    elif not twd or not twd.get("game"):
        L.append("Catégorie GTA VI introuvable sur Twitch pour l'instant.")
    else:
        if not twd["streams"]:
            L.append("Aucun stream en direct dans cette langue.")
        for i, s in enumerate(twd["streams"][:10], 1):
            L.append(f"{i}. **{s['user_name']}** — {fmt_num(s['viewer_count'])} spectateurs — {s['title']}  ")
            L.append(f"   https://www.twitch.tv/{s['user_login']}")
        L.append("")
        L.append("## Twitch — clips les plus vus (temps forts déjà repérés par les viewers)")
        if not twd["clips"]:
            L.append("Aucun clip dans la fenêtre.")
        for i, c in enumerate(twd["clips"], 1):
            moment = ""
            if c.get("vod_offset") is not None and c.get("video_id"):
                moment = f" · moment dans la VOD : {fmt_dur(c['vod_offset'])} (https://www.twitch.tv/videos/{c['video_id']}?t={int(c['vod_offset'])}s)"
            L.append(f"{i}. **{c['title']}** — {c['broadcaster_name']} · {fmt_num(c['view_count'])} vues{moment}  ")
            L.append(f"   {c['url']}")
    L.append("")
    L.append("_Rappel : clippe uniquement les créateurs qui ont donné leur accord (ou une campagne de clipping), et crédite-les._")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=int, default=24)
    ap.add_argument("--lang", default="fr")
    ap.add_argument("--no-save", action="store_true")
    ap.add_argument("--json", help="écrit aussi les données brutes dans ce fichier JSON (pour la page Claude)")
    a = ap.parse_args()

    yt_items, yt_err, twd, tw_err, moments = [], None, None, None, []
    try:
        yt_items = youtube_trends(a.hours, a.lang)
        moments = youtube_moments(yt_items)
    except ApiError as e:
        yt_err = str(e)
    try:
        twd = twitch_trends(a.hours, a.lang)
    except ApiError as e:
        tw_err = str(e)

    if a.json:
        def clean_clip(c):
            return {k: c.get(k) for k in ("title", "broadcaster_name", "view_count", "url", "thumbnail_url",
                                           "vod_offset", "video_id", "created_at", "duration")}
        def clean_stream(st):
            return {k: st.get(k) for k in ("user_name", "user_login", "viewer_count", "title", "started_at",
                                            "thumbnail_url")}
        payload = {
            "updatedAt": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "windowHours": a.hours, "lang": a.lang,
            "youtube": [{k: round(v[k], 1) if isinstance(v[k], float) else v[k]
                         for k in ("id", "title", "channel", "channelId", "url", "thumb", "age_h", "views", "likes",
                                   "comments", "velocity", "live", "watching", "duration", "score")}
                        for v in yt_items[:25]],
            "moments": moments,
            "twitch": {"game": (twd or {}).get("game"),
                       "streams": [clean_stream(x) for x in (twd or {}).get("streams", [])[:15]],
                       "clips": [clean_clip(x) for x in (twd or {}).get("clips", [])[:12]]},
            "errors": {"youtube": yt_err, "twitch": tw_err},
        }
        Path(a.json).write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    report = build_report(yt_items, yt_err, twd, tw_err, a.hours, a.lang)
    print(report)
    if not a.no_save:
        REPORT_DIR.mkdir(exist_ok=True)
        (REPORT_DIR / "latest.md").write_text(report, encoding="utf-8")
        stamp = dt.datetime.now(dt.timezone(dt.timedelta(hours=1))).strftime("%Y-%m-%d_%Hh%M")
        (REPORT_DIR / f"{stamp}.md").write_text(report, encoding="utf-8")
    return 0 if not (yt_err and tw_err) else 1


if __name__ == "__main__":
    sys.exit(main())
