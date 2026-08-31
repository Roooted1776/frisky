# RedMed

Native iOS medical ID. Profile stays in Keychain. A passerby who taps the NXP NTAG216 band opens a static HTML card from `#d=` — no login, no RedMed server.

Owner tabs: **RedMed · 911 · Aid · NFC**. Band tap / scanner: **RedMed · 911 · Aid**.

GitHub repo is `frisky`. The iOS app builds only on macOS + Xcode.

## Run (macOS)

```
./scripts/run.sh
```

## Passerby shell (any OS)

```
python3 -m http.server 8787 --bind 127.0.0.1
BASE=http://127.0.0.1:8787 ./scripts/smoke-pages.sh
```

Band write base `https://roooted1776.github.io/tapper/` is **404** until `Roooted1776.github.io` exists and is published. Do not write bands until that host serves RedMed · 911 · Aid. See `docs/domain.md` and `docs/AUDIT.md`.

Policies: in-app Help (`RedMed-Xcode/RedMed/Help.html`). Do not call the chip encrypted or HIPAA certified (`docs/DO-NOT.md`).
