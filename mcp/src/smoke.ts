/**
 * Non-stdio smoke for RedMed master MCP backends.
 * Run: npm run smoke  (loads mcp/.env if present)
 */

import { loadDotEnv } from "./dotenv.js";
import {
  hostingerTokenPresent,
  identityFilePresent,
  resolveExecMode,
  resolveVpsSshConfig,
} from "./env.js";
import {
  REDMED_DOMAIN,
  REDMED_VPS_ID,
  listVirtualMachines,
  listWebsites,
} from "./hostinger.js";
import { sshProbe } from "./ssh.js";
import {
  DEFAULT_SUPABASE_URL,
  PROJECT_REF,
  createPublishableClient,
  readEnvPresence,
  resolveSupabaseUrl,
} from "./supabase.js";
import { SERVER_VERSION } from "./server.js";

async function main() {
  loadDotEnv();

  const presence = readEnvPresence();
  console.log(
    JSON.stringify(
      {
        step: "redmed_ping",
        server: "redmed-mcp",
        version: SERVER_VERSION,
        role: "master",
        projectRef: PROJECT_REF,
        execMode: resolveExecMode(),
        env: {
          ...presence,
          hostingerToken: hostingerTokenPresent(),
          vpsIdentity: identityFilePresent(),
        },
        defaultUrl: DEFAULT_SUPABASE_URL,
        ssh: resolveVpsSshConfig(),
      },
      null,
      2
    )
  );

  const url = resolveSupabaseUrl();
  const healthUrl = `${url.replace(/\/$/, "")}/auth/v1/health`;
  const key =
    process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ||
    process.env.SUPABASE_SECRET_KEY?.trim();
  const headers: Record<string, string> = { Accept: "application/json" };
  if (key) {
    headers.apikey = key;
    headers.Authorization = `Bearer ${key}`;
  }

  const healthRes = await fetch(healthUrl, { headers });
  console.log(
    JSON.stringify(
      {
        step: "supabase_project_info",
        healthUrl,
        httpStatus: healthRes.status,
        reachable: healthRes.ok,
        body: (await healthRes.text()).slice(0, 200),
      },
      null,
      2
    )
  );

  if (presence.publishableKey) {
    const client = createPublishableClient();
    const { error } = await client.auth.getSession();
    console.log(
      JSON.stringify(
        {
          step: "publishable_getSession",
          ok: !error,
          error: error?.message ?? null,
        },
        null,
        2
      )
    );
  }

  if (presence.secretKey) {
    const secret = process.env.SUPABASE_SECRET_KEY!.trim();
    const openApiUrl = `${url.replace(/\/$/, "")}/rest/v1/`;
    const res = await fetch(openApiUrl, {
      headers: {
        apikey: secret,
        Authorization: `Bearer ${secret}`,
        Accept: "application/openapi+json",
      },
    });
    let tables: string[] = [];
    if (res.ok) {
      const spec = (await res.json()) as { paths?: Record<string, unknown> };
      tables = [
        ...new Set(
          Object.keys(spec.paths ?? {})
            .map((p) => p.replace(/^\//, "").split("/")[0] ?? "")
            .filter((name) => name && !name.startsWith("rpc"))
        ),
      ].sort();
    }
    console.log(
      JSON.stringify(
        {
          step: "supabase_list_tables",
          httpStatus: res.status,
          tableCount: tables.length,
          tables,
        },
        null,
        2
      )
    );
  } else {
    console.log(
      JSON.stringify({
        step: "supabase_list_tables",
        skipped: true,
        reason: "SUPABASE_SECRET_KEY not set",
      })
    );
  }

  const vms = await listVirtualMachines();
  const vm = vms.data?.find((v) => v.id === REDMED_VPS_ID) ?? null;
  console.log(
    JSON.stringify(
      {
        step: "hostinger_vps_info",
        ok: vms.ok && Boolean(vm),
        error: vms.error,
        vm: vm
          ? {
              id: vm.id,
              hostname: vm.hostname,
              state: vm.state,
              ipv4: vm.ipv4?.[0]?.address,
            }
          : null,
      },
      null,
      2
    )
  );

  const sites = await listWebsites(REDMED_DOMAIN);
  console.log(
    JSON.stringify(
      {
        step: "hostinger_websites",
        ok: sites.ok,
        error: sites.error,
        total: sites.data?.meta?.total ?? sites.data?.data?.length ?? 0,
      },
      null,
      2
    )
  );

  const ssh = await sshProbe();
  console.log(
    JSON.stringify(
      {
        step: "hostinger_ssh_probe",
        ok: ssh.ok,
        detail: ssh.detail,
        mode: resolveExecMode(),
        error: ssh.result.error,
      },
      null,
      2
    )
  );

  const failures: string[] = [];
  if (!healthRes.ok) failures.push("supabase health");
  if (!vms.ok || !vm) failures.push("hostinger vps");
  if (!ssh.ok) failures.push("ssh");

  if (failures.length) {
    console.error(`Smoke: failed — ${failures.join(", ")}`);
    process.exit(1);
  }
  console.error("Smoke: ok (master stack)");
}

main().catch((err) => {
  console.error("Smoke failed:", err);
  process.exit(1);
});
