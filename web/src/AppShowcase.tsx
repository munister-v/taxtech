import { useEffect, useRef, useState } from 'react';
import './appShowcase.css';

// The app, shown the way it is: real screens of the iOS app (taken in the Simulator against a local demo account,
// web/public/landing/app-*.webp) in an iPhone frame on a light stage. Pills switch the screen; while the section is
// on screen it walks through them by itself until someone picks one. The QR tab plays the payment: the invoice,
// then "Paid" with the authorisation code.

type Tab = { id: 'home' | 'card' | 'qr'; frames: string[] };
const TABS: Tab[] = [
  { id: 'home', frames: ['/landing/app-home.webp'] },
  { id: 'card', frames: ['/landing/app-card-designs.webp'] },
  { id: 'qr', frames: ['/landing/app-qr-confirm.webp', '/landing/app-qr-paid.webp'] },
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

  const label = (id: Tab['id']) => (id === 'home' ? t('Рахунок', 'Account') : id === 'card' ? t('Картка', 'Card') : 'QR');

  return (
    <section id="app" className="as" ref={box}>
      <div className="as-in">
        <div className="as-copy">
        <h2 className="as-h">{t('Усе в застосунку.', 'All in the app.')}</h2>
        <p className="as-sub">{t('Рахунок, картки й оплата за QR — на iPhone.', 'Account, cards and QR payments on your iPhone.')}</p>
        <div className="as-pills" role="tablist">
          {TABS.map((x, i) => (
            <button key={x.id} type="button" role="tab" aria-selected={tab === i} className={tab === i ? 'on' : ''}
              onClick={() => { setHeld(true); setTab(i); }}>{label(x.id)}</button>
          ))}
        </div>
        <a className="as-store" href="https://apps.apple.com/ua/app/tax-tech-digital-finance-lab/id6830268604" target="_blank" rel="noreferrer">
          <img src="/app-store-black.svg" alt="App Store" width="168" height="56" loading="lazy" decoding="async" />
          <span>Tax Tech: Digital Finance Lab</span>
        </a>
        </div>
        <div className="as-stage">
          <div className="as-phone">
            <div className="as-screen">
              {TABS.map((x, i) => x.frames.map((src, k) => (
                <img key={src} src={src} fetchPriority="low" alt={i === tab && k === frame ? label(x.id) : ''} width="600" height="1304" decoding="async"
                  className={i === tab && (k === frame || (k === 0 && frame === 0)) ? 'on' : ''} />
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
