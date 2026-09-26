/**
 * Env helpers for RedMed MCP. Secrets stay in process env / mcp/.env — never logged.
 */

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export function expandHome(p: string): string {
  if (p.startsWith("~/")) return path.join(os.homedir(), p.slice(2));
  if (p === "~") return os.homedir();
  return p;
}

export function readTokenFile(filePath: string): string | undefined {
  try {
    const raw = fs.readFileSync(expandHome(filePath), "utf8").trim();
    return raw || undefined;
  } catch {
    return undefined;
  }
}

/** Prefer env; fall back to ~/.config/hostinger-mcp/api_token (local Mini wiring). */
export function resolveHostingerToken(): string | undefined {
  const fromEnv = process.env.HOSTINGER_API_TOKEN?.trim();
  if (fromEnv) return fromEnv;
  return readTokenFile("~/.config/hostinger-mcp/api_token");
}

export function hostingerTokenPresent(): boolean {
  return Boolean(resolveHostingerToken());
}

export type VpsSshConfig = {
  host: string;
  user: string;
  identityFile: string;
  port: number;
};

export function resolveVpsSshConfig(): VpsSshConfig {
  return {
    host:
      process.env.REDMED_VPS_HOST?.trim() ||
      process.env.SSH_HOST?.trim() ||
      "hostinger-vps",
    user: process.env.REDMED_VPS_USER?.trim() || "root",
    identityFile: expandHome(
      process.env.REDMED_VPS_IDENTITY?.trim() || "~/.ssh/hostinger_vps"
    ),
    port: Number(process.env.REDMED_VPS_PORT?.trim() || "22") || 22,
  };
}

export function identityFilePresent(): boolean {
  try {
    return fs.existsSync(resolveVpsSshConfig().identityFile);
  } catch {
    return false;
  }
}

/** `ssh` (default, Mini → VPS) or `local` (in-process on the VPS). */
export type ExecMode = "ssh" | "local";

export function resolveExecMode(): ExecMode {
  const raw = process.env.REDMED_EXEC_MODE?.trim().toLowerCase();
  return raw === "local" ? "local" : "ssh";
}

export function mcpTokenPresent(): boolean {
  return Boolean(process.env.REDMED_MCP_TOKEN?.trim());
}
