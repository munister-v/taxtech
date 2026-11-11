// Roma Live: a city of accounts paying real places. The places are the shops, cafés, restaurants, hotels and museums
// of central Rome from OpenStreetMap (rome.json, see web/scripts/build-city.py); the people, the cards and the money
// are simulated here. Each payment goes through the same steps as in the bank: velocity and impossible-travel checks,
// a limit, then a debit; a declined one is drawn red.

export type Cat = 'food' | 'cafe' | 'bar' | 'shop' | 'stay' | 'culture' | 'money' | 'health';
export const CATS: Cat[] = ['cafe', 'food', 'bar', 'shop', 'stay', 'culture', 'money', 'health'];
export const CAT_COLOR: Record<Cat, string> = {
  cafe: '#ffd400', food: '#ff8a3d', bar: '#ff4fa3', shop: '#5ad1ff', stay: '#9d7bff', culture: '#46e3a6', money: '#e8e8e8', health: '#ff5a5a',
};

export type CityData = {
  origin: [number, number];
  bounds: [number, number, number, number];
  b: [number, ...number[][]][];       // [height, outer ring [x0, y0, x1, y1, …], courtyard rings…]
  v: [number, number, string, string, number, string, VenueInfo?][]; // x, y, cat, name, building, subtype, details
  roads: Record<'major' | 'mid' | 'minor' | 'foot', number[][]>;
  river: number[][];
  areas: Record<'park' | 'water' | 'square', number[][][]>;
  labels: [number, number, string, number][]; // x, y, name, 0 rione | 1 landmark | 2 piazza
};
export type VenueInfo = { a?: string; h?: string; c?: string; s?: string };

export type Venue = {
  i: number; x: number; y: number; z: number; cat: Cat; name: string; b: number; sub: string; info: VenueInfo; rione: string;
  pop: number; rev: number; n: number; hours: Float32Array; last: Tx[]; mix: [number, number, number];
};
export type Account = { i: number; id: string; kind: 'resident' | 'tourist' | 'commuter'; hx: number; hy: number; x: number; y: number; lastT: number; recent: number[]; bal: number; you?: boolean; name?: string };
export type Tx = {
  id: number; t: number; acc: Account; venue: Venue; amount: number; ok: boolean; reason?: 'velocity' | 'travel' | 'limit' | 'funds';
  fx: number; fy: number; fz: number;
};

// Average ticket in TAX and how busy each kind of place is hour by hour (0..23), Rome-like: late lunch, late dinner.
const TICKET: Record<Cat, [number, number]> = {
  cafe: [55, 0.6], food: [780, 0.55], bar: [290, 0.5], shop: [1600, 0.9], stay: [5200, 0.5], culture: [640, 0.4], money: [1400, 0.5], health: [260, 0.7],
};
const H = (pts: [number, number][]) => { const a = new Float32Array(24); for (let h = 0; h < 24; h++) { let v = 0; for (const [c, w] of pts) { const d = Math.min(Math.abs(h - c), 24 - Math.abs(h - c)); v += w * Math.exp(-(d * d) / 3.2); } a[h] = v; } return a; };
const PROFILE: Record<Cat, Float32Array> = {
  cafe: H([[8, 1], [11, .5], [16, .45]]), food: H([[13.3, 1], [20.6, 1.15]]), bar: H([[19, .6], [22.5, 1], [0.5, .7]]), shop: H([[11.5, .8], [17.5, 1]]),
  stay: H([[10.5, .7], [15, 1]]), culture: H([[10, .8], [14.5, 1]]), money: H([[9.5, .6], [13, .5], [18, .6]]), health: H([[10, .7], [17.5, .7]]),
};
const WEIGHT: Record<Cat, number> = { cafe: 1.5, food: 1.3, bar: .8, shop: 1, stay: .2, culture: .45, money: .1, health: .3 };

