/**
 * RedMed MCP — Cursor stdio entrypoint (ops / non-PHI only).
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { loadDotEnv } from "./dotenv.js";
import { SERVER_NAME, SERVER_VERSION, createRedmedServer } from "./server.js";

async function main() {
  loadDotEnv();
  const server = createRedmedServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${SERVER_NAME} v${SERVER_VERSION} listening on stdio (master)`);
}

main().catch((err) => {
  console.error("redmed-mcp failed to start:", err);
  process.exit(1);
});
