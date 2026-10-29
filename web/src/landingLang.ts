import { createContext, useContext } from 'react';
import { LANDING_I18N } from './landingI18n';

// Language of the logged-out landing. English is the default; the choice is remembered per browser.
export type LandingLang = 'en' | 'uk' | 'it' | 'de' | 'ru';
export const LANDING_LANGS: { id: LandingLang; label: string }[] = [
  { id: 'en', label: 'EN' }, { id: 'uk', label: 'UA' }, { id: 'it', label: 'IT' }, { id: 'de', label: 'DE' }, { id: 'ru', label: 'RU' },
];

/** Picks the copy for `lang`: Ukrainian and English come inline, the rest are looked up by the English string. */
export function landingText(lang: LandingLang, uk: string, en: string): string {
  if (lang === 'en') return en;
  if (lang === 'uk') return uk;
  return LANDING_I18N[lang][en] ?? en;
}

export const LANDING_LANG_KEY = 'tt-landing-lang';

export function initialLandingLang(): LandingLang {
  try {
    const saved = localStorage.getItem(LANDING_LANG_KEY);
    if (LANDING_LANGS.some(l => l.id === saved)) return saved as LandingLang;
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
  return { lang, t: (uk: string, en: string) => landingText(lang, uk, en) };
}
