/**
 * RedMed MCP — Streamable HTTP entrypoint for the VPS (ops / non-PHI only).
 *
 * Listens on REDMED_MCP_PORT (default 8787), path /mcp.
 * Requires Authorization: Bearer $REDMED_MCP_TOKEN on every request.
 */

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

import { loadDotEnv } from "./dotenv.js";
import { SERVER_NAME, SERVER_VERSION, createRedmedServer } from "./server.js";

const PATH = "/mcp";
const DEFAULT_PORT = 8787;

function readBearer(req: IncomingMessage): string | null {
  const raw = req.headers.authorization;
  if (!raw) return null;
  const m = /^Bearer\s+(.+)$/i.exec(raw.trim());
  return m?.[1]?.trim() || null;
}

function sendJson(
  res: ServerResponse,
  status: number,
  body: unknown
): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

function unauthorized(res: ServerResponse): void {
  sendJson(res, 401, {
    jsonrpc: "2.0",
    error: { code: -32001, message: "Unauthorized" },
    id: null,
  });
}

function methodNotAllowed(res: ServerResponse): void {
  sendJson(res, 405, {
    jsonrpc: "2.0",
    error: { code: -32000, message: "Method not allowed" },
    id: null,
  });
}

async function handleMcp(
  req: IncomingMessage,
  res: ServerResponse
): Promise<void> {
  const token = process.env.REDMED_MCP_TOKEN?.trim();
  if (!token) {
    sendJson(res, 503, {
      jsonrpc: "2.0",
      error: { code: -32002, message: "REDMED_MCP_TOKEN not configured" },
      id: null,
    });
    return;
  }
  if (readBearer(req) !== token) {
    unauthorized(res);
    return;
  }

  const server = createRedmedServer();
  // Stateless: one transport per request (matches createRedmedServer-per-request).
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  });

  res.on("close", () => {
    void transport.close();
    void server.close();
  });

  try {
    await server.connect(transport);
    await transport.handleRequest(req, res);
  } catch (err) {
    console.error("MCP request failed:", err);
    if (!res.headersSent) {
      sendJson(res, 500, {
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error" },
        id: null,
      });
    }
  }
}

async function main() {
  loadDotEnv();

  if (!process.env.REDMED_MCP_TOKEN?.trim()) {
    console.error("redmed-mcp http: set REDMED_MCP_TOKEN before starting");
    process.exit(1);
  }

  // Remote container defaults to local shell unless explicitly overridden.
  if (!process.env.REDMED_EXEC_MODE?.trim()) {
    process.env.REDMED_EXEC_MODE = "local";
  }

  const port = Number(process.env.REDMED_MCP_PORT?.trim() || DEFAULT_PORT) || DEFAULT_PORT;
  const host = process.env.REDMED_MCP_HOST?.trim() || "0.0.0.0";

  const httpServer = createServer((req, res) => {
    const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
    if (url.pathname === "/healthz") {
      sendJson(res, 200, {
        ok: true,
        server: SERVER_NAME,
        version: SERVER_VERSION,
        path: PATH,
      });
      return;
    }
    if (url.pathname !== PATH) {
      sendJson(res, 404, { error: "Not found" });
      return;
    }
    if (req.method !== "POST" && req.method !== "GET" && req.method !== "DELETE") {
      methodNotAllowed(res);
      return;
    }
    void handleMcp(req, res);
  });

  httpServer.listen(port, host, () => {
    console.error(
      `${SERVER_NAME} v${SERVER_VERSION} Streamable HTTP on http://${host}:${port}${PATH}`
    );
  });
}

main().catch((err) => {
  console.error("redmed-mcp http failed to start:", err);
  process.exit(1);
});
