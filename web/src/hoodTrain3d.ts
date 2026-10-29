import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

// A metro train in a Roman station, rendered with three.js: three 19 m cars with a driver's cab, silver shell, our dark livery
// with the mark and the wordmark, lit windows, sliding plug doors, wheels and bogies, rails, a platform edge, arches behind.
// Loaded on demand by HoodPlatform. The page sets the phase (at / out / left); the train rolls in, opens its doors, shuts
// them and leaves. Units are metres.

export type TrainPhase = 'at' | 'out' | 'left';
export type TrainApi = { setPhase: (p: TrainPhase) => void; setLed: (s: string) => void; dispose: () => void };

const L = 19.2, GAP = 1.1, W = 2.9, BT = 0.07;       // car length, gangway, width, bevel
const Y0 = 0.55, Y1 = 3.72;                            // underside and roof of the shell
const DOORS = [-6.9, -2.3, 2.3, 6.9];
const XOFF = 47;                                       // far enough for the whole train to be out of frame

const ease = {
  outQuart: (k: number) => 1 - Math.pow(1 - k, 4),
  inCubic: (k: number) => k * k * k,
  inOut: (k: number) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2),
};
const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));

function canvasTex(w: number, h: number, draw: (c: CanvasRenderingContext2D) => void, repeatX = false): { tex: THREE.CanvasTexture; ctx: CanvasRenderingContext2D } {
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
  const ctx = cv.getContext('2d')!;
  draw(ctx);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
  if (repeatX) tex.wrapS = THREE.RepeatWrapping;
  return { tex, ctx };
}

// Lit interior seen through the glass: warm light, a ceiling strip, seat backs, poles and a few blurred passengers.
function interiorTexture(seed: number): THREE.CanvasTexture {
  return canvasTex(512, 160, c => {
    const g = c.createLinearGradient(0, 0, 0, 160);
    g.addColorStop(0, '#fff3d0'); g.addColorStop(0.18, '#f6d9a0'); g.addColorStop(1, '#a8772f');
    c.fillStyle = g; c.fillRect(0, 0, 512, 160);
    c.fillStyle = 'rgba(255,255,255,.9)'; c.fillRect(0, 0, 512, 8);
    c.fillStyle = 'rgba(70,48,18,.55)';
    c.fillStyle = 'rgba(86,58,24,.38)'; c.fillRect(0, 118, 512, 42);
    c.fillStyle = 'rgba(70,48,18,.5)'; for (let x = 0; x < 512; x += 64) c.fillRect(x + 62, 118, 2, 42);
    c.fillStyle = 'rgba(40,26,10,.5)'; c.fillRect(0, 150, 512, 10);
    c.strokeStyle = 'rgba(190,196,206,.9)'; c.lineWidth = 3.5;
    for (let x = 70; x < 512; x += 170) { c.beginPath(); c.moveTo(x, 6); c.lineTo(x, 152); c.stroke(); }
    c.beginPath(); c.moveTo(0, 38); c.lineTo(512, 38); c.stroke();
    c.filter = 'blur(2.4px)'; c.fillStyle = 'rgba(38,24,10,.78)';
    let s = seed * 9301 + 49297;
    const rnd = () => ((s = (s * 9301 + 49297) % 233280) / 233280);
    for (let i = 0; i < 3; i++) {
      if (rnd() < 0.4) continue;
      const x = 40 + rnd() * 430, h = 70 + rnd() * 18;
      c.beginPath(); c.arc(x, 160 - h - 8, 11, 0, 6.3); c.fill();
      c.beginPath(); c.roundRect(x - 17, 160 - h + 6, 34, h, 12); c.fill();
    }
    c.filter = 'none';
  }).tex;
}

