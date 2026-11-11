import * as THREE from 'three';
import { MapControls } from 'three/examples/jsm/controls/MapControls.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { CATS, CAT_COLOR, type CitySim, type Tx, type Venue } from './citySim';

// The 3D city. Every OpenStreetMap building of central Rome (courtyards included) is extruded to its height. Roofs carry
// the day's turnover of the places inside (dark violet → red → amber → warm white), facades get a window grid with a
// few lights on and a shopfront band lit by the same turnover; parks, water and piazzas are filled, streets are hairlines,
// rioni, piazzas and monuments are labelled. A payment is a thin arc from where the payer stands to the roof of the place.
// Motion is kept quiet on purpose: heat eases in, nothing blinks, rings only for declines and your own payments.

const BG = 0x05060a;
const TEX_W = 128;
const ARCS = 700, SEG = 32, RINGS = 120;

export type SceneApi = {
  dispose(): void;
  flyTo(x: number, y: number, dist?: number): void;
  select(v: Venue | null): void;
  setAuto(on: boolean): void;
  setCats(on: Record<string, boolean>): void;
  setLabels(on: boolean): void;
  home(): void;
};

type Opts = { preview?: boolean; onPick?: (v: Venue | null) => void };

const RAMP = /* glsl */`
  vec3 ramp(float t) {
    t = clamp(t, 0.0, 1.0);
    vec3 c0 = vec3(.20,.08,.34), c1 = vec3(.58,.12,.40), c2 = vec3(.90,.30,.22), c3 = vec3(.99,.60,.16), c4 = vec3(1.0,.90,.62);
    if (t < .25) return mix(c0, c1, t / .25);
    if (t < .5) return mix(c1, c2, (t - .25) / .25);
    if (t < .75) return mix(c2, c3, (t - .5) / .25);
    return mix(c3, c4, (t - .75) / .25);
  }`;

