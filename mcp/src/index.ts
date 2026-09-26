/**
 * RedMed MCP — Cursor stdio server (ops / non-PHI only).
 *
 * Hard wall: do not add tools that store or read Assist band `#d=` /
 * medical ICE profile payloads. Profile data stays on-device + band URL.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import {
  DEFAULT_SUPABASE_URL,
  PROJECT_REF,
  createPublishableClient,
  createSecretClient,
  readEnvPresence,
  resolveSupabaseUrl,
} from "./supabase.js";

const SERVER_NAME = "redmed-mcp";
const SERVER_VERSION = "0.1.0";

function textResult(text: string, isError = false) {
  return {
    content: [{ type: "text" as const, text }],
    ...(isError ? { isError: true } : {}),
  };
}

function createServer(): McpServer {
  const server = new McpServer({
    name: SERVER_NAME,
    version: SERVER_VERSION,
  });

  server.tool(
    "redmed_ping",
    "Health check for the RedMed MCP process. Reports name/version and whether Supabase env vars are present — never echoes key material.",
    {},
    async () => {
      const presence = readEnvPresence();
      const payload = {
        ok: true,
        server: SERVER_NAME,
        version: SERVER_VERSION,
        projectRef: PROJECT_REF,
        supabaseUrl: resolveSupabaseUrl(),
        env: {
          SUPABASE_URL: presence.url,
          SUPABASE_PUBLISHABLE_KEY: presence.publishableKey,
          SUPABASE_SECRET_KEY: presence.secretKey,
        },
        productWall:
          "Assist #d= ICE profiles are not a Supabase backend. Ops/non-PHI tools only.",
      };
      return textResult(JSON.stringify(payload, null, 2));
    }
  );

  server.tool(
    "supabase_project_info",
    "Confirm RedMed Supabase project URL/ref and run a cheap reachability check against the API gateway.",
    {},
    async () => {
      const url = resolveSupabaseUrl();
      const presence = readEnvPresence();
      const healthUrl = `${url.replace(/\/$/, "")}/auth/v1/health`;

      let reachable = false;
      let httpStatus: number | null = null;
      let detail = "";

      try {
        const headers: Record<string, string> = {
          Accept: "application/json",
        };
        const key =
          process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ||
          process.env.SUPABASE_SECRET_KEY?.trim();
        if (key) {
          headers.apikey = key;
          headers.Authorization = `Bearer ${key}`;
        }
        const res = await fetch(healthUrl, { headers });
        httpStatus = res.status;
        reachable = res.ok;
        const body = await res.text();
        detail = body.slice(0, 200);
        if (!key) {
          // Still useful: missing keys is a config signal even if health responds.
          detail = detail || "No publishable/secret key in env; request may be rejected.";
        }
      } catch (err) {
        detail = err instanceof Error ? err.message : String(err);
      }

      // Optional second probe via supabase-js when publishable key exists.
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

      const payload = {
        projectRef: PROJECT_REF,
        supabaseUrl: url,
        defaultUrl: DEFAULT_SUPABASE_URL,
        healthUrl,
        reachable,
        httpStatus,
        publishableClientOk,
        env: {
          SUPABASE_URL: presence.url,
          SUPABASE_PUBLISHABLE_KEY: presence.publishableKey,
          SUPABASE_SECRET_KEY: presence.secretKey,
        },
        detail: detail || null,
      };

      return textResult(JSON.stringify(payload, null, 2), !reachable);
    }
  );

  server.tool(
    "supabase_list_tables",
    "List public schema tables exposed by PostgREST (OpenAPI). Uses the secret key. Empty project → empty list.",
    {},
    async () => {
      const presence = readEnvPresence();
      if (!presence.secretKey) {
        return textResult(
          JSON.stringify(
            {
              error: "Missing SUPABASE_SECRET_KEY",
              tables: [],
              hint: "Set the secret key in the MCP process env (never commit it).",
            },
            null,
            2
          ),
          true
        );
      }

      // Ensure client can be constructed (validates key present).
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
          return textResult(
            JSON.stringify(
              {
                error: `OpenAPI fetch failed HTTP ${res.status}`,
                detail: body.slice(0, 300),
                tables: [],
              },
              null,
              2
            ),
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

        return textResult(
          JSON.stringify(
            {
              projectRef: PROJECT_REF,
              schema: "public",
              tableCount: tables.length,
              tables,
            },
            null,
            2
          )
        );
      } catch (err) {
        return textResult(
          JSON.stringify(
            {
              error: err instanceof Error ? err.message : String(err),
              tables: [],
            },
            null,
            2
          ),
          true
        );
      }
    }
  );

  return server;
}

async function main() {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${SERVER_NAME} v${SERVER_VERSION} listening on stdio`);
}

main().catch((err) => {
  console.error("redmed-mcp failed to start:", err);
  process.exit(1);
});