function wallTexture(): THREE.CanvasTexture {
  return canvasTex(2048, 512, c => {
    const g = c.createLinearGradient(0, 0, 0, 512);
    g.addColorStop(0, '#0a0806'); g.addColorStop(1, '#1b130b');
    c.fillStyle = g; c.fillRect(0, 0, 2048, 512);
    // brick courses
    c.strokeStyle = 'rgba(120,86,48,.10)'; c.lineWidth = 1;
    for (let y = 0; y < 512; y += 16) { c.beginPath(); c.moveTo(0, y); c.lineTo(2048, y); c.stroke(); }
    const step = 205;
    for (let i = 0; i < 10; i++) {
      const cx = 102 + i * step;
      const ng = c.createLinearGradient(0, 120, 0, 460);
      ng.addColorStop(0, 'rgba(120,80,30,.15)'); ng.addColorStop(0.55, 'rgba(230,170,84,.5)'); ng.addColorStop(1, 'rgba(255,220,150,.2)');
      c.fillStyle = ng; c.beginPath(); c.moveTo(cx - 74, 470); c.lineTo(cx - 74, 250); c.arc(cx, 250, 74, Math.PI, 0); c.lineTo(cx + 74, 470); c.closePath(); c.fill();
      c.strokeStyle = 'rgba(220,193,149,.5)'; c.lineWidth = 3; c.stroke();
      c.strokeStyle = 'rgba(220,193,149,.2)'; c.lineWidth = 2;
      c.beginPath(); c.moveTo(cx - 90, 470); c.lineTo(cx - 90, 250); c.arc(cx, 250, 90, Math.PI, 0); c.lineTo(cx + 90, 470); c.stroke();
      const lg = c.createRadialGradient(cx, 190, 4, cx, 190, 120);
      lg.addColorStop(0, 'rgba(255,214,140,.55)'); lg.addColorStop(1, 'rgba(255,214,140,0)');
      c.fillStyle = lg; c.fillRect(cx - 120, 70, 240, 240);
      c.fillStyle = 'rgba(255,230,170,.95)'; c.fillRect(cx - 12, 186, 24, 8);
    }
  }, true).tex;
}

function liveryTexture(rose: string, onLoad: () => void): THREE.CanvasTexture {
  const img = new Image();
  const draw = (c: CanvasRenderingContext2D, withLogo: boolean) => {
    c.clearRect(0, 0, 1024, 256);
    const g = c.createLinearGradient(0, 0, 0, 256);
    g.addColorStop(0, '#202329'); g.addColorStop(1, '#0a0b0e');
    c.fillStyle = g; c.fillRect(0, 0, 1024, 256);
    // the card's guilloche, engraved in gold, behind the lettering
    c.save(); c.translate(512, 128); c.scale(7.2, 7.2); c.translate(-50, -50);
    c.strokeStyle = 'rgba(255,212,0,.5)'; c.lineWidth = 0.1; c.stroke(new Path2D(rose));
    c.restore();
    const vg = c.createLinearGradient(0, 0, 1024, 0);
    vg.addColorStop(0, 'rgba(0,0,0,.85)'); vg.addColorStop(0.28, 'rgba(0,0,0,0)'); vg.addColorStop(0.72, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,.85)');
    c.fillStyle = vg; c.fillRect(0, 0, 1024, 256);
    if (withLogo) {
      c.drawImage(img, 218, 52, 92, 108);
      c.fillStyle = '#fff'; c.textBaseline = 'alphabetic';
      c.font = '500 118px Inter, "SF Pro Display", Helvetica, Arial, sans-serif'; c.fillText('Tax', 334, 158);
      const w = c.measureText('Tax').width;
      c.font = '300 118px Inter, "SF Pro Display", Helvetica, Arial, sans-serif'; c.fillText('Tech', 334 + w, 158);
    }
  };
  const t = canvasTex(1024, 256, c => draw(c, false));
  img.onload = () => { draw(t.ctx, true); t.tex.needsUpdate = true; onLoad(); };
  img.src = '/icons/mark-white.svg';
  return t.tex;
}

