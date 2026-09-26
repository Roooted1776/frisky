/**
 * Tiny .env loader (no dependency). Does not override existing process.env.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function loadDotEnv(fromDir?: string): void {
  const dir =
    fromDir ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const envPath = path.join(dir, ".env");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = val;
  }
}
