#!/usr/bin/env bash
# Thin wrapper — keeps existing ./scripts/smoke-pages.sh call sites.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT
exec python3 - "$@" <<'PY'
"""Local / live page-load smoke for the passerby shell + redirects.

Usage:
  ./scripts/smoke-pages.sh
  BASE=https://redmed.live ./scripts/smoke-pages.sh
  BASE=http://195.35.60.70 HOST_HEADER=redmed.live ./scripts/smoke-pages.sh
  BASE=https://roooted1776.github.io ./scripts/smoke-pages.sh
"""
from __future__ import annotations

import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("BASE", "http://127.0.0.1:8787").rstrip("/")
HOST_HEADER = os.environ.get("HOST_HEADER", "").strip()
UA = "RedMed-smoke-pages/1.0 (+https://github.com/Roooted1776/frisky)"
REPO = Path(os.environ["REPO_ROOT"])

# Tap-to-view must stay ungated — no biometrics / login / WebAuthn in the shell.
AUTH_CODE_NEEDLES = (
    "BiometricAuth",
    "LocalAuthentication",
    "evaluatePolicy",
    "deviceOwnerAuthentication",
    "navigator.credentials",
    "PublicKeyCredential",
    "webauthn",
    "WebAuthn",
)
# Passerby shell must not mention biometrics anywhere (incl. HTML comments) —
# MAX.md: no biometric copy in passerby HTML. Also ban login-gate UI copy.
AUTH_COPY_NEEDLES = (
    "Face ID",
    "Touch ID",
    "biometric",
    "passcode",
    "Unlock with",
    "Sign in",
    "Sign In",
    "Log in",
    "Log In",
)
# Passerby shell is not an ad surface. Trackers on tapper.html would load on a
# band tap (PHI in the fragment). Store / listing pixels stay off this file.
# docs/ADVERTISING.md + docs/DO-NOT.md.
AD_NETWORK_NEEDLES = (
    "googletagmanager",
    "google-analytics",
    "analytics.google",
    "gtag(",
    "facebook.net",
    "connect.facebook.com",
    "fbevents.js",
    "fbq(",
    "analytics.tiktok",
    "ttq(",
    "hotjar",
    "mixpanel",
    "cdn.segment",
    "segment.com",
    "amplitude.com",
    "doubleclick.net",
    "googlesyndication",
    "adsbygoogle",
    "clarity.ms",
    "plausible.io",
)


def check_tapper_no_auth(path: Path) -> bool:
    raw = path.read_text(encoding="utf-8")
    ok = True
    for needle in AUTH_CODE_NEEDLES:
        if needle in raw:
            print(f"FAIL {path} auth code: {needle}")
            ok = False
    for needle in AUTH_COPY_NEEDLES:
        if needle in raw:
            print(f"FAIL {path} auth copy: {needle}")
            ok = False
    if ok:
        print(f"OK   no-auth {path.relative_to(REPO)}")
    return ok


def check_tapper_no_remote_connect(path: Path) -> bool:
    """Aid tutorials ship inline. A band tap must reach no third-party origin,
    so CSP connect-src stays 'self' — that is what blocks the owner-app-only
    hospital lookup (overpass-api.de) from ever firing in the passerby shell."""
    raw = path.read_text(encoding="utf-8")
    for line in raw.splitlines():
        if "Content-Security-Policy" not in line:
            continue
        directive = ""
        for part in line.split(";"):
            if "connect-src" in part:
                directive = part.strip().strip('"')
                break
        if directive != "connect-src 'self'":
            print(f"FAIL {path} CSP connect-src must be 'self', got: {directive!r}")
            return False
        print(f"OK   csp-connect-self {path.relative_to(REPO)}")
        return True
    print(f"FAIL {path} missing Content-Security-Policy")
    return False


def check_tapper_no_ads(path: Path) -> bool:
    raw = path.read_text(encoding="utf-8")
    lower = raw.lower()
    ok = True
    for needle in AD_NETWORK_NEEDLES:
        if needle.lower() in lower:
            print(f"FAIL {path} ad network: {needle}")
            ok = False
    if ok:
        print(f"OK   no-ads {path.relative_to(REPO)}")
    return ok


# Abort further GETs after this many transport failures (SSL/timeout/refused).
# Prevents ~15×20s hangs against Namecheap parking / dead hosts.
_transport_fails = 0
_TRANSPORT_FAIL_LIMIT = 2
# Shorter than before: dead HTTPS should fail CI fast; live hosts answer quickly.
_FETCH_TIMEOUT = 8


def fetch(path: str) -> tuple[int, bytes]:
    global _transport_fails
    if _transport_fails >= _TRANSPORT_FAIL_LIMIT:
        print(f"FAIL SKIP {path} (transport fail budget exhausted)")
        return 0, b""
    url = BASE + path
    headers = {"User-Agent": UA}
    if HOST_HEADER:
        headers["Host"] = HOST_HEADER
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=_FETCH_TIMEOUT) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read() if e.fp else b""
    except Exception as e:
        _transport_fails += 1
        print(f"FAIL ERR {path} {e}")
        return 0, b""


