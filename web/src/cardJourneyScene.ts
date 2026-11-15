import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { LOOKS, T, clamp, lookAt, ss, type Look } from './cardLooks';

// One card for the whole top of the landing, rendered with three.js and driven by the scroll:
// it stands upright in the hero, lies down on a payment terminal ("Tap. Paid."), then stands up again and changes its look.
// The face is painted on a canvas (mark, chip, number, guilloche); a second canvas tells the metal where it is polished,
// so the engraving catches the light as the card turns. Loaded on demand by CardJourney.tsx.

export type JourneyApi = {
  setProgress: (p: number) => void;
  setPointer: (x: number, y: number) => void;
  setVisible: (v: boolean) => void;
  resize: () => void;
  dispose: () => void;
};
type Opts = { rosette: string; markUrl: string; amount: string; still: boolean; onLook: (i: number) => void; onReady: () => void };

const CW = 3.2, CH = CW / 1.586, CR = 0.135, CT = 0.036;   // card: width, height, corner, thickness
const PW = 2.5, PH = 4.2, PD = 0.42;                        // terminal
const TW = 1400, TH = Math.round(TW / 1.586);
const CAM_Z = 12, FOV = 30;

function slab(w: number, h: number, r: number, d: number) {
  const s = new THREE.Shape(), x = -w / 2, y = -h / 2;
  s.moveTo(x + r, y); s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r); s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h); s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
  const bevel = Math.min(0.012, d * 0.3);
  const g = new THREE.ExtrudeGeometry(s, { depth: d - bevel * 2, bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 3, curveSegments: 20 });
  g.translate(0, 0, -d / 2 + bevel);
  const pos = g.attributes.position, uv = g.attributes.uv;
  for (let i = 0; i < pos.count; i++) uv.setXY(i, (pos.getX(i) + w / 2) / w, (pos.getY(i) + h / 2) / h);
  return g;
}

function canvas(w: number, h: number) {
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
  return [cv, cv.getContext('2d')!] as const;
}
function tex(cv: HTMLCanvasElement, srgb: boolean, aniso: number) {
  const t = new THREE.CanvasTexture(cv);
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = aniso;
  return t;
}
const loadImg = (src: string) => new Promise<HTMLImageElement | null>(res => {
  const im = new Image(); im.decoding = 'async';
  im.onload = () => res(im); im.onerror = () => res(null); im.src = src;
});
function rr(c: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
}
const spaced = (c: CanvasRenderingContext2D, px: number) => { try { (c as unknown as { letterSpacing: string }).letterSpacing = `${px}px`; } catch { /* older browsers keep normal spacing */ } };
const SANS = '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", Arial, sans-serif';
const MONO = '"SF Mono", ui-monospace, Menlo, Consolas, monospace';

