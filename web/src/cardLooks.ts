// The card journey at the top of the landing: the looks of the card and the scroll timeline.
// Shared by the page (CardJourney.tsx) and the WebGL scene (cardJourneyScene.ts), so it must not import three.

export type Look = {
  id: string; uk: string; en: string;
  a: string; b: string;        // face gradient, top-left to bottom-right
  ink: string;                 // mark, number, name
  line: string;                // guilloche lines
  tint: string;                // colour of the light around the card
  metal: number; rough: number;
  photo?: string;
};

export const LOOKS: Look[] = [
  { id: 'black', uk: 'Чорна', en: 'Black', a: '#202024', b: '#070708', ink: '#f4f4f6', line: '#ffd400', tint: '#d6a84a', metal: 0.92, rough: 0.42 },
  { id: 'gold', uk: 'Золота', en: 'Gold', a: '#dcb85e', b: '#8a6520', ink: '#241a06', line: '#fff3cc', tint: '#f0c95a', metal: 1, rough: 0.3 },
  { id: 'emerald', uk: 'Смарагд', en: 'Emerald', a: '#12684e', b: '#04261c', ink: '#effff8', line: '#86e8c2', tint: '#2fc48e', metal: 0.9, rough: 0.36 },
  { id: 'bordeaux', uk: 'Бордо', en: 'Bordeaux', a: '#7a1630', b: '#2c0612', ink: '#fff1f3', line: '#f3a6b6', tint: '#d0395a', metal: 0.9, rough: 0.36 },
  { id: 'midnight', uk: 'Опівніч', en: 'Midnight', a: '#1b2c74', b: '#060a24', ink: '#f0f3ff', line: '#93a9ff', tint: '#5672f0', metal: 0.9, rough: 0.36 },
  { id: 'white', uk: 'Біла', en: 'White', a: '#ffffff', b: '#d2d3d9', ink: '#17171b', line: '#aeb0ba', tint: '#e9e9f0', metal: 0.3, rough: 0.34 },
  { id: 'colosseum', uk: 'Колізей вночі', en: 'Colosseum by night', a: '#1a1410', b: '#060504', ink: '#ffffff', line: '#ffd400', tint: '#e6a85c', metal: 0, rough: 0.6, photo: '/cards/roma-colosseum-night.webp' },
  { id: 'marble', uk: 'Мармур', en: 'Marble', a: '#d8d2c6', b: '#8d877c', ink: '#1b1813', line: '#ffd400', tint: '#ddd5c6', metal: 0, rough: 0.6, photo: '/cards/roma-marble.webp' },
];

/** Where each chapter sits on the scroll, as a share of the pinned track. */
export const T = {
  heroOut: [0.03, 0.11], tapIn: [0.13, 0.2], approach: [0.21, 0.3], pay: 0.3, tapOut: [0.44, 0.51],
  looksIn: [0.54, 0.61], looks: [0.61, 0.95],
} as const;

export const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
export const ss = (a: number, b: number, v: number) => { const k = clamp((v - a) / (b - a)); return k * k * (3 - 2 * k); };

/** The look on screen at progress p and how far the scroll is from it (-0.5 … 0.5). */
export function lookAt(p: number) {
  const f = clamp((p - T.looks[0]) / (T.looks[1] - T.looks[0])) * (LOOKS.length - 1);
  const i = Math.round(f);
  return { i, frac: f - i };
}
export const lookProgress = (i: number) => T.looks[0] + (i / (LOOKS.length - 1)) * (T.looks[1] - T.looks[0]);
