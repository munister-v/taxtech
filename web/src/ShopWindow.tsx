import React, { useCallback, useEffect, useRef, useState } from 'react';

// Saint Agnes, one piece at a time: a wide lookbook frame, then a horizontal rail where each piece takes the whole row —
// large photo, large type, TaxPay under the price. Scroll or use the arrows; the debit arrives as the app sends it.

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
type Pay = 'tap' | 'paid';

export default function ShopWindow({ items, wall, t, fmt, push }: Props) {
  const rail = useRef<HTMLDivElement>(null);
  const [cur, setCur] = useState(0);
  const [pay, setPay] = useState<Record<number, Pay>>({});
  const still = useRef(false);

  useEffect(() => { still.current = window.matchMedia('(prefers-reduced-motion: reduce)').matches; }, []);

  useEffect(() => {
    const el = rail.current;
    if (!el) return;
    let raf = 0;
    const on = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => { raf = 0; setCur(Math.round(el.scrollLeft / Math.max(1, el.clientWidth))); });
    };
    el.addEventListener('scroll', on, { passive: true });
    return () => { el.removeEventListener('scroll', on); if (raf) cancelAnimationFrame(raf); };
  }, []);

  const go = useCallback((k: number) => {
    const el = rail.current;
    if (!el) return;
    const n = Math.max(0, Math.min(items.length - 1, k));
    el.scrollTo({ left: n * el.clientWidth, behavior: still.current ? 'auto' : 'smooth' });
  }, [items.length]);

  const tapToPay = (id: number) => {
    if (pay[id]) return;
    setPay(p => ({ ...p, [id]: 'tap' }));
    window.setTimeout(() => setPay(p => ({ ...p, [id]: 'paid' })), still.current ? 200 : 1150);
  };

  const n = items.length;

  return (
    <div className="bl-vt">
      <div className="bl-vt-look bl-rv"><img src={wall} alt="" loading="lazy" decoding="async" /></div>

      <div className="bl-vt-bar">
        <span className="bl-vt-count" aria-live="polite"><b>{String(Math.min(cur, Math.max(0, n - 1)) + 1).padStart(2, '0')}</b> / {String(n || 4).padStart(2, '0')}</span>
        <span className="bl-vt-line" aria-hidden><i style={{ width: `${((cur + 1) / (n || 4)) * 100}%` }} /></span>
        <span className="bl-vt-arrows">
          <button type="button" aria-label="←" disabled={cur <= 0} onClick={() => go(cur - 1)}>←</button>
          <button type="button" aria-label="→" disabled={cur >= n - 1} onClick={() => go(cur + 1)}>→</button>
        </span>
      </div>

      <div className="bl-vt-rail" ref={rail}>
        {(n ? items : Array.from({ length: 1 }, () => ({ id: 0 } as WindowItem))).map((p, k) => {
          const s = p.title ? split(p.title) : null;
          const price = Number(p.price) || 0;
          const st = pay[p.id];
          return (
            <article key={p.id} className="bl-vt-slide" aria-label={s?.name}>
              <div className="bl-vt-ph">{p.image_url && <img src={p.image_url} alt="" loading={k ? 'lazy' : 'eager'} decoding="async" />}</div>
              <div className="bl-vt-txt">
                <small>{s?.brand || 'Saint Agnes'}</small>
                <h3>{s?.name || ' '}</h3>
                <b>{p.price ? <>{fmt(price)} <em>TAX</em></> : ' '}</b>
                {p.title && (
                  <button type="button" className={`bl-vt-pay ${st || ''}`} onClick={() => tapToPay(p.id)} disabled={!!st}>
                    {st === 'paid' ? `✓ ${t('Сплачено', 'Paid')}` : st === 'tap' ? '· · ·' : <>{t('Сплатити через TaxPay', 'Pay with TaxPay')}<i aria-hidden>→</i></>}
                  </button>
                )}
                {st === 'paid' && <div className="bl-toast bl-push bl-vt-paid" role="status">{push('Saint Agnes', price, BALANCE - price)}</div>}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