/** Paints one look: the colour of the face and the map of polish (G = roughness, B = metalness). */
function paintLook(look: Look, mark: HTMLImageElement | null, photo: HTMLImageElement | null, rosette: Path2D) {
  const [cv, c] = canvas(TW, TH), [ov, o] = canvas(TW / 2, TH / 2);
  const u = TW / 100;                                    // one unit = 1 % of the card's width
  o.scale(0.5, 0.5);
  const polish = (rough: number, metal: number) => `rgb(0,${Math.round(clamp(rough) * 255)},${Math.round(clamp(metal) * 255)})`;
  const darkInk = parseInt(look.ink.slice(1, 3), 16) < 0x80;   // dark ink on a light card is matte print, light ink is foil
  const foil = darkInk ? polish(0.95, 0) : polish(0.16, 1);

  if (photo) {
    const k = Math.max(TW / photo.width, TH / photo.height), w = photo.width * k, h = photo.height * k;
    c.drawImage(photo, (TW - w) / 2, (TH - h) / 2, w, h);
    const sh = c.createLinearGradient(0, 0, TW * 0.7, TH);
    sh.addColorStop(0, 'rgba(0,0,0,.62)'); sh.addColorStop(0.5, 'rgba(0,0,0,.2)'); sh.addColorStop(1, 'rgba(0,0,0,.62)');
    if (!darkInk) { c.fillStyle = sh; c.fillRect(0, 0, TW, TH); }
  } else {
    const g = c.createLinearGradient(0, 0, TW * 0.8, TH);
    g.addColorStop(0, look.a); g.addColorStop(1, look.b);
    c.fillStyle = g; c.fillRect(0, 0, TW, TH);
    const glow = c.createRadialGradient(TW * 0.74, TH * 0.44, 0, TW * 0.74, TH * 0.44, TW * 0.46);
    glow.addColorStop(0, look.line + '14'); glow.addColorStop(1, look.line + '00');
    c.fillStyle = glow; c.fillRect(0, 0, TW, TH);
  }
  o.fillStyle = polish(look.rough, look.metal); o.fillRect(0, 0, TW, TH);

  // guilloche rosette, to the right of the centre and larger than the card
  if (!photo) for (const [ctx, style, lw, alpha] of [[c, look.line, 0.19, 0.7], [o, polish(look.rough * 0.3, 1), 0.3, 1]] as const) {
    const R = 43 * u;
    ctx.save(); ctx.translate(TW * 0.74 - R, TH * 0.48 - R); ctx.scale(R / 50, R / 50);
    ctx.globalAlpha = alpha; ctx.strokeStyle = style; ctx.lineWidth = lw; ctx.stroke(rosette); ctx.restore();
  }

  const ink = (fn: (ctx: CanvasRenderingContext2D, style: string) => void, colour = look.ink) => { fn(c, colour); fn(o, foil); };

  // mark and wordmark
  if (mark) {
    const mh = 9.4 * u, mw = mh * (mark.width / mark.height || 0.85);
    const [tv, tc] = canvas(Math.ceil(mw), Math.ceil(mh));
    tc.drawImage(mark, 0, 0, mw, mh);
    const stamp = (ctx: CanvasRenderingContext2D, style: string) => {
      tc.globalCompositeOperation = 'source-in'; tc.fillStyle = style; tc.fillRect(0, 0, tv.width, tv.height);
      ctx.drawImage(tv, 6.4 * u, 6.2 * u);
    };
    ink(stamp);
  }
  ink((ctx, style) => {
    ctx.fillStyle = style; ctx.textBaseline = 'alphabetic'; spaced(ctx, 0);
    ctx.font = `400 ${6.3 * u}px ${SANS}`; ctx.fillText('Tax', 16.8 * u, 13.2 * u);
    const w = ctx.measureText('Tax').width;
    ctx.font = `700 ${6.3 * u}px ${SANS}`; ctx.fillText('Tech', 16.8 * u + w, 13.2 * u);
  });
  // contactless
  ink((ctx, style) => {
    ctx.strokeStyle = style; ctx.lineWidth = 0.62 * u; ctx.lineCap = 'round';
    for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(86.2 * u, 10.6 * u, (2 + i * 2.1) * u, -0.72, 0.72); ctx.stroke(); }
  });
  // chip
  const chip = c.createLinearGradient(6.4 * u, 23 * u, 19.6 * u, 33 * u);
  chip.addColorStop(0, '#f7e7b4'); chip.addColorStop(0.35, '#d3ac55'); chip.addColorStop(0.62, '#f0d58e'); chip.addColorStop(1, '#a47f33');
  for (const [ctx, fill, stroke] of [[c, chip, 'rgba(70,45,5,.6)'], [o, polish(0.2, 1), polish(0.5, 1)]] as const) {
    rr(ctx, 6.4 * u, 23 * u, 13.2 * u, 10 * u, 1.8 * u); ctx.fillStyle = fill; ctx.fill();
    ctx.strokeStyle = stroke; ctx.lineWidth = 0.26 * u;
    ctx.save(); ctx.translate(6.4 * u, 23 * u); ctx.scale((13.2 * u) / 44, (10 * u) / 34);
    ctx.lineWidth = 0.9;
    ctx.stroke(new Path2D('M.5 12h12.5q4 0 4 5t-4 5H.5M43.5 12H31q-4 0-4 5t4 5h12.5M17 .5v8.5M27 .5v8.5M17 33.5V25M27 33.5V25M17 9h10v16H17z'));
    ctx.restore();
  }
  // number, holder, kind
  ink((ctx, style) => {
    ctx.fillStyle = style; ctx.textBaseline = 'alphabetic'; ctx.textAlign = 'left';
    ctx.font = `500 ${5 * u}px ${MONO}`; spaced(ctx, 0.5 * u);
    ctx.fillText('••••  ••••  ••••  6595', 6.4 * u, 47.4 * u);
    ctx.font = `500 ${2.7 * u}px ${SANS}`; spaced(ctx, 0.42 * u);
    ctx.fillText('DEMO USER', 6.4 * u, 56.2 * u);
  });
  ink((ctx, style) => {
    ctx.fillStyle = style; ctx.textAlign = 'right'; ctx.font = `600 ${2.4 * u}px ${SANS}`; spaced(ctx, 0.5 * u);
    ctx.fillText('VIRTUAL', 93.6 * u, 56.2 * u); ctx.textAlign = 'left'; spaced(ctx, 0);
  }, photo ? (darkInk ? look.ink : '#ffd400') : darkInk ? look.ink : look.line);
  return { cv, ov };
}

