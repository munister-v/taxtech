import { initialLandingLang, type LandingLang } from './landingLang';
import { APP_I18N } from './appI18nData';

// Strings written inline in App.tsx as tr('українською', 'in English'). Ukrainian and English stay next to the
// markup; Italian, German and Russian are looked up by the English string (appI18nData.ts), falling back to English.
// The app root sets the current language on every render, so components need no extra prop or context.

let current: LandingLang = initialLandingLang();

export function setTrLang(l: LandingLang) { current = l; }

// The server writes receipts, statements, PDFs and operation texts in the language of the request: ?lang or
// Accept-Language. A browser sends its own system language (a phone set to Russian sends ru even when the app is in
// English), so every call to our API carries the app's language instead.
if (typeof window !== 'undefined' && !(window.fetch as { __lang?: boolean }).__lang) {
  const orig = window.fetch.bind(window);
  const patched = (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    let ours = false;
    try {
      const u = new URL(url, location.href);
      const base = (window as { ARMY_BANK_BASE?: string }).ARMY_BANK_BASE;
      const apiOrigin = base ? new URL(base, location.href).origin : location.origin;
      ours = u.pathname.startsWith('/api/') && (u.origin === location.origin || u.origin === apiOrigin);
    } catch { /* not a URL */ }
    if (!ours) return orig(input, init);
    const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined));
    headers.set('Accept-Language', current);
    return orig(input, { ...init, headers });
  };
  (patched as { __lang?: boolean }).__lang = true;
  window.fetch = patched as typeof window.fetch;
}
export function trLang(): LandingLang { return current; }

export function tr(uk: string, en: string): string {
  if (current === 'uk') return uk;
  if (current === 'en') return en;
  return APP_I18N[current][en] ?? en;
}
