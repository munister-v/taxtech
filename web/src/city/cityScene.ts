import * as THREE from 'three';
import { MapControls } from 'three/examples/jsm/controls/MapControls.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { CATS, CAT_COLOR, type CitySim, type Tx, type Venue } from './citySim';

// The 3D city: every OpenStreetMap building of central Rome extruded to its height and coloured by the turnover of the
// places inside it (an inferno ramp, dark to white-hot), streets as hairlines, the Tiber as a ribbon. Each payment is
// an arc from where the payer stands to the roof of the place, a comet head, then a ring where it lands.
// Everything that moves is done in shaders over fixed pools, so a busy evening costs a few buffer range updates.

const BG = 0x040507;
const TEX_W = 128;
const ARCS = 900, SEG = 28, RINGS = 500;

export type SceneApi = {
  dispose(): void;
  flyTo(x: number, y: number, dist?: number): void;
  select(v: Venue | null): void;
  setAuto(on: boolean): void;
  setCats(on: Record<string, boolean>): void;
};

type Opts = { preview?: boolean; onPick?: (v: Venue | null) => void; onIdle?: () => void };

const W3 = (x: number, y: number, z = 0) => new THREE.Vector3(x, z, -y);

function rampGLSL() {
  return /* glsl */`
  vec3 ramp(float t) {
    t = clamp(t, 0.0, 1.0);
    vec3 c0 = vec3(.16,.05,.30), c1 = vec3(.62,.10,.42), c2 = vec3(.96,.30,.20), c3 = vec3(1.0,.64,.10), c4 = vec3(1.0,.95,.62);
    if (t < .25) return mix(c0, c1, t / .25);
    if (t < .5) return mix(c1, c2, (t - .25) / .25);
    if (t < .75) return mix(c2, c3, (t - .5) / .25);
    return mix(c3, c4, (t - .75) / .25);
  }`;
}

