/**
 * Supabase clients for the RedMed MCP process only.
 *
 * Product wall: Assist band `#d=` ICE profiles are NOT a Supabase backend.
 * Never store or read medical card / `#d=` payloads through these clients.
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export const PROJECT_REF = "mohxobgyjkcmkqxijgeg";
export const DEFAULT_SUPABASE_URL = `https://${PROJECT_REF}.supabase.co`;

export type EnvPresence = {
  url: boolean;
  publishableKey: boolean;
  secretKey: boolean;
};

export function readEnvPresence(): EnvPresence {
  return {
    url: Boolean(process.env.SUPABASE_URL?.trim()),
    publishableKey: Boolean(process.env.SUPABASE_PUBLISHABLE_KEY?.trim()),
    secretKey: Boolean(process.env.SUPABASE_SECRET_KEY?.trim()),
  };
}

export function resolveSupabaseUrl(): string {
  const fromEnv = process.env.SUPABASE_URL?.trim();
  return fromEnv || DEFAULT_SUPABASE_URL;
}

function requireKey(name: "SUPABASE_PUBLISHABLE_KEY" | "SUPABASE_SECRET_KEY"): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(
      `Missing ${name}. Set it in the environment (or mcp/.env) — never commit keys.`
    );
  }
  return value;
}

/** RLS-respecting client (publishable key). */
export function createPublishableClient(): SupabaseClient {
  return createClient(resolveSupabaseUrl(), requireKey("SUPABASE_PUBLISHABLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Elevated client (secret key). MCP process only — bypasses RLS. */
export function createSecretClient(): SupabaseClient {
  return createClient(resolveSupabaseUrl(), requireKey("SUPABASE_SECRET_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
