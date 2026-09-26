/**
 * Non-stdio smoke: call the same logic paths the MCP tools use.
 * Run: SUPABASE_*=… npm run smoke
 */

import {
  DEFAULT_SUPABASE_URL,
  PROJECT_REF,
  createPublishableClient,
  readEnvPresence,
  resolveSupabaseUrl,
} from "./supabase.js";

async function main() {
  const presence = readEnvPresence();
  console.log(
    JSON.stringify(
      {
        step: "redmed_ping",
        server: "redmed-mcp",
        version: "0.1.0",
        projectRef: PROJECT_REF,
        env: presence,
        defaultUrl: DEFAULT_SUPABASE_URL,
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

  if (!healthRes.ok && !key) {
    console.error("Smoke: set SUPABASE_PUBLISHABLE_KEY and/or SUPABASE_SECRET_KEY for a full check.");
    process.exit(2);
  }
  if (!healthRes.ok) {
    console.error("Smoke: health endpoint not reachable.");
    process.exit(1);
  }
  console.error("Smoke: ok");
}

main().catch((err) => {
  console.error("Smoke failed:", err);
  process.exit(1);
});
