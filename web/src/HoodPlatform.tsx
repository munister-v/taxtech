// The platform above the map: a night station under Roman arches and a metro train that rolls in, brakes, opens its doors,
// shuts them and rolls out again, in step with the train on the map. Pure SVG + CSS; the parent only sets the phase:
//   at   — the train stands at the platform (doors open once it has stopped)
//   out  — doors close, the train leaves to the right
//   left — parked out of sight on the left, ready to roll in

export type PlatPhase = 'at' | 'out' | 'left';

const CARS = [0, 1];
const WIN = [0, 1, 2];

function Rider({ x, y, k }: { x: number; y: number; k: number }) {
  // A passenger seen through the window: a head and shoulders, a few of them for life.
  return <g opacity=".72" fill="#3a2a10"><circle cx={x} cy={y - 6 + k} r="8" /><path d={`M${x - 15} ${y + 30}q1-22 15-22t15 22z`} /></g>;
}

export default function HoodPlatform({ phase, roman, name, next, going }: { phase: PlatPhase; roman: string; name: string; next: string; going: boolean }) {
  return (
    <div className={`bl-plat ${phase}`} aria-hidden>
      <svg className="bl-plat-bg" viewBox="0 0 1200 300" preserveAspectRatio="xMidYMid slice">
        <defs>
          <linearGradient id="plwall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#0b0907" /><stop offset="1" stopColor="#1c140c" /></linearGradient>
          <linearGradient id="plniche" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#6b4a1e" stopOpacity=".15" /><stop offset=".55" stopColor="#d9a24a" stopOpacity=".42" /><stop offset="1" stopColor="#ffd98a" stopOpacity=".18" /></linearGradient>
          <linearGradient id="plfloor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#1a1510" /><stop offset="1" stopColor="#060504" /></linearGradient>
        </defs>
        <rect width="1200" height="300" fill="url(#plwall)" />
        {/* Roman arches on the back wall, each with a lit niche */}
        {Array.from({ length: 7 }, (_, i) => {
          const x = -40 + i * 200;
          return (
            <g key={i}>
              <path d={`M${x + 26} 240V120a74 74 0 0 1 148 0V240z`} fill="url(#plniche)" stroke="rgba(220,193,149,.55)" strokeWidth="1.5" />
              <path d={`M${x + 14} 240V120a86 86 0 0 1 172 0V240`} fill="none" stroke="rgba(220,193,149,.22)" strokeWidth="1" />
              <path d={`M${x + 46} 240V122a54 54 0 0 1 108 0V240`} fill="none" stroke="rgba(255,226,160,.18)" strokeWidth="1" />
              <rect x={x + 5} y="118" width="190" height="2" fill="rgba(220,193,149,.2)" />
            </g>
          );
        })}
        {/* overhead wire */}
        <path d="M0 22Q300 30 600 22T1200 22" fill="none" stroke="rgba(220,193,149,.5)" strokeWidth="1.2" />
        <path d="M0 30Q300 38 600 30T1200 30" fill="none" stroke="rgba(220,193,149,.25)" strokeWidth="1" />
        {/* platform floor with the safety strip and a reflection of the niches */}
        <rect y="240" width="1200" height="60" fill="url(#plfloor)" />
        <rect y="240" width="1200" height="4" fill="#ffd400" opacity=".9" />
        <rect y="244" width="1200" height="2" fill="rgba(0,0,0,.6)" />
        {Array.from({ length: 7 }, (_, i) => <rect key={i} x={-40 + i * 200 + 60} y="252" width="80" height="34" rx="12" fill="rgba(217,162,74,.07)" />)}
      </svg>

      <div className="bl-plat-sign">
        <b className="bl-plat-line">T</b>
        {going
          ? <span className="bl-plat-nx"><i>→</i>{next}</span>
          : <span className="bl-plat-st"><em>{roman}</em>{name}</span>}
      </div>

      <div className="bl-plat-train">
        <svg viewBox="0 0 1240 236">
          <defs>
            <linearGradient id="pltbody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#f4f6f9" /><stop offset=".5" stopColor="#d3d8df" /><stop offset="1" stopColor="#8e96a2" /></linearGradient>
            <linearGradient id="pltwin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffeebb" /><stop offset="1" stopColor="#f0c366" /></linearGradient>
            <linearGradient id="pltglass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#1f2a3d" /><stop offset="1" stopColor="#0b111c" /></linearGradient>
            <radialGradient id="pltlamp"><stop offset="0" stopColor="#fffbe6" /><stop offset=".4" stopColor="#fff0b0" stopOpacity=".7" /><stop offset="1" stopColor="#fff0b0" stopOpacity="0" /></radialGradient>
          </defs>
          {/* pantographs */}
          {[310, 930].map(x => <path key={x} d={`M${x - 34} 20L${x} 4L${x + 34} 20M${x - 22} 20L${x} 12L${x + 22} 20M${x - 40} 4h80`} fill="none" stroke="#9aa3af" strokeWidth="2.4" strokeLinecap="round" />)}
          {/* bogies */}
          {CARS.flatMap(c => [110, 510].map(x => (
            <g key={c + '-' + x} transform={`translate(${c * 620 + x} 212)`}>
              <rect x="-62" y="-14" width="124" height="22" rx="6" fill="#262a31" />
              <circle cx="-34" cy="6" r="16" fill="#15181d" /><circle cx="-34" cy="6" r="6" fill="#59606b" />
              <circle cx="34" cy="6" r="16" fill="#15181d" /><circle cx="34" cy="6" r="6" fill="#59606b" />
            </g>
          )))}
          {/* body */}
          <rect x="0" y="22" width="1240" height="186" rx="46" fill="url(#pltbody)" />
          <rect x="0" y="22" width="1240" height="186" rx="46" fill="none" stroke="rgba(255,255,255,.5)" strokeWidth="1.5" />
          <rect x="612" y="30" width="16" height="170" fill="#20242b" />
          {/* livery: yellow band and the name */}
          <rect x="0" y="152" width="1240" height="30" fill="#ffd400" />
          <rect x="0" y="182" width="1240" height="6" fill="#8e7400" opacity=".55" />
          {CARS.map(c => <text key={c} x={c * 620 + 310} y="174" textAnchor="middle" fontFamily="Jost, sans-serif" fontWeight="600" fontSize="22" letterSpacing="6" fill="#14100a">TAXTECH</text>)}
          {/* windows and doors */}
          {CARS.map(c => (
            <g key={c} transform={`translate(${c * 620} 0)`}>
              {WIN.map(i => {
                const x = 143 + i * 127;
                return (
                  <g key={i}>
                    <rect x={x} y="50" width="106" height="74" rx="12" fill="url(#pltwin)" stroke="#3b414b" strokeWidth="3" />
                    {(c + i) % 2 === 0 && <Rider x={x + 38} y={92} k={i} />}
                    {(c + i) % 3 === 1 && <Rider x={x + 70} y={96} k={0} />}
                    <path d={`M${x + 6} 56h40l-22 62h-18z`} fill="rgba(255,255,255,.18)" />
                  </g>
                );
              })}
              {(c === 1 ? [60] : [60, 490]).map(x => (
                <g key={x}>
                  <rect x={x - 6} y="38" width="88" height="124" rx="8" fill="#20242b" />
                  <rect x={x} y="44" width="76" height="112" rx="5" fill="url(#pltwin)" />
                  <g className="bl-plat-door">
                    <rect className="l" x={x} y="44" width="38" height="112" rx="5" fill="#c7cdd6" stroke="#3b414b" strokeWidth="2.5" />
                    <rect className="l" x={x + 6} y="54" width="26" height="52" rx="4" fill="url(#pltglass)" />
                    <rect className="r" x={x + 38} y="44" width="38" height="112" rx="5" fill="#c7cdd6" stroke="#3b414b" strokeWidth="2.5" />
                    <rect className="r" x={x + 44} y="54" width="26" height="52" rx="4" fill="url(#pltglass)" />
                  </g>
                  <rect x={x + 30} y="30" width="16" height="6" rx="3" fill="#2fd07a" className="bl-plat-led" />
                </g>
              ))}
            </g>
          ))}
          {/* driver's cab on the right */}
          <path d="M1112 50h74q26 0 40 56l8 18h-122z" fill="url(#pltglass)" stroke="#3b414b" strokeWidth="3" />
          <path d="M1124 58h30l-34 62h-26z" fill="rgba(255,255,255,.14)" />
          <circle cx="1220" cy="140" r="9" fill="#fff" /><circle cx="1220" cy="140" r="46" fill="url(#pltlamp)" className="bl-plat-lamp" />
          <circle cx="2" cy="140" r="6" fill="#ff4d3d" opacity=".9" />
        </svg>
      </div>
      <div className="bl-plat-shade" />
    </div>
  );
}
