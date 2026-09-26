# RedMed MCP — client wiring

Bearer token file: `~/.config/redmed-mcp/token`  
Remote URL (live): `https://srv2010795.hstgr.cloud/mcp`  
Canonical (after CF DNS): `https://mcp.redmed.live/mcp`

## Cursor

Project: `frisky/.cursor/mcp.json` → `redmed` + `redmed-remote`  
Global: `~/.cursor/mcp.json` → same  
Reload: Cursor Settings → MCP → refresh / restart Cursor.

## Claude Desktop

File: `~/Library/Application Support/Claude/claude_desktop_config.json`  
Entry: `redmed` (stdio via `mcp/bin/run-stdio.sh`).  
Fully quit and reopen Claude Desktop (⌘Q).

Remote HTTPS for Desktop: Settings → Connectors → add custom  
URL `https://srv2010795.hstgr.cloud/mcp`, auth Bearer from token file.

## Claude Code

```bash
claude mcp list   # should show redmed + redmed-remote
```

## Perplexity Desktop (Pro/Max)

1. Settings → Connectors → install Helper if prompted → restart.
2. **Remote (preferred):** Add Custom Remote Connector  
   - Name: `RedMed`  
   - URL: `https://srv2010795.hstgr.cloud/mcp`  
   - Auth: API Key / Bearer  
   - Key: contents of `~/.config/redmed-mcp/token`  
   - Transport: Streamable HTTP  
3. **Local fallback:** Add Connector (Simple)  
   - Command: `/Users/claude/frisky/mcp/bin/run-stdio.sh`  
4. Enable under Sources on a new chat.