function rng(seed: number) { let s = seed >>> 0; return () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

export class CitySim {
  venues: Venue[] = [];
  accounts: Account[] = [];
  byCat: Record<Cat, Venue[]> = { food: [], cafe: [], bar: [], shop: [], stay: [], culture: [], money: [], health: [] };
  grid = new Map<number, Venue[]>();
  heights: Float32Array;
  bRev: Float32Array;                  // turnover per building
  bPulse: Float32Array;                // fades after each payment
  minute = 7 * 60;                     // simulated clock, minutes since 00:00 of day 1
  day = 1;
  speed = 1;                           // simulated minutes per real second
  rate = 1;                            // payments drawn, multiplier
  on: Record<Cat, boolean> = { food: true, cafe: true, bar: true, shop: true, stay: true, culture: true, money: true, health: true };
  stats = { vol: 0, n: 0, declined: 0, perMin: 0, byCat: {} as Record<Cat, number> };
  feed: Tx[] = [];
  cityHours = new Float32Array(24);
  reasons = { velocity: 0, travel: 0, limit: 0, funds: 0 };
  private seq = 1;
  private acc = 0;
  private window: number[] = [];
  private R = rng(20261111);
  you: Account | null = null;
  onTx: ((tx: Tx) => void) | null = null;

  constructor(public D: CityData) {
    const R = this.R;
    this.heights = new Float32Array(D.b.length);
    D.b.forEach((b, i) => { this.heights[i] = b[0] as number; });
    const rioni = D.labels.filter(l => l[3] === 0);
    const rioneOf = (x: number, y: number) => { let best = '', bd = 1e9; for (const l of rioni) { const d = Math.hypot(l[0] - x, l[1] - y); if (d < bd) { bd = d; best = l[2]; } } return best; };
    this.bRev = new Float32Array(D.b.length);
    this.bPulse = new Float32Array(D.b.length);
    for (const c of CATS) this.stats.byCat[c] = 0;
    D.v.forEach(([x, y, cat, name, b, sub, info], i) => {
      const c = cat as Cat;
      // log-normal popularity, landmarks and big hotels draw more
      let pop = Math.exp((R() + R() + R() - 1.5) * 1.3);
      if (sub === 'attraction' || sub === 'museum') pop *= 2.2;
      const v: Venue = { i, x, y, z: b >= 0 ? this.heights[b] + 2 : 3, cat: c, name, b, sub, info: info || {}, rione: rioneOf(x, y), pop, rev: 0, n: 0, hours: new Float32Array(24), last: [], mix: [0, 0, 0] };
      this.venues.push(v);
      this.byCat[c].push(v);
      const k = this.key(x, y);
      if (!this.grid.has(k)) this.grid.set(k, []);
      this.grid.get(k)!.push(v);
    });
    // Accounts: residents live in buildings without shops, tourists sleep in hotels, commuters come in from Termini.
    const shopB = new Set(this.venues.map(v => v.b));
    const homes = D.b.map((_, i) => i).filter(i => !shopB.has(i));
    const hotels = this.byCat.stay;
    const centre = (i: number) => { const r = D.b[i][1] as number[]; let x = 0, y = 0; const n = r.length / 2; for (let k = 0; k < r.length; k += 2) { x += r[k]; y += r[k + 1]; } return [x / n, y / n]; };
    const [bx0, by0, bx1, by1] = D.bounds;
    for (let i = 0; i < 9000; i++) {
      const r = R();
      let hx: number, hy: number, kind: Account['kind'];
      if (r < 0.55 && homes.length) { [hx, hy] = centre(homes[(R() * homes.length) | 0]); kind = 'resident'; }
      else if (r < 0.85 && hotels.length) { const h = hotels[(R() * hotels.length) | 0]; hx = h.x; hy = h.y; kind = 'tourist'; }
      else { hx = bx1 - R() * 200; hy = by0 + (by1 - by0) * (0.45 + R() * 0.35); kind = 'commuter'; }
      hx = Math.max(bx0, Math.min(bx1, hx)); hy = Math.max(by0, Math.min(by1, hy));
      this.accounts.push({ i, id: this.accId(), kind, hx, hy, x: hx, y: hy, lastT: -1e9, recent: [], bal: kind === 'tourist' ? 60000 : 24000 });
    }
  }

  private key(x: number, y: number) { return (Math.floor(x / 250) + 100) * 1000 + Math.floor(y / 250) + 100; }
  private accId() { const R = this.R; return 'TT' + String((R() * 90 + 10) | 0) + ' •••• ' + String((R() * 9000 + 1000) | 0); }

  hour() { return Math.floor(this.minute / 60) % 24; }
  clock() { const m = Math.floor(this.minute) % 1440; return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`; }
  /** How busy the city is right now, 0..1 */
  busy() { const h = (this.minute / 60) % 24; let s = 0; for (const c of CATS) s += WEIGHT[c] * lerpH(PROFILE[c], h); return s / 2.4; }

  private pickVenue(a: Account, cat: Cat): Venue | null {
    const R = this.R;
    const list = this.byCat[cat];
    if (!list.length) return null;
    // gravity model: a dozen candidates, weighted by popularity and how far the walk is
    let best: Venue | null = null, bw = 0;
    const walk = a.kind === 'tourist' ? 520 : 340;
    for (let k = 0; k < 18; k++) {
      const v = list[(R() * list.length) | 0];
      const d = Math.hypot(v.x - a.x, v.y - a.y);
      const w = v.pop * Math.exp(-d / walk) * (0.5 + R());
      if (w > bw) { bw = w; best = v; }
    }
    return best;
  }

  private pickCat(): Cat {
    const h = (this.minute / 60) % 24;
    let s = 0; const w: number[] = [];
    for (const c of CATS) { const x = this.on[c] ? WEIGHT[c] * lerpH(PROFILE[c], h) : 0; w.push(x); s += x; }
    let r = this.R() * s;
    for (let i = 0; i < CATS.length; i++) { r -= w[i]; if (r <= 0) return CATS[i]; }
    return 'cafe';
  }

  private amount(c: Cat) { const [m, sd] = TICKET[c]; const R = this.R; const g = (R() + R() + R() + R() - 2) * 1.2; return Math.max(5, Math.round(m * Math.exp(g * sd) / 5) * 5); }

  /** Book a payment the way the bank does: checks first, then the debit. */
  pay(a: Account, v: Venue, amount: number): Tx {
    const t = this.minute;
    let ok = true; let reason: Tx['reason'];
    a.recent = a.recent.filter(x => t - x < 10);
    const jump = Math.hypot(v.x - a.x, v.y - a.y), mins = t - a.lastT;
    if (a.recent.length >= 4) { ok = false; reason = 'velocity'; }
    else if (mins < 6 && jump > 1500) { ok = false; reason = 'travel'; }
    else if (amount > 30000) { ok = false; reason = 'limit'; }
    else if (amount > a.bal) { ok = false; reason = 'funds'; }
    const tx: Tx = { id: this.seq++, t, acc: a, venue: v, amount, ok, reason, fx: a.x, fy: a.y, fz: 1 };
    a.recent.push(t);
    if (ok) {
      a.bal -= amount; a.x = v.x; a.y = v.y; a.lastT = t;
      v.rev += amount; v.n++; v.hours[this.hour()] += amount; v.mix[a.kind === 'resident' ? 0 : a.kind === 'tourist' ? 1 : 2]++;
      this.cityHours[this.hour()] += amount;
      if (v.b >= 0) { this.bRev[v.b] += amount; this.bPulse[v.b] = 1; }
      this.stats.vol += amount; this.stats.n++; this.stats.byCat[v.cat] += amount;
    } else { this.stats.declined++; this.reasons[reason!]++; }
    v.last.unshift(tx); if (v.last.length > 6) v.last.pop();
    this.feed.unshift(tx); if (this.feed.length > 40) this.feed.pop();
    this.window.push(performance.now());
    this.onTx?.(tx);
    return tx;
  }

  /** A card-testing burst or a cloned card: a few payments that the checks should stop. */
  private fraud() {
    const R = this.R;
    const a = this.accounts[(R() * this.accounts.length) | 0];
    if (a.you) return;
    if (R() < 0.5) {
      const v = this.pickVenue(a, R() < .5 ? 'shop' : 'food'); if (!v) return;
      for (let k = 0; k < 6; k++) this.pay(a, v, 5 + ((R() * 4) | 0) * 5);
    } else {
      const far = this.venues[(R() * this.venues.length) | 0];
      a.lastT = this.minute;
      this.pay(a, far, this.amount(far.cat));
    }
  }

  step(dt: number) {
    const prev = this.minute;
    this.minute += dt * this.speed;
    if (Math.floor(this.minute / 1440) !== Math.floor(prev / 1440)) this.newDay();
    // payments per real second: the city's pulse times the visual rate
    this.acc += dt * (2 + 13 * this.busy()) * this.rate * Math.min(2, 0.7 + this.speed / 6);
    let guard = 0;
    while (this.acc >= 1 && guard++ < 60) {
      this.acc -= 1;
      if (this.R() < 0.012) { this.fraud(); continue; }
      const a = this.accounts[(this.R() * this.accounts.length) | 0];
      if (a.you) continue;
      // people drift home between payments
      if (this.minute - a.lastT > 120) { a.x = a.hx; a.y = a.hy; }
      const c = this.pickCat();
      const v = this.pickVenue(a, c);
      if (v) this.pay(a, v, this.amount(c));
    }
    const k = Math.exp(-dt * 3.2);
    for (let i = 0; i < this.bPulse.length; i++) if (this.bPulse[i] > 0.002) this.bPulse[i] *= k; else this.bPulse[i] = 0;
    const now = performance.now();
    while (this.window.length && now - this.window[0] > 4000) this.window.shift();
    // payments per simulated minute
    this.stats.perMin = this.window.length / 4 / Math.max(0.0001, this.speed);
  }

  private newDay() {
    this.day++;
    this.bRev.fill(0);
    for (const v of this.venues) { v.rev = 0; v.n = 0; v.hours.fill(0); v.mix = [0, 0, 0]; }
    this.cityHours.fill(0);
    this.reasons = { velocity: 0, travel: 0, limit: 0, funds: 0 };
    this.stats.vol = 0; this.stats.n = 0; this.stats.declined = 0;
    for (const c of CATS) this.stats.byCat[c] = 0;
    for (const a of this.accounts) a.bal += a.kind === 'tourist' ? 9000 : 1200;
  }

  /** The visitor's own account in the city: lives where they say, pays where they tap. */
  join(name: string, x: number, y: number, bal: number): Account {
    const a: Account = { i: this.accounts.length, id: 'TT' + String(10 + ((this.R() * 89) | 0)) + ' •••• ' + String(1000 + ((this.R() * 8999) | 0)), kind: 'resident', hx: x, hy: y, x, y, lastT: -1e9, recent: [], bal, you: true, name };
    this.accounts.push(a);
    this.you = a;
    return a;
  }

  venuesNear(x: number, y: number, r: number) {
    const out: Venue[] = [];
    for (let gx = Math.floor((x - r) / 250); gx <= Math.floor((x + r) / 250); gx++)
      for (let gy = Math.floor((y - r) / 250); gy <= Math.floor((y + r) / 250); gy++)
        for (const v of this.grid.get((gx + 100) * 1000 + gy + 100) || []) if (Math.hypot(v.x - x, v.y - y) <= r) out.push(v);
    return out;
  }

  search(q: string, n = 7) {
    const s = q.trim().toLowerCase();
    if (s.length < 2) return [];
    const out: Venue[] = [];
    for (const v of this.venues) { if (v.name.toLowerCase().includes(s)) { out.push(v); if (out.length >= 40) break; } }
    return out.sort((a, b) => (a.name.toLowerCase().startsWith(s) ? 0 : 1) - (b.name.toLowerCase().startsWith(s) ? 0 : 1) || b.pop - a.pop).slice(0, n);
  }

  /** Rank of a place among its kind by today's turnover, 1-based */
  rank(v: Venue) { let r = 1; for (const o of this.byCat[v.cat]) if (o.rev > v.rev) r++; return r; }

  top(n = 5) { return [...this.venues].sort((a, b) => b.rev - a.rev).slice(0, n); }
}

function lerpH(p: Float32Array, h: number) { const a = Math.floor(h) % 24, b = (a + 1) % 24, f = h - Math.floor(h); return p[a] * (1 - f) + p[b] * f; }
