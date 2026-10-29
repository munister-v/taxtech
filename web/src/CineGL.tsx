import { useEffect, useRef } from 'react';
import { DAWN_SPOTS } from './fireData';

/**
 * One WebGL background for the hero and the "evening in Rome" scene.
 * Four photographs sit in a texture array; scrolling moves a float `S` through them. Between two photos the first one
 * burns away from the bottom with a glowing ember edge. Warm light in the photos flickers like real fire, a torch
 * follows the pointer, and the first frame burns in from darkness. Sparks float on a 2D canvas above.
 */

export const GL_OK = (() => {
  try { return !!document.createElement('canvas').getContext('webgl2'); } catch { return false; }
})();

type Src = { url: string; fx: number; fy: number };
const SRC: Src[] = [
  { url: '/landing/colosseum-dawn.webp', fx: 0.22, fy: 0.3 },
  { url: '/landing/rome-forum-sunset.webp', fx: 0.5, fy: 0.62 },
  { url: '/landing/rome-pantheon-night.webp', fx: 0.5, fy: 0.38 },
  { url: '/landing/rome-trevi-night.webp', fx: 0.5, fy: 0.28 },
];
const ASPECT = 1.5;

const VERT = `#version 300 es
in vec2 aPos;
out vec2 vUv;
void main() { vUv = vec2(aPos.x * .5 + .5, .5 - aPos.y * .5); gl_Position = vec4(aPos, 0., 1.); }`;

const FRAG = `#version 300 es
precision highp float;
precision highp sampler2DArray;
uniform sampler2DArray uTex;
uniform vec2 uRes, uMouse;
uniform float uTime, uS, uIntro, uTorch, uAspect;
uniform float uZoom[4];
uniform vec2 uFocus[4];
in vec2 vUv;
out vec4 outColor;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
  return mix(mix(hash(i), hash(i + vec2(1., 0.)), f.x), mix(hash(i + vec2(0., 1.)), hash(i + vec2(1., 1.)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0., a = .5; for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(17., 9.); a *= .5; } return v; }

vec3 tex(int i, vec2 p) {
  float A = uRes.x / uRes.y;
  vec2 s = A > uAspect ? vec2(1., uAspect / A) : vec2(A / uAspect, 1.);
  vec2 f = uFocus[i];
  vec2 vc = .5 * s + (1. - s) * f;
  vec2 uv = p * s + (1. - s) * f;
  uv = vc + (uv - vc) / uZoom[i];
  return texture(uTex, vec3(uv, float(i))).rgb;
}

void main() {
  vec2 p = vUv;
  float A = uRes.x / uRes.y;
  int ia = int(min(floor(uS), 2.));
  float t = clamp(uS - float(ia), 0., 1.);
  int ib = ia + 1;

  // Burn field: the fire climbs from the bottom.
  float n = fbm(p * 3.2 + vec2(float(ia) * 7.1, 0.));
  float b = n * .7 + (1. - p.y) * .3;
  float th = t * 1.25 - .12;
  float edge = b - th;
  float live = smoothstep(0., .03, t) * (1. - smoothstep(.97, 1., t));

  // Heat haze around the burning edge.
  vec2 haze = (vec2(fbm(p * 9. + vec2(0., -uTime * .5)), fbm(p * 9. + 5. - vec2(0., uTime * .5))) - .5) * .018 * live * (1. - smoothstep(0., .3, abs(edge)));

  vec3 colA = tex(ia, p + haze);
  vec3 colB = tex(ib, p + haze);
  vec3 col;
  if (edge < 0.) {
    col = colB;
    float back = smoothstep(-.06, 0., edge);
    col += vec3(.9, .3, .04) * back * .55 * live;
  } else {
    float char_ = smoothstep(.24, 0., edge);
    col = colA * mix(1., .1, char_ * live);
    float w = .08;
    float band = smoothstep(w * 2.2, 0., edge);
    float core = smoothstep(w * .55, 0., edge);
    float fl = .65 + .7 * noise(p * 70. + uTime * 3.);
    col += (vec3(1., .33, .04) * band * 1.5 + vec3(1., .82, .45) * core * 2.) * fl * live;
  }

  // Warm light in the photographs breathes like fire.
  float luma = dot(col, vec3(.299, .587, .114));
  float warm = smoothstep(.1, .42, col.r - col.b) * smoothstep(.32, .8, luma);
  float fk = fbm(p * vec2(16., 26.) + vec2(uTime * .35, -uTime * 1.3));
  col *= 1. + warm * (fk - .45) * .75;
  col += warm * vec3(.34, .1, .0) * fk * .5;

  // Torch under the pointer.
  float r = length((p - uMouse) * vec2(A, 1.));
  float torch = uTorch * smoothstep(.5, 0., r);
  float tf = .75 + .5 * fbm(p * 8. + vec2(0., -uTime * 1.5));
  col *= 1. + torch * .3;
  col += vec3(.6, .24, .04) * torch * torch * .38 * tf;

  col *= 1. - .38 * pow(length(p - .5) * 1.25, 2.6);
  col += (hash(p * uRes + fract(uTime)) - .5) * .03;

  // First frame: the picture burns in from the middle.
  float ib2 = fbm(p * 3. + 3.7) * .7 + length((p - vec2(.5, .6)) * vec2(A * .6, 1.)) * .55;
  float edge2 = ib2 - (uIntro * 1.6 - .25);
  float vis = 1. - smoothstep(-.012, .012, edge2);
  float introLive = 1. - smoothstep(.94, 1., uIntro);
  float lineI = smoothstep(.1, 0., edge2) * step(0., edge2);
  col = col * vis + (vec3(1., .4, .06) * lineI * 1.6 + vec3(1., .8, .4) * smoothstep(.03, 0., edge2) * step(0., edge2) * 1.2) * introLive;
  outColor = vec4(col, 1.);
}`;

