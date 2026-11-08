import React, { useEffect, useRef, useState } from 'react';

// Saint Agnes as a shop window on the street: stone front, fascia and awning, a brass frame around the glass, a lit
// room with the lookbook on the back wall, four pieces on plinths with hanging price tags. Pointer movement shifts the
// layers (depth) and the reflection on the glass; the OPEN plaque switches the lights; a piece opens a card on the
// glass where TaxPay is tapped and the debit arrives as the app sends it.

export type WindowItem = { id: number; title: string; price: number | string; image_url?: string };

type Props = {
  items: WindowItem[];
  wall: string;
  t: (uk: string, en: string) => string;
  fmt: (n: number) => string;
  push: (merchant: string, amount: number, bal: number) => React.ReactNode;
};

// "Women's Jacket MC2 SAINT BARTH (grey)" -> brand "MC2 SAINT BARTH", name "Women's Jacket"
const split = (title: string) => {
  const name = title.replace(/\s*\([^)]*\)\s*$/, '');
  const brand = name.match(/\s([A-Z0-9][A-Z0-9 .&'-]+)$/)?.[1] || '';
  return { brand, name: (brand ? name.slice(0, -brand.length) : name).trim() };
};

const BALANCE = 24000;
type Pay = 'idle' | 'tap' | 'paid';

export default function ShopWindow({ items, wall, t, fmt, push }: Props) {
  const root = useRef<HTMLDivElement>(null);
  const [on, setOn] = useState(false);          // the window lights
  const [pick, setPick] = useState<number | null>(null);
  const [pay, setPay] = useState<Pay>('idle');
  const still = useRef(false);

  // The lights come on when the window is in view, one lamp after another.
  useEffect(() => {
    const el = root.current;
    if (!el) return;
    still.current = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) { setOn(true); io.disconnect(); } },
      { root: el.closest('.bl'), threshold: 0.35 });
    io.observe(el);
    return () => io.disconnect();
  }, []);

  // Depth: the layers move against the pointer, the glass reflection follows it.
  useEffect(() => {
    const el = root.current;
    if (!el || !window.matchMedia('(hover: hover) and (pointer: fine)').matches || still.current) return;
    let raf = 0, nx = 0, ny = 0;
    const apply = () => { raf = 0; el.style.setProperty('--mx', nx.toFixed(3)); el.style.setProperty('--my', ny.toFixed(3)); };
    const move = (e: PointerEvent) => {
      const r = el.getBoundingClientRect();
      nx = ((e.clientX - r.left) / r.width) * 2 - 1;
      ny = ((e.clientY - r.top) / r.height) * 2 - 1;
      if (!raf) raf = requestAnimationFrame(apply);
    };
    const leave = () => { nx = 0; ny = 0; if (!raf) raf = requestAnimationFrame(apply); };
    el.addEventListener('pointermove', move);
    el.addEventListener('pointerleave', leave);
    return () => { el.removeEventListener('pointermove', move); el.removeEventListener('pointerleave', leave); if (raf) cancelAnimationFrame(raf); };
  }, []);

  useEffect(() => {
    if (pick === null) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setPick(null); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pick]);

  useEffect(() => { setPay('idle'); }, [pick]);

  const tapToPay = () => {
    if (pay !== 'idle') return;
    setPay('tap');
    window.setTimeout(() => setPay('paid'), still.current ? 200 : 1150);
  };

  const pieces = items.length ? items : Array.from({ length: 4 }, (_, i) => ({ id: -i } as WindowItem));
  const cur = pick !== null ? items[pick] : undefined;
  const info = cur?.title ? split(cur.title) : null;
  const price = Number(cur?.price) || 0;

  return (
    <div className={`bl-vt${on ? ' on' : ''}${pick !== null ? ' has-pick' : ''}`} ref={root} style={{ ['--n' as string]: pieces.length }}>
      <div className="bl-vt-fascia" aria-hidden><span>SAINT AGNES</span></div>
      <div className="bl-vt-awning" aria-hidden><i /></div>
      <div className="bl-vt-frame">
        <div className="bl-vt-room" onClick={e => { if (!(e.target as HTMLElement).closest('.bl-vt-piece, .bl-vt-card, .bl-vt-open')) setPick(null); }}>
          <img className="bl-vt-wall" src={wall} alt="" loading="lazy" decoding="async" />
          <div className="bl-vt-ambient" aria-hidden />
          <div className="bl-vt-beams" aria-hidden>{pieces.map((p, k) => <i key={k} style={{ ['--k' as string]: k }} />)}</div>
          <div className="bl-vt-track" aria-hidden>{pieces.map((p, k) => <i key={k} style={{ ['--k' as string]: k }} />)}</div>

          <button type="button" className="bl-vt-open" aria-pressed={on} aria-label={t('Світло у вітрині', 'Window lights')}
            onClick={() => setOn(v => !v)}>
            <i aria-hidden />
            <span key={String(on)}>{on ? t('Відчинено', 'Open') : t('Зачинено', 'Closed')}</span>
          </button>

          <div className="bl-vt-scene">
            {pieces.map((p, k) => {
              const s = p.title ? split(p.title) : null;
              return (
                <button key={p.id} type="button" className={`bl-vt-piece${pick === k ? ' picked' : ''}`} style={{ ['--k' as string]: k }}
                  disabled={!p.title} aria-label={p.title ? `${s?.name}, ${fmt(Number(p.price))} TAX` : undefined}
                  onClick={() => setPick(pick === k ? null : k)}>
                  <span className="bl-vt-lb">{p.image_url && <img src={p.image_url} alt="" loading="lazy" decoding="async" />}</span>
                  {p.title && (
                    <span className="bl-vt-tag" aria-hidden>
                      <i />
                      <u><small>{s?.brand || 'Saint Agnes'}</small><b>{fmt(Number(p.price))} <em>TAX</em></b></u>
                    </span>
                  )}
                  <span className="bl-vt-plinth" aria-hidden />
                </button>
              );
            })}
          </div>

          <div className="bl-vt-floor" aria-hidden />
          <div className="bl-vt-glass" aria-hidden />

          {cur && info && (
            <div className="bl-vt-card" role="dialog" aria-label={info.name} data-side={pick !== null && pick < pieces.length / 2 ? 'r' : 'l'}>
              <button type="button" className="bl-vt-x" aria-label={t('Закрити', 'Close')} onClick={() => setPick(null)}><i aria-hidden /></button>
              <small>{info.brand || 'Saint Agnes'}</small>
              <h3>{info.name}</h3>
              <b>{fmt(price)} <em>TAX</em></b>
              <button type="button" className={`bl-vt-pay ${pay}`} onClick={tapToPay} disabled={pay !== 'idle'}>
                <span className="bl-vt-ripple" aria-hidden />
                <span>{pay === 'paid' ? `✓ ${t('Сплачено', 'Paid')}` : pay === 'tap' ? '· · ·' : t('Сплатити через TaxPay', 'Pay with TaxPay')}</span>
              </button>
              {pay === 'paid' && <div className="bl-toast bl-push bl-vt-paid" role="status">{push('Saint Agnes', price, BALANCE - price)}</div>}
            </div>
          )}
        </div>
      </div>
      <div className="bl-vt-step" aria-hidden />
    </div>
  );
}
