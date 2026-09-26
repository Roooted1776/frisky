/**
 * Hostinger REST helpers (developers.hostinger.com).
 * Ops only — static Assist + VPS control plane. No Assist/#d= PHI.
 */

import { resolveHostingerToken } from "./env.js";

const API_BASE = "https://developers.hostinger.com";

export const REDMED_DOMAIN = "redmed.live";
export const REDMED_VPS_ID = 2010795;
export const REDMED_VPS_IP = "2.25.249.204";

export type HostingerFetchResult<T> = {
  ok: boolean;
  httpStatus: number | null;
  data: T | null;
  error: string | null;
};

async function hostingerFetch<T>(
  path: string,
  init?: RequestInit
): Promise<HostingerFetchResult<T>> {
  const token = resolveHostingerToken();
  if (!token) {
    return {
      ok: false,
      httpStatus: null,
      data: null,
      error: "Missing HOSTINGER_API_TOKEN (env or ~/.config/hostinger-mcp/api_token)",
    };
  }

  try {
    const res = await fetch(`${API_BASE}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        ...(init?.headers ?? {}),
      },
    });
    const text = await res.text();
    let parsed: unknown = null;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = text;
    }
    if (!res.ok) {
      return {
        ok: false,
        httpStatus: res.status,
        data: null,
        error:
          typeof parsed === "object" && parsed && "message" in parsed
            ? String((parsed as { message: unknown }).message)
            : text.slice(0, 300),
      };
    }
    return { ok: true, httpStatus: res.status, data: parsed as T, error: null };
  } catch (err) {
    return {
      ok: false,
      httpStatus: null,
      data: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export type VirtualMachine = {
  id: number;
  hostname?: string;
  plan?: string;
  state?: string;
  ipv4?: { address?: string }[];
  template?: { name?: string };
};

export async function listVirtualMachines(): Promise<
  HostingerFetchResult<VirtualMachine[]>
> {
  return hostingerFetch<VirtualMachine[]>("/api/vps/v1/virtual-machines");
}

export async function getVirtualMachine(
  id: number
): Promise<HostingerFetchResult<VirtualMachine>> {
  return hostingerFetch<VirtualMachine>(`/api/vps/v1/virtual-machines/${id}`);
}

export type WebsiteRow = {
  domain?: string;
  username?: string;
  website_type?: string;
  is_enabled?: boolean;
};

export type WebsiteList = {
  data?: WebsiteRow[];
  meta?: { total?: number };
};

export async function listWebsites(domain?: string): Promise<
  HostingerFetchResult<WebsiteList>
> {
  const q = new URLSearchParams({ page: "1", per_page: "50" });
  if (domain) q.set("domain", domain);
  return hostingerFetch<WebsiteList>(`/api/hosting/v1/websites?${q}`);
}

export type Subscription = {
  id?: string;
  name?: string;
  status?: string;
  next_billing_at?: string | null;
};

export async function listSubscriptions(): Promise<
  HostingerFetchResult<Subscription[]>
> {
  return hostingerFetch<Subscription[]>("/api/billing/v1/subscriptions");
}

export async function getDnsRecords(
  domain: string
): Promise<HostingerFetchResult<unknown>> {
  return hostingerFetch(`/api/dns/v1/${encodeURIComponent(domain)}`);
}
