import { useEffect, useRef, useState } from 'react';
import './heroLive.css';

// The hero, alive: Rome's clock and weather in a pill, what the city has paid today as one big number that keeps
// climbing, and the city's real payments arriving as notifications (GET /api/city/live?names=1, the same city as
// /roma). Polls only while the hero is on screen and the tab is visible.

type Pay = { id: number; a: number; ok: boolean; n?: string; r?: string; c?: string; w: string };
type Live = { rome: string; weather?: { t: number | null }; stats: { vol: number; n: number }; payments: Pay[]; last_id: number };

const fmt = (n: number) => Math.round(n).toLocaleString('uk-UA').replace(/\s/g, ' ');
const POLL = 3000, SHOW = 2300;
// OpenStreetMap has places called just "Bar" or "Tabacchi": the notifications show the ones with a name of their own
const GENERIC = /^(bar|bar snack|caff[eè]|cafe|ristorante|pizzeria|tabacchi|edicola|farmacia|miscellanea|market|minimarket|alimentari|bancomat|atm|hotel|b&b|bistrot)$/i;
const named = (n: string) => n.length > 4 && !GENERIC.test(n.trim());

function useLive(active: boolean) {
  const [live, setLive] = useState<Live | null>(null);
  const [queue, setQueue] = useState<Pay[]>([]);
  const last = useRef(0);
  useEffect(() => {
    if (!active) return;
    let on = true;
    const get = async () => {
      if (document.hidden) return;
      try {
        const j = await fetch(`/api/city/live?since=${last.current}&limit=6&names=1`).then(r => r.json());
        if (!on || !j?.ok) return;
        const d: Live = j.data;
        last.current = d.last_id || last.current;
        setLive(d);
        const fresh = d.payments.filter(p => p.ok && p.n && named(p.n));
        if (fresh.length) setQueue(q => [...q, ...fresh].slice(-8));
      } catch { /* keep the last state */ }
    };
    get();
    const id = window.setInterval(get, POLL);
    return () => { on = false; clearInterval(id); };
  }, [active]);
  return { live, queue, setQueue };
}

/** A number that climbs to its target instead of jumping */
function useCount(target: number) {
  const [v, setV] = useState(0);
  const cur = useRef(0);
  useEffect(() => {
    if (!target) return;
    let raf = 0;
    const from = cur.current || target * .985, t0 = performance.now(), dur = cur.current ? POLL : 1600;
    const step = (t: number) => {
      const k = Math.min(1, (t - t0) / dur), e = cur.current ? k : 1 - Math.pow(1 - k, 3);
      const x = from + (target - from) * e;
      setV(x);
      if (k < 1) raf = requestAnimationFrame(step); else cur.current = target;
    };
    raf = requestAnimationFrame(step);
    return () => { cancelAnimationFrame(raf); cur.current = cur.current || target; };
  }, [target]);
  return v;
}

export function HeroPill({ live, t }: { live: Live | null; t: (uk: string, en: string) => string }) {
  return (
    <div className={`hl-pill${live ? ' on' : ''}`}>
      <i aria-hidden />
      <span>Roma · {live ? live.rome : '—'}</span>
      {live?.weather?.t != null && <span className="hl-pill-t">{Math.round(live.weather.t)}°</span>}
      <span className="hl-pill-l">{t('наживо', 'live')}</span>
    </div>
  );
}

export function HeroNumber({ live, t }: { live: Live | null; t: (uk: string, en: string) => string }) {
  const v = useCount(live?.stats.vol || 0);
  return (
    <div className={`hl-num${live ? ' on' : ''}`}>
      <div className="hl-num-v"><b>{live ? fmt(v) : '0'}</b><span>TAX</span></div>
      <p>{t('сплачено в Римі сьогодні', 'paid in Rome today')}{live ? ` · ${fmt(live.stats.n)} ${t('платежів', 'payments')}` : ''}</p>
    </div>
  );
}

/** Real payments of the city, one every couple of seconds, newest on top, three at most */
export function HeroFeed({ queue, setQueue, t }: { queue: Pay[]; setQueue: (f: (q: Pay[]) => Pay[]) => void; t: (uk: string, en: string) => string }) {
  const [shown, setShown] = useState<Pay[]>([]);
  const q = useRef(queue);
  q.current = queue;
  useEffect(() => {
    const id = window.setInterval(() => {
      const next = q.current[0];
      if (!next) return;
      setQueue(x => x.filter(y => y.id !== next.id));
      setShown(s => [next, ...s.filter(x => x.id !== next.id)].slice(0, 3));
    }, SHOW);
    return () => clearInterval(id);
  }, [setQueue]);
  return (
    <div className="hl-feed" aria-live="off">
      {shown.map((p, i) => (
        <div key={p.id} className={`bl-toast bl-push hl-toast hl-${i}`}>
          <span className="bl-push-ic" aria-hidden><img src="/icons/mark-white.svg" alt="" /></span>
          <div className="bl-push-tx">
            <div className="bl-push-top"><b>TaxTech</b><em>{t('зараз', 'now')}</em></div>
            <p className="bl-push-h"><u>−{fmt(p.a)} TAX</u> · {p.n}</p>
            <p>{p.r ? `${p.r} · ` : ''}{p.w}</p>
          </div>
        </div>
      ))}
    </div>
  );
}

/** One hook for the three pieces: polls while `el` is on screen */
export function useHeroLive(el: React.RefObject<HTMLElement | null>) {
  const [vis, setVis] = useState(true);
  useEffect(() => {
    const node = el.current;
    if (!node) return;
    const io = new IntersectionObserver(([e]) => setVis(e.isIntersecting), { threshold: .05 });
    io.observe(node);
    return () => io.disconnect();
  }, [el]);
  return useLive(vis);
}
