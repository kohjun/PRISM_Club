/**
 * Minimal API client for the PRISM Club admin console.
 *
 * Reads the API base URL at runtime so the same build can target
 * dev/staging/prod. Order of precedence:
 *   1. localStorage.adminApiBase (set by the login UI)
 *   2. import.meta.env.VITE_API_BASE_URL (compile-time)
 *   3. http://localhost:3000/v1 (dev default)
 */

const STORAGE_KEY_TOKEN = 'prism.admin.token';
const STORAGE_KEY_API_BASE = 'prism.admin.apiBase';
const STORAGE_KEY_SESSION = 'prism.admin.session';

export interface Session {
  user_id: string;
  nickname: string | null;
  roles: string[];
  status: string;
  issued_at: string;
  expires_at: string;
}

export function getApiBase(): string {
  const stored = localStorage.getItem(STORAGE_KEY_API_BASE);
  if (stored && stored.length > 0) return stored.replace(/\/+$/, '');
  const env = (import.meta as { env?: { VITE_API_BASE_URL?: string } }).env
    ?.VITE_API_BASE_URL;
  if (env && env.length > 0) return env.replace(/\/+$/, '');
  return 'http://localhost:3000/v1';
}

export function setApiBase(value: string): void {
  localStorage.setItem(STORAGE_KEY_API_BASE, value.replace(/\/+$/, ''));
}

export function getToken(): string | null {
  return localStorage.getItem(STORAGE_KEY_TOKEN);
}

export function getSession(): Session | null {
  const raw = localStorage.getItem(STORAGE_KEY_SESSION);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as Session;
  } catch {
    return null;
  }
}

export function setSession(token: string, session: Session): void {
  localStorage.setItem(STORAGE_KEY_TOKEN, token);
  localStorage.setItem(STORAGE_KEY_SESSION, JSON.stringify(session));
}

export function clearSession(): void {
  localStorage.removeItem(STORAGE_KEY_TOKEN);
  localStorage.removeItem(STORAGE_KEY_SESSION);
}

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init.headers as Record<string, string> | undefined),
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${getApiBase()}${path}`, { ...init, headers });
  if (!res.ok) {
    let msg = `HTTP ${res.status}`;
    try {
      const body = (await res.json()) as { error?: { message?: string } };
      if (body?.error?.message) msg = body.error.message;
    } catch {
      /* ignore */
    }
    throw new ApiError(res.status, msg);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

// --- endpoints used by the admin console ---

export interface LoginResponse {
  access_token: string;
  session: Session;
}

export async function login(userId: string): Promise<LoginResponse> {
  return request<LoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ user_id: userId }),
  });
}

export interface OpsSummary {
  pending_contributions: { count: number };
  open_reports: { count: number };
  recruitment_posts: { count_open: number; count_total: number };
  recent_users: {
    count: number;
    items: { id: string; nickname: string | null; created_at: string }[];
  };
  recent_rooms: {
    count: number;
    items: { id: string; slug: string; name: string; created_at: string }[];
  };
  recent_posts: {
    count: number;
    items: {
      id: string;
      body_preview: string;
      room_slug: string;
      created_at: string;
    }[];
  };
}

export async function fetchOpsSummary(): Promise<OpsSummary> {
  return request<OpsSummary>('/admin/ops/summary');
}

export interface ReportItem {
  id: string;
  reporter: { id: string; nickname: string | null };
  target_type: string;
  target_id: string;
  reason: string;
  status: string;
  resolution: string | null;
  created_at: string;
}

export async function fetchOpenReports(): Promise<{ items: ReportItem[] }> {
  return request<{ items: ReportItem[] }>('/admin/reports?status=OPEN');
}

export async function refreshSignals(): Promise<{
  hubs_processed: number;
  signals_written: number;
}> {
  return request('/admin/signals/refresh', { method: 'POST' });
}

export interface EventsClientStatus {
  mode: 'mock' | 'prism';
  base_url_configured: boolean;
  timeout_ms: number;
  stats: {
    parsed_ok: number;
    parse_failed: number;
    http_errors: number;
    timeouts: number;
    last_error: string | null;
    last_error_at: string | null;
  };
  note?: string;
}

export async function fetchEventsClientStatus(): Promise<EventsClientStatus> {
  return request<EventsClientStatus>('/admin/events-client/status');
}

export interface AnalyticsSummary {
  window_days: number;
  counts: { event_type: string; count: number }[];
}

export async function fetchAnalyticsSummary(): Promise<AnalyticsSummary> {
  return request<AnalyticsSummary>('/admin/analytics/summary');
}