/** The terminal: a dark body with a contactless sign, a screen and a keypad; the screen exists twice, waiting and paid. */
function paintTerminal(amount: string) {
  const W = 500, H = 840;
  const [body, b] = canvas(W, H), [idle, i] = canvas(W, H), [paid, p] = canvas(W, H);
  const g = b.createLinearGradient(0, 0, W, H); g.addColorStop(0, '#1c1c20'); g.addColorStop(1, '#09090b');
  b.fillStyle = g; b.fillRect(0, 0, W, H);
  b.strokeStyle = 'rgba(255,255,255,.34)'; b.lineWidth = 7; b.lineCap = 'round';
  for (let k = 0; k < 4; k++) { b.beginPath(); b.arc(W / 2 - 34, 150, 20 + k * 24, -0.78, 0.78); b.stroke(); }
  b.fillStyle = '#040405'; rr(b, 52, 330, W - 104, 270, 26); b.fill();
  b.fillStyle = 'rgba(255,255,255,.1)';
  for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) { rr(b, 92 + c * 116, 650 + r * 58, 84, 34, 12); b.fill(); }
  for (const ctx of [i, p]) { ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H); }
  // waiting: the amount
  rr(i, 52, 330, W - 104, 270, 26); i.fillStyle = '#12161a'; i.fill();
  i.textAlign = 'center'; i.fillStyle = '#ffffff'; i.font = `700 92px ${SANS}`; i.fillText(amount, W / 2, 486);
  i.fillStyle = '#ffd400'; i.font = `600 34px ${SANS}`; spaced(i, 6); i.fillText('TAX', W / 2 + 3, 546);
  // paid: green with a tick
  const pg = p.createLinearGradient(0, 330, 0, 600); pg.addColorStop(0, '#22c97c'); pg.addColorStop(1, '#0c8a4f');
  rr(p, 52, 330, W - 104, 270, 26); p.fillStyle = pg; p.fill();
  p.strokeStyle = '#fff'; p.lineWidth = 22; p.lineCap = 'round'; p.lineJoin = 'round';
  p.beginPath(); p.moveTo(W / 2 - 62, 468); p.lineTo(W / 2 - 16, 514); p.lineTo(W / 2 + 68, 420); p.stroke();
  return { body, idle, paid };
}

