import type { CSSProperties } from 'react';

// Roman identity shared by the landing and the web bank: inscription type (Forum has Latin and Cyrillic capitals),
// laurel wreath, Greek-key meander, arcade strip, Roman numerals. Gold is the same #c7a46f as the guilloche rosette.

export const ROMAN_FONT = "'Forum', 'Cormorant SC', 'Times New Roman', serif";
export const ROMAN_GOLD = '#c7a46f';
export const ROMAN_YEAR = 'MMXXVI';

export function toRoman(n: number): string {
  const map: [number, string][] = [[1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'], [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']];
  let out = '';
  for (const [v, s] of map) while (n >= v) { out += s; n -= v; }
  return out;
}

const svgUri = (svg: string) => `url("data:image/svg+xml,${encodeURIComponent(svg)}")`;

/** Greek key (meander) as a repeating background; tile is 20×14. */
export const meanderBg = (color = ROMAN_GOLD) =>
  svgUri(`<svg xmlns="http://www.w3.org/2000/svg" width="20" height="14" viewBox="0 0 20 14"><path d="M0 13H20M16 13V1H4V9H10V5H8" fill="none" stroke="${color}" stroke-width="1.3" stroke-linejoin="miter"/></svg>`);

/** Row of arches (a Roman arcade) as a repeating background; tile is 36×22. */
export const arcadeBg = (color = ROMAN_GOLD) =>
  svgUri(`<svg xmlns="http://www.w3.org/2000/svg" width="36" height="22" viewBox="0 0 36 22"><path d="M0 .7H36M3 22V11a15 11 0 0 1 30 0V22" fill="none" stroke="${color}" stroke-width="1.1"/></svg>`);

export function Meander({ color = ROMAN_GOLD, opacity = 0.5, style, className }: { color?: string; opacity?: number; style?: CSSProperties; className?: string }) {
  return <div aria-hidden className={className} style={{ height: 14, opacity, backgroundImage: meanderBg(color), backgroundRepeat: 'repeat-x', ...style }} />;
}

export function Arcade({ color = ROMAN_GOLD, opacity = 0.4, style, className }: { color?: string; opacity?: number; style?: CSSProperties; className?: string }) {
  return <div aria-hidden className={className} style={{ height: 22, opacity, backgroundImage: arcadeBg(color), backgroundRepeat: 'repeat-x', ...style }} />;
}

// Laurel branch: leaves follow an arc of the circle, shrinking towards the tip.
const LEAVES = (() => {
  const out: { x: number; y: number; rot: number; s: number }[] = [];
  const N = 12, R = 36;
  for (let i = 0; i < N; i++) {
    const th = (100 + i * (150 / (N - 1))) * Math.PI / 180;
    const px = 50 + R * Math.cos(th), py = 50 + R * Math.sin(th);
    const tang = Math.atan2(Math.cos(th), -Math.sin(th));
    const s = 1 - i * 0.04;
    for (const side of [-1, 1]) {
      const phi = tang + side * 0.66;
      out.push({ x: px + Math.cos(phi) * 5.2 * s, y: py + Math.sin(phi) * 5.2 * s, rot: (phi * 180) / Math.PI + 90, s });
    }
  }
  const tip = (250 * Math.PI) / 180;
  out.push({ x: 50 + (R + 1) * Math.cos(tip), y: 50 + (R + 1) * Math.sin(tip), rot: (Math.atan2(Math.cos(tip), -Math.sin(tip)) * 180) / Math.PI + 90, s: 0.8 });
  return out;
})();
const STEM = (() => {
  const a = (100 * Math.PI) / 180, b = (252 * Math.PI) / 180, R = 36;
  return `M${(50 + R * Math.cos(a)).toFixed(1)} ${(50 + R * Math.sin(a)).toFixed(1)}A${R} ${R} 0 0 1 ${(50 + R * Math.cos(b)).toFixed(1)} ${(50 + R * Math.sin(b)).toFixed(1)}`;
})();

/** Laurel wreath, open at the top. Draws on a 100×100 box, so it can ring a mark or stand alone. */
export function Laurel({ size = 64, color = ROMAN_GOLD, style, className }: { size?: number; color?: string; style?: CSSProperties; className?: string }) {
  const branch = (
    <g>
      <path d={STEM} fill="none" stroke={color} strokeWidth="0.9" strokeLinecap="round" />
      {LEAVES.map((l, i) => <ellipse key={i} cx={l.x.toFixed(1)} cy={l.y.toFixed(1)} rx={(2.5 * l.s).toFixed(2)} ry={(6 * l.s).toFixed(2)} transform={`rotate(${l.rot.toFixed(1)} ${l.x.toFixed(1)} ${l.y.toFixed(1)})`} fill={color} fillOpacity=".85" />)}
    </g>
  );
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 100 100" aria-hidden style={style}>
      {branch}
      <g transform="translate(100 0) scale(-1 1)">{branch}</g>
    </svg>
  );
}

/** Text running round a circle (for the rosette): `r` is the radius of the baseline in a 100×100 box. */
export function RingText({ text, id, r = 49.6, size = 2.5, color = ROMAN_GOLD }: { text: string; id: string; r?: number; size?: number; color?: string }) {
  return (
    <g fontFamily={ROMAN_FONT} fontSize={size} letterSpacing=".9" fill={color}>
      <path id={id} d={`M50 ${50 - r}A${r} ${r} 0 1 1 49.99 ${50 - r}`} fill="none" />
      <text><textPath href={`#${id}`} startOffset="0" textLength={(2 * Math.PI * r - 1).toFixed(1)} lengthAdjust="spacing">{text}</textPath></text>
    </g>
  );
}
