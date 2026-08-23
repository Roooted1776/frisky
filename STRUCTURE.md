# RedMed tree map

Single source of truth: **git `main`** → `Roooted1776/frisky`.
Local Mac path: **`/Users/claude/Documents/frisky`** only.

```text
frisky/
├── AGENTS.md                 # product rules for agents
├── MAX.md                    # Max history / profile memory
├── SECURITY.md               # threat model
├── README.md                 # human overview
├── STRUCTURE.md              # this file
├── RedMed-Xcode/             # native owner app
│   ├── RedMed.xcodeproj/
│   ├── scripts/              # brand asset helpers
│   └── RedMed/               # Swift sources (flat) + bundled resources
├── tapper/                   # hosted passerby shell (Pages)
│   ├── index.html            # == root tapper.html
│   ├── sw.js
│   └── Brand*.png / pheart.png
├── tapper.html               # root mirror of tapper shell
├── sw.js
├── card.html · get.html · get/   # legacy #d= redirects
├── assets/                   # brand assets for Pages
├── docs/                     # domain, NFC restore, band sourcing
├── scripts/                  # run, deploy, smoke, sync-tapper
└── .github/workflows/        # ios-build, pages-deploy
```

## Code organization (logical)

See Xcode Project Navigator groups under target **RedMed**. Disk remains flat
under `RedMed-Xcode/RedMed/` so:

- `INFOPLIST_FILE = RedMed/Info.plist` stays stable
- `CODE_SIGN_ENTITLEMENTS = RedMed/RedMed.entitlements` stays stable
- `Bundle.main.url(forResource:withExtension:)` keeps basename loads
- Pages CI `cmp` paths for `tapper.html` stay stable

## Recent security / load work (on main)

- Keychain: `biometryCurrentSet` ACL + parked `LAContext` after Face ID
- Unlock: embed WK warm overlaps Face ID; cancelWarm on parked path
- ATS / Edit keyboard traits / SECURITY.md aligned with bound Keychain

Pull `main` on the MacBook to receive these.
