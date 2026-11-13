// Screen-spoofing and form guards for the bank's web pages. Runs before React mounts.
// 1. Framing: the server already sends X-Frame-Options/frame-ancestors; this is the fallback for old browsers.
// 2. Foreign host: a reverse proxy can serve the real bundle under another domain and harvest what is typed.
//    On any host that is not ours the page is covered and every form is disabled.
// 3. Sensitive fields (PIN, one-time code, password): no spell/auto-correct, no copy/cut/drag out of them,
//    and PIN/OTP boxes are emptied when the tab has been hidden for 45 s.
const OURS = /^(bank\.munister\.com\.ua|localhost|127\.0\.0\.1|\[::1\]|[a-z0-9-]+\.localhost)$/;

function breakOut() {
  try { if (window.top && window.top !== window.self) window.top.location.href = window.self.location.href; } catch { /* cross-origin parent */ }
  if (window.top !== window.self) document.documentElement.style.display = 'none';
}

function coverForeignHost() {
  const box = document.createElement('div');
  box.setAttribute('role', 'alert');
  box.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:24px;background:#000;color:#fff;font:600 18px/1.4 system-ui,sans-serif;text-align:center';
  box.innerHTML = '<div style="font-size:22px">This is not the TaxTech bank</div><div style="font-weight:400;opacity:.75;max-width:420px">The address of this page is not ours. Do not type anything here. Open the bank only at bank.munister.com.ua.</div><a style="margin-top:8px;padding:12px 22px;border-radius:99px;background:#ffd400;color:#111;text-decoration:none" href="https://bank.munister.com.ua/">Go to bank.munister.com.ua</a>';
  const mount = () => { document.body.appendChild(box); document.querySelectorAll('input,textarea,button,select').forEach(e => ((e as HTMLInputElement).disabled = true)); };
  if (document.body) mount(); else document.addEventListener('DOMContentLoaded', mount, { once: true });
}

const sensitive = (el: Element): el is HTMLInputElement =>
  el instanceof HTMLInputElement && (el.type === 'password' || (el.inputMode === 'numeric' && el.maxLength > 0 && el.maxLength <= 8));
const isCode = (el: HTMLInputElement) => el.type !== 'password' || el.inputMode === 'numeric';

function harden(el: HTMLInputElement) {
  if (el.dataset.fg) return;
  el.dataset.fg = '1';
  el.setAttribute('autocapitalize', 'off'); el.setAttribute('autocorrect', 'off'); el.spellcheck = false;
  el.setAttribute('data-lpignore', 'true');
  if (isCode(el)) { el.setAttribute('autocomplete', el.maxLength === 6 ? 'one-time-code' : 'off'); }
  const stop = (e: Event) => e.preventDefault();
  el.addEventListener('copy', stop); el.addEventListener('cut', stop); el.addEventListener('dragstart', stop);
}

function clearCodes() {
  const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
  document.querySelectorAll('input').forEach(el => {
    if (!sensitive(el) || !isCode(el) || !el.value) return;
    set?.call(el, ''); el.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

export function installFormGuard() {
  if (typeof window === 'undefined') return;
  breakOut();
  if (!OURS.test(location.hostname)) { coverForeignHost(); return; }
  const scan = (root: ParentNode) => root.querySelectorAll('input').forEach(el => { if (sensitive(el)) harden(el); });
  new MutationObserver(ms => ms.forEach(m => m.addedNodes.forEach(n => {
    if (n instanceof HTMLInputElement) { if (sensitive(n)) harden(n); } else if (n instanceof HTMLElement) scan(n);
  }))).observe(document.documentElement, { childList: true, subtree: true });
  document.addEventListener('DOMContentLoaded', () => scan(document), { once: true });
  let hiddenAt = 0;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) hiddenAt = Date.now();
    else if (hiddenAt && Date.now() - hiddenAt > 45000) clearCodes();
  });
}