function ledTexture(): { tex: THREE.CanvasTexture; set: (s: string) => void } {
  const { tex, ctx } = canvasTex(768, 56, () => {});
  const set = (s: string) => {
    ctx.fillStyle = '#050505'; ctx.fillRect(0, 0, 768, 56);
    ctx.fillStyle = '#ffb020'; ctx.font = '700 34px ui-monospace, Menlo, monospace'; ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
    ctx.shadowColor = 'rgba(255,176,32,.9)'; ctx.shadowBlur = 8;
    ctx.fillText(s.slice(0, 30), 384, 30);
    ctx.shadowBlur = 0;
    // LED matrix: dark grid over the glow
    ctx.fillStyle = 'rgba(0,0,0,.55)';
    for (let x = 0; x < 768; x += 4) ctx.fillRect(x, 0, 1, 56);
    for (let y = 0; y < 56; y += 4) ctx.fillRect(0, y, 768, 1);
    tex.needsUpdate = true;
  };
  set('');
  return { tex, set };
}

function glowTexture(): THREE.CanvasTexture {
  return canvasTex(128, 128, c => {
    const g = c.createRadialGradient(64, 64, 0, 64, 64, 64);
    g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.25, 'rgba(255,240,190,.6)'); g.addColorStop(1, 'rgba(255,240,190,0)');
    c.fillStyle = g; c.fillRect(0, 0, 128, 128);
  }).tex;
}

