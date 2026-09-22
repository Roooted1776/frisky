# Dual Mac (MacBook Air + Mini)

Hub is GitHub. Each Mac is a client. They never push to each other.

| Machine | Clone | Origin | My Machines worker name |
|---------|--------|--------|-------------------------|
| MacBook Air | `~/Documents/frisky` | `https://github.com/Roooted1776/frisky.git` | `macbook-air` |
| Mac Mini | `~/Documents/frisky` | same | `mac-mini` |

On the current MacBook Air that is `/Users/claude/Documents/frisky`. Mini uses the same `~/Documents/frisky` even if the username differs. One clone per machine. GitHub Desktop may sit on that clone. Do not let it make a second folder.

HTTPS + `gh` (port 443). School/cafe Wi‑Fi often blocks SSH:22, and `Roooted1776` has no GitHub SSH keys. Do not copy Cloud Agent tokens onto either Mac.

## 0. Cloud alongside both Macs (My Machines)

Managed Linux Cloud Agents cover the static Pages / tapper shell. For iOS (`owner/`) or any tool that must run on a Mac, keep a **My Machines** worker alive on that Mac. The agent brain stays in Cursor cloud; terminal / edits / (optional) GUI run on the Mac. Same Cursor account as Desktop, phone, and [cursor.com/agents](https://cursor.com/agents).

Do this once per Mac (Terminal.app, after §2 git is green):

```bash
~/Documents/frisky/scripts/setup-mac-worker.sh install
~/Documents/frisky/scripts/setup-mac-worker.sh login
```

Then leave a worker running:

```bash
# MacBook Air (day-to-day)
~/Documents/frisky/scripts/setup-mac-worker.sh start macbook-air

# Mac Mini (always-on; add --computer-use when the agent must drive Xcode / GUI)
~/Documents/frisky/scripts/setup-mac-worker.sh start mac-mini
# or:
~/Documents/frisky/scripts/setup-mac-worker.sh start mac-mini --computer-use
```

Keep that Terminal window open (or run under a launch agent you trust). Check from either Mac:

```bash
~/Documents/frisky/scripts/setup-mac-worker.sh status
~/Documents/frisky/scripts/setup-mac-worker.sh debug
```

### Pick where a task runs

| Work | Target |
|------|--------|
| `tapper/`, `sw.js`, `#d=` codec, Pages smoke | Managed Linux Cloud Agent (this VM) |
| Xcode / Simulator / device / Keychain-adjacent | `mac-mini` (or local Desktop on that Mac) |
| Laptop-local tools while Air is open | `macbook-air` |

From [cursor.com/agents](https://cursor.com/agents) (or phone): environment dropdown → **Cloud** (Linux) or **macbook-air** / **mac-mini**. From Slack/GitHub/Linear: `worker=mac-mini` or `worker=macbook-air` (name must match `--name`, same Cursor user, worker started inside `~/Documents/frisky`).

With `--computer-use` on Mini: first start installs **Cursor Computer Use**; grant Accessibility + Screen Recording in System Settings → Privacy & Security (to that helper, not Terminal / Cursor.app).

Workers need outbound HTTPS only (`api2.cursor.sh`, `api2direct.cursor.sh`, artifacts S3; plus `downloads.cursor.com` on first computer-use install). No inbound ports. Do not paste Cloud Agent / service-account tokens onto a Mac — use `agent login` or a **personal** API key.

## 1. Cursor update (each Mac)

Desktop ShipIt is failing to replace `/Applications/Cursor.app` (quarantine / `com.apple.macl`). Retry inside Cursor will not clear it. Cloud agents and My Machines workers stay up; this is the local app.

Run from **Terminal.app**, not Cursor:

```bash
~/Documents/frisky/scripts/fix-cursor-update-macos.sh diagnose
~/Documents/frisky/scripts/fix-cursor-update-macos.sh repair
~/Documents/frisky/scripts/fix-cursor-update-macos.sh reinstall-prep
```

Then: empty Trash → download https://cursor.com/download → install **one** copy into `/Applications` (not Downloads, not the mounted DMG) → open it.

Keep `~/Library/Application Support/Cursor` and `~/.cursor`. That is chats/settings.

Until desktop reattaches, use the web agent. Do not kill a healthy cloud run to “reconnect.”

### Cursor settings + colors (MacBook ↔ Mini)

Both machines are peers. Cloud agents cannot read either Mac’s Cursor profile. Sync locally.

Theme and color overrides live in `~/Library/Application Support/Cursor/User/settings.json` (`workbench.colorTheme`, `workbench.colorCustomizations`, token color keys). Theme **extensions** must be installed too or the theme name resolves to a fallback. Do **not** copy `state.vscdb` or the whole Application Support tree by hand.

On the Mac that already looks right (MacBook **or** Mini):

```bash
~/Documents/frisky/scripts/sync-cursor-settings-macos.sh export
```

AirDrop / USB / `scp` the tarball (`~/Documents/frisky/.local/cursor-user-sync/cursor-user-sync.tar.gz`) to the other Mac. Quit Cursor there, then:

```bash
~/Documents/frisky/scripts/sync-cursor-settings-macos.sh import
# or: ... import /path/to/cursor-user-sync.tar.gz
~/Documents/frisky/scripts/sync-cursor-settings-macos.sh status
```

Reload Window. Bundle stays under `.local/` (gitignored) — do not commit it (MCP tokens can sit in `~/.cursor/mcp.json`).

UI alternative (also carries colors): Cmd+Shift+P → **Preferences: Open Profiles (UI)** → export profile on one Mac → import + activate on the other.

## 2. Git (each Mac)

Same steps on MacBook Air and Mini:

```bash
# already cloned (either Mac):
~/Documents/frisky/scripts/setup-mac-git.sh

# MacBook or Mini with no clone yet:
# install Homebrew if missing, then:
gh repo clone Roooted1776/frisky ~/Documents/frisky
~/Documents/frisky/scripts/setup-mac-git.sh
```

The script logs you in as **Roooted1776** over HTTPS if needed, pins `origin`, refuses extra remotes, sets repo identity to `Max` / `maxaguilaraasted@gmail.com` (overwrites school / `mrmax115` / Cursor Agent emails), then `fetch` + `pull --ff-only` + `push --dry-run`.

### Email split (intentional workaround)

| Surface | Address | Notes |
|---------|---------|-------|
| Cursor / Grok Bot login | `m.aguilar-aasted@students.mccc.edu` | Keep. No account cutover required. |
| Git author (MacBook Air + Mini) | `maxaguilaraasted@gmail.com` | GitHub-verified on this repo. `setup-mac-git.sh` pins it. |
| Do not use for git | `mrmax115@gmail.com`, school email | Stale / never authored here. |

Gmail MCP for agents: authorize via **Cursor** (connected), not a separate Grok Bot OAuth. “This app is blocked” on a Grok Gmail plugin is expected — use Cursor’s Gmail.

Any-location smoke (home, school, cafe): `gh auth status` and `git fetch` both succeed on that Wi‑Fi.

## 3. Daily

1. Cloud / PR → squash-merge into `main` only.
2. On the Mac you are about to open Xcode: Fetch + Pull `main` (GitHub Desktop or `git pull --ff-only origin main`).
3. Delete the feature branch after merge.
4. Do not keep a second remote (`wire-privacy-info-target` is unsafe).
5. Do not leave uncommitted work on both Macs at once. Last pull wins; the other Mac must commit or stash first.

## Failures

| Symptom | Fix |
|---------|-----|
| `Authentication failed` / 403 | `gh auth login` (GitHub.com, HTTPS, git credentials yes). Then `gh auth setup-git`. |
| Logged in as `cursor` | Cloud VM identity. On a Mac: `gh auth logout` and log in as `Roooted1776`. |
| Extra remotes | `git remote remove <name>`. Only `origin`. |
| Diverged / non-ff | You committed on this Mac without pulling. `git status`; do not force-push `main`. |
| Cursor “Reconnect failed” | Tunnel attach. Reload Window, or open the agent in the browser. Not a git failure. |
| Cursor “couldn’t update” | Section 1. Do not keep clicking Try Again. |
| Theme/colors don’t match the other Mac | Section 1 “Cursor settings + colors”. Export on the good Mac, import on the other; install listed theme extensions. |
| Machine missing in agents environment dropdown | Section 0. Worker process stopped, wrong Cursor login, or not started inside `~/Documents/frisky`. Run `setup-mac-worker.sh status` / `debug`. |
| `worker=mac-mini` rejected / wrong repo | Worker name or git remote mismatch. Restart with `start mac-mini` from the frisky clone. No silent fallback to Linux. |
| Only Air shows online, not Mini | Mini worker not started (or asleep / offline). Section 0 on the Mini. |
| Wrong remote `rooted1776/risky` | Does not exist. Repo is `Roooted1776/frisky` (three o’s). |