export function createCityScene(el: HTMLElement, sim: CitySim, opts: Opts = {}): SceneApi {
  const D = sim.D;
  const preview = !!opts.preview;
  const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setClearColor(BG, 1);
  el.appendChild(renderer.domElement);
  renderer.domElement.style.display = 'block';
  renderer.domElement.style.touchAction = preview ? 'pan-y' : 'none';

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(BG, 2400, 6800);
  const camera = new THREE.PerspectiveCamera(36, 1, 5, 24000);
  const uniforms = { uTime: { value: 0 }, uFogNear: { value: 2400 }, uFogFar: { value: 6800 }, uBg: { value: new THREE.Color(BG) } };

  // ── Heat: building turnover (eased), selection, has-places; venue selection ──
  const nb = D.b.length;
  const bRows = Math.ceil(nb / TEX_W);
  const bHeat = new Uint8Array(TEX_W * bRows * 4);
  const bTex = new THREE.DataTexture(bHeat, TEX_W, bRows, THREE.RGBAFormat);
  bTex.needsUpdate = true;
  const shown = new Float32Array(nb);
  const hasVenue = new Uint8Array(nb);
  for (const v of sim.venues) if (v.b >= 0) hasVenue[v.b] = 1;
  const vRows = Math.ceil(sim.venues.length / TEX_W);
  const vHeat = new Uint8Array(TEX_W * vRows * 4);
  const vTex = new THREE.DataTexture(vHeat, TEX_W, vRows, THREE.RGBAFormat);
  vTex.needsUpdate = true;

  // ── Ground and filled areas ──
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(40000, 40000), new THREE.MeshBasicMaterial({ color: 0x090a0f }));
  ground.rotation.x = -Math.PI / 2;
  scene.add(ground);

  const fill = (polys: number[][][], color: number, y: number) => {
    const pos: number[] = [];
    for (const poly of polys) {
      const ring = (r: number[]) => { const a: THREE.Vector2[] = []; for (let k = 0; k < r.length; k += 2) a.push(new THREE.Vector2(r[k], r[k + 1])); return a; };
      const outer = ring(poly[0]), holes = poly.slice(1).map(ring);
      const pts = outer.concat(...holes);
      for (const [a, b, c] of THREE.ShapeUtils.triangulateShape(outer, holes)) for (const i of [a, b, c]) pos.push(pts[i].x, y, -pts[i].y);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    scene.add(new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide, fog: true })));
  };
  const ribbon = (lines: number[][], half: number, color: number, y: number) => {
    const pos: number[] = [];
    for (const l of lines) {
      const n = l.length / 2;
      for (let i = 0; i < n - 1; i++) {
        const x1 = l[i * 2], y1 = l[i * 2 + 1], x2 = l[i * 2 + 2], y2 = l[i * 2 + 3];
        const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy) || 1, nx = -dy / L * half, ny = dx / L * half;
        const a = [x1 + nx, y1 + ny], b = [x1 - nx, y1 - ny], c = [x2 + nx, y2 + ny], d = [x2 - nx, y2 - ny];
        for (const [px, py] of [a, b, c, b, d, c]) pos.push(px, y, -py);
      }
      for (let i = 0; i < n; i++) for (let k = 0; k < 10; k++) {
        const a0 = (k / 10) * Math.PI * 2, a1 = ((k + 1) / 10) * Math.PI * 2, cx = l[i * 2], cy = l[i * 2 + 1];
        pos.push(cx, y, -cy, cx + Math.cos(a0) * half, y, -(cy + Math.sin(a0) * half), cx + Math.cos(a1) * half, y, -(cy + Math.sin(a1) * half));
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    scene.add(new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide, fog: true })));
  };
  ribbon(D.river, 44, 0x0b1726, 0.2);
  fill(D.areas.water, 0x0b1726, 0.25);
  fill(D.areas.park, 0x0b1510, 0.3);
  fill(D.areas.square, 0x13141a, 0.35);

  // ── Streets ──
  const roadLayer = (lines: number[][], color: number, opacity: number, y: number) => {
    const pos: number[] = [];
    for (const l of lines) for (let i = 0; i < l.length - 2; i += 2) pos.push(l[i], y, -l[i + 1], l[i + 2], y, -l[i + 3]);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    scene.add(new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color, transparent: true, opacity, fog: true })));
  };
  roadLayer(D.roads.foot, 0x262a35, 0.7, 0.5);
  roadLayer(D.roads.minor, 0x313644, 0.9, 0.6);
  roadLayer(D.roads.mid, 0x4a5062, 1, 0.7);
  roadLayer(D.roads.major, 0x6e6c62, 1, 0.8);

  // ── Buildings: one merged mesh; building id, roof flag and distance along the wall per vertex ──
  let buildings!: THREE.Mesh;
  {
    const rings = D.b.map(b => (b.slice(1) as number[][]).map(r => { const a: THREE.Vector2[] = []; for (let k = 0; k < r.length; k += 2) a.push(new THREE.Vector2(r[k], r[k + 1])); return a; }));
    const tris = rings.map(rs => THREE.ShapeUtils.triangulateShape(rs[0], rs.slice(1)));
    let nv = 0;
    rings.forEach((rs, i) => { nv += tris[i].length * 3; for (const r of rs) nv += r.length * 6; });
    const P = new Float32Array(nv * 3), N = new Float32Array(nv * 3), I = new Float32Array(nv), T = new Float32Array(nv), U = new Float32Array(nv);
    let o = 0;
    const put = (x: number, y: number, z: number, nx: number, nz: number, ny: number, id: number, top: number, u: number) => {
      P[o * 3] = x; P[o * 3 + 1] = y; P[o * 3 + 2] = z; N[o * 3] = nx; N[o * 3 + 1] = ny; N[o * 3 + 2] = nz; I[o] = id; T[o] = top; U[o] = u; o++;
    };
    const edges: number[] = [];
    rings.forEach((rs, id) => {
      const h = D.b[id][0] as number;
      const all = rs.flat();
      for (const [a, b, c] of tris[id]) for (const k of [a, b, c]) put(all[k].x, h, -all[k].y, 0, 0, 1, id, 1, 0);
      for (const r of rs) {
        let u = 0;
        for (let k = 0; k < r.length; k++) {
          const p1 = r[k], p2 = r[(k + 1) % r.length];
          const dx = p2.x - p1.x, dy = p2.y - p1.y, L = Math.hypot(dx, dy) || 1, nx = dy / L, nz = dx / L;
          put(p1.x, 0, -p1.y, nx, nz, 0, id, 0, u); put(p2.x, 0, -p2.y, nx, nz, 0, id, 0, u + L); put(p2.x, h, -p2.y, nx, nz, 0, id, 1, u + L);
          put(p1.x, 0, -p1.y, nx, nz, 0, id, 0, u); put(p2.x, h, -p2.y, nx, nz, 0, id, 1, u + L); put(p1.x, h, -p1.y, nx, nz, 0, id, 1, u);
          u += L;
          edges.push(p1.x, h + 0.15, -p1.y, p2.x, h + 0.15, -p2.y);
        }
      }
    });
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(P, 3));
    g.setAttribute('normal', new THREE.BufferAttribute(N, 3));
    g.setAttribute('bid', new THREE.BufferAttribute(I, 1));
    g.setAttribute('top', new THREE.BufferAttribute(T, 1));
    g.setAttribute('wu', new THREE.BufferAttribute(U, 1));
    g.computeBoundingSphere();
    const mat = new THREE.ShaderMaterial({
      uniforms: { ...uniforms, heat: { value: bTex } },
      side: THREE.DoubleSide,
      vertexShader: /* glsl */`
        attribute float bid; attribute float top; attribute float wu;
        uniform sampler2D heat;
        varying vec3 vN; varying float vY; varying float vU; varying vec4 vHeat; varying float vDist; varying float vId;
        void main() {
          int id = int(bid + .5);
          vHeat = texelFetch(heat, ivec2(id % ${TEX_W}, id / ${TEX_W}), 0);
          vN = normal; vY = position.y; vU = wu; vId = bid;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          vDist = -mv.z;
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        uniform vec3 uBg; uniform float uFogNear; uniform float uFogFar;
        varying vec3 vN; varying float vY; varying float vU; varying vec4 vHeat; varying float vDist; varying float vId;
        ${RAMP}
        float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
        void main() {
          float lv = vHeat.r, sel = vHeat.b, has = vHeat.a;
          vec3 n = normalize(vN);
          float roof = step(.5, n.y);
          float light = .5 + .5 * max(dot(n, normalize(vec3(.35, .9, .25))), 0.0);
          vec3 stone = vec3(.17, .175, .2);
          vec3 heat = ramp(lv);
          float lit = has * smoothstep(0.0, .06, lv);
          vec3 col;
          if (roof > .5) {
            col = mix(stone * 1.15, heat, lit);
          } else {
            // facade: dark stone tinted by the roof colour, darker towards the street
            col = mix(stone, heat * .55, lit * .35) * mix(.55, 1.0, smoothstep(0.0, 14.0, vY));
            vec2 cell = vec2(vU / 3.3, vY / 3.5);
            vec2 f = fract(cell);
            float aa = 1.0 - smoothstep(.22, .5, max(fwidth(cell.x), fwidth(cell.y)));
            float win = step(.26, f.x) * step(f.x, .74) * step(.28, f.y) * step(f.y, .8) * step(1.0, cell.y);
            float h = hash(vec3(floor(cell), vId));
            col *= 1.0 - win * aa * .4;
            col += win * aa * step(.68, h) * vec3(1.0, .74, .42) * (.09 + .16 * h);
            // shopfronts: the ground floor glows with the day's turnover
            float shop = (1.0 - step(1.0, cell.y)) * step(.15, f.x) * step(f.x, .85) * step(.12, f.y) * step(f.y, .8);
            col += shop * aa * lit * heat * .28;
          }
          col *= light;
          col = pow(col, vec3(2.2));
          col = mix(col, pow(vec3(1.0, .78, .1), vec3(2.2)) * (roof > .5 ? 1.0 : .55), sel * .85);
          col = mix(col, uBg, smoothstep(uFogNear, uFogFar, vDist));
          gl_FragColor = vec4(col, 1.0);
        }`,
    });
    buildings = new THREE.Mesh(g, mat);
    scene.add(buildings);
    // roof outlines: the crisp edge that makes the blocks read at any distance
    const eg = new THREE.BufferGeometry();
    eg.setAttribute('position', new THREE.Float32BufferAttribute(edges, 3));
    // (not on the landing: fine lines under a moving camera shimmer)
    if (!preview) scene.add(new THREE.LineSegments(eg, new THREE.LineBasicMaterial({ color: 0x5a5f70, transparent: true, opacity: 0.38, fog: true, depthWrite: false })));
  }

  // ── Places: a small dot on each roof, visible when close ──
  const catIndex = Object.fromEntries(CATS.map((c, i) => [c, i])) as Record<string, number>;
  const catCols = CATS.map(c => new THREE.Color(CAT_COLOR[c]));
  const catOn = { value: CATS.map(() => 1) };
  const scaleU = { value: 1 };
  {
    const n = sim.venues.length;
    const P = new Float32Array(n * 3), C = new Float32Array(n), I = new Float32Array(n);
    sim.venues.forEach((v, i) => { P[i * 3] = v.x; P[i * 3 + 1] = v.z; P[i * 3 + 2] = -v.y; C[i] = catIndex[v.cat]; I[i] = i; });
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(P, 3));
    g.setAttribute('cat', new THREE.BufferAttribute(C, 1));
    g.setAttribute('vid', new THREE.BufferAttribute(I, 1));
    const m = new THREE.ShaderMaterial({
      uniforms: { heat: { value: vTex }, cols: { value: catCols }, on: catOn, uScale: scaleU },
      transparent: true, depthWrite: false,
      vertexShader: /* glsl */`
        attribute float cat; attribute float vid;
        uniform sampler2D heat; uniform vec3 cols[8]; uniform float on[8]; uniform float uScale;
        varying vec3 vC; varying float vA; varying float vSel;
        void main() {
          int id = int(vid + .5); int c = int(cat + .5);
          vSel = texelFetch(heat, ivec2(id % ${TEX_W}, id / ${TEX_W}), 0).g;
          vC = cols[c];
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          float d = -mv.z;
          vA = on[c] * (1.0 - smoothstep(700.0, 1500.0, d)) + vSel;
          gl_PointSize = (vSel > .5 ? 16.0 : 6.0) * uScale * clamp(500.0 / d, .6, 1.6);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        varying vec3 vC; varying float vA; varying float vSel;
        void main() {
          float r = length(gl_PointCoord - .5) * 2.0;
          float a = smoothstep(1.0, .7, r) * min(vA, 1.0);
          if (a < .02) discard;
          float rim = smoothstep(.55, .75, r);
          gl_FragColor = vec4(mix(vC, vec3(.02), rim * .8), a);
        }`,
    });
    const pts = new THREE.Points(g, m);
    pts.frustumCulled = false;
    pts.renderOrder = 2;
    if (!preview) scene.add(pts);
  }

  // ── Payments: thin arcs with a short trail, a small head ──
  const arcGeo = new THREE.BufferGeometry();
  const NV = ARCS * SEG * 2;
  const aA = new Float32Array(NV * 3), aB = new Float32Array(NV * 3), aS = new Float32Array(NV), aM = new Float32Array(NV * 4), aC = new Float32Array(NV * 3);
  for (let a = 0; a < ARCS; a++) for (let s = 0; s < SEG; s++) { const i = (a * SEG + s) * 2; aS[i] = s / SEG; aS[i + 1] = (s + 1) / SEG; aM[i * 4] = -999; aM[i * 4 + 4] = -999; aM[i * 4 + 1] = 1; aM[i * 4 + 5] = 1; }
  const attr = (arr: Float32Array, n: number) => { const b = new THREE.BufferAttribute(arr, n); b.setUsage(THREE.DynamicDrawUsage); return b; };
  const arcAttrs = { a: attr(aA, 3), b: attr(aB, 3), m: attr(aM, 4), c: attr(aC, 3) };
  arcGeo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(NV * 3), 3));
  arcGeo.setAttribute('aA', arcAttrs.a); arcGeo.setAttribute('aB', arcAttrs.b); arcGeo.setAttribute('aS', new THREE.BufferAttribute(aS, 1));
  arcGeo.setAttribute('aM', arcAttrs.m); arcGeo.setAttribute('aC', arcAttrs.c);
  const arcVS = (head: boolean) => /* glsl */`
    attribute vec3 aA; attribute vec3 aB; attribute vec4 aM; attribute vec3 aC; ${head ? '' : 'attribute float aS;'}
    uniform float uTime; uniform float uScale;
    varying vec3 vC; varying float vA;
    vec3 bez(float s) { vec3 m = (aA + aB) * .5 + vec3(0.0, aM.z, 0.0); float u = 1.0 - s; return u * u * aA + 2.0 * u * s * m + s * s * aB; }
    void main() {
      float p = (uTime - aM.x) / aM.y;
      vC = aC;
      ${head ? `
      float s = clamp(p, 0.0, 1.0);
      vA = (p < 0.0 || p > 1.15) ? 0.0 : (p < 1.0 ? 1.0 : 1.0 - (p - 1.0) / .15);
      vec4 mv = modelViewMatrix * vec4(bez(s), 1.0);
      gl_PointSize = (aM.w > .5 ? 12.0 : 6.0) * uScale * clamp(900.0 / -mv.z, .5, 1.5);
      gl_Position = projectionMatrix * mv;` : `
      float lag = p - aS;
      vA = (p < 0.0 || lag < 0.0) ? 0.0 : exp(-lag * 4.5) * clamp(1.0 - (p - 1.0) / .35, 0.0, 1.0) * (aM.w > .5 ? 1.0 : .6);
      gl_Position = projectionMatrix * modelViewMatrix * vec4(bez(aS), 1.0);`}
    }`;
  const arcU = { ...uniforms, uScale: scaleU };
  const arcMat = new THREE.ShaderMaterial({
    uniforms: arcU, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: arcVS(false),
    fragmentShader: /* glsl */`varying vec3 vC; varying float vA; void main() { if (vA < .01) discard; gl_FragColor = vec4(vC * vA, vA); }`,
  });
  const arcs = new THREE.LineSegments(arcGeo, arcMat);
  arcs.frustumCulled = false;
  scene.add(arcs);

  const headGeo = new THREE.BufferGeometry();
  const hA = new Float32Array(ARCS * 3), hB = new Float32Array(ARCS * 3), hM = new Float32Array(ARCS * 4), hC = new Float32Array(ARCS * 3);
  for (let a = 0; a < ARCS; a++) { hM[a * 4] = -999; hM[a * 4 + 1] = 1; }
  const headAttrs = { a: attr(hA, 3), b: attr(hB, 3), m: attr(hM, 4), c: attr(hC, 3) };
  headGeo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(ARCS * 3), 3));
  headGeo.setAttribute('aA', headAttrs.a); headGeo.setAttribute('aB', headAttrs.b); headGeo.setAttribute('aM', headAttrs.m); headGeo.setAttribute('aC', headAttrs.c);
  const heads = new THREE.Points(headGeo, new THREE.ShaderMaterial({
    uniforms: arcU, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: arcVS(true),
    fragmentShader: /* glsl */`varying vec3 vC; varying float vA; void main() { float r = length(gl_PointCoord - .5) * 2.0; float a = smoothstep(1.0, .2, r) * vA; if (a < .01) discard; gl_FragColor = vec4(mix(vC, vec3(1.0), smoothstep(.45, 0.0, r) * .6) * a, a); }`,
  }));
  heads.frustumCulled = false;
  scene.add(heads);

  // ── Rings: only a declined payment and your own ──
  const ringGeo = new THREE.BufferGeometry();
  const rP = new Float32Array(RINGS * 3), rM = new Float32Array(RINGS * 2), rC = new Float32Array(RINGS * 3);
  for (let i = 0; i < RINGS; i++) rM[i * 2] = -999;
  const ringAttrs = { p: attr(rP, 3), m: attr(rM, 2), c: attr(rC, 3) };
  ringGeo.setAttribute('position', ringAttrs.p); ringGeo.setAttribute('aM', ringAttrs.m); ringGeo.setAttribute('aC', ringAttrs.c);
  const rings = new THREE.Points(ringGeo, new THREE.ShaderMaterial({
    uniforms: arcU, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */`
      attribute vec2 aM; attribute vec3 aC; uniform float uTime; uniform float uScale;
      varying vec3 vC; varying float vAge;
      void main() {
        vAge = (uTime - aM.x) / 1.6; vC = aC;
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = (vAge < 0.0 || vAge > 1.0) ? 0.0 : clamp(aM.y * (.25 + vAge) * uScale * 900.0 / -mv.z, 0.0, 160.0);
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: /* glsl */`
      varying vec3 vC; varying float vAge;
      void main() {
        float r = length(gl_PointCoord - .5) * 2.0;
        float a = smoothstep(.08, 0.0, abs(r - .86)) * (1.0 - vAge);
        if (a < .01) discard;
        gl_FragColor = vec4(vC * a, a);
      }`,
  }));
  rings.frustumCulled = false;
  scene.add(rings);

  let arcN = 0, ringN = 0;
  const dirty = { arc: [] as number[], ring: [] as number[] };
  const RED = new THREE.Color('#ff3b47'), YOU = new THREE.Color('#ffffff');
  const now = () => performance.now() / 1000;

  const spawn = (tx: Tx) => {
    const v = tx.venue;
    if (!sim.on[v.cat] && !tx.acc.you) return;
    const t0 = now();
    const a = arcN; arcN = (arcN + 1) % ARCS;
    const d = Math.hypot(v.x - tx.fx, v.y - tx.fy);
    const dur = 1.1 + Math.min(1.6, d / 1100);
    const h = 20 + d * 0.22 + v.z * 0.5;
    const col = tx.acc.you ? YOU : tx.ok ? catCols[catIndex[v.cat]] : RED;
    const big = tx.acc.you || !tx.ok ? 1 : 0;
    const A = [tx.fx, 2, -tx.fy], B = [v.x, v.z, -v.y];
    for (let s = 0; s < SEG * 2; s++) {
      const i = a * SEG * 2 + s;
      aA.set(A, i * 3); aB.set(B, i * 3); aC[i * 3] = col.r; aC[i * 3 + 1] = col.g; aC[i * 3 + 2] = col.b;
      aM[i * 4] = t0; aM[i * 4 + 1] = dur; aM[i * 4 + 2] = h; aM[i * 4 + 3] = big;
    }
    hA.set(A, a * 3); hB.set(B, a * 3); hC[a * 3] = col.r; hC[a * 3 + 1] = col.g; hC[a * 3 + 2] = col.b;
    hM[a * 4] = t0; hM[a * 4 + 1] = dur; hM[a * 4 + 2] = h; hM[a * 4 + 3] = big;
    dirty.arc.push(a);
    if (big) {
      const r = ringN; ringN = (ringN + 1) % RINGS;
      rP.set(B, r * 3); rM[r * 2] = t0 + dur; rM[r * 2 + 1] = tx.acc.you ? 90 : 60; rC[r * 3] = col.r; rC[r * 3 + 1] = col.g; rC[r * 3 + 2] = col.b;
      dirty.ring.push(r);
    }
  };

  const flush = () => {
    if (dirty.arc.length) {
      const lo = Math.min(...dirty.arc), hi = Math.max(...dirty.arc), n = SEG * 2;
      for (const [b, k] of [[arcAttrs.a, 3], [arcAttrs.b, 3], [arcAttrs.c, 3], [arcAttrs.m, 4]] as [THREE.BufferAttribute, number][]) {
        b.clearUpdateRanges(); b.addUpdateRange(lo * n * k, (hi - lo + 1) * n * k); b.needsUpdate = true;
      }
      for (const [b, k] of [[headAttrs.a, 3], [headAttrs.b, 3], [headAttrs.c, 3], [headAttrs.m, 4]] as [THREE.BufferAttribute, number][]) {
        b.clearUpdateRanges(); b.addUpdateRange(lo * k, (hi - lo + 1) * k); b.needsUpdate = true;
      }
      dirty.arc.length = 0;
    }
    if (dirty.ring.length) {
      const lo = Math.min(...dirty.ring), hi = Math.max(...dirty.ring);
      for (const [b, k] of [[ringAttrs.p, 3], [ringAttrs.m, 2], [ringAttrs.c, 3]] as [THREE.BufferAttribute, number][]) {
        b.clearUpdateRanges(); b.addUpdateRange(lo * k, (hi - lo + 1) * k); b.needsUpdate = true;
      }
      dirty.ring.length = 0;
    }
  };
  const prevOnTx = sim.onTx;
  sim.onTx = tx => { prevOnTx?.(tx); spawn(tx); };

  // ── Labels: rioni from afar, monuments and piazzas closer in; no overlaps, eased in and out ──
  const labelBox = document.createElement('div');
  labelBox.className = 'cl-labels';
  el.appendChild(labelBox);
  // well-known places get a label from afar; every other monument only when the camera is close
  const FAMOUS = /colosse|pantheon|fontana di trevi|navona|castel sant|san pietro|foro romano|fori imperiali|vittoriano|altare della patria|campidoglio|circo massimo|piazza di spagna|trinità dei monti|piazza del popolo|bocca della verit|ara pacis|teatro di marcello|largo di torre argentina|campo de' fiori|piazza venezia|mausoleo di augusto|quirinale|santa maria maggiore|terme di diocleziano|palatino|arco di costantino|trastevere/i;
  const labels = preview ? [] : D.labels.map(([x, y, name, k0]) => {
    const k = k0 === 1 && !FAMOUS.test(name) ? 3 : k0 === 2 && FAMOUS.test(name) ? 1 : k0;
    const s = document.createElement('span');
    s.className = `cl-lb k${k === 3 ? 1 : k}${k === 3 ? ' minor' : ''}`;
    s.textContent = k === 0 ? name.toUpperCase() : name;
    labelBox.appendChild(s);
    return { x, y, k, el: s, w: 0, on: false, z: k === 1 || k === 3 ? 22 : 4 };
  });
  let labelsOn = true;

  // ── Camera, controls, post ──
  const [bx0, by0, bx1, by1] = D.bounds;
  const HOME = { t: new THREE.Vector3(preview ? 150 : 60, 0, preview ? 60 : 40), off: new THREE.Vector3(-760, preview ? 1350 : 1500, 1500) };
  camera.position.copy(HOME.t).add(HOME.off);
  camera.lookAt(HOME.t);
  const controls = new MapControls(camera, renderer.domElement);
  controls.target.copy(HOME.t);
  controls.enableDamping = true; controls.dampingFactor = 0.07;
  controls.maxPolarAngle = 1.3; controls.minDistance = 90; controls.maxDistance = 5200;
  controls.autoRotateSpeed = preview ? 0.4 : 0.18;
  // the landing holds still: no rotation, nothing for the eye to chase
  controls.autoRotate = !preview;
  controls.zoomToCursor = true;
  controls.enabled = !preview;
  let lastUser = performance.now();
  let fly: { t0: number; dur: number; fromT: THREE.Vector3; toT: THREE.Vector3; fromP: THREE.Vector3; toP: THREE.Vector3 } | null = null;
  controls.addEventListener('start', () => { lastUser = performance.now(); controls.autoRotate = false; fly = null; });
  controls.addEventListener('end', () => { lastUser = performance.now(); });

  const rt = new THREE.WebGLRenderTarget(1, 1, { type: THREE.HalfFloatType, samples: 4 });
  const composer = new EffectComposer(renderer, rt);
  composer.addPass(new RenderPass(scene, camera));
  if (!preview) composer.addPass(new UnrealBloomPass(new THREE.Vector2(256, 256), 0.32, 0.4, 0.82));
  composer.addPass(new OutputPass());

  const resize = () => {
    const w = el.clientWidth, h = el.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    renderer.domElement.style.width = w + 'px'; renderer.domElement.style.height = h + 'px';
    composer.setPixelRatio(renderer.getPixelRatio());
    composer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    scaleU.value = Math.min(1.4, Math.max(.7, h / 900)) * renderer.getPixelRatio() / 1.5;
    for (const L of labels) L.w = 0;
  };
  const ro = new ResizeObserver(resize);
  ro.observe(el);
  resize();

  const flyTo = (x: number, y: number, dist = 520) => {
    const toT = new THREE.Vector3(x, 0, -y);
    const off = camera.position.clone().sub(controls.target).normalize();
    if (off.y < 0.5) { off.y = 0.62; off.normalize(); }
    fly = { t0: performance.now(), dur: 1500, fromT: controls.target.clone(), toT, fromP: camera.position.clone(), toP: toT.clone().add(off.multiplyScalar(dist)) };
    controls.autoRotate = false; lastUser = performance.now();
  };

  let selV: Venue | null = null;
  const ray = new THREE.Raycaster();
  let down: { x: number; y: number } | null = null;
  const onDown = (e: PointerEvent) => { down = { x: e.clientX, y: e.clientY }; };
  const onUp = (e: PointerEvent) => {
    if (!down || preview) return;
    const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
    down = null;
    if (moved > 6) return;
    const r = renderer.domElement.getBoundingClientRect();
    ray.setFromCamera(new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), camera);
    const hit = ray.intersectObject(buildings, false)[0] || ray.intersectObject(ground, false)[0];
    if (!hit) { opts.onPick?.(null); return; }
    const px = hit.point.x, py = -hit.point.z;
    const dist = (v: Venue) => Math.hypot(v.x - px, v.y - py);
    let best: Venue | null = null;
    if (hit.object === buildings && hit.faceIndex != null) {
      const bid = Math.round((buildings.geometry.getAttribute('bid') as THREE.BufferAttribute).getX(hit.faceIndex * 3));
      // the busiest place in the building first, then the nearest one
      best = sim.venues.filter(v => v.b === bid && sim.on[v.cat]).sort((a, b) => (b.rev - a.rev) || (dist(a) - dist(b)))[0] || null;
    }
    if (!best) best = sim.venuesNear(px, py, 40).filter(v => sim.on[v.cat]).sort((a, b) => dist(a) - dist(b))[0] || null;
    opts.onPick?.(best);
  };
  renderer.domElement.addEventListener('pointerdown', onDown);
  renderer.domElement.addEventListener('pointerup', onUp);

  // ── Loop ──
  let raf = 0, last = performance.now(), visible = true, frame = 0, maxRev = 1;
  const io = new IntersectionObserver(es => { visible = es[0]?.isIntersecting ?? true; if (visible && !raf) { last = performance.now(); raf = requestAnimationFrame(loop); } }, { rootMargin: '100px' });
  io.observe(el);
  const onVis = () => { if (!document.hidden && visible && !raf) { last = performance.now(); raf = requestAnimationFrame(loop); } };
  document.addEventListener('visibilitychange', onVis);
  const v3 = new THREE.Vector3();
  const boxes: [number, number, number, number][] = [];

  const placeLabels = () => {
    if (!labels.length) return;
    const W = el.clientWidth, H = el.clientHeight;
    const dist = camera.position.distanceTo(controls.target);
    boxes.length = 0;
    const cap = [10, 12, 8, 10], used = [0, 0, 0, 0];
    for (const k of [1, 0, 3, 2]) {
      const want = labelsOn && (k === 0 ? dist > 650 : k === 1 ? dist < 3200 : k === 2 ? dist < 750 : dist < 520);
      for (const L of labels) {
        if (L.k !== k) continue;
        let show = false;
        if (want) {
          v3.set(L.x, L.z, -L.y).project(camera);
          if (used[k] < cap[k] && v3.z < 1 && v3.x > -.95 && v3.x < .95 && v3.y > -.9 && v3.y < .85) {
            const sx = (v3.x * .5 + .5) * W, sy = (-v3.y * .5 + .5) * H;
            if (!L.w) L.w = L.el.offsetWidth || 80;
            const bx: [number, number, number, number] = [sx - L.w / 2 - 14, sy - 16, sx + L.w / 2 + 14, sy + 16];
            if (!boxes.some(b => bx[0] < b[2] && bx[2] > b[0] && bx[1] < b[3] && bx[3] > b[1])) {
              boxes.push(bx);
              used[k]++;
              show = true;
              L.el.style.transform = `translate(${sx.toFixed(1)}px, ${sy.toFixed(1)}px) translate(-50%, -50%)`;
            }
          }
        }
        if (show !== L.on) { L.on = show; L.el.classList.toggle('on', show); }
      }
    }
  };

  function loop(t: number) {
    raf = 0;
    if (!visible || document.hidden) return;
    const dt = Math.min(0.1, (t - last) / 1000);
    last = t;
    uniforms.uTime.value = now();
    sim.step(dt);
    flush();

    frame++;
    if (frame % 30 === 1) { let m = 1; for (let i = 0; i < nb; i++) if (sim.bRev[i] > m) m = sim.bRev[i]; maxRev = Math.max(m, 20000); }
    const lm = Math.log1p(maxRev), ease = 1 - Math.exp(-dt * 1.4);
    const selB = selV ? selV.b : -1;
    for (let i = 0; i < nb; i++) {
      const r = sim.bRev[i];
      const tgt = r > 0 ? 0.06 + 0.94 * Math.pow(Math.log1p(r) / lm, 2.4) : 0;
      shown[i] += (tgt - shown[i]) * ease;
      bHeat[i * 4] = shown[i] * 255;
      bHeat[i * 4 + 2] = i === selB ? 255 : 0;
      bHeat[i * 4 + 3] = hasVenue[i] ? 255 : 0;
    }
    bTex.needsUpdate = true;
    if (frame % 10 === 1) {
      for (let i = 0; i < sim.venues.length; i++) vHeat[i * 4 + 1] = selV && selV.i === i ? 255 : 0;
      vTex.needsUpdate = true;
    }

    if (fly) {
      const k = Math.min(1, (performance.now() - fly.t0) / fly.dur), e = k < .5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
      controls.target.lerpVectors(fly.fromT, fly.toT, e);
      camera.position.lerpVectors(fly.fromP, fly.toP, e);
      if (k >= 1) fly = null;
    } else if (!preview && !controls.autoRotate && performance.now() - lastUser > 30000 && !selV) controls.autoRotate = true;
    controls.target.x = Math.max(bx0, Math.min(bx1, controls.target.x));
    controls.target.z = Math.max(-by1, Math.min(-by0, controls.target.z));
    controls.update(dt);
    composer.render();
    placeLabels();
    raf = requestAnimationFrame(loop);
  }
  raf = requestAnimationFrame(loop);

  return {
    dispose() {
      cancelAnimationFrame(raf); raf = 0;
      io.disconnect(); ro.disconnect();
      document.removeEventListener('visibilitychange', onVis);
      renderer.domElement.removeEventListener('pointerdown', onDown);
      renderer.domElement.removeEventListener('pointerup', onUp);
      sim.onTx = prevOnTx;
      controls.dispose();
      scene.traverse(o => { const m = o as THREE.Mesh; m.geometry?.dispose(); (m.material as THREE.Material | undefined)?.dispose?.(); });
      bTex.dispose(); vTex.dispose(); rt.dispose();
      composer.dispose();
      renderer.dispose();
      renderer.domElement.remove();
      labelBox.remove();
    },
    flyTo,
    select(v) { selV = v; frame = 0; },
    setAuto(on) { controls.autoRotate = on; },
    setCats(on) { catOn.value = CATS.map(c => (on[c] ? 1 : 0)); },
    setLabels(on) { labelsOn = on; },
    home() {
      fly = { t0: performance.now(), dur: 1600, fromT: controls.target.clone(), toT: HOME.t.clone(), fromP: camera.position.clone(), toP: HOME.t.clone().add(HOME.off) };
    },
  };
}