const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const sm = (v: number) => { const k = clamp(v); return k * k * (3 - 2 * k); };

export default function CineGL() {
  const cv = useRef<HTMLCanvasElement | null>(null);
  const em = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = cv.current, ember = em.current;
    const wrap = canvas?.closest('.bl-cine') as HTMLElement | null;
    const root = canvas?.closest('.bl') as HTMLElement | null;
    if (!canvas || !ember || !wrap || !root) return;
    const gl = canvas.getContext('webgl2', { antialias: false, alpha: false, powerPreference: 'high-performance' });
    if (!gl) return;
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const small = window.innerWidth < 760;

    const shader = (type: number, src: string) => {
      const s = gl.createShader(type)!; gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) { console.warn(gl.getShaderInfoLog(s)); return null; }
      return s;
    };
    const vs = shader(gl.VERTEX_SHADER, VERT), fs = shader(gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) return;
    const prog = gl.createProgram()!;
    gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) { console.warn(gl.getProgramInfoLog(prog)); return; }
    gl.useProgram(prog);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(prog, 'aPos');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    const U = (n: string) => gl.getUniformLocation(prog, n);
    const uRes = U('uRes'), uMouse = U('uMouse'), uTime = U('uTime'), uS = U('uS'), uIntro = U('uIntro'), uTorch = U('uTorch'), uAspect = U('uAspect'), uZoom = U('uZoom[0]'), uFocus = U('uFocus[0]');
    gl.uniform1f(uAspect, ASPECT);
    gl.uniform2fv(uFocus, new Float32Array(SRC.flatMap(s => [s.fx, s.fy])));
    gl.uniform1i(U('uTex'), 0);

    // Textures: every photo is cropped to 3:2 and stacked in one array texture.
    const TW = small ? 1400 : 2048, TH = Math.round(TW / ASPECT);
    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D_ARRAY, tex);
    const levels = Math.floor(Math.log2(Math.max(TW, TH))) + 1;
    gl.texStorage3D(gl.TEXTURE_2D_ARRAY, levels, gl.RGBA8, TW, TH, SRC.length);
    gl.texParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    let ready = 0, readyAt = 0, dead = false;
    const stage = document.createElement('canvas'); stage.width = TW; stage.height = TH;
    const sctx = stage.getContext('2d')!;
    SRC.forEach((s, i) => {
      const img = new Image();
      img.decoding = 'async';
      img.onload = () => {
        if (dead) return;
        const ir = img.naturalWidth / img.naturalHeight;
        let sw = img.naturalWidth, sh = img.naturalHeight, sx = 0, sy = 0;
        if (ir > ASPECT) { sw = sh * ASPECT; sx = (img.naturalWidth - sw) * 0.5; } else { sh = sw / ASPECT; sy = (img.naturalHeight - sh) * s.fy; }
        sctx.drawImage(img, sx, sy, sw, sh, 0, 0, TW, TH);
        gl.bindTexture(gl.TEXTURE_2D_ARRAY, tex);
        gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
        gl.texSubImage3D(gl.TEXTURE_2D_ARRAY, 0, 0, 0, i, TW, TH, 1, gl.RGBA, gl.UNSIGNED_BYTE, stage);
        if (++ready === SRC.length) { gl.generateMipmap(gl.TEXTURE_2D_ARRAY); readyAt = performance.now(); wrap.classList.add('bl-cine-live'); }
      };
      img.src = s.url;
    });

    let W = 1, H = 1;
    const dprCap = small ? 1.4 : 1.75;
    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, dprCap);
      W = canvas.clientWidth || 1; H = canvas.clientHeight || 1;
      canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
      ember.width = W; ember.height = H;
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.uniform2f(uRes, canvas.width, canvas.height);
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    // Pointer: the torch follows it; with no pointer (touch, idle) it wanders by itself.
    const mouse = { x: 0.5, y: 0.5, tx: 0.5, ty: 0.5, on: 0, last: -1e9 };
    const onMove = (e: PointerEvent) => {
      const r = canvas.getBoundingClientRect();
      mouse.tx = (e.clientX - r.left) / r.width; mouse.ty = (e.clientY - r.top) / r.height;
      mouse.last = performance.now(); mouse.on = e.pointerType === 'mouse' ? 1 : 0;
    };
    window.addEventListener('pointermove', onMove, { passive: true });

    // Sparks over the picture: they leave the lit arches of the first photo, then drift as gold dust.
    const ectx = ember.getContext('2d')!;
    type P = { x: number; y: number; vx: number; vy: number; life: number; age: number; r: number; hue: number; ph: number; dust: boolean };
    const ps: P[] = [];
    const emit = DAWN_SPOTS.filter(s => s[2] * s[3] > 3).map(s => ({ x: s[0] / 100, y: (s[1] + s[3] * 0.25) / 100, w: s[2] / 100 }));
    const maxP = small ? 70 : 130;
    let heroZ = 1.12, vis = true, S = 0, alphaHero = 1, alphaDust = 0;
    const mapToScreen = (ex: number, ey: number, z: number) => {
      const A = W / H;
      const sx = A > ASPECT ? 1 : A / ASPECT, sy = A > ASPECT ? ASPECT / A : 1;
      const fx = SRC[0].fx, fy = SRC[0].fy;
      const vcx = 0.5 * sx + (1 - sx) * fx, vcy = 0.5 * sy + (1 - sy) * fy;
      const ux = vcx + (ex - vcx) * z, uy = vcy + (ey - vcy) * z;
      return [((ux - (1 - sx) * fx) / sx) * W, ((uy - (1 - sy) * fy) / sy) * H];
    };
    const spawn = () => {
      const dust = Math.random() < 0.18 + alphaDust * 0.7;
      if (dust) {
        ps.push({ x: Math.random() * W, y: H * (0.3 + Math.random() * 0.8), vx: (Math.random() - 0.5) * 0.02, vy: -(0.02 + Math.random() * 0.05), life: 5000 + Math.random() * 5000, age: 0, r: 0.8 + Math.random() * 1.6, hue: 36 + Math.random() * 14, ph: Math.random() * 6.28, dust: true });
        return;
      }
      const e = emit[(Math.random() * emit.length) | 0];
      if (!e) return;
      const [px, py] = mapToScreen(e.x + (Math.random() - 0.5) * e.w, e.y, heroZ);
      ps.push({ x: px, y: py, vx: (Math.random() - 0.35) * 0.1, vy: -(0.06 + Math.random() * 0.18), life: 2400 + Math.random() * 3600, age: 0, r: 1 + Math.random() * 2.6, hue: 22 + Math.random() * 26, ph: Math.random() * 6.28, dust: false });
    };

    const io = new IntersectionObserver(es => { vis = es[0]?.isIntersecting ?? true; }, { threshold: 0 });
    io.observe(wrap);

    const heroEl = wrap.querySelector<HTMLElement>('.bl-hero');
    const romeEl = wrap.querySelector<HTMLElement>('.bl-rome');
    const zoom = new Float32Array(4);
    let raf = 0, last = performance.now(), t0 = last;

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(48, now - last); last = now;
      if (!vis || document.hidden || ready < SRC.length) return;
      const box = root.getBoundingClientRect();
      const y = box.top - wrap.getBoundingClientRect().top;
      const heroH = heroEl?.offsetHeight || H;
      // Scroll -> S: 0 hero, 1 forum, 2 pantheon, 3 trevi, burning between whole numbers.
      let s = 0, sEvening = 0;
      if (romeEl) {
        const p = clamp((box.top - romeEl.getBoundingClientRect().top) / Math.max(1, romeEl.offsetHeight - root.clientHeight));
        sEvening = p * 3;
      }
      if (y < heroH) s = clamp((y - 0.5 * heroH) / (0.5 * heroH));
      else s = 1 + sm((sEvening - 1 + 0.2) / 0.4) + sm((sEvening - 2 + 0.2) / 0.4);
      S = s;
      wrap.style.setProperty('--shade', clamp((S - 0.15) / 0.7).toFixed(3));
      heroZ = 1.12 + 0.3 * clamp(y / heroH);
      zoom[0] = heroZ;
      for (let i = 1; i < 4; i++) zoom[i] = 1.05 + clamp(sEvening - (i - 1), -0.35, 1.35) * 0.1;
      gl.uniform1fv(uZoom, zoom);

      const idle = now - mouse.last > 2500 || !mouse.on;
      const time = still ? 0 : (now - t0) / 1000;
      if (idle) { mouse.tx = 0.5 + 0.28 * Math.sin(time * 0.37); mouse.ty = 0.55 + 0.16 * Math.sin(time * 0.51 + 1); }
      mouse.x += (mouse.tx - mouse.x) * 0.1; mouse.y += (mouse.ty - mouse.y) * 0.1;
      gl.uniform2f(uMouse, mouse.x, mouse.y);
      gl.uniform1f(uTorch, still ? 0 : (idle ? 0.4 : 1));
      gl.uniform1f(uTime, time);
      gl.uniform1f(uS, S);
      gl.uniform1f(uIntro, still ? 1 : clamp((now - readyAt) / 3200));
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

      if (still) return;
      alphaHero = 1 - clamp(S / 0.55);
      alphaDust = sm((S - 0.7) / 0.5);
      ectx.clearRect(0, 0, W, H);
      ectx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 3 && ps.length < maxP; i++) if (Math.random() < 0.6) spawn();
      for (let i = ps.length - 1; i >= 0; i--) {
        const q = ps[i];
        q.age += dt;
        if (q.age >= q.life) { ps.splice(i, 1); continue; }
        q.ph += dt * 0.003;
        q.x += (q.vx + Math.sin(q.ph) * 0.05) * dt * (W / 1400);
        q.y += q.vy * dt * (H / 900);
        const k = q.age / q.life;
        const fade = q.dust ? 0.35 + 0.65 * alphaDust : alphaHero;
        const a = Math.sin(Math.PI * Math.min(1, k * 1.15)) * (0.55 + 0.45 * Math.sin(q.ph * 6)) * fade * (q.dust ? 0.7 : 1);
        if (a <= 0.01) continue;
        const r = q.r * (W / 1400 + 0.6) * (1 - k * 0.5);
        const g = ectx.createRadialGradient(q.x, q.y, 0, q.x, q.y, r * 5);
        g.addColorStop(0, `hsla(${q.hue},100%,72%,${a})`);
        g.addColorStop(0.2, `hsla(${q.hue},100%,58%,${a * 0.6})`);
        g.addColorStop(1, `hsla(${q.hue},100%,50%,0)`);
        ectx.fillStyle = g;
        ectx.beginPath(); ectx.arc(q.x, q.y, r * 5, 0, 6.2832); ectx.fill();
        ectx.fillStyle = `hsla(${q.hue},100%,88%,${a * 0.95})`;
        ectx.beginPath(); ectx.arc(q.x, q.y, Math.max(0.7, r * 0.75), 0, 6.2832); ectx.fill();
      }
    };
    raf = requestAnimationFrame(frame);

    const lost = (e: Event) => { e.preventDefault(); };
    canvas.addEventListener('webglcontextlost', lost);
    return () => {
      dead = true;
      cancelAnimationFrame(raf);
      ro.disconnect(); io.disconnect();
      window.removeEventListener('pointermove', onMove);
      canvas.removeEventListener('webglcontextlost', lost);
      wrap.classList.remove('bl-cine-live');
      // Not lose_context(): React may remount this effect on the same canvas, which would hand back a dead context.
      gl.deleteTexture(tex); gl.deleteBuffer(buf); gl.deleteProgram(prog);
    };
  }, []);

  return (
    <>
      <canvas ref={cv} className="bl-cine-gl-cv" />
      <canvas ref={em} className="bl-cine-em" />
    </>
  );
}
