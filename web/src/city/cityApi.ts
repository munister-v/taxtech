// Small fetch helper shared by Roma Live (/roma) and the QR payment page (/pay/<code>): the bank's Bearer token
// from localStorage when there is one, the session cookie and its CSRF header otherwise.

export const token = () => { try { return localStorage.getItem('army_bank_token') || ''; } catch { return ''; } };
const csrf = () => document.cookie.split('; ').find(c => c.startsWith('kp_csrf='))?.slice(8) || '';

export type ApiErr = Error & { status?: number };

export async function api<T>(path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const tk = token();
  if (tk) headers.Authorization = `Bearer ${tk}`;
  const c = csrf();
  if (c) headers['X-CSRF-Token'] = decodeURIComponent(c);
  const r = await fetch(path, { method: body ? 'POST' : 'GET', credentials: 'include', headers, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => null);
  if (!r.ok || !j?.ok) { const e: ApiErr = new Error(j?.error || String(r.status)); e.status = r.status; throw e; }
  return j.data as T;
}

/** Remember where to come back to after signing in (App.tsx reads it in onLogin). */
export const returnHere = (path = location.pathname) => { try { sessionStorage.setItem('tt-after-login', path); } catch { /* ignore */ } };

export type PayRes = {
  outcome: 'approved' | 'declined' | 'sca_required' | 'closed'; approved?: boolean; response_code?: string; message?: string;
  new_balance?: number; id?: number; auth_code?: string; rrn?: string; fee?: number; three_ds?: boolean;
};
export type QrInvoice = {
  code: string; venue: number; name: string; cat: string; rione: string; amount: number; sca: boolean;
  status: 'pending' | 'processing' | 'paid' | 'declined' | 'expired' | 'cancelled'; expires_in: number;
  response_code?: string; auth_code?: string; rrn?: string; who?: string; three_ds?: boolean;
};
export type Me = { name: string; who: string; balance: number; card_id: number | null; card_last4: string | null; payments: { id: number }[] };
