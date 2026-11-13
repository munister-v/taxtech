import * as THREE from 'three';
import { SVGLoader } from 'three/examples/jsm/loaders/SVGLoader.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import markSvg from './assets/mark.svg?raw';

// The hero's chrome objects: the TaxTech mark in polished chrome, a gold TAX coin and a small chrome sphere, lit by a
// studio environment so every turn throws highlights. They float, turn slowly and lean towards the pointer.
// A handful of meshes: cheap to draw, paused while the hero is off screen.

export type ChromeApi = { dispose(): void };

function markShapes() {
  const data = new SVGLoader().parse(markSvg);
  const shapes: THREE.Shape[] = [];
  for (const p of data.paths) shapes.push(...SVGLoader.createShapes(p));
  return shapes;
}

/** The mark as a bevelled solid, centred, about 2 units tall */
function markGeometry(depth: number, bevel: number) {
  const g = new THREE.ExtrudeGeometry(markShapes(), { depth, bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 6, curveSegments: 48 });
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

export function createChromeScene(el: HTMLElement, opts: { still?: boolean } = {}): ChromeApi {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.35;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  el.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  // a studio: the room plus two softboxes in front, so flat chrome faces carry a bright band that slides as they turn
  const room = new RoomEnvironment();
  const box = new THREE.MeshBasicMaterial({ color: 0xffffff });
  box.color.multiplyScalar(6);
  const soft1 = new THREE.Mesh(new THREE.PlaneGeometry(9, 1.6), box); soft1.position.set(0, 3.2, 9); soft1.lookAt(0, 0, 0); room.add(soft1);
  const soft2 = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 7), box); soft2.position.set(-7, 0, 6); soft2.lookAt(0, 0, 0); room.add(soft2);
  const env = pmrem.fromScene(room, 0.03).texture;
  scene.environment = env;

  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 0, 9);

  const key = new THREE.DirectionalLight(0xfff1d6, 2.2); key.position.set(3, 4, 5); scene.add(key);
  const rim = new THREE.DirectionalLight(0xffd400, 2.6); rim.position.set(-4, 1, -3); scene.add(rim);
  const fill = new THREE.PointLight(0xffffff, 18, 12); fill.position.set(-1.5, 2.5, 4); scene.add(fill);

  const chrome = new THREE.MeshPhysicalMaterial({ color: 0xf2f0eb, metalness: 1, roughness: 0.05, clearcoat: 1, clearcoatRoughness: 0.03, envMapIntensity: 2.2 });
  const gold = new THREE.MeshPhysicalMaterial({ color: 0xffc94a, metalness: 1, roughness: 0.18, clearcoat: 0.6, clearcoatRoughness: 0.1, envMapIntensity: 1.2 });
  const goldDeep = new THREE.MeshPhysicalMaterial({ color: 0xe0a530, metalness: 1, roughness: 0.28, envMapIntensity: 1.1 });

  const group = new THREE.Group();
  scene.add(group);

  const mark = new THREE.Mesh(markGeometry(0.42, 0.06), chrome);
  mark.scale.setScalar(1.18);
  group.add(mark);

  const coin = new THREE.Group();
  coin.scale.setScalar(0.82);
  coin.add(new THREE.Mesh(coinGeometry(0.62, 0.13), gold));
  // the mark embossed on both faces of the coin
  const em = markGeometry(0.035, 0.012);
  em.scale(0.36, 0.36, 1);
  const front = new THREE.Mesh(em, goldDeep); front.position.z = 0.07; coin.add(front);
  const back = new THREE.Mesh(em, goldDeep); back.position.z = -0.07; back.rotation.y = Math.PI; coin.add(back);
  group.add(coin);

  const ball = new THREE.Mesh(new THREE.SphereGeometry(0.26, 64, 48), chrome);
  group.add(ball);

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
    // on a phone: smaller, in the space between the header and the headline
    group.position.set(tall ? -0.1 : Math.min(halfW * 0.4, 2.9), tall ? halfH * 0.36 : 0.05, 0);
    group.scale.setScalar(tall ? Math.min(0.6, halfW / 2.3) : 1);
  };
  const ro = new ResizeObserver(layout);
  ro.observe(el);
  layout();

  // the pointer leans the group a little
  const aim = { x: 0, y: 0 }, lean = { x: 0, y: 0 };
  const onMove = (e: PointerEvent) => { aim.x = (e.clientX / window.innerWidth) * 2 - 1; aim.y = (e.clientY / window.innerHeight) * 2 - 1; };
  window.addEventListener('pointermove', onMove, { passive: true });

  let raf = 0, visible = true, t0 = performance.now();
  const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting; if (visible && !raf && !opts.still) raf = requestAnimationFrame(loop); }, { threshold: 0 });
  io.observe(el);

  function frame(t: number) {
    const s = (t - t0) / 1000;
    lean.x += (aim.x - lean.x) * 0.04; lean.y += (aim.y - lean.y) * 0.04;
    group.rotation.y = lean.x * 0.16; group.rotation.x = lean.y * 0.08;
    // straight and calm: the mark upright with a slow sway, the coin upright and spinning, the sphere hanging still
    mark.rotation.set(0, Math.sin(s * 0.4) * 0.32, 0);
    mark.position.y = Math.sin(s * 0.7) * 0.05;
    coin.position.set(1.25, -1.0 + Math.sin(s * 0.8 + 1) * 0.06, 0.6);
    coin.rotation.set(0, s * 1.1, 0);
    ball.position.set(-1.25, 1.1 + Math.sin(s * 0.6) * 0.05, 0.3);
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
  if (opts.still) frame(t0 + 2600); else raf = requestAnimationFrame(loop);

  return {
    dispose() {
      cancelAnimationFrame(raf);
      io.disconnect(); ro.disconnect();
      window.removeEventListener('pointermove', onMove);
      document.removeEventListener('visibilitychange', onVis);
      scene.traverse(o => { const m = o as THREE.Mesh; m.geometry?.dispose(); });
      chrome.dispose(); gold.dispose(); goldDeep.dispose(); box.dispose(); env.dispose(); pmrem.dispose();
      renderer.dispose(); renderer.domElement.remove();
    },
  };
}
