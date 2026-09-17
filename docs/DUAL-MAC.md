# Dual Mac (MacBook + Mini)

Hub is GitHub. Each Mac is a client. They never push to each other.

| Machine | Clone | Origin |
|---------|--------|--------|
| MacBook | `~/Documents/frisky` | `https://github.com/Roooted1776/frisky.git` |
| Mac Mini | `~/Documents/frisky` | same |

On the current MacBook that is `/Users/claude/Documents/frisky`. Mini uses the same `~/Documents/frisky` even if the username differs. One clone per machine. GitHub Desktop may sit on that clone. Do not let it make a second folder.

HTTPS + `gh` (port 443). School/cafe Wi‑Fi often blocks SSH:22, and `Roooted1776` has no GitHub SSH keys. Do not copy Cloud Agent tokens onto either Mac.

## 1. Cursor update (each Mac)

Desktop ShipIt is failing to replace `/Applications/Cursor.app` (quarantine / `com.apple.macl`). Retry inside Cursor will not clear it. Cloud agents stay up; this is the local app.

Run from **Terminal.app**, not Cursor:

```bash
~/Documents/frisky/scripts/fix-cursor-update-macos.sh diagnose
~/Documents/frisky/scripts/fix-cursor-update-macos.sh repair
~/Documents/frisky/scripts/fix-cursor-update-macos.sh reinstall-prep
```

Then: empty Trash → download https://cursor.com/download → install **one** copy into `/Applications` (not Downloads, not the mounted DMG) → open it.

Keep `~/Library/Application Support/Cursor` and `~/.cursor`. That is chats/settings.

Until desktop reattaches, use the web agent. Do not kill a healthy cloud run to “reconnect.”

### Cursor settings + colors (Mini → MacBook)

Cloud agents cannot read either Mac’s Cursor profile. Sync locally.

Theme and color overrides live in `~/Library/Application Support/Cursor/User/settings.json` (`workbench.colorTheme`, `workbench.colorCustomizations`, token color keys). Theme **extensions** must be installed too or the theme name resolves to a fallback.

On the **Mini** (source of truth for prefs):

```bash
~/Documents/frisky/scripts/sync-cursor-settings-macos.sh export
```

AirDrop / USB / `scp` the tarball (`~/Documents/frisky/.local/cursor-user-sync/cursor-user-sync.tar.gz`) to the MacBook. Quit Cursor on the MacBook, then:

```bash
~/Documents/frisky/scripts/sync-cursor-settings-macos.sh import
# or: ... import /path/to/cursor-user-sync.tar.gz
```

Reload Window. `status` prints the theme/color keys on the current Mac. Bundle stays under `.local/` (gitignored) — do not commit it (MCP tokens can sit in `~/.cursor/mcp.json`).

UI alternative (also carries colors): Cmd+Shift+P → **Preferences: Open Profiles (UI)** → export profile on Mini → import + activate on MacBook.

## 2. Git (each Mac)

Same steps on MacBook and Mini:

```bash
# already cloned:
~/Documents/frisky/scripts/setup-mac-git.sh

# Mini with no clone yet:
# install Homebrew if missing, then:
gh repo clone Roooted1776/frisky ~/Documents/frisky
~/Documents/frisky/scripts/setup-mac-git.sh
```

The script logs you in as **Roooted1776** over HTTPS if needed, pins `origin`, refuses extra remotes, sets repo identity to `Max` / `m.aguilar-aasted@students.mccc.edu` when unset, then `fetch` + `pull --ff-only` + `push --dry-run`.

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
| MacBook theme/colors ≠ Mini | Section 1 “Cursor settings + colors”. Export on Mini, import on MacBook; install listed theme extensions. |
| Wrong remote `rooted1776/risky` | Does not exist. Repo is `Roooted1776/frisky` (three o’s). |
