/**
 * VPS shell via OpenSSH (Mini) or local bash (remote MCP on the box).
 * Non-interactive only. Product wall: no Assist/#d= PHI tooling.
 */

import { spawn } from "node:child_process";
import fs from "node:fs";

import {
  identityFilePresent,
  resolveExecMode,
  resolveVpsSshConfig,
  type ExecMode,
} from "./env.js";

export type SshExecResult = {
  ok: boolean;
  mode: ExecMode;
  host: string;
  user: string;
  identityFile: string;
  command: string;
  stdout: string;
  stderr: string;
  exitCode: number | null;
  signal: string | null;
  durationMs: number;
  error: string | null;
};

const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_TIMEOUT_MS = 120_000;

/** Block obvious interactive / catastrophic patterns for an agent shell. */
const BLOCKED = [
  /\bsudo\s+-i\b/i,
  /\bpasswd\b/i,
  /\bvim\b|\bnano\b|\bless\b|\bmore\b/i,
  /\brm\s+(-[^\s]*f[^\s]*\s+)?\/\b/,
  /\bmkfs\b|\bdd\s+if=/i,
  /\bshutdown\b|\breboot\b|\bhalt\b|\bpoweroff\b/i,
];

export function assertCommandAllowed(command: string): string | null {
  const trimmed = command.trim();
  if (!trimmed) return "Empty command";
  if (trimmed.length > 4000) return "Command too long (max 4000 chars)";
  for (const re of BLOCKED) {
    if (re.test(trimmed)) {
      return `Blocked by RedMed MCP policy (matches ${re}). Use Hostinger VPS MCP for power actions, or run manually.`;
    }
  }
  return null;
}

function baseMeta(command: string): Pick<
  SshExecResult,
  "mode" | "host" | "user" | "identityFile" | "command"
> {
  const mode = resolveExecMode();
  const cfg = resolveVpsSshConfig();
  return {
    mode,
    host: mode === "local" ? "local" : cfg.host,
    user: mode === "local" ? process.env.USER || "root" : cfg.user,
    identityFile: mode === "local" ? "(local)" : cfg.identityFile,
    command,
  };
}

export async function sshExec(
  command: string,
  timeoutMs = DEFAULT_TIMEOUT_MS
): Promise<SshExecResult> {
  const started = Date.now();
  const meta = baseMeta(command);
  const blocked = assertCommandAllowed(command);
  if (blocked) {
    return {
      ok: false,
      ...meta,
      stdout: "",
      stderr: "",
      exitCode: null,
      signal: null,
      durationMs: 0,
      error: blocked,
    };
  }

  const timeout = Math.min(Math.max(timeoutMs, 1_000), MAX_TIMEOUT_MS);

  if (meta.mode === "local") {
    return runSpawn("/bin/bash", ["-lc", command], meta, command, started, timeout);
  }

  const cfg = resolveVpsSshConfig();
  if (!identityFilePresent()) {
    return {
      ok: false,
      ...meta,
      stdout: "",
      stderr: "",
      exitCode: null,
      signal: null,
      durationMs: Date.now() - started,
      error: `Identity file missing: ${cfg.identityFile}`,
    };
  }

  try {
    fs.chmodSync(cfg.identityFile, 0o600);
  } catch {
    /* ignore */
  }

  const args = [
    "-i",
    cfg.identityFile,
    "-p",
    String(cfg.port),
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "IdentitiesOnly=yes",
    `${cfg.user}@${cfg.host}`,
    command,
  ];

  return runSpawn("ssh", args, meta, command, started, timeout);
}

function runSpawn(
  bin: string,
  args: string[],
  meta: ReturnType<typeof baseMeta>,
  command: string,
  started: number,
  timeout: number
): Promise<SshExecResult> {
  return new Promise((resolve) => {
    const child = spawn(bin, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let settled = false;

    const finish = (
      payload: Omit<SshExecResult, "durationMs" | keyof typeof meta> & {
        durationMs?: number;
      } & Partial<typeof meta>
    ) => {
      if (settled) return;
      settled = true;
      resolve({
        ...meta,
        ...payload,
        durationMs: Date.now() - started,
      } as SshExecResult);
    };

    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      finish({
        ok: false,
        command,
        stdout: stdout.slice(0, 50_000),
        stderr: stderr.slice(0, 20_000),
        exitCode: null,
        signal: "SIGKILL",
        error: `Timed out after ${timeout}ms`,
      });
    }, timeout);

    child.stdout.on("data", (buf: Buffer) => {
      if (stdout.length < 50_000) stdout += buf.toString("utf8");
    });
    child.stderr.on("data", (buf: Buffer) => {
      if (stderr.length < 20_000) stderr += buf.toString("utf8");
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      finish({
        ok: false,
        command,
        stdout,
        stderr,
        exitCode: null,
        signal: null,
        error: err.message,
      });
    });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      finish({
        ok: code === 0,
        command,
        stdout: stdout.slice(0, 50_000),
        stderr: stderr.slice(0, 20_000),
        exitCode: code,
        signal: signal ?? null,
        error: code === 0 ? null : `${bin} exited ${code ?? signal}`,
      });
    });
  });
}

export async function sshProbe(): Promise<{
  ok: boolean;
  detail: string;
  result: SshExecResult;
}> {
  const result = await sshExec(
    "echo REDMED_SSH_OK; hostname; (uptime -p 2>/dev/null || uptime 2>/dev/null || cat /proc/uptime 2>/dev/null || true)",
    15_000
  );
  return {
    ok: result.ok && result.stdout.includes("REDMED_SSH_OK"),
    detail: result.ok
      ? result.stdout.trim().split("\n").slice(0, 3).join(" | ")
      : result.error || result.stderr || "exec failed",
    result,
  };
}
