import * as THREE from 'three';
import { SVGLoader } from 'three/examples/jsm/loaders/SVGLoader.js';
import markSvg from './assets/mark.svg?raw';

// The hero's chrome objects: the TaxTech mark in liquid chrome, gold TAX coins and chrome spheres scattered in depth.
// The chrome look comes from a studio environment drawn for it: a bright sky, a sharp horizon, a dark floor, two
// softboxes and a warm glow, so every face carries gradients and bands that slide as it turns. On load the mark turns
// to face the viewer and the small things drop in; then everything floats, and the depth layers drift with the pointer.
// A few dozen draw calls: cheap; paused while the hero is off screen.

export type ChromeApi = { dispose(): void };

function markShapes() {
  const data = new SVGLoader().parse(markSvg);
  const shapes: THREE.Shape[] = [];
  for (const p of data.paths) shapes.push(...SVGLoader.createShapes(p));
  return shapes;
}

/** The mark as a bevelled solid, centred, about 2 units tall */
function markGeometry(depth: number, bevel: number) {
  const g = new THREE.ExtrudeGeometry(markShapes(), { depth, bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 8, curveSegments: 48 });
  g.center();
  g.computeBoundingBox();
  const h = g.boundingBox!.max.y - g.boundingBox!.min.y;
  const k = 2 / h;
  g.scale(k, -k, k);                 // SVG y runs down
  g.computeVertexNormals();
  return g;
}

/** A coin: a lathe profile with a rounded rim */
function coinGeometry(r: number, t: number) {
  const pts: THREE.Vector2[] = [new THREE.Vector2(0, -t / 2)];
  const rim = t / 2;
  pts.push(new THREE.Vector2(r - rim, -t / 2));
  for (let i = 0; i <= 12; i++) { const a = -Math.PI / 2 + (i / 12) * Math.PI; pts.push(new THREE.Vector2(r - rim + Math.cos(a) * rim, Math.sin(a) * rim)); }
  pts.push(new THREE.Vector2(0, t / 2));
  const g = new THREE.LatheGeometry(pts, 96);
  g.rotateX(Math.PI / 2);
  return g;
}

/** The studio the chrome reflects: sky, horizon, floor, softboxes, a warm glow */
function studio(): THREE.Scene {
  const s = new THREE.Scene();
  const dome = new THREE.Mesh(new THREE.SphereGeometry(40, 64, 32), new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false,
    vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
    fragmentShader: `varying vec3 vP;
      void main(){
        float y = vP.y;
        vec3 sky = mix(vec3(1.25, 1.2, 1.12), vec3(0.55, 0.6, 0.72), smoothstep(0.05, 0.9, y));
        vec3 floor_ = mix(vec3(0.05, 0.04, 0.03), vec3(0.16, 0.12, 0.07), smoothstep(-0.9, -0.02, y));
        vec3 c = y > 0.0 ? sky : floor_;
        c += vec3(1.6, 1.45, 1.2) * exp(-pow(y * 22.0, 2.0));                     // the bright horizon line
        c += vec3(1.1, 0.75, 0.25) * 0.55 * exp(-pow((vP.x - 0.7) * 3.0, 2.0) - pow((y + 0.1) * 3.0, 2.0)); // warm glow
        gl_FragColor = vec4(c, 1.0);
      }`,
  }));
  s.add(dome);
  const box = new THREE.MeshBasicMaterial({ color: new THREE.Color(5, 5, 4.6) });
  const a = new THREE.Mesh(new THREE.PlaneGeometry(10, 1.2), box); a.position.set(0, 6, 12); a.lookAt(0, 0, 0); s.add(a);
  const b = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 9), box); b.position.set(-11, 1, 6); b.lookAt(0, 0, 0); s.add(b);
  const c = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 6), new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 2.4, 1.2) })); c.position.set(10, -1, 4); c.lookAt(0, 0, 0); s.add(c);
  return s;
}

const easeOut = (x: number) => 1 - Math.pow(1 - Math.min(1, Math.max(0, x)), 3);
const easeBack = (x: number) => { const k = Math.min(1, Math.max(0, x)), c = 1.4; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); };

type Bit = { obj: THREE.Object3D; base: THREE.Vector3; depth: number; spin: number; phase: number; delay: number; coin: boolean; show: boolean };

