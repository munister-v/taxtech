import {StrictMode, Suspense, lazy, useEffect, useState} from 'react';
import {createRoot} from 'react-dom/client';
import BankLanding from './BankLanding';

// A logged-out visitor gets only the landing; the banking app (App.tsx, most of the bundle) loads in its own chunk,
// fetched while the browser is idle or when the visitor taps log in / sign up.
type AuthView = 'login' | 'register';
const loadApp = () => import('./App.tsx');
const App = lazy(() => loadApp().then(m => ({
  default: (p: { initialAuthView?: AuthView }) => <m.ErrorBoundary><m.default {...p} /></m.ErrorBoundary>,
})));

function hasToken() {
  try { return !!localStorage.getItem('army_bank_token'); } catch { return false; }
}

function Root() {
  const [view, setView] = useState<AuthView | 'app' | null>(() =>
    hasToken() || location.hash === '#login' || location.hash === '#register' ? 'app' : null);
  useEffect(() => {
    if (view) return;
    // The app chunk is prefetched after the page has settled, and not at all on a saver/slow connection.
    const net = (navigator as Navigator & { connection?: { saveData?: boolean; effectiveType?: string } }).connection;
    if (net?.saveData || /(^|-)2g$/.test(net?.effectiveType ?? '')) return;
    const run = () => { loadApp().catch(() => {}); };
    const go = () => { if (window.requestIdleCallback) window.requestIdleCallback(run, { timeout: 6000 }); else window.setTimeout(run, 4000); };
    if (document.readyState === 'complete') go(); else window.addEventListener('load', go, { once: true });
  }, [view]);
  if (!view) return <BankLanding onAuth={setView} />;
  return (
    <Suspense fallback={<div style={{ position: 'fixed', inset: 0, background: '#000' }} />}>
      <App initialAuthView={view === 'app' ? undefined : view} />
    </Suspense>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
);
