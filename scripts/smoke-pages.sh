#!/usr/bin/env bash
# Thin wrapper — keeps existing ./scripts/smoke-pages.sh call sites.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT
exec python3 - "$@" <<'PY'
"""Local / live page-load smoke for the passerby shell + redirects.

Usage:
  ./scripts/smoke-pages.sh
  BASE=https://redmed.pages.dev ./scripts/smoke-pages.sh
"""
from __future__ import annotations

import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("BASE", "http://127.0.0.1:8787").rstrip("/")
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
# Visible copy (HTML comments stripped) — never ask for these on tapper.
AUTH_VISIBLE_NEEDLES = (
    "Face ID",
    "Touch ID",
    "passcode",
    "Unlock with",
    "Sign in",
    "Sign In",
    "Log in",
    "Log In",
)


def strip_html_comments(text: str) -> str:
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def check_tapper_no_auth(path: Path) -> bool:
    raw = path.read_text(encoding="utf-8")
    ok = True
    for needle in AUTH_CODE_NEEDLES:
        if needle in raw:
            print(f"FAIL {path} auth code: {needle}")
            ok = False
    visible = strip_html_comments(raw)
    for needle in AUTH_VISIBLE_NEEDLES:
        if needle in visible:
            print(f"FAIL {path} auth copy: {needle}")
            ok = False
    if ok:
        print(f"OK   no-auth {path.relative_to(REPO)}")
    return ok


def fetch(path: str) -> tuple[int, bytes]:
    url = BASE + path
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read() if e.fp else b""
    except Exception as e:
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
    for rel in (
        "tapper.html",
        "tapper/index.html",
        "RedMed-Xcode/RedMed/tapper.html",
    ):
        ok &= check_tapper_no_auth(REPO / rel)

    ok &= check("/tapper/", 'data-tab="medical"', 'data-tab="911"', 'data-tab="aid"')
    ok &= check("/tapper/index.html", 'data-tab="medical"')
    ok &= check("/get/", "/tapper/")
    ok &= check("/get.html", "/tapper/")
    ok &= check("/card.html", "/tapper/")
    ok &= check("/index.html", "tapper/")
    ok &= check("/BrandLogo.png")
    ok &= check("/BrandWordmark.png")
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