export function mountTrain(host: HTMLElement, rose: string): TrainApi {
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
  renderer.domElement.className = 'bl-plat-gl';
  host.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x070605);
  scene.fog = new THREE.Fog(0x070605, 26, 60);
  const pm = new THREE.PMREMGenerator(renderer);
  scene.environment = pm.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.55;

  const camera = new THREE.PerspectiveCamera(26, 3.5, 0.5, 120);
  const camBase = new THREE.Vector3(-2.2, 2.6, 13.5);
  camera.position.copy(camBase); camera.lookAt(0.4, 2.0, 0);

  scene.add(new THREE.HemisphereLight(0xffe2b0, 0x1a1008, 0.5));
  [-9, 0, 9].forEach(x => { const p = new THREE.PointLight(0xffd8a0, 38, 22, 2); p.position.set(x, 5.4, 3.5); scene.add(p); });

  // ── station: tunnel wall with arches, track bed, rails, platform edge
  const wallTex = wallTexture();
  const wall = new THREE.Mesh(new THREE.PlaneGeometry(61, 11), new THREE.MeshBasicMaterial({ map: wallTex, fog: true }));
  wall.position.set(0, 4.6, -4.4); scene.add(wall);
  const bed = new THREE.Mesh(new THREE.PlaneGeometry(80, 6.2), new THREE.MeshStandardMaterial({ color: 0x0d0c0b, roughness: 0.95 }));
  bed.rotation.x = -Math.PI / 2; bed.position.set(0, 0, -1.35); scene.add(bed);
  const railM = new THREE.MeshStandardMaterial({ color: 0x8a919b, metalness: 0.9, roughness: 0.35 });
  [-0.72, 0.72].forEach(z => { const r = new THREE.Mesh(new THREE.BoxGeometry(80, 0.18, 0.12), railM); r.position.set(0, 0.12, z); scene.add(r); });
  const sleepers = new THREE.InstancedMesh(new THREE.BoxGeometry(0.28, 0.1, 2.5), new THREE.MeshStandardMaterial({ color: 0x1b1814, roughness: 0.9 }), 140);
  { const m = new THREE.Matrix4(); for (let i = 0; i < 140; i++) { m.setPosition(-40 + i * 0.58, 0.05, 0); sleepers.setMatrixAt(i, m); } scene.add(sleepers); }
  const platTop = new THREE.Mesh(new THREE.BoxGeometry(80, 1.2, 9), new THREE.MeshStandardMaterial({ color: 0x241d16, roughness: 0.28, metalness: 0.15, envMapIntensity: 0.8 }));
  platTop.position.set(0, 0.4, 6.3); scene.add(platTop);                 // top face at y = 1.0, edge at z = 1.8
  const strip = new THREE.Mesh(new THREE.BoxGeometry(80, 0.02, 0.4), new THREE.MeshStandardMaterial({ color: 0xffd400, emissive: 0x6a5500, roughness: 0.5 }));
  strip.position.set(0, 1.011, 2.05); scene.add(strip);
  const tile = canvasTex(256, 256, c => { c.fillStyle = '#16120d'; c.fillRect(0, 0, 256, 256); c.strokeStyle = 'rgba(220,193,149,.14)'; c.lineWidth = 2; for (let i = 0; i <= 256; i += 64) { c.beginPath(); c.moveTo(i, 0); c.lineTo(i, 256); c.moveTo(0, i); c.lineTo(256, i); c.stroke(); } }).tex;
  tile.wrapS = tile.wrapT = THREE.RepeatWrapping; tile.repeat.set(40, 4);
  (platTop.material as THREE.MeshStandardMaterial).map = tile;

  // ── the train
  const train = new THREE.Group();
  scene.add(train);
  const stepX = L + GAP;
  const bodyM = new THREE.MeshPhysicalMaterial({ color: 0xdde1e7, metalness: 0.72, roughness: 0.34, clearcoat: 0.7, clearcoatRoughness: 0.18, envMapIntensity: 1.25 });
  const darkM = new THREE.MeshPhysicalMaterial({ color: 0x0b0c10, metalness: 0.35, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.12 });
  const yellowM = new THREE.MeshStandardMaterial({ color: 0xffd400, emissive: 0x4d3b00, roughness: 0.38, metalness: 0.25 });
  const rubberM = new THREE.MeshStandardMaterial({ color: 0x0a0a0c, roughness: 0.85 });
  const steelM = new THREE.MeshStandardMaterial({ color: 0x9aa1ab, metalness: 0.9, roughness: 0.35 });
  const glassM = new THREE.MeshPhysicalMaterial({ color: 0x05080e, metalness: 1, roughness: 0.04, transparent: true, opacity: 0.3, envMapIntensity: 1.8, depthWrite: false });
  const cabGlassM = new THREE.MeshPhysicalMaterial({ color: 0x06090f, metalness: 0.9, roughness: 0.06, clearcoat: 1, envMapIntensity: 1.6 });
  const interiors = [interiorTexture(1), interiorTexture(2), interiorTexture(3), interiorTexture(4)];
  const intM = interiors.map(t => new THREE.MeshBasicMaterial({ map: t, toneMapped: true }));
  const livery = liveryTexture(rose, () => {});
  const liveryM = new THREE.MeshStandardMaterial({ map: livery, roughness: 0.3, metalness: 0.3, emissive: 0xffffff, emissiveMap: livery, emissiveIntensity: 0.16 });
  const led = ledTexture();
  const ledM = new THREE.MeshBasicMaterial({ map: led.tex });
  const glow = glowTexture();

  const ZF = W / 2 + BT + 0.004;                          // plane that sits on the side of the shell
  const leaves: { m: THREE.Object3D; base: number; dir: number }[] = [];
  const spills: THREE.Mesh[] = [];

  const shellGeo = (head: boolean) => {
    const s = new THREE.Shape();
    const x0 = -L / 2, x1 = L / 2, r = 0.32;
    s.moveTo(x0 + r, Y0); s.lineTo(x1 - r, Y0); s.quadraticCurveTo(x1, Y0, x1, Y0 + r);
    if (head) {
      s.lineTo(x1, 1.5); s.bezierCurveTo(x1 - 0.1, 2.5, x1 - 1.1, 3.35, x1 - 2.7, Y1 - 0.02);
    } else {
      s.lineTo(x1, Y1 - r); s.quadraticCurveTo(x1, Y1, x1 - r, Y1);
    }
    s.lineTo(x0 + r, Y1); s.quadraticCurveTo(x0, Y1, x0, Y1 - r); s.lineTo(x0, Y0 + r); s.quadraticCurveTo(x0, Y0, x0 + r, Y0);
    const g = new THREE.ExtrudeGeometry(s, { depth: W, bevelEnabled: true, bevelSize: BT, bevelThickness: BT, bevelSegments: 3, curveSegments: 18 });
    g.translate(0, 0, -W / 2);
    return g;
  };
  const plane = (w: number, h: number, mat: THREE.Material, x: number, y: number, z: number) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat); m.position.set(x, y, z); return m;
  };

  function buildCar(i: number, head: boolean): THREE.Group {
    const car = new THREE.Group();
    car.position.x = (i - 1) * stepX;
    car.add(new THREE.Mesh(shellGeo(head), bodyM));

    // livery: dark skirt panel and the yellow line, then the roof-edge line
    car.add(plane(L - 0.4, 0.88, darkM, 0, 1.01, ZF));
    car.add(plane(L - 0.4, 0.11, yellowM, 0, 1.5, ZF + 0.001));
    car.add(plane(L - 0.4, 0.04, new THREE.MeshStandardMaterial({ color: 0x20242b, roughness: 0.5 }), 0, 3.12, ZF + 0.001));
    const lv = plane(5.6, 1.4, liveryM, 0, 0.98, ZF + 0.003); lv.scale.set(0.55, 0.55, 1); car.add(lv);

    // windows between the doors: lit interior behind a reflective pane, in a rubber gasket
    const bounds: [number, number][] = [[-L / 2 + 0.5, DOORS[0] - 0.78], [DOORS[0] + 0.78, DOORS[1] - 0.78], [DOORS[1] + 0.78, DOORS[2] - 0.78], [DOORS[2] + 0.78, DOORS[3] - 0.78], [DOORS[3] + 0.78, L / 2 - 0.5]];
    bounds.forEach(([a, b], k) => {
      if (head && k === 4) return;
      const w = b - a, parts = w > 3 ? 2 : 1, pw = (w - (parts - 1) * 0.14) / parts;
      for (let p = 0; p < parts; p++) {
        const cx = a + pw / 2 + p * (pw + 0.14), cy = 2.38, h = 1.2;
        car.add(plane(pw + 0.1, h + 0.1, rubberM, cx, cy, ZF + 0.002));
        car.add(plane(pw, h, intM[(i + k + p) % 4], cx, cy, ZF + 0.004));
        car.add(plane(pw, h, glassM, cx, cy, ZF + 0.006));
      }
    });
    if (head) {
      // cab side window following the slope of the nose
      const s = new THREE.Shape(); s.moveTo(7.75, 1.8); s.lineTo(7.75, 3.1); s.lineTo(8.75, 3.2); s.bezierCurveTo(9.15, 2.9, 9.4, 2.3, 9.5, 1.8); s.closePath();
      const m = new THREE.Mesh(new THREE.ShapeGeometry(s), cabGlassM); m.position.z = ZF + 0.004; car.add(m);
      const frame = new THREE.Mesh(new THREE.ShapeGeometry(s), rubberM); frame.scale.set(1.04, 1.04, 1); frame.position.set(-0.32, -0.07, ZF + 0.002); car.add(frame);
      // headlight and the red marker on the tail
      const hl = new THREE.Sprite(new THREE.SpriteMaterial({ map: glow, color: 0xfff2c0, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
      hl.position.set(L / 2 + 0.2, 1.05, 1.0); hl.scale.set(4, 4, 1); car.add(hl);
    }

    // plug doors: lit vestibule, two leaves that slide apart, a status light above
    DOORS.forEach(dc => {
      if (head && dc === DOORS[3]) return;
      const opening = plane(1.42, 1.98, intM[(i + 1) % 4], dc, 2.04, ZF + 0.006); car.add(opening);
      car.add(plane(1.5, 0.06, rubberM, dc, 3.05, ZF + 0.008));
      [-1, 1].forEach(dir => {
        const leaf = new THREE.Group();
        const slab = new THREE.Mesh(new THREE.BoxGeometry(0.7, 1.96, 0.05), new THREE.MeshPhysicalMaterial({ color: 0xcfd4db, metalness: 0.7, roughness: 0.3, clearcoat: 0.6 }));
        leaf.add(slab);
        const gl = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 1.12), cabGlassM); gl.position.set(0, 0.28, 0.027); leaf.add(gl);
        const gm = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 1.12), glassM); gm.position.set(0, 0.28, 0.029); leaf.add(gm);
        const edge = new THREE.Mesh(new THREE.BoxGeometry(0.04, 1.96, 0.06), rubberM); edge.position.x = -dir * 0.35; leaf.add(edge);
        leaf.position.set(dc + dir * 0.35, 2.04, ZF + 0.034);
        car.add(leaf);
        leaves.push({ m: leaf, base: dc + dir * 0.35, dir });
      });
      const lamp = plane(0.4, 0.08, new THREE.MeshBasicMaterial({ color: 0x2fd07a }), dc, 3.2, ZF + 0.008); car.add(lamp);
      // light spilling onto the platform
      const sp = new THREE.Mesh(new THREE.PlaneGeometry(2.1, 2.2), new THREE.MeshBasicMaterial({ map: glow, color: 0xffe3a0, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false }));
      sp.rotation.x = -Math.PI / 2; sp.position.set(car.position.x + dc, 1.02, 3.0); sp.userData.dc = dc; spills.push(sp); scene.add(sp); sp.userData.car = car;
    });

    // roof equipment and the destination board under the roof line
    [-5.4, 5.4].forEach(x => { const ac = new THREE.Mesh(new THREE.BoxGeometry(2.7, 0.34, 1.5), new THREE.MeshStandardMaterial({ color: 0xb7bdc7, metalness: 0.6, roughness: 0.4 })); ac.position.set(x, Y1 + 0.16, 0); car.add(ac); });
    if (i === 1) {
      const pg = new THREE.Group();
      [[-0.9, 0.9], [0.9, 0.9]].forEach(([x, y]) => { const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 1.5, 6), steelM); arm.position.set(x * 0.4, y * 0.75, 0); arm.rotation.z = x * 0.4; pg.add(arm); });
      const bar = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.06, 1.8), steelM); bar.position.set(0, 1.62, 0); pg.add(bar);
      pg.position.set(0, Y1 + 0.2, 0); car.add(pg);
    }
    car.add(plane(3.4, 0.27, ledM, 0, 3.42, ZF + 0.004));
    car.add(plane(3.52, 0.34, rubberM, 0, 3.42, ZF + 0.002));
    if (head) {
      const wiper = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.02, 0.02), steelM); wiper.position.set(L / 2 - 1.2, 2.4, 0.4); wiper.rotation.z = 0.6; car.add(wiper);
    }

    // bogies: frame, four wheels, brake discs, partly hidden behind the platform edge
    [-6.2, 6.2].forEach(x => {
      const bg = new THREE.Group(); bg.position.set(x, 0, 0);
      const fr = new THREE.Mesh(new THREE.BoxGeometry(3.6, 0.28, 2.2), new THREE.MeshStandardMaterial({ color: 0x1b1d22, metalness: 0.6, roughness: 0.5 })); fr.position.y = 0.62; bg.add(fr);
      [-1.25, 1.25].forEach(wx => [-0.72, 0.72].forEach(wz => {
        const wh = new THREE.Mesh(new THREE.CylinderGeometry(0.46, 0.46, 0.14, 28), new THREE.MeshStandardMaterial({ color: 0x2b2e34, metalness: 0.9, roughness: 0.35 }));
        wh.rotation.x = Math.PI / 2; wh.position.set(wx, 0.5, wz); bg.add(wh);
      }));
      car.add(bg);
    });
    // equipment boxes under the floor
    [-2.2, 2.2].forEach(x => { const bx = new THREE.Mesh(new THREE.BoxGeometry(2.6, 0.5, 2.0), new THREE.MeshStandardMaterial({ color: 0x23262c, metalness: 0.5, roughness: 0.55 })); bx.position.set(x, 0.4, 0); car.add(bx); });
    return car;
  }
  [0, 1, 2].forEach(i => train.add(buildCar(i, i === 2)));
  // gangways between the cars
  [0, 1].forEach(i => {
    const x = (i - 1) * stepX + L / 2 + GAP / 2;
    const gw = new THREE.Mesh(new THREE.BoxGeometry(GAP + 0.1, 3.0, 2.5), new THREE.MeshStandardMaterial({ color: 0x0d0e11, roughness: 0.9 }));
    gw.position.set(x, 2.05, 0); train.add(gw);
    for (let k = -4; k <= 4; k++) { const rb = new THREE.Mesh(new THREE.BoxGeometry(0.03, 3.02, 2.52), new THREE.MeshStandardMaterial({ color: 0x2a2d34, roughness: 0.8 })); rb.position.set(x + k * 0.11, 2.05, 0); train.add(rb); }
  });

  // ── motion
  let phase: TrainPhase = 'left';
  let x = -XOFF, from = -XOFF, to = -XOFF, t0 = 0, dur = 1, fn = ease.outQuart, open = 0, openTo = 0, openT0 = 0, openFrom = 0, openDelay = 0;
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const go = (target: number, ms: number, f: (k: number) => number, delay = 0) => { from = x; to = target; dur = Math.max(1, ms); fn = f; t0 = performance.now() + delay; };
  const setOpen = (v: number, delay = 0) => { openFrom = open; openTo = v; openT0 = performance.now() + delay; openDelay = 1; };
  const api: TrainApi = {
    setPhase(p) {
      if (p === phase) return;
      phase = p;
      if (p === 'left') { x = from = to = -XOFF; open = openTo = 0; }
      else if (p === 'at') { if (reduce) { x = from = to = 0; setOpen(1); } else { go(0, 2600, ease.outQuart); setOpen(1, 2700); } }
      else { setOpen(0); if (reduce) { x = from = to = XOFF; } else go(XOFF, 1500, ease.inCubic, 600); }
    },
    setLed(s) { led.set(s); },
    dispose() { cancelAnimationFrame(raf); ro.disconnect(); io.disconnect(); renderer.dispose(); scene.traverse(o => { const m = o as THREE.Mesh; if (m.geometry) m.geometry.dispose(); }); renderer.domElement.remove(); },
  };

  let raf = 0, visible = true;
  const resize = () => {
    const w = host.clientWidth || 1, h = host.clientHeight || 1;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.fov = w / h < 2 ? 38 : 33;
    camera.updateProjectionMatrix();
  };
  const ro = new ResizeObserver(resize); ro.observe(host); resize();
  const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting; if (visible && !raf) raf = requestAnimationFrame(frame); }, { threshold: 0.01 });
  io.observe(host);

  function frame(now: number) {
    raf = 0;
    if (!visible || document.hidden) { raf = visible ? requestAnimationFrame(frame) : 0; return; }
    if (now >= t0) x = from + (to - from) * fn(clamp((now - t0) / dur));
    train.position.x = x;
    if (openDelay && now >= openT0) { const k = clamp((now - openT0) / 650); open = openFrom + (openTo - openFrom) * ease.inOut(k); if (k >= 1) openDelay = 0; }
    leaves.forEach(l => { l.m.position.x = l.base + l.dir * 0.66 * open; });
    spills.forEach(sp => { sp.position.x = x + (sp.userData.car as THREE.Group).position.x + sp.userData.dc; (sp.material as THREE.MeshBasicMaterial).opacity = 0.55 * open; });
    const s = now / 1000;
    camera.position.set(camBase.x + Math.sin(s * 0.25) * 0.25, camBase.y + Math.sin(s * 0.19) * 0.04, camBase.z);
    camera.lookAt(0.4, 2.0, 0);
    renderer.render(scene, camera);
    raf = requestAnimationFrame(frame);
  }
  raf = requestAnimationFrame(frame);
  return api;
}