export function createCityScene(el: HTMLElement, sim: CitySim, opts: Opts = {}): SceneApi {
  const D = sim.D;
  const preview = !!opts.preview;
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, preview ? 1.5 : 1.75));
  renderer.setClearColor(BG, 1);
  el.appendChild(renderer.domElement);
  renderer.domElement.style.display = 'block';
  renderer.domElement.style.touchAction = preview ? 'pan-y' : 'none';

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(BG, 2600, 7200);
  const camera = new THREE.PerspectiveCamera(38, 1, 5, 24000);
  const uniforms = { uTime: { value: 0 }, uFogNear: { value: 2600 }, uFogFar: { value: 7200 }, uBg: { value: new THREE.Color(BG) } };

  // ── Heat textures: building turnover/pulse/selection, venue pulse/selection/category ──
  const bRows = Math.ceil(D.b.length / TEX_W);
  const bHeat = new Uint8Array(TEX_W * bRows * 4);
  const bTex = new THREE.DataTexture(bHeat, TEX_W, bRows, THREE.RGBAFormat);
  bTex.needsUpdate = true;
  const hasVenue = new Uint8Array(D.b.length);
  for (const v of sim.venues) if (v.b >= 0) hasVenue[v.b] = 1;
  const vRows = Math.ceil(sim.venues.length / TEX_W);
  const vHeat = new Uint8Array(TEX_W * vRows * 4);
  const vTex = new THREE.DataTexture(vHeat, TEX_W, vRows, THREE.RGBAFormat);
  vTex.needsUpdate = true;
  const vPulse = new Float32Array(sim.venues.length);

  // ── Ground, parks, river ──
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(40000, 40000), new THREE.MeshBasicMaterial({ color: 0x07080b }));
  ground.rotation.x = -Math.PI / 2;
  scene.add(ground);

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
      // round the joints
      for (let i = 0; i < n; i++) for (let k = 0; k < 10; k++) {
        const a0 = (k / 10) * Math.PI * 2, a1 = ((k + 1) / 10) * Math.PI * 2, cx = l[i * 2], cy = l[i * 2 + 1];
        pos.push(cx, y, -cy, cx + Math.cos(a0) * half, y, -(cy + Math.sin(a0) * half), cx + Math.cos(a1) * half, y, -(cy + Math.sin(a1) * half));
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide }));
    scene.add(m);
    return m;
  };
  ribbon(D.river, 46, 0x0a1a2c, 0.3);

  // ── Streets as hairlines ──
  const roadMat = (c: number, o: number) => new THREE.LineBasicMaterial({ color: c, transparent: true, opacity: o, fog: true });
  const roadLayer = (lines: number[][], mat: THREE.Material, y: number) => {
    const pos: number[] = [];
    for (const l of lines) for (let i = 0; i < l.length - 2; i += 2) pos.push(l[i], y, -l[i + 1], l[i + 2], y, -l[i + 3]);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    const s = new THREE.LineSegments(g, mat);
    scene.add(s);
    return s;
  };
  roadLayer(D.roads.foot, roadMat(0x2a2e3a, 0.55), 0.5);
  roadLayer(D.roads.minor, roadMat(0x353a48, 0.8), 0.6);
  roadLayer(D.roads.mid, roadMat(0x5a6074, 0.9), 0.7);
  roadLayer(D.roads.major, roadMat(0x8d8a7a, 1), 0.8);

  // ── Buildings: one merged mesh, building id per vertex ──
  {
    let nv = 0;
    const tris: number[][] = [];
    for (const b of D.b) {
      const n = (b.length - 1) / 2;
      const contour: THREE.Vector2[] = [];
      for (let k = 0; k < n; k++) contour.push(new THREE.Vector2(b[1 + k * 2], b[2 + k * 2]));
      const t = THREE.ShapeUtils.triangulateShape(contour, []);
      tris.push(t.flat());
      nv += t.length * 3 + n * 6;
    }
    const P = new Float32Array(nv * 3), N = new Float32Array(nv * 3), I = new Float32Array(nv), T = new Float32Array(nv);
    let o = 0;
    const put = (x: number, y: number, z: number, nx: number, ny: number, nz: number, id: number, top: number) => {
      P[o * 3] = x; P[o * 3 + 1] = y; P[o * 3 + 2] = z; N[o * 3] = nx; N[o * 3 + 1] = ny; N[o * 3 + 2] = nz; I[o] = id; T[o] = top; o++;
    };
    D.b.forEach((b, id) => {
      const h = b[0], n = (b.length - 1) / 2;
      for (const k of tris[id]) put(b[1 + k * 2], h, -b[2 + k * 2], 0, 1, 0, id, 1);
      for (let k = 0; k < n; k++) {
        const x1 = b[1 + k * 2], y1 = b[2 + k * 2], k2 = (k + 1) % n, x2 = b[1 + k2 * 2], y2 = b[2 + k2 * 2];
        const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy) || 1, nx = dy / L, nz = dx / L;
        put(x1, 0, -y1, nx, 0, nz, id, 0); put(x2, 0, -y2, nx, 0, nz, id, 0); put(x2, h, -y2, nx, 0, nz, id, 1);
        put(x1, 0, -y1, nx, 0, nz, id, 0); put(x2, h, -y2, nx, 0, nz, id, 1); put(x1, h, -y1, nx, 0, nz, id, 1);
      }
    });
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(P, 3));
    g.setAttribute('normal', new THREE.BufferAttribute(N, 3));
    g.setAttribute('bid', new THREE.BufferAttribute(I, 1));
    g.setAttribute('top', new THREE.BufferAttribute(T, 1));
    g.computeBoundingSphere();
    const mat = new THREE.ShaderMaterial({
      uniforms: { ...uniforms, heat: { value: bTex } },
      side: THREE.DoubleSide,
      vertexShader: /* glsl */`
        attribute float bid; attribute float top;
        uniform sampler2D heat;
        varying vec3 vN; varying float vTop; varying vec4 vHeat; varying float vDist;
        void main() {
          int id = int(bid + .5);
          vHeat = texelFetch(heat, ivec2(id % ${TEX_W}, id / ${TEX_W}), 0);
          vN = normal; vTop = top;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          vDist = -mv.z;
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        uniform vec3 uBg; uniform float uFogNear; uniform float uFogFar; uniform float uTime;
        varying vec3 vN; varying float vTop; varying vec4 vHeat; varying float vDist;
        ${rampGLSL()}
        void main() {
          float lv = vHeat.r, pulse = vHeat.g, sel = vHeat.b, has = vHeat.a;
          float light = .42 + .58 * max(dot(normalize(vN), normalize(vec3(.35, .9, .25))), 0.0);
          vec3 base = vec3(.2, .21, .25);
          vec3 col = has > .5 ? mix(base * 1.25, ramp(lv), smoothstep(0.0, .08, lv)) : base;
          col *= light * mix(.38, 1.0, vTop);
          col = pow(col, vec3(2.2));
          col += vec3(1.0, .7, .25) * pulse * pulse * vTop * .55;
          col = mix(col, vec3(1.0, .65, 0.0) * (0.8 + 0.3 * sin(uTime * 5.0)), sel * .8);
          col = mix(col, uBg, smoothstep(uFogNear, uFogFar, vDist));
          gl_FragColor = vec4(col, 1.0);
        }`,
    });
    const mesh = new THREE.Mesh(g, mat);
    mesh.name = 'buildings';
    scene.add(mesh);
  }
  const buildings = scene.getObjectByName('buildings') as THREE.Mesh;

  // ── Places: a dot on every roof, coloured by kind ──
  const catIndex = Object.fromEntries(CATS.map((c, i) => [c, i])) as Record<string, number>;
  const catCols = CATS.map(c => new THREE.Color(CAT_COLOR[c]));
  const catOn = { value: CATS.map(() => 1) };
  let venueMat!: THREE.ShaderMaterial;
  {
    const n = sim.venues.length;
    const P = new Float32Array(n * 3), C = new Float32Array(n), I = new Float32Array(n);
    sim.venues.forEach((v, i) => { P[i * 3] = v.x; P[i * 3 + 1] = v.z; P[i * 3 + 2] = -v.y; C[i] = catIndex[v.cat]; I[i] = i; });
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(P, 3));
    g.setAttribute('cat', new THREE.BufferAttribute(C, 1));
    g.setAttribute('vid', new THREE.BufferAttribute(I, 1));
    const m = new THREE.ShaderMaterial({
      uniforms: { ...uniforms, heat: { value: vTex }, cols: { value: catCols }, on: catOn, uScale: { value: 1 } },
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      vertexShader: /* glsl */`
        attribute float cat; attribute float vid;
        uniform sampler2D heat; uniform vec3 cols[8]; uniform float on[8]; uniform float uScale;
        varying vec3 vC; varying float vA; varying float vSel;
        void main() {
          int id = int(vid + .5); int c = int(cat + .5);
          vec4 h = texelFetch(heat, ivec2(id % ${TEX_W}, id / ${TEX_W}), 0);
          vC = cols[c]; vSel = h.g;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          float d = -mv.z;
          vA = on[c] * (.55 + h.r * 1.4) * (1.0 - smoothstep(3000.0, 7000.0, d));
          gl_PointSize = clamp((5.0 + h.r * 22.0 + vSel * 26.0) * uScale * 900.0 / d, 1.5, 48.0);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        varying vec3 vC; varying float vA; varying float vSel;
        void main() {
          float r = length(gl_PointCoord - .5) * 2.0;
          float core = smoothstep(1.0, .15, r);
          float ring = vSel * smoothstep(.12, 0.0, abs(r - .82));
          gl_FragColor = vec4(mix(vC, vec3(1.0), ring) * (core + ring), (core * .9 + ring) * vA);
        }`,
    });
    venueMat = m;
    const pts = new THREE.Points(g, m);
    pts.frustumCulled = false;
    scene.add(pts);
  }

  // ── Payments: arcs (trail) and heads, in fixed pools ──
  const arcGeo = new THREE.BufferGeometry();
  const aA = new Float32Array(ARCS * SEG * 2 * 3), aB = new Float32Array(ARCS * SEG * 2 * 3), aS = new Float32Array(ARCS * SEG * 2), aM = new Float32Array(ARCS * SEG * 2 * 4), aC = new Float32Array(ARCS * SEG * 2 * 3);
  for (let a = 0; a < ARCS; a++) for (let s = 0; s < SEG; s++) { const i = (a * SEG + s) * 2; aS[i] = s / SEG; aS[i + 1] = (s + 1) / SEG; aM[i * 4] = -999; aM[i * 4 + 4] = -999; aM[i * 4 + 1] = 1; aM[i * 4 + 5] = 1; }
  const attr = (arr: Float32Array, n: number) => { const b = new THREE.BufferAttribute(arr, n); b.setUsage(THREE.DynamicDrawUsage); return b; };
  const arcAttrs = { a: attr(aA, 3), b: attr(aB, 3), m: attr(aM, 4), c: attr(aC, 3) };
  arcGeo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(ARCS * SEG * 2 * 3), 3));
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
      vA = (p < 0.0 || p > 1.25) ? 0.0 : (p < 1.0 ? 1.0 : 1.0 - (p - 1.0) / .25);
      vec4 mv = modelViewMatrix * vec4(bez(s), 1.0);
      gl_PointSize = clamp((aM.w > .5 ? 34.0 : 18.0) * uScale * 900.0 / -mv.z, 2.0, 40.0);
      gl_Position = projectionMatrix * mv;` : `
      float s = aS;
      float lag = p - s;
      vA = (p < 0.0 || lag < 0.0) ? 0.0 : exp(-lag * 3.2) * clamp(1.0 - (p - 1.0) / .6, 0.0, 1.0);
      gl_Position = projectionMatrix * modelViewMatrix * vec4(bez(s), 1.0);`}
    }`;
  const arcMat = new THREE.ShaderMaterial({
    uniforms: { ...uniforms, uScale: { value: 1 } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: arcVS(false),
    fragmentShader: /* glsl */`varying vec3 vC; varying float vA; void main() { if (vA < .004) discard; gl_FragColor = vec4(vC * vA * 1.25, vA); }`,
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
  const headMat = new THREE.ShaderMaterial({
    uniforms: arcMat.uniforms, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: arcVS(true),
    fragmentShader: /* glsl */`varying vec3 vC; varying float vA; void main() { float r = length(gl_PointCoord - .5) * 2.0; float a = smoothstep(1.0, 0.0, r); a = a * a * vA; if (a < .01) discard; gl_FragColor = vec4(mix(vC, vec3(1.0), smoothstep(.5, 0.0, r)) * a * 2.0, a); }`,
  });
  const heads = new THREE.Points(headGeo, headMat);
  heads.frustumCulled = false;
  scene.add(heads);

  // ── Rings where a payment lands ──
  const ringGeo = new THREE.BufferGeometry();
  const rP = new Float32Array(RINGS * 3), rM = new Float32Array(RINGS * 2), rC = new Float32Array(RINGS * 3);
  for (let i = 0; i < RINGS; i++) rM[i * 2] = -999;
  const ringAttrs = { p: attr(rP, 3), m: attr(rM, 2), c: attr(rC, 3) };
  ringGeo.setAttribute('position', ringAttrs.p); ringGeo.setAttribute('aM', ringAttrs.m); ringGeo.setAttribute('aC', ringAttrs.c);
  const ringMat = new THREE.ShaderMaterial({
    uniforms: { ...uniforms, uScale: { value: 1 } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */`
      attribute vec2 aM; attribute vec3 aC; uniform float uTime; uniform float uScale;
      varying vec3 vC; varying float vAge;
      void main() {
        vAge = (uTime - aM.x) / 1.3; vC = aC;
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = (vAge < 0.0 || vAge > 1.0) ? 0.0 : clamp(aM.y * (.2 + vAge) * uScale * 900.0 / -mv.z, 0.0, 220.0);
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: /* glsl */`
      varying vec3 vC; varying float vAge;
      void main() {
        float r = length(gl_PointCoord - .5) * 2.0;
        float a = smoothstep(.16, 0.0, abs(r - .82)) * (1.0 - vAge) * (1.0 - vAge);
        if (a < .01) discard;
        gl_FragColor = vec4(vC * a * 1.6, a);
      }`,
  });
  const rings = new THREE.Points(ringGeo, ringMat);
  rings.frustumCulled = false;
  scene.add(rings);

  let arcN = 0, ringN = 0;
  const dirty = { arc: [] as number[], ring: [] as number[] };
  const RED = new THREE.Color('#ff2a3a'), YOU = new THREE.Color('#ffffff');
  const now = () => performance.now() / 1000;

  const spawn = (tx: Tx) => {
    const v = tx.venue;
    if (!sim.on[v.cat] && !tx.acc.you) return;
    const t0 = now();
    const a = arcN; arcN = (arcN + 1) % ARCS;
    const d = Math.hypot(v.x - tx.fx, v.y - tx.fy);
    const dur = 0.7 + Math.min(1.4, d / 1400);
    const h = 25 + d * 0.28 + v.z * 0.4;
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
    const r = ringN; ringN = (ringN + 1) % RINGS;
    rP.set(B, r * 3); rM[r * 2] = t0 + dur; rM[r * 2 + 1] = big ? 150 : 34 + Math.min(80, tx.amount / 60); rC[r * 3] = col.r; rC[r * 3 + 1] = col.g; rC[r * 3 + 2] = col.b;
    dirty.ring.push(r);
    pendingPulse.push([v.i, t0 + dur]);
  };
  const pendingPulse: [number, number][] = [];

  const flush = () => {
    if (dirty.arc.length) {
      const lo = Math.min(...dirty.arc), hi = Math.max(...dirty.arc);
      // a wrap-around makes the range the whole pool; still a single upload
      const n = SEG * 2;
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

  // ── Camera, controls, bloom ──
  const [bx0, by0, bx1, by1] = D.bounds;
  const target = new THREE.Vector3(preview ? 150 : 100, 0, preview ? 60 : 0);
  camera.position.copy(target).add(new THREE.Vector3(-900, preview ? 1500 : 2100, 1900));
  camera.lookAt(target);
  const controls = new MapControls(camera, renderer.domElement);
  controls.target.copy(target);
  controls.enableDamping = true; controls.dampingFactor = 0.08;
  controls.maxPolarAngle = 1.32; controls.minDistance = 120; controls.maxDistance = 6500;
  controls.autoRotateSpeed = preview ? 0.55 : 0.35;
  controls.autoRotate = true;
  controls.zoomToCursor = true;
  if (preview) { controls.enabled = false; }
  let lastUser = performance.now();
  controls.addEventListener('start', () => { lastUser = performance.now(); controls.autoRotate = false; fly = null; opts.onIdle?.(); });
  controls.addEventListener('end', () => { lastUser = performance.now(); });

  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), preview ? 0.75 : 0.8, 0.5, 0.62);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());

  const resize = () => {
    const w = el.clientWidth, h = el.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    renderer.domElement.style.width = w + 'px'; renderer.domElement.style.height = h + 'px';
    composer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    const sc = h / 900;
    arcMat.uniforms.uScale.value = sc; ringMat.uniforms.uScale.value = sc;
    venueMat.uniforms.uScale.value = sc;
  };
  const ro = new ResizeObserver(resize);
  ro.observe(el);
  resize();

  // ── Fly-to and picking ──
  let fly: { t0: number; dur: number; fromT: THREE.Vector3; toT: THREE.Vector3; fromP: THREE.Vector3; toP: THREE.Vector3 } | null = null;
  const flyTo = (x: number, y: number, dist = 520) => {
    const toT = W3(x, y, 0);
    const off = camera.position.clone().sub(controls.target).normalize();
    if (off.y < 0.45) { off.y = 0.6; off.normalize(); }
    fly = { t0: performance.now(), dur: 1300, fromT: controls.target.clone(), toT, fromP: camera.position.clone(), toP: toT.clone().add(off.multiplyScalar(dist)) };
    controls.autoRotate = false; lastUser = performance.now();
  };

  let selV: Venue | null = null;
  const select = (v: Venue | null) => { selV = v; };

  const ray = new THREE.Raycaster();
  let down: { x: number; y: number; t: number } | null = null;
  const onDown = (e: PointerEvent) => { down = { x: e.clientX, y: e.clientY, t: performance.now() }; };
  const onUp = (e: PointerEvent) => {
    if (!down || preview) return;
    const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
    down = null;
    if (moved > 6) return;
    const r = renderer.domElement.getBoundingClientRect();
    ray.setFromCamera(new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), camera);
    const hit = ray.intersectObject(buildings, false)[0] || ray.intersectObject(ground, false)[0];
    if (!hit) { opts.onPick?.(null); return; }
    let best: Venue | null = null;
    if (hit.object === buildings && hit.faceIndex != null) {
      const bid = Math.round((buildings.geometry.getAttribute('bid') as THREE.BufferAttribute).getX(hit.faceIndex * 3));
      const inB = sim.venues.filter(v => v.b === bid && sim.on[v.cat]);
      best = inB.sort((a, b) => Math.hypot(a.x - hit.point.x, a.y + hit.point.z) - Math.hypot(b.x - hit.point.x, b.y + hit.point.z))[0] || null;
    }
    if (!best) {
      const near = sim.venuesNear(hit.point.x, -hit.point.z, 45).filter(v => sim.on[v.cat]);
      best = near.sort((a, b) => Math.hypot(a.x - hit.point.x, a.y + hit.point.z) - Math.hypot(b.x - hit.point.x, b.y + hit.point.z))[0] || null;
    }
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

  function loop(t: number) {
    raf = 0;
    if (!visible || document.hidden) return;
    const dt = Math.min(0.1, (t - last) / 1000);
    last = t;
    const T = now();
    uniforms.uTime.value = T;
    (arcMat.uniforms.uTime as { value: number }).value = T;
    sim.step(dt);
    flush();

    // heat → textures
    frame++;
    if (frame % 20 === 1) { let m = 1; for (let i = 0; i < sim.bRev.length; i++) if (sim.bRev[i] > m) m = sim.bRev[i]; maxRev = Math.max(m, 20000); }
    const lm = Math.log1p(maxRev);
    const selB = selV ? selV.b : -1;
    for (let i = 0; i < D.b.length; i++) {
      const r = sim.bRev[i];
      bHeat[i * 4] = r > 0 ? Math.min(255, 18 + 237 * Math.log1p(r) / lm) : 0;
      bHeat[i * 4 + 1] = Math.min(255, sim.bPulse[i] * 255);
      bHeat[i * 4 + 2] = i === selB ? 255 : 0;
      bHeat[i * 4 + 3] = hasVenue[i] ? 255 : 0;
    }
    bTex.needsUpdate = true;
    for (let k = pendingPulse.length - 1; k >= 0; k--) if (pendingPulse[k][1] <= T) { vPulse[pendingPulse[k][0]] = 1; pendingPulse.splice(k, 1); }
    const kd = Math.exp(-dt * 2.2);
    for (let i = 0; i < vPulse.length; i++) {
      vPulse[i] *= kd;
      vHeat[i * 4] = vPulse[i] * 255;
      vHeat[i * 4 + 1] = selV && selV.i === i ? 255 : 0;
    }
    vTex.needsUpdate = true;

    if (fly) {
      const k = Math.min(1, (performance.now() - fly.t0) / fly.dur), e = k < .5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
      controls.target.lerpVectors(fly.fromT, fly.toT, e);
      camera.position.lerpVectors(fly.fromP, fly.toP, e);
      if (k >= 1) fly = null;
    } else if (!preview && !controls.autoRotate && performance.now() - lastUser > 14000 && !selV) controls.autoRotate = true;
    // keep the camera over the city
    controls.target.x = Math.max(bx0, Math.min(bx1, controls.target.x));
    controls.target.z = Math.max(-by1, Math.min(-by0, controls.target.z));
    controls.update(dt);
    composer.render();
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
      scene.traverse(o => { const m = o as THREE.Mesh; m.geometry?.dispose(); const mat = m.material as THREE.Material | undefined; mat?.dispose?.(); });
      bTex.dispose(); vTex.dispose();
      composer.dispose();
      renderer.dispose();
      renderer.domElement.remove();
    },
    flyTo,
    select,
    setAuto(on: boolean) { controls.autoRotate = on; },
    setCats(on: Record<string, boolean>) { catOn.value = CATS.map(c => (on[c] ? 1 : 0)); },
  };
}
