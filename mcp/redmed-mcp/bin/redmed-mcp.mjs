#!/usr/bin/env node
/**
 * redmed-mcp v0.2 — stdio MCP server for RedMed ops.
 * Product wall: refuse ICE / #d= / PHI handling.
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FORBIDDEN =
  /\b(#d=|ice\s*profile|medical\s*card|phi|health\s*record|patient\s*data)\b/i;

const BLOCKED_SSH =
  /\b(rm\s+-rf\s+\/|mkfs|dd\s+if=|shutdown|reboot|userdel|passwd\s|iptables\s+-F|ufw\s+reset)\b/i;

function wallCheck(text) {
  if (text && FORBIDDEN.test(text)) {
    return 'Blocked by RedMed product wall: do not pass Assist #d= / ICE / PHI through MCP.';
  }
  return null;
}

const server = new McpServer({
  name: 'redmed-mcp',
  version: '0.2.0',
});

server.tool(
  'redmed_stack_status',
  'Read-only status of Assist hosts, DNS, backup github.io, and ops pointers. Never returns profile data.',
  {},
  async () => {
    const script = path.join(__dirname, 'redmed-stack-status.mjs');
    const r = spawnSync(process.execPath, [script], { encoding: 'utf8', timeout: 45000 });
    const out = (r.stdout || '') + (r.stderr || '');
    return {
      content: [{ type: 'text', text: out || `exit ${r.status}` }],
    };
  },
);

server.tool(
  'supabase_ops_status',
  'Ops-only Supabase pointer. Confirms project ref; does not read medical rows.',
  {
    note: z.string().optional().describe('Optional ops note (no PHI)'),
  },
  async ({ note }) => {
    const blocked = wallCheck(note || '');
    if (blocked) {
      return { content: [{ type: 'text', text: blocked }], isError: true };
    }
    const ref = process.env.REDMED_SUPABASE_REF || 'mohxobgyjkcmkqxijgeg';
    const text = JSON.stringify(
      {
        project: 'RedMed Secure Data',
        ref,
        role: 'ops-metadata-only',
        productWall: 'Zero ICE/PHI profiles in this project',
        note: note || null,
      },
      null,
      2,
    );
    return { content: [{ type: 'text', text }] };
  },
);

server.tool(
  'hostinger_ssh_exec',
  'Run a non-destructive command on the RedMed ops VPS. Destructive patterns are refused. Never use for Assist deploy of #d= data.',
  {
    command: z.string().describe('Shell command to run on the VPS'),
  },
  async ({ command }) => {
    const blocked = wallCheck(command);
    if (blocked) {
      return { content: [{ type: 'text', text: blocked }], isError: true };
    }
    if (BLOCKED_SSH.test(command)) {
      return {
        content: [
          {
            type: 'text',
            text: 'Blocked: command matches destructive pattern. Confirm with Max and use an explicit allow-list path.',
          },
        ],
        isError: true,
      };
    }
    const host = process.env.REDMED_SSH_HOST || '2.25.249.204';
    const key = process.env.REDMED_SSH_KEY || `${process.env.HOME}/.ssh/hostinger_vps`;
    const user = process.env.REDMED_SSH_USER || 'root';
    try {
      const out = execFileSync(
        'ssh',
        [
          '-i',
          key,
          '-o',
          'BatchMode=yes',
          '-o',
          'StrictHostKeyChecking=accept-new',
          '-o',
          'ConnectTimeout=15',
          `${user}@${host}`,
          command,
        ],
        { encoding: 'utf8', timeout: 60000, maxBuffer: 2 * 1024 * 1024 },
      );
      return { content: [{ type: 'text', text: out.slice(0, 100_000) }] };
    } catch (e) {
      return {
        content: [
          {
            type: 'text',
            text: `SSH failed: ${e.message}\n${e.stdout || ''}\n${e.stderr || ''}`,
          },
        ],
        isError: true,
      };
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
