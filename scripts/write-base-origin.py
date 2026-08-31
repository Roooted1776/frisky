#!/usr/bin/env python3
"""Print the origin of AppConfig.medicalCardBaseURL (scheme://host).

Used by pages-deploy.yml so live smoke tracks the URL written onto bands.
Fails if the Swift file cannot be parsed — do not silently fall back to a
hardcoded host (that is how a 404 write base stayed green).
"""
from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "RedMed-Xcode" / "RedMed" / "AppConfig.swift"


def write_base_url(text: str) -> str:
    m = re.search(
        r"static let medicalCardCustomDomainTBD: String\? = (nil|\"([^\"]+)\")",
        text,
    )
    if not m:
        raise SystemExit("AppConfig.medicalCardCustomDomainTBD not found")
    if m.group(1) != "nil":
        url = m.group(2)
    else:
        m = re.search(
            r"static var medicalCardBaseURL: String \{.*?return \"(https://[^\"]+)\"",
            text,
            re.S,
        )
        if not m:
            raise SystemExit("AppConfig.medicalCardBaseURL fallback URL not found")
        url = m.group(1)
    parsed = urlparse(url)
    if parsed.scheme not in ("https", "http") or not parsed.netloc:
        raise SystemExit(f"write base is not an http(s) URL: {url!r}")
    return f"{parsed.scheme}://{parsed.netloc}"


def main() -> int:
    text = SWIFT.read_text(encoding="utf-8")
    print(write_base_url(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