export function createChromeScene(el: HTMLElement, opts: { still?: boolean } = {}): ChromeApi {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  el.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x050506, 10, 17);          // the far small things sink into the dark
  const pmrem = new THREE.PMREMGenerator(renderer);
  const studioScene = studio();
  const env = pmrem.fromScene(studioScene, 0.02).texture;
  scene.environment = env;

  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 0, 9);

  const rim = new THREE.DirectionalLight(0xffd400, 1.6); rim.position.set(-4, 1, -3); scene.add(rim);

  const chrome = new THREE.MeshPhysicalMaterial({ color: 0xffffff, metalness: 1, roughness: 0.035, envMapIntensity: 1.25 });
  const gold = new THREE.MeshPhysicalMaterial({ color: 0xffc547, metalness: 1, roughness: 0.14, envMapIntensity: 1.15 });
  const goldDeep = new THREE.MeshPhysicalMaterial({ color: 0xd99a28, metalness: 1, roughness: 0.3, envMapIntensity: 1 });

  const group = new THREE.Group();
  scene.add(group);

  const mark = new THREE.Mesh(markGeometry(0.42, 0.08), chrome);
  group.add(mark);

  const coinGeo = coinGeometry(0.62, 0.13);
  const em = markGeometry(0.035, 0.012);
  em.scale(0.36, 0.36, 1);
  const makeCoin = () => {
    const c = new THREE.Group();
    c.add(new THREE.Mesh(coinGeo, gold));
    const f = new THREE.Mesh(em, goldDeep); f.position.z = 0.07; c.add(f);
    const k = new THREE.Mesh(em, goldDeep); k.position.z = -0.07; k.rotation.y = Math.PI; c.add(k);
    return c;
  };
  const ballGeo = new THREE.SphereGeometry(1, 64, 48);
  const makeBall = (r: number) => { const m = new THREE.Mesh(ballGeo, chrome); m.scale.setScalar(r); return m; };

  // the scatter: [x, y, z, size, coin?] around the mark; z < 0 is behind it, z > 0 in front
  const LAYOUT: [number, number, number, number, boolean][] = [
    [1.35, -1.05, 0.8, 0.82, true],
    [-1.35, 1.15, 0.4, 0.27, false],
    [-1.75, -1.25, -1.2, 0.5, true],
    [2.05, 1.35, -1.6, 0.45, true],
    [0.55, 1.75, -2.6, 0.16, false],
    [-2.35, 0.1, -2.8, 0.38, true],
    [2.5, -0.15, 1.6, 0.11, false],
    [-0.6, -1.85, 1.2, 0.13, false],
  ];
  const bits: Bit[] = LAYOUT.map(([x, y, z, size, coin], i) => {
    const obj = coin ? makeCoin() : makeBall(size);
    if (coin) obj.scale.setScalar(size);
    group.add(obj);
    return { obj, base: new THREE.Vector3(x, y, z), depth: z, spin: (0.6 + (i % 3) * 0.35) * (i % 2 ? -1 : 1), phase: i * 1.7, delay: 0.25 + i * 0.09, coin, show: true };
  });

  // where things sit: to the right of the headline on a wide screen, above it on a tall one
  let tall = false;
  const layout = () => {
    const w = el.clientWidth, h = el.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    renderer.domElement.style.width = w + 'px'; renderer.domElement.style.height = h + 'px';
    camera.aspect = w / h; camera.updateProjectionMatrix();
    tall = h > w * 1.1;
    const halfW = Math.tan((camera.fov * Math.PI) / 360) * camera.position.z * camera.aspect;
    const halfH = Math.tan((camera.fov * Math.PI) / 360) * camera.position.z;
    group.position.set(tall ? 0 : Math.min(halfW * 0.4, 2.9), tall ? halfH * 0.36 : 0.05, 0);
    group.scale.setScalar(tall ? Math.min(0.58, halfW / 2.5) : 1);
    // a phone keeps the near things only
    bits.forEach(b => { b.show = !tall || b.depth > -1.5; });
  };
  const ro = new ResizeObserver(layout);
  ro.observe(el);
  layout();

  // the pointer leans the group; the depth layers drift against each other
  const aim = { x: 0, y: 0 }, lean = { x: 0, y: 0 };
  const onMove = (e: PointerEvent) => { aim.x = (e.clientX / window.innerWidth) * 2 - 1; aim.y = (e.clientY / window.innerHeight) * 2 - 1; };
  window.addEventListener('pointermove', onMove, { passive: true });

  let raf = 0, visible = true;
  const t0 = performance.now();
  const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting; if (visible && !raf && !opts.still) raf = requestAnimationFrame(loop); }, { threshold: 0 });
  io.observe(el);

  function frame(t: number) {
    const s = (t - t0) / 1000;
    lean.x += (aim.x - lean.x) * 0.045; lean.y += (aim.y - lean.y) * 0.045;
    group.rotation.y = lean.x * 0.14; group.rotation.x = lean.y * 0.07;

    // the mark turns to the viewer on load, then sways
    const inM = easeBack(s / 1.6);
    mark.scale.setScalar(1.18 * (0.7 + 0.3 * easeOut(s / 1.2)));
    mark.rotation.set(0, (1 - inM) * -1.9 + Math.sin(s * 0.4) * 0.3 * easeOut((s - 1) / 2), 0);
    mark.position.y = Math.sin(s * 0.7) * 0.05;

    for (const b of bits) {
      const k = easeOut((s - b.delay) / 1.1);
      const drift = (b.depth + 3) * 0.06;
      b.obj.position.set(
        b.base.x - lean.x * drift,
        b.base.y + (1 - k) * 3.2 + Math.sin(s * 0.7 + b.phase) * 0.07 + lean.y * drift * 0.6,
        b.base.z,
      );
      if (b.coin) b.obj.rotation.set(Math.sin(s * 0.5 + b.phase) * 0.18, s * b.spin + b.phase, 0);
      b.obj.visible = b.show && k > 0.001;
    }
    renderer.render(scene, camera);
  }
  function loop(t: number) {
    raf = 0;
    if (!visible || document.hidden) return;
    frame(t);
    raf = requestAnimationFrame(loop);
  }
  const onVis = () => { if (!document.hidden && visible && !raf && !opts.still) raf = requestAnimationFrame(loop); };
  document.addEventListener('visibilitychange', onVis);
  if (opts.still) frame(t0 + 4000); else raf = requestAnimationFrame(loop);

  return {
    dispose() {
      cancelAnimationFrame(raf);
      io.disconnect(); ro.disconnect();
      window.removeEventListener('pointermove', onMove);
      document.removeEventListener('visibilitychange', onVis);
      for (const sc of [scene, studioScene]) sc.traverse(o => { const m = o as THREE.Mesh; m.geometry?.dispose(); const mat = m.material as THREE.Material | undefined; if (mat && mat !== chrome && mat !== gold && mat !== goldDeep) mat.dispose?.(); });
      chrome.dispose(); gold.dispose(); goldDeep.dispose(); env.dispose(); pmrem.dispose();
      renderer.dispose(); renderer.domElement.remove();
    },
  };
}