export async function createJourney(cv: HTMLCanvasElement, opts: Opts): Promise<JourneyApi> {
  const renderer = new THREE.WebGLRenderer({ canvas: cv, alpha: true, antialias: true, powerPreference: 'high-performance' });
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.95;
  const aniso = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  const env = pmrem.fromScene(new RoomEnvironment(), 0.03).texture;
  scene.environment = env;
  const camera = new THREE.PerspectiveCamera(FOV, 1, 0.1, 60);
  camera.position.set(0, 0, CAM_Z);

  const key = new THREE.DirectionalLight(0xffffff, 1.0); key.position.set(-3, 5, 8); scene.add(key);
  const rim = new THREE.PointLight(0xffd9a0, 12, 0, 2); scene.add(rim);

  // ── card
  const rosette = new Path2D(opts.rosette);
  const mark = await loadImg(opts.markUrl);
  const faces: { map: THREE.CanvasTexture; orm: THREE.CanvasTexture }[] = [];
  const makeFace = (i: number, photo: HTMLImageElement | null) => {
    const { cv: a, ov } = paintLook(LOOKS[i], mark, photo, rosette);
    faces[i]?.map.dispose(); faces[i]?.orm.dispose();
    faces[i] = { map: tex(a, true, aniso), orm: tex(ov, false, aniso) };
  };
  LOOKS.forEach((_, i) => makeFace(i, null));
  const faceMat = new THREE.MeshPhysicalMaterial({ map: faces[0].map, roughnessMap: faces[0].orm, metalnessMap: faces[0].orm, roughness: 1, metalness: 1, clearcoat: 0.55, clearcoatRoughness: 0.22, envMapIntensity: 0.5 });
  const edgeMat = new THREE.MeshStandardMaterial({ color: LOOKS[0].b, roughness: 0.3, metalness: 0.9 });
  const card = new THREE.Mesh(slab(CW, CH, CR, CT), [faceMat, edgeMat]);
  scene.add(card);
  let shown = -1;
  const applyLook = (i: number) => {
    if (i === shown) return;
    shown = i;
    const f = faces[i], l = LOOKS[i];
    faceMat.map = f.map; faceMat.roughnessMap = f.orm; faceMat.metalnessMap = f.orm;
    faceMat.clearcoat = l.photo ? 0.3 : parseInt(l.ink.slice(1, 3), 16) < 0x80 ? 0.2 : 0.55; faceMat.envMapIntensity = l.photo ? 0.3 : 0.5;
    key.intensity = l.photo ? 0.55 : 1.0; rim.intensity = l.photo ? 5 : 12;
    edgeMat.color.set(l.photo ? '#141416' : l.b).lerp(new THREE.Color(l.a), 0.35);
    rim.color.set(l.tint);
    opts.onLook(i);
  };
  applyLook(0);
  // photo looks arrive after the first frame; the look repaints in place when its picture is ready
  LOOKS.forEach((l, i) => { if (l.photo) loadImg(l.photo).then(im => { if (im && !dead) { makeFace(i, im); if (shown === i) { shown = -1; applyLook(i); } } }); });

  // ── terminal and the rings of the tap
  const rig = new THREE.Group(); scene.add(rig);
  const tp = paintTerminal(opts.amount);
  const idleTex = tex(tp.idle, true, aniso), paidTex = tex(tp.paid, true, aniso);
  const termTop = new THREE.MeshStandardMaterial({ map: tex(tp.body, true, aniso), emissive: 0xffffff, emissiveMap: idleTex, emissiveIntensity: 1.15, roughness: 0.32, metalness: 0.35, transparent: true });
  const termSide = new THREE.MeshStandardMaterial({ color: 0x0c0c0e, roughness: 0.4, metalness: 0.5, transparent: true });
  const term = new THREE.Mesh(slab(PW, PH, 0.34, PD), [termTop, termSide]);
  rig.add(term);
  const CARD_Y = 1.02;                                   // where the card meets the terminal, above its screen
  const rings = [0, 1, 2].map(() => {
    const m = new THREE.Mesh(new THREE.RingGeometry(0.94, 1, 72), new THREE.MeshBasicMaterial({ color: 0x6dffb0, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    m.position.set(0, CARD_Y, PD / 2 + 0.05); rig.add(m);
    return m;
  });

  // ── state
  let p = 0, ps = 0, px = 0, py = 0, sx = 0, sy = 0, vis = true, dead = false, raf = 0;
  let last = performance.now(), time = 0, born = -1, paid = false, ringAt = -10;
  let vw = 8, vh = 6, base = 1, mobile = false;
  const qI = new THREE.Quaternion(), qRig = new THREE.Quaternion(), q = new THREE.Quaternion(), qe = new THREE.Quaternion();
  const e = new THREE.Euler(), v = new THREE.Vector3(), heroP = new THREE.Vector3(), tapP = new THREE.Vector3(), lookP = new THREE.Vector3();

  const resize = () => {
    const w = cv.clientWidth || 1, h = cv.clientHeight || 1;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, w < 700 ? 2 : 1.75));
    renderer.setSize(w, h, false);
    camera.aspect = w / h; camera.updateProjectionMatrix();
    vh = 2 * CAM_Z * Math.tan((FOV * Math.PI) / 360); vw = vh * camera.aspect;
    mobile = w <= 860;
    base = Math.min(1.34, (vw * 0.84) / CW, (vh * 0.4) / CH);
    heroP.set(0, vh * (mobile ? 0.13 : 0.12), 0);
    lookP.set(0, vh * 0.045, 0);
    rig.rotation.set(-0.93, mobile ? -0.24 : -0.44, mobile ? 0.06 : 0.12);
    rig.position.set(mobile ? 0 : vw * 0.2, mobile ? -vh * 0.2 : -vh * 0.07, 0);
    rig.scale.setScalar(mobile ? Math.min(base * 0.95, (vw * 0.78) / CW, (vh * 0.2) / CH) : Math.min(base * 0.8, (vw * 0.3) / CW));
    qRig.setFromEuler(rig.rotation);
  };
  resize();

  const frame = (now: number) => {
    raf = 0;
    if (dead) return;
    const dt = Math.min(0.05, (now - last) / 1000); last = now; time += dt;
    if (born < 0) { born = time; opts.onReady(); }
    ps += (p - ps) * (1 - Math.exp(-dt * 8));
    if (Math.abs(p - ps) < 0.0004) ps = p;
    sx += (px - sx) * (1 - Math.exp(-dt * 5)); sy += (py - sy) * (1 - Math.exp(-dt * 5));

    const a = ss(T.heroOut[1] - 0.02, T.approach[0] + 0.02, ps);   // hero → terminal
    const b = ss(T.tapOut[0], T.looksIn[0] + 0.02, ps);            // terminal → looks
    const tapW = a * (1 - b);
    const { i, frac } = lookAt(ps);
    applyLook(i);

    // the card comes down onto the terminal, touches, and lifts a little once paid
    const gap = 1.25 - 1.1 * ss(T.approach[0], T.pay, ps) + 0.3 * ss(T.pay + 0.01, T.pay + 0.1, ps);
    tapP.set(0, CARD_Y, PD / 2 + gap).multiplyScalar(rig.scale.x).applyQuaternion(qRig).add(rig.position);
    v.copy(heroP).lerp(tapP, a).lerp(lookP, b);
    const intro = opts.still ? 1 : 1 - Math.pow(1 - clamp((time - born) / 1.5), 4);
    v.y += (opts.still ? 0 : Math.sin(time * 0.8) * 0.045 * (1 - tapW)) - (1 - intro) * vh * 0.2;
    card.position.copy(v);
    const s0 = base + (rig.scale.x - base) * a;
    card.scale.setScalar(s0 + (base * 1.04 - s0) * b);
    q.copy(qI).slerp(qRig, a).slerp(qI, b);
    const calm = 1 - tapW * 0.85;
    const swing = opts.still ? 0 : Math.sign(frac) * ss(0.16, 0.5, Math.abs(frac)) * (Math.PI / 2);
    e.set(
      (opts.still ? 0 : Math.sin(time * 0.47) * 0.045) * calm - sy * 0.2 * calm,
      (opts.still ? 0 : Math.sin(time * 0.6) * 0.17) * calm + sx * 0.3 * calm + swing - (1 - intro) * 1.25,
      0,
    );
    card.quaternion.copy(q).multiply(qe.setFromEuler(e));

    // terminal fades in from below; its screen and the rings answer the tap
    term.visible = tapW > 0.01;
    termTop.opacity = termSide.opacity = clamp(tapW * 1.25);
    term.position.z = -(1 - tapW) * 1.6;
    const nowPaid = ps >= T.pay && ps < T.tapOut[1];
    if (nowPaid !== paid) { paid = nowPaid; termTop.emissiveMap = paid ? paidTex : idleTex; if (paid) ringAt = time; }
    rings.forEach((m, k) => {
      const t = clamp((time - ringAt - k * 0.2) / 1.25);
      m.visible = t > 0 && t < 1 && tapW > 0.2;
      m.scale.setScalar(0.9 + t * 2.3);
      (m.material as THREE.MeshBasicMaterial).opacity = (1 - t) * (1 - t) * 0.85;
    });

    rim.position.set(Math.cos(time * 0.5) * 4.2 + v.x, Math.sin(time * 0.37) * 2.4 + v.y + 1, 4.6);
    renderer.render(scene, camera);
    if (vis) raf = requestAnimationFrame(frame);
  };
  raf = requestAnimationFrame(frame);

  return {
    setProgress: x => { p = clamp(x); },
    setPointer: (x, y) => { px = x; py = y; },
    setVisible: x => { vis = x; if (x && !raf && !dead) { last = performance.now(); raf = requestAnimationFrame(frame); } },
    resize,
    dispose: () => {
      dead = true; if (raf) cancelAnimationFrame(raf);
      faces.forEach(f => { f.map.dispose(); f.orm.dispose(); });
      [idleTex, paidTex, termTop.map!].forEach(t => t.dispose());
      [card, term, ...rings].forEach(m => { m.geometry.dispose(); (Array.isArray(m.material) ? m.material : [m.material]).forEach(x => x.dispose()); });
      env.dispose(); pmrem.dispose(); renderer.dispose();
    },
  };
}
