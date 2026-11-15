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
];

/** Where each chapter sits on the scroll, as a share of the pinned track. */
export const T = {
  heroOut: [0.02, 0.1], tapIn: [0.14, 0.3], approach: [0.3, 0.5], pay: 0.5, tapOut: [2, 3],
  looksIn: [2, 3], looks: [2, 3],
} as const;

export const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
export const ss = (a: number, b: number, v: number) => { const k = clamp((v - a) / (b - a)); return k * k * (3 - 2 * k); };

/** The look on screen at progress p and how far the scroll is from it (-0.5 … 0.5). */
export function lookAt(p: number) {
  const f = clamp((p - T.looks[0]) / (T.looks[1] - T.looks[0])) * (LOOKS.length - 1);   // one look today, so always 0
  const i = Math.round(f);
  return { i, frac: f - i };
}
