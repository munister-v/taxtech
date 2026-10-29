import { createContext, useContext } from 'react';
import { LANDING_I18N } from './landingI18n';

// One language for the whole site: the landing, sign-in and the banking app read and write the same choice,
// so a visitor who picks a language on the landing signs in and lands in the app in that language.
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
export const APP_LANG_KEY = 'army_bank_language';   // the key the banking app has always used

const isLang = (v: unknown): v is LandingLang => LANDING_LANGS.some(l => l.id === v);

/** The saved choice (the app's key first, then the landing's), else the browser's language, else English. */
export function initialLandingLang(): LandingLang {
  try {
    for (const k of [APP_LANG_KEY, LANDING_LANG_KEY]) {
      const saved = localStorage.getItem(k);
      if (isLang(saved)) return saved;
    }
  } catch { /* storage can be blocked */ }
  try {
    for (const tag of navigator.languages || [navigator.language]) {
      const base = String(tag).slice(0, 2).toLowerCase();
      if (isLang(base)) return base;
    }
  } catch { /* no navigator */ }
  return 'en';
}

export function saveLandingLang(l: LandingLang) {
  try { localStorage.setItem(LANDING_LANG_KEY, l); localStorage.setItem(APP_LANG_KEY, l); } catch { /* ignore */ }
}

export const LandingLangContext = createContext<LandingLang>('en');

/** t('українською', 'in English') */
export function useLandingT() {
  const lang = useContext(LandingLangContext);
  return { lang, t: (uk: string, en: string) => landingText(lang, uk, en) };
}
