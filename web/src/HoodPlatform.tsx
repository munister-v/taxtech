// The platform above the map: a night station under Roman arches and a metro train that rolls in, brakes, opens its doors,
// shuts them and rolls out again, in step with the train on the map. Pure SVG + CSS; the parent only sets the phase:
//   at   — the train stands at the platform (doors open once it has stopped)
//   out  — doors close, the train leaves to the right
//   left — parked out of sight on the left, ready to roll in
// The cars carry our livery: the mark and the wordmark on a dark panel with the card's guilloche, a yellow stripe,
// and an amber LED board that shows the station or the next stop.

import { useEffect, useRef, useState } from 'react';
import type { TrainApi } from './hoodTrain3d';

export type PlatPhase = 'at' | 'out' | 'left';

const CARS = [0, 1];
const WIN = [0, 1, 2];
const CAR_W = 620;

function Rider({ x, y, k }: { x: number; y: number; k: number }) {
  // A passenger seen through the window: a head and shoulders, hair and shirt vary a little.
  const hair = ['#2b1d0e', '#4a3016', '#1c1410', '#6b4a22'][k % 4], shirt = ['#7d3b2e', '#2e4a63', '#3d3d45', '#8a6a2a'][k % 4];
  return (
    <g opacity=".92">
      <path d={`M${x - 17} ${y + 34}q1-24 17-24t17 24z`} fill={shirt} />
      <circle cx={x} cy={y - 4} r="9" fill="#d9a77a" />
      <path d={`M${x - 9.5} ${y - 5}a9.5 9.5 0 0 1 19 0q-9.5-4-19 0z`} fill={hair} />
    </g>
  );
}

function Door({ x, tail }: { x: number; tail?: boolean }) {
  return (
    <g>
      <rect x={x - 8} y="36" width="92" height="132" rx="8" fill="#171a20" />
      {/* the lit vestibule behind the leaves, with a pole and a floor strip */}
      <rect x={x} y="44" width="76" height="116" rx="5" fill="url(#pltwin)" />
      <rect x={x + 36} y="44" width="4" height="116" fill="#9aa3af" />
      <rect x={x} y="150" width="76" height="10" fill="#6d5524" opacity=".55" />
      <g className="bl-plat-door">
        <g className="l">
          <rect x={x} y="44" width="38" height="116" rx="5" fill="#cfd5dd" stroke="#3b414b" strokeWidth="2.5" />
          <rect x={x + 6} y="52" width="26" height="62" rx="4" fill="url(#pltglass)" />
          <path d={`M${x + 8} 56h8l-9 52h-4z`} fill="rgba(255,255,255,.18)" />
          <rect x={x + 6} y="124" width="26" height="22" rx="3" fill="#b6bdc7" />
          <rect x={x + 33} y="44" width="5" height="116" fill="#20242b" />
        </g>
        <g className="r">
          <rect x={x + 38} y="44" width="38" height="116" rx="5" fill="#cfd5dd" stroke="#3b414b" strokeWidth="2.5" />
          <rect x={x + 44} y="52" width="26" height="62" rx="4" fill="url(#pltglass)" />
          <path d={`M${x + 46} 56h8l-9 52h-4z`} fill="rgba(255,255,255,.18)" />
          <rect x={x + 44} y="124" width="26" height="22" rx="3" fill="#b6bdc7" />
          <rect x={x + 38} y="44" width="5" height="116" fill="#20242b" />
        </g>
      </g>
      {/* door button, status light, pictogram */}
      <circle cx={x + (tail ? 92 : -14)} cy="104" r="5" fill="#20242b" /><circle cx={x + (tail ? 92 : -14)} cy="104" r="2.2" className="bl-plat-led" />
      <rect x={x + 22} y="26" width="32" height="8" rx="4" fill="#0c0e12" />
      <rect x={x + 26} y="28.2" width="24" height="3.6" rx="1.8" className="bl-plat-led" />
      <path d={`M${x + 28} 138l6-7v14zM${x + 48} 138l-6-7v14z`} fill="rgba(20,16,10,.5)" />
      {/* light spilling onto the platform when the doors are open */}
      <path className="bl-plat-spill" d={`M${x} 214h76l34 40h-144z`} fill="url(#pltspill)" />
    </g>
  );
}

