import { useEffect, useRef, useState } from 'react';
import './appShowcase.css';

// The app, shown the way it is: real screens of the iOS app (taken in the Simulator against a local demo account,
// web/public/landing/app-*.webp) in an iPhone frame on a light stage. Pills switch the screen; while the section is
// on screen it walks through them by itself until someone picks one. The QR tab plays the payment: the invoice,
// then "Paid" with the authorisation code.

type Tab = { id: 'home' | 'card' | 'qr'; frames: string[] };
const TABS: Tab[] = [
  { id: 'home', frames: ['/landing/app-s-home.webp'] },
  { id: 'card', frames: ['/landing/app-s-card-designs.webp'] },
  { id: 'qr', frames: ['/landing/app-s-qr-confirm.webp', '/landing/app-s-qr-paid.webp'] },
];
const STEP = 4200;

export default function AppShowcase({ t }: { t: (uk: string, en: string) => string }) {
  const box = useRef<HTMLElement>(null);
  const [tab, setTab] = useState(0);
  const [frame, setFrame] = useState(0);
  const [seen, setSeen] = useState(false);
  const [held, setHeld] = useState(false);       // a pill was clicked: no more autoplay

  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setSeen(e.isIntersecting), { threshold: .2 });
    io.observe(el);
    return () => io.disconnect();
  }, []);

  // the QR tab: the invoice first, then the payment goes through
  useEffect(() => {
    setFrame(0);
    if (TABS[tab].frames.length < 2 || !seen) return;
    const id = window.setTimeout(() => setFrame(1), 1700);
    return () => clearTimeout(id);
  }, [tab, seen]);

  useEffect(() => {
    if (!seen || held) return;
    const id = window.setTimeout(() => setTab(x => (x + 1) % TABS.length), TABS[tab].frames.length > 1 ? STEP + 1400 : STEP);
    return () => clearTimeout(id);
  }, [tab, seen, held]);

  const label = (id: Tab['id']) => (id === 'home' ? t('Рахунок', 'Account') : id === 'card' ? t('Картки', 'Cards') : 'QR');

  return (
    <section id="app" className="as" ref={box}>
      <div className="as-in">
        <div className="as-copy">
        <h2 className="as-h">{t('Усе в застосунку.', 'All in the app.')}</h2>
        <div className="as-pills" role="tablist">
          {TABS.map((x, i) => (
            <button key={x.id} type="button" role="tab" aria-selected={tab === i} className={tab === i ? 'on' : ''}
              onClick={() => { setHeld(true); setTab(i); }}>{label(x.id)}</button>
          ))}
        </div>
        <a className="as-store" href="https://apps.apple.com/ua/app/tax-tech-digital-finance-lab/id6830268604" target="_blank" rel="noreferrer">
          <img src="/app-store-black.svg" alt="App Store" width="168" height="56" loading="lazy" decoding="async" />
        </a>
        </div>
        <div className="as-stage"
          onPointerMove={e => { const r = e.currentTarget.getBoundingClientRect(); e.currentTarget.style.setProperty('--ry', `${(((e.clientX - r.left) / r.width - .5) * 14).toFixed(1)}deg`); e.currentTarget.style.setProperty('--rx', `${(-((e.clientY - r.top) / r.height - .5) * 8).toFixed(1)}deg`); }}
          onPointerLeave={e => { e.currentTarget.style.removeProperty('--ry'); e.currentTarget.style.removeProperty('--rx'); }}>
          <div className="as-glow" aria-hidden />
          <div className="as-chip as-chip-a" aria-hidden><i>✓</i><span><b>Saint Agnes</b><small>−144.90 TAX</small></span></div>
          <div className="as-chip as-chip-b" aria-hidden><i>❄</i><span><b>{t('Картку заморожено', 'Card frozen')}</b><small>•• 8632</small></span></div>
          <div className="as-chip as-chip-c" aria-hidden><i>+</i><span><b>{t('Поповнення', 'Top up')}</b><small>+1 000 TAX</small></span></div>
          <div className="as-phone as-phone-2" aria-hidden>
            <div className="as-screen">
              {TABS.map((x, i) => x.frames.map((src, k) => (
                <img key={src} src={src} fetchPriority="low" alt={''} width="600" height="1304" decoding="async"
                  className={i === (tab + 1) % TABS.length && (k === 0) ? 'on' : ''} />
              )))}
            </div>
            <i className="as-btn as-btn-a" aria-hidden /><i className="as-btn as-btn-b" aria-hidden /><i className="as-btn as-btn-c" aria-hidden />
          </div>
          <div className="as-phone">
            <div className="as-screen">
              {TABS.map((x, i) => x.frames.map((src, k) => (
                <img key={src} src={src} fetchPriority="low" alt={i === tab && k === frame ? label(x.id) : ''} width="600" height="1304" decoding="async"
                  className={i === tab && (k === frame) ? 'on' : ''} />
              )))}
            </div>
            <i className="as-btn as-btn-a" aria-hidden /><i className="as-btn as-btn-b" aria-hidden /><i className="as-btn as-btn-c" aria-hidden />
          </div>
          <div className="as-floor" aria-hidden />
        </div>
      </div>
    </section>
  );
}
