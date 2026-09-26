/**
 * RedMed MCP — shared tool registration (ops / non-PHI only).
 *
 * Surfaces:
 *   - Supabase project mohxobgyjkcmkqxijgeg
 *   - Hostinger API (static Assist host + VPS control plane)
 *   - VPS shell via SSH (Mini) or local exec (remote HTTP on the box)
 *
 * Hard wall: do not add tools that store or read Assist band `#d=` /
 * medical ICE profile payloads. Profile data stays on-device + band URL.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import {
  hostingerTokenPresent,
  identityFilePresent,
  mcpTokenPresent,
  resolveExecMode,
  resolveVpsSshConfig,
} from "./env.js";
import {
  REDMED_DOMAIN,
  REDMED_VPS_ID,
  REDMED_VPS_IP,
  getVirtualMachine,
  listSubscriptions,
  listVirtualMachines,
  listWebsites,
} from "./hostinger.js";
import { sshExec, sshProbe } from "./ssh.js";
import {
  DEFAULT_SUPABASE_URL,
  PROJECT_REF,
  createPublishableClient,
  createSecretClient,
  readEnvPresence,
  resolveSupabaseUrl,
} from "./supabase.js";

export const SERVER_NAME = "redmed-mcp";
export const SERVER_VERSION = "0.2.0";

function textResult(text: string, isError = false) {
  return {
    content: [{ type: "text" as const, text }],
    ...(isError ? { isError: true } : {}),
  };
}

function jsonResult(payload: unknown, isError = false) {
  return textResult(JSON.stringify(payload, null, 2), isError);
}

async function probeSupabaseHealth() {
  const url = resolveSupabaseUrl();
  const healthUrl = `${url.replace(/\/$/, "")}/auth/v1/health`;
  const presence = readEnvPresence();
  const headers: Record<string, string> = { Accept: "application/json" };
  const key =
    process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ||
    process.env.SUPABASE_SECRET_KEY?.trim();
  if (key) {
    headers.apikey = key;
    headers.Authorization = `Bearer ${key}`;
  }

  let reachable = false;
  let httpStatus: number | null = null;
  let detail = "";
  try {
    const res = await fetch(healthUrl, { headers });
    httpStatus = res.status;
    reachable = res.ok;
    detail = (await res.text()).slice(0, 200);
  } catch (err) {
    detail = err instanceof Error ? err.message : String(err);
  }

  let publishableClientOk: boolean | null = null;
  if (presence.publishableKey) {
    try {
      const client = createPublishableClient();
      const { error } = await client.auth.getSession();
      publishableClientOk = !error;
      if (error) detail = `${detail} | auth.getSession: ${error.message}`.trim();
    } catch (err) {
      publishableClientOk = false;
      detail = `${detail} | client: ${
        err instanceof Error ? err.message : String(err)
      }`.trim();
    }
  }

  return {
    projectRef: PROJECT_REF,
    supabaseUrl: url,
    healthUrl,
    reachable,
    httpStatus,
    publishableClientOk,
    env: presence,
    detail: detail || null,
  };
}

export function createRedmedServer(): McpServer {
  const server = new McpServer({
    name: SERVER_NAME,
    version: SERVER_VERSION,
  });

  server.tool(
    "redmed_ping",
    "Health check for the RedMed MCP process. Reports name/version and which backend env vars/files are present — never echoes secrets.",
    {},
    async () => {
      const presence = readEnvPresence();
      const ssh = resolveVpsSshConfig();
      return jsonResult({
        ok: true,
        server: SERVER_NAME,
        version: SERVER_VERSION,
        role: "master",
        projectRef: PROJECT_REF,
        supabaseUrl: resolveSupabaseUrl(),
        domain: REDMED_DOMAIN,
        execMode: resolveExecMode(),
        env: {
          SUPABASE_URL: presence.url,
          SUPABASE_PUBLISHABLE_KEY: presence.publishableKey,
          SUPABASE_SECRET_KEY: presence.secretKey,
          HOSTINGER_API_TOKEN: hostingerTokenPresent(),
          REDMED_VPS_IDENTITY: identityFilePresent(),
          REDMED_MCP_TOKEN: mcpTokenPresent(),
        },
        vps: {
          id: REDMED_VPS_ID,
          ip: REDMED_VPS_IP,
          sshHost: ssh.host,
          sshUser: ssh.user,
          identityFile: ssh.identityFile,
        },
        productWall:
          "Assist #d= ICE profiles are not a Supabase/VPS backend. Ops/non-PHI tools only.",
      });
    }
  );

  server.tool(
    "redmed_stack_status",
    "One-shot status across Supabase, Hostinger VPS API, Hostinger websites for redmed.live, and VPS shell (SSH or local).",
    {},
    async () => {
      const [supabase, vms, websites, subs, ssh] = await Promise.all([
        probeSupabaseHealth(),
        listVirtualMachines(),
        listWebsites(REDMED_DOMAIN),
        listSubscriptions(),
        sshProbe(),
      ]);

      const vm =
        vms.data?.find((v) => v.id === REDMED_VPS_ID) ?? vms.data?.[0] ?? null;

      const payload = {
        ok: supabase.reachable && vms.ok && Boolean(vm) && ssh.ok,
        server: SERVER_NAME,
        version: SERVER_VERSION,
        execMode: resolveExecMode(),
        supabase: {
          reachable: supabase.reachable,
          httpStatus: supabase.httpStatus,
          publishableClientOk: supabase.publishableClientOk,
        },
        hostinger: {
          apiToken: hostingerTokenPresent(),
          vps: vm
            ? {
                id: vm.id,
                hostname: vm.hostname,
                plan: vm.plan,
                state: vm.state,
                ipv4: vm.ipv4?.[0]?.address ?? null,
                template: vm.template?.name ?? null,
              }
            : null,
          vpsError: vms.error,
          websites: {
            total:
              websites.data?.meta?.total ?? websites.data?.data?.length ?? 0,
            rows: (websites.data?.data ?? []).slice(0, 10),
            error: websites.error,
          },
          subscriptions: {
            count: Array.isArray(subs.data) ? subs.data.length : 0,
            rows: Array.isArray(subs.data)
              ? subs.data.map((s) => ({
                  id: s.id,
                  name: s.name,
                  status: s.status,
                  next_billing_at: s.next_billing_at,
                }))
              : [],
            error: subs.error,
          },
        },
        ssh: {
          ok: ssh.ok,
          detail: ssh.detail,
          mode: resolveExecMode(),
          host: resolveVpsSshConfig().host,
        },
        productWall: "No Assist/#d= PHI through this stack.",
      };

      return jsonResult(payload, !payload.ok);
    }
  );

  server.tool(
    "supabase_project_info",
    "Confirm RedMed Supabase project URL/ref and run a cheap reachability check against the API gateway.",
    {},
    async () => {
      const info = await probeSupabaseHealth();
      return jsonResult(
        { ...info, defaultUrl: DEFAULT_SUPABASE_URL },
        !info.reachable
      );
    }
  );

  server.tool(
    "supabase_list_tables",
    "List public schema tables exposed by PostgREST (OpenAPI). Uses the secret key. Empty project → empty list.",
    {},
    async () => {
      const presence = readEnvPresence();
      if (!presence.secretKey) {
        return jsonResult(
          {
            error: "Missing SUPABASE_SECRET_KEY",
            tables: [],
            hint: "Set the secret key in the MCP process env (never commit it).",
          },
          true
        );
      }

      createSecretClient();

      const url = resolveSupabaseUrl().replace(/\/$/, "");
      const secret = process.env.SUPABASE_SECRET_KEY!.trim();
      const openApiUrl = `${url}/rest/v1/`;

      try {
        const res = await fetch(openApiUrl, {
          headers: {
            apikey: secret,
            Authorization: `Bearer ${secret}`,
            Accept: "application/openapi+json",
          },
        });

        if (!res.ok) {
          const body = await res.text();
          return jsonResult(
            {
              error: `OpenAPI fetch failed HTTP ${res.status}`,
              detail: body.slice(0, 300),
              tables: [],
            },
            true
          );
        }

        const spec = (await res.json()) as {
          paths?: Record<string, unknown>;
          definitions?: Record<string, unknown>;
          components?: { schemas?: Record<string, unknown> };
        };

        const fromPaths = Object.keys(spec.paths ?? {})
          .map((p) => p.replace(/^\//, "").split("/")[0] ?? "")
          .filter((name) => name && !name.startsWith("rpc"));

        const fromDefs = Object.keys(
          spec.definitions ?? spec.components?.schemas ?? {}
        ).filter((name) => !name.includes("."));

        const tables = [...new Set([...fromPaths, ...fromDefs])].sort();

        return jsonResult({
          projectRef: PROJECT_REF,
          schema: "public",
          tableCount: tables.length,
          tables,
        });
      } catch (err) {
        return jsonResult(
          {
            error: err instanceof Error ? err.message : String(err),
            tables: [],
          },
          true
        );
      }
    }
  );

  server.tool(
    "hostinger_vps_info",
    "Hostinger VPS control-plane snapshot for the RedMed KVM (API). Prefer this for power/plan state; use hostinger_ssh_exec for shell.",
    {},
    async () => {
      const detail = await getVirtualMachine(REDMED_VPS_ID);
      if (!detail.ok || !detail.data) {
        const all = await listVirtualMachines();
        return jsonResult(
          {
            expectedId: REDMED_VPS_ID,
            error: detail.error,
            httpStatus: detail.httpStatus,
            all: all.data ?? [],
            allError: all.error,
          },
          true
        );
      }
      const vm = detail.data;
      return jsonResult({
        id: vm.id,
        hostname: vm.hostname,
        plan: vm.plan,
        state: vm.state,
        ipv4: vm.ipv4?.[0]?.address ?? REDMED_VPS_IP,
        template: vm.template?.name ?? null,
        sshHint: `ssh -i ~/.ssh/hostinger_vps root@${vm.ipv4?.[0]?.address ?? REDMED_VPS_IP}`,
      });
    }
  );

  server.tool(
    "hostinger_websites",
    "List Hostinger websites, optionally filtered to redmed.live (static Assist origin).",
    {
      domain: z
        .string()
        .optional()
        .describe("Domain substring filter (default: redmed.live)"),
    },
    async ({ domain }) => {
      const filter = domain?.trim() || REDMED_DOMAIN;
      const res = await listWebsites(filter);
      if (!res.ok) {
        return jsonResult(
          { error: res.error, httpStatus: res.httpStatus, websites: [] },
          true
        );
      }
      return jsonResult({
        domain: filter,
        total: res.data?.meta?.total ?? res.data?.data?.length ?? 0,
        websites: res.data?.data ?? [],
      });
    }
  );

  server.tool(
    "hostinger_ssh_exec",
    "Run a non-interactive command on the RedMed VPS. Mini uses SSH (IdentityFile); remote HTTP mode uses local bash (REDMED_EXEC_MODE=local). Blocked: reboot/shutdown, interactive editors, rm -rf /.",
    {
      command: z.string().describe("Remote shell command (non-interactive)"),
      timeoutMs: z
        .number()
        .int()
        .min(1000)
        .max(120000)
        .optional()
        .describe("Timeout in ms (default 30000, max 120000)"),
    },
    async ({ command, timeoutMs }) => {
      const result = await sshExec(command, timeoutMs ?? 30_000);
      return jsonResult(result, !result.ok);
    }
  );

  server.tool(
    "hostinger_ssh_probe",
    "Quick VPS shell connectivity check (hostname + uptime) via SSH or local exec.",
    {},
    async () => {
      const probe = await sshProbe();
      return jsonResult(
        {
          ok: probe.ok,
          detail: probe.detail,
          mode: resolveExecMode(),
          config: resolveVpsSshConfig(),
          exitCode: probe.result.exitCode,
          error: probe.result.error,
        },
        !probe.ok
      );
    }
  );

  return server;
}