def check(path: str, *needles: str) -> bool:
    code, body = fetch(path)
    if code not in (200, 301, 302):
        print(f"FAIL {code} {path}")
        return False
    for needle in needles:
        if needle.encode() not in body:
            print(f"FAIL {path} missing: {needle}")
            return False
    if b"Set up your RedMed band" in body:
        print(f"FAIL {path} still band-setup")
        return False
    print(f"OK   {code} {path}")
    return True


def main() -> int:
    ok = True
    # Static: band-tap shell never ships an auth gate (runs even if server is down).
    ok &= check_tapper_no_auth(REPO / "tapper/index.html")
    ok &= check_tapper_no_ads(REPO / "tapper/index.html")
    ok &= check_tapper_no_remote_connect(REPO / "tapper/index.html")
    tapper_src = (REPO / "tapper/index.html").read_text(encoding="utf-8")
    if "function profileHasContent" not in tapper_src:
        print("FAIL tapper/index.html missing profileHasContent")
        ok = False
    elif "classList.toggle('is-unlinked'" not in tapper_src:
        print("FAIL tapper/index.html never toggles is-unlinked")
        ok = False
    elif 'classList.add("is-unlinked")' not in tapper_src and "classList.add('is-unlinked')" not in tapper_src:
        print("FAIL tapper/index.html missing first-paint is-unlinked")
        ok = False
    elif "No Patient" not in tapper_src:
        print("FAIL tapper/index.html missing No Patient empty state")
        ok = False
    elif "Couldn't Read This Band" not in tapper_src:
        print("FAIL tapper/index.html missing decode-fail empty copy")
        ok = False
    elif tapper_src.find('id="panel-911"') < 0 or tapper_src.find('id="aidStopAlarm"') < tapper_src.find('id="panel-911"'):
        print("FAIL tapper/index.html Stop The Alarm is not on the 911 panel")
        ok = False
    elif "Tap Stop The Alarm to cancel" not in tapper_src:
        print("FAIL tapper/index.html crash hint missing Stop The Alarm")
        ok = False
    else:
        print("OK   empty-state gates tapper/index.html")
    if "copyTextToClipboard" not in tapper_src or "enableHighAccuracy: true" not in tapper_src:
        print("FAIL tapper/index.html Copy Coordinates / high-accuracy GPS missing")
        ok = False
    elif "toFixed(6)" not in tapper_src:
        print("FAIL tapper/index.html GPS copy must use 6 decimal places")
        ok = False
    else:
        print("OK   copy-coords tapper/index.html")
    root_tapper = (REPO / "tapper.html").read_text(encoding="utf-8")
    if "data-tab=\"medical\"" in root_tapper:
        print("FAIL tapper.html is a full shell copy — keep it a redirect")
        ok = False
    elif "tapper/" not in root_tapper:
        print("FAIL tapper.html missing tapper/ redirect")
        ok = False
    else:
        print("OK   redirect tapper.html")
    emergency_stub = (REPO / "redmed-emergency.html").read_text(encoding="utf-8")
    if "data-tab=\"medical\"" in emergency_stub:
        print("FAIL redmed-emergency.html is a full shell copy — keep it a redirect")
        ok = False
    elif "tapper/" not in emergency_stub:
        print("FAIL redmed-emergency.html missing tapper/ redirect")
        ok = False
    else:
        print("OK   redirect redmed-emergency.html")

    ok &= check("/tapper/", 'data-tab="medical"', 'data-tab="911"', 'id="tab-aid"')
    ok &= check("/tapper/index.html", 'data-tab="medical"')
    # Passerby chrome: RedMed · 911 · Aid — no NFC tab button.
    code, body = fetch("/tapper/")
    if code == 200 and b'id="tab-nfc"' in body:
        print("FAIL /tapper/ has NFC tab (owner-only)")
        ok = False
    elif code == 200:
        print("OK   Aid tab present, no NFC tab /tapper/")
    ok &= check("/get/", "/tapper/")
    ok &= check("/get.html", "/tapper/")
    ok &= check("/card.html", "/tapper/")
    ok &= check("/redmed-emergency.html", "/tapper/")
    ok &= check("/index.html", "tapper/")
    # Brand photos live under assets/ (canonical) + tapper/ (shell-relative).
    ok &= check("/assets/BrandLogo.png")
    ok &= check("/assets/BrandWordmark.png")
    ok &= check("/assets/pheart.png")
    ok &= check("/tapper/pheart.png")
    ok &= check("/tapper/BrandLogo.png")
    ok &= check("/tapper/BrandWordmark.png")
    ok &= check("/tapper/sw.js", "redmed-tapper-v")
    if not ok:
        print(f"smoke-pages failed against {BASE}", file=sys.stderr)
        return 1
    print(f"smoke-pages OK — {BASE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
