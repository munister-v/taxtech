import { createContext, useContext } from 'react';

// Language of the logged-out landing. English is the default; the choice is remembered per browser.
export type LandingLang = 'en' | 'uk';

export const LANDING_LANG_KEY = 'tt-landing-lang';

export function initialLandingLang(): LandingLang {
  try {
    const saved = localStorage.getItem(LANDING_LANG_KEY);
    if (saved === 'en' || saved === 'uk') return saved;
  } catch { /* storage can be blocked */ }
  return 'en';
}

export function saveLandingLang(l: LandingLang) {
  try { localStorage.setItem(LANDING_LANG_KEY, l); } catch { /* ignore */ }
}

export const LandingLangContext = createContext<LandingLang>('en');

/** t('українською', 'in English') */
export function useLandingT() {
  const lang = useContext(LandingLangContext);
  return { lang, t: (uk: string, en: string) => (lang === 'en' ? en : uk) };
}
