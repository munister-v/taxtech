import React, { useEffect, useRef, useState } from 'react';

// Saint Agnes as a catalogue spread: a wide lookbook frame, then four tall portraits with quiet type. A piece opens a
// sheet with the photo and TaxPay; the debit arrives as the app sends it.

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
  const [pick, setPick] = useState<number | null>(null);
  const [pay, setPay] = useState<Pay>('idle');
  const still = useRef(false);

  useEffect(() => { still.current = window.matchMedia('(prefers-reduced-motion: reduce)').matches; }, []);
  useEffect(() => { setPay('idle'); }, [pick]);
  useEffect(() => {
    if (pick === null) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setPick(null); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pick]);

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
    <div className="bl-vt">
      <div className="bl-vt-look bl-rv"><img src={wall} alt="" loading="lazy" decoding="async" /></div>
      <div className="bl-vt-grid">
        {pieces.map((p, k) => {
          const s = p.title ? split(p.title) : null;
          return (
            <button key={p.id} type="button" className="bl-vt-item bl-rv" disabled={!p.title} onClick={() => setPick(k)}
              aria-label={p.title ? `${s?.name}, ${fmt(Number(p.price))} TAX` : undefined}>
              <span className="bl-vt-ph">
                {p.image_url && <img src={p.image_url} alt="" loading="lazy" decoding="async" />}
                <i className="bl-vt-n" aria-hidden>{String(k + 1).padStart(2, '0')}</i>
                <i className="bl-vt-go" aria-hidden>{t('Сплатити через TaxPay', 'Pay with TaxPay')}</i>
              </span>
              <small>{s?.brand || ' '}</small>
              <span className="bl-vt-name">{s?.name || ' '}</span>
              <b>{p.price ? <>{fmt(Number(p.price))} <em>TAX</em></> : ' '}</b>
            </button>
          );
        })}
      </div>

      {cur && info && (
        <div className="bl-vt-sheet" role="dialog" aria-modal="true" aria-label={info.name} onClick={e => { if (e.target === e.currentTarget) setPick(null); }}>
          <div className="bl-vt-panel">
            <button type="button" className="bl-vt-x" aria-label={t('Закрити', 'Close')} onClick={() => setPick(null)}><i aria-hidden /></button>
            <div className="bl-vt-big">{cur.image_url && <img src={cur.image_url} alt="" decoding="async" />}</div>
            <div className="bl-vt-info">
              <small>{info.brand || 'Saint Agnes'}</small>
              <h3>{info.name}</h3>
              <b>{fmt(price)} <em>TAX</em></b>
              <button type="button" className={`bl-vt-pay ${pay}`} onClick={tapToPay} disabled={pay !== 'idle'}>
                <span className="bl-vt-ripple" aria-hidden />
                <span>{pay === 'paid' ? `✓ ${t('Сплачено', 'Paid')}` : pay === 'tap' ? '· · ·' : t('Сплатити через TaxPay', 'Pay with TaxPay')}</span>
              </button>
              {pay === 'paid' && <div className="bl-toast bl-push bl-vt-paid" role="status">{push('Saint Agnes', price, BALANCE - price)}</div>}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
