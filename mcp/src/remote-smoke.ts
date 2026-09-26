/**
 * One-shot remote MCP smoke against Streamable HTTP.
 *   REDMED_MCP_TOKEN=… npx tsx src/remote-smoke.ts [url]
 */
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

import { loadDotEnv } from "./dotenv.js";

async function main() {
  loadDotEnv();
  const token = process.env.REDMED_MCP_TOKEN?.trim();
  if (!token) throw new Error("REDMED_MCP_TOKEN required");
  const url = new URL(
    process.argv[2] || "https://srv2010795.hstgr.cloud/mcp"
  );
  const transport = new StreamableHTTPClientTransport(url, {
    requestInit: { headers: { Authorization: `Bearer ${token}` } },
  });
  const client = new Client({ name: "redmed-remote-smoke", version: "0.2.0" });
  await client.connect(transport);
  const tools = await client.listTools();
  console.log(
    JSON.stringify(
      { url: url.href, tools: tools.tools.map((t) => t.name) },
      null,
      2
    )
  );
  const probe = await client.callTool({
    name: "hostinger_ssh_probe",
    arguments: {},
  });
  console.log(JSON.stringify(probe, null, 2));
  const text = JSON.stringify(probe);
  if (!text.includes("srv2010795") && !text.includes("REDMED_SSH_OK")) {
    throw new Error("hostinger_ssh_probe did not return VPS hostname");
  }
  console.error("Remote smoke: ok");
  await client.close();
}

main().catch((err) => {
  console.error("Remote smoke failed:", err);
  process.exit(1);
});