export default function HoodPlatform({ phase, roman, name, next, going, rose }: { phase: PlatPhase; roman: string; name: string; next: string; going: boolean; rose: string }) {
  const led = (going ? `→ ${next}` : `${roman} ${name}`).toUpperCase();
  // The 3D train (three.js, loaded on demand) replaces the flat SVG one where WebGL is available.
  const host = useRef<HTMLDivElement | null>(null);
  const api = useRef<TrainApi | null>(null);
  const [gl, setGl] = useState(false);
  const last = useRef({ phase, led }); last.current = { phase, led };
  useEffect(() => {
    let dead = false;
    let a: TrainApi | null = null;
    try { const c = document.createElement('canvas'); if (!(c.getContext('webgl2') || c.getContext('webgl'))) return; } catch { return; }
    import('./hoodTrain3d').then(m => {
      if (dead || !host.current) return;
      try { a = m.mountTrain(host.current, rose); api.current = a; a.setLed(last.current.led); a.setPhase(last.current.phase); setGl(true); } catch { a?.dispose(); a = null; }
    }).catch(() => {});
    return () => { dead = true; a?.dispose(); api.current = null; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => { api.current?.setPhase(phase); }, [phase]);
  useEffect(() => { api.current?.setLed(led); }, [led]);
  return (
    <div className={`bl-plat ${phase}${gl ? ' gl' : ''}`} aria-hidden>
      <div className="bl-plat-glhost" ref={host} />
      <svg className="bl-plat-bg" viewBox="0 0 1200 300" preserveAspectRatio="xMidYMid slice">
        <defs>
          <linearGradient id="plwall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#0b0907" /><stop offset="1" stopColor="#1c140c" /></linearGradient>
          <linearGradient id="plniche" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#6b4a1e" stopOpacity=".15" /><stop offset=".55" stopColor="#d9a24a" stopOpacity=".42" /><stop offset="1" stopColor="#ffd98a" stopOpacity=".18" /></linearGradient>
          <linearGradient id="plfloor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#1d1812" /><stop offset="1" stopColor="#060504" /></linearGradient>
          <radialGradient id="pllamp"><stop offset="0" stopColor="#ffe3a0" stopOpacity=".55" /><stop offset="1" stopColor="#ffe3a0" stopOpacity="0" /></radialGradient>
          <pattern id="pltile" width="26" height="14" patternUnits="userSpaceOnUse"><rect width="25" height="13" fill="rgba(220,193,149,.06)" /></pattern>
        </defs>
        <rect width="1200" height="300" fill="url(#plwall)" />
        {Array.from({ length: 7 }, (_, i) => {
          const x = -40 + i * 200;
          return (
            <g key={i}>
              <path d={`M${x + 26} 240V120a74 74 0 0 1 148 0V240z`} fill="url(#plniche)" stroke="rgba(220,193,149,.55)" strokeWidth="1.5" />
              <path d={`M${x + 14} 240V120a86 86 0 0 1 172 0V240`} fill="none" stroke="rgba(220,193,149,.22)" strokeWidth="1" />
              <path d={`M${x + 46} 240V122a54 54 0 0 1 108 0V240`} fill="none" stroke="rgba(255,226,160,.18)" strokeWidth="1" />
              <rect x={x + 5} y="118" width="190" height="2" fill="rgba(220,193,149,.2)" />
              {/* keystone and a hanging lamp in each bay */}
              <path d={`M${x + 92} 44h16l-3 14h-10z`} fill="rgba(220,193,149,.35)" />
              <circle cx={x + 100} cy="74" r="38" fill="url(#pllamp)" />
              <path d={`M${x + 100} 30v36`} stroke="rgba(220,193,149,.5)" strokeWidth="1.2" /><path d={`M${x + 90} 66h20l-4 10h-12z`} fill="#ffe3a0" opacity=".9" />
            </g>
          );
        })}
        <rect y="204" width="1200" height="36" fill="url(#pltile)" />
        <path d="M0 22Q300 30 600 22T1200 22" fill="none" stroke="rgba(220,193,149,.5)" strokeWidth="1.2" />
        <path d="M0 30Q300 38 600 30T1200 30" fill="none" stroke="rgba(220,193,149,.25)" strokeWidth="1" />
        <rect y="240" width="1200" height="60" fill="url(#plfloor)" />
        <rect y="240" width="1200" height="4" fill="#ffd400" opacity=".9" />
        {Array.from({ length: 80 }, (_, i) => <circle key={i} cx={8 + i * 15} cy="248" r="1.6" fill="#ffd400" opacity=".35" />)}
        <rect y="244" width="1200" height="2" fill="rgba(0,0,0,.6)" />
        {Array.from({ length: 7 }, (_, i) => <rect key={i} x={-40 + i * 200 + 60} y="258" width="80" height="26" rx="12" fill="rgba(217,162,74,.08)" />)}
      </svg>

      <div className="bl-plat-sign">
        <b className="bl-plat-line">T</b>
        {going
          ? <span className="bl-plat-nx"><i>→</i>{next}</span>
          : <span className="bl-plat-st"><em>{roman}</em>{name}</span>}
      </div>

      <div className="bl-plat-train">
        <svg viewBox="0 0 1240 262">
          <defs>
            <linearGradient id="pltbody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fbfcfd" /><stop offset=".35" stopColor="#dfe3e9" /><stop offset="1" stopColor="#99a1ad" /></linearGradient>
            <linearGradient id="pltwin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffeebb" /><stop offset="1" stopColor="#f0c366" /></linearGradient>
            <linearGradient id="pltglass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#25324a" /><stop offset="1" stopColor="#0b111c" /></linearGradient>
            <linearGradient id="pltdark" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#23262d" /><stop offset="1" stopColor="#0d0e11" /></linearGradient>
            <linearGradient id="pltspill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffe7a6" stopOpacity=".6" /><stop offset="1" stopColor="#ffe7a6" stopOpacity="0" /></linearGradient>
            <radialGradient id="pltlamp"><stop offset="0" stopColor="#fffbe6" /><stop offset=".4" stopColor="#fff0b0" stopOpacity=".7" /><stop offset="1" stopColor="#fff0b0" stopOpacity="0" /></radialGradient>
            <clipPath id="pltband"><rect x="0" y="126" width="1240" height="58" /></clipPath>
          </defs>

          {/* rail under the wheels */}
          <rect x="-40" y="240" width="1320" height="5" rx="2" fill="#3b3f46" /><rect x="-40" y="240" width="1320" height="1.6" fill="#8b929c" />

          {/* roof: air conditioning units, pantographs, roof line */}
          {CARS.map(c => (
            <g key={c} transform={`translate(${c * CAR_W} 0)`}>
              <rect x="60" y="10" width="150" height="14" rx="5" fill="#b9bfc9" /><rect x="60" y="10" width="150" height="4" rx="2" fill="#e9edf2" />
              {Array.from({ length: 6 }, (_, i) => <rect key={i} x={72 + i * 22} y="14" width="2" height="8" fill="#6b727d" />)}
              <rect x="400" y="10" width="150" height="14" rx="5" fill="#b9bfc9" /><rect x="400" y="10" width="150" height="4" rx="2" fill="#e9edf2" />
              {Array.from({ length: 6 }, (_, i) => <rect key={i} x={412 + i * 22} y="14" width="2" height="8" fill="#6b727d" />)}
              <path d="M240 20L310 6L380 20" fill="none" stroke="#8a929e" strokeWidth="2.6" strokeLinecap="round" /><path d="M262 20L310 12L358 20M284 6h52" fill="none" stroke="#a8afba" strokeWidth="2" strokeLinecap="round" />
              <rect x="296" y="18" width="28" height="6" rx="2" fill="#4b525d" />
            </g>
          ))}

          {/* underframe: bogies, equipment boxes, brake discs */}
          {CARS.map(c => (
            <g key={c} transform={`translate(${c * CAR_W} 0)`}>
              <rect x="190" y="204" width="86" height="22" rx="3" fill="#2a2e35" /><rect x="190" y="204" width="86" height="3" fill="#4a505a" />
              <rect x="296" y="206" width="52" height="18" rx="3" fill="#23262d" />
              <rect x="356" y="204" width="86" height="22" rx="3" fill="#2a2e35" /><rect x="356" y="204" width="86" height="3" fill="#4a505a" />
              {[100, 520].map(x => (
                <g key={x} transform={`translate(${x} 226)`}>
                  <rect x="-66" y="-10" width="132" height="20" rx="6" fill="#262a31" /><rect x="-66" y="-10" width="132" height="3" rx="1.5" fill="#4a505a" />
                  {[-36, 36].map(w => (
                    <g key={w}>
                      <circle cx={w} cy="6" r="17" fill="#101215" /><circle cx={w} cy="6" r="11" fill="#2a2e35" /><circle cx={w} cy="6" r="5" fill="#8b929c" />
                      {Array.from({ length: 6 }, (_, s) => <path key={s} d={`M${w} 6L${w + 10 * Math.cos(s * Math.PI / 3)} ${6 + 10 * Math.sin(s * Math.PI / 3)}`} stroke="#59606b" strokeWidth="1.6" />)}
                    </g>
                  ))}
                </g>
              ))}
            </g>
          ))}

          {/* body shell */}
          <rect x="0" y="24" width="1240" height="188" rx="46" fill="url(#pltbody)" />
          <rect x="0" y="24" width="1240" height="188" rx="46" fill="none" stroke="rgba(255,255,255,.55)" strokeWidth="1.5" />
          <path d="M40 30h1160" stroke="rgba(255,255,255,.7)" strokeWidth="2" strokeLinecap="round" />
          {/* panel seams and rivets along the roof edge */}
          {Array.from({ length: 28 }, (_, i) => <path key={i} d={`M${46 + i * 43} 38v6`} stroke="rgba(60,66,78,.25)" strokeWidth="1.2" />)}
          {/* gangway between the cars */}
          <rect x="606" y="30" width="28" height="178" fill="#0f1115" />
          {Array.from({ length: 9 }, (_, i) => <path key={i} d={`M${608 + i * 3} 32v174`} stroke="#2b2f37" strokeWidth="1.2" />)}

          {/* livery: dark panel with the guilloche, the mark and the wordmark, then the yellow stripe */}
          <rect x="0" y="126" width="1240" height="58" fill="url(#pltdark)" />
          <g clipPath="url(#pltband)">
            {CARS.map(c => (
              <g key={c}>
                <svg x={c * CAR_W + CAR_W / 2 - 150} y="86" width="300" height="300" viewBox="0 0 100 100" opacity=".5">
                  <path d={rose} fill="none" stroke="#ffd400" strokeWidth=".16" />
                </svg>
              </g>
            ))}
          </g>
          {CARS.map(c => (
            <g key={c} transform={`translate(${c * CAR_W + CAR_W / 2} 155)`}>
              <image href="/icons/mark-white.svg" x="-96" y="-20" width="34" height="40" />
              <text x="-52" y="9" fontFamily="Inter, 'SF Pro Display', sans-serif" fontSize="30" fontWeight="500" fill="#fff" letterSpacing="-.5">Tax<tspan fontWeight="300">Tech</tspan></text>
            </g>
          ))}
          <rect x="0" y="184" width="1240" height="9" fill="#ffd400" />
          <rect x="0" y="193" width="1240" height="3" fill="#7d6500" opacity=".6" />
          <rect x="0" y="122" width="1240" height="4" fill="#ffd400" opacity=".9" />
          {CARS.map(c => <text key={c} x={c * CAR_W + 30} y="119" fontFamily="ui-monospace, Menlo, monospace" fontSize="10" letterSpacing="1.5" fill="#5c6470">T-{6595 + c}</text>)}

          {/* windows, vents, rails, seats, passengers */}
          {CARS.map(c => (
            <g key={c} transform={`translate(${c * CAR_W} 0)`}>
              {WIN.map(i => {
                const x = 143 + i * 127;
                return (
                  <g key={i}>
                    <rect x={x - 5} y="45" width="116" height="84" rx="14" fill="#20242b" />
                    <rect x={x} y="50" width="106" height="74" rx="11" fill="url(#pltwin)" />
                    <rect x={x} y="50" width="106" height="9" rx="5" fill="#fff6d2" opacity=".85" />
                    <rect x={x} y="104" width="106" height="20" fill="#6d5524" opacity=".45" />
                    <path d={`M${x + 8} 106q10-12 22-12h46q12 0 22 12z`} fill="#4a3a1c" opacity=".55" />
                    {(c + i) % 2 === 0 && <Rider x={x + 38} y={86} k={i + c} />}
                    {(c * 2 + i) % 3 === 1 && <Rider x={x + 72} y={90} k={i + 1} />}
                    <path d={`M${x} 77h106`} stroke="#9aa3af" strokeWidth="2.2" /><path d={`M${x + 12} 77v-6M${x + 54} 77v-6M${x + 94} 77v-6`} stroke="#9aa3af" strokeWidth="1.6" />
                    <path d={`M${x + 8} 56h34l-20 62h-18z`} fill="rgba(255,255,255,.16)" />
                    <rect x={x + 2} y="50" width="102" height="5" rx="2" fill="none" stroke="rgba(255,255,255,.4)" strokeWidth="1" />
                  </g>
                );
              })}
              {c === 0 && <><Door x={60} /><Door x={500} tail /></>}
              {c === 1 && <Door x={60} />}
            </g>
          ))}

          {/* LED boards under the roof line: the station, or the next stop */}
          {CARS.map(c => (
            <g key={c} transform={`translate(${c * CAR_W + 238} 31)`}>
              <rect width="150" height="15" rx="3" fill="#0a0a0c" stroke="#3b414b" strokeWidth="1" />
              <text x="75" y="11.2" textAnchor="middle" fontFamily="ui-monospace, Menlo, monospace" fontSize="9.4" fontWeight="700" letterSpacing="1.2" fill="#ffb020" className="bl-plat-ledtx">{led.length > 22 ? led.slice(0, 22) : led}</text>
            </g>
          ))}

          {/* driver's cab */}
          <path d="M1108 48h76q30 0 44 60l10 22h-130z" fill="url(#pltglass)" stroke="#3b414b" strokeWidth="3" />
          <path d="M1120 56h34l-36 66h-28z" fill="rgba(255,255,255,.14)" />
          <path d="M1172 112l40-38" stroke="#9aa3af" strokeWidth="2.4" strokeLinecap="round" /><circle cx="1172" cy="112" r="2.6" fill="#9aa3af" />
          <image href="/icons/mark-white.svg" x="1178" y="140" width="22" height="26" opacity=".95" />
          <rect x="1210" y="104" width="8" height="30" rx="4" fill="#fff6c8" /><circle cx="1224" cy="150" r="7" fill="#fff" />
          <circle cx="1224" cy="150" r="52" fill="url(#pltlamp)" className="bl-plat-lamp" />
          <rect x="1228" y="198" width="14" height="8" rx="2" fill="#4a505a" />
          <circle cx="4" cy="150" r="5" fill="#ff3d2e" opacity=".9" /><circle cx="4" cy="110" r="3" fill="#ff3d2e" opacity=".7" />
        </svg>
      </div>
      <div className="bl-plat-shade" />
    </div>
  );
}
