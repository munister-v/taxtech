import { initialLandingLang, type LandingLang } from './landingLang';
import { APP_I18N } from './appI18nData';

// Strings written inline in App.tsx as tr('українською', 'in English'). Ukrainian and English stay next to the
// markup; Italian, German and Russian are looked up by the English string (appI18nData.ts), falling back to English.
// The app root sets the current language on every render, so components need no extra prop or context.

let current: LandingLang = initialLandingLang();

export function setTrLang(l: LandingLang) { current = l; }
export function trLang(): LandingLang { return current; }

export function tr(uk: string, en: string): string {
  if (current === 'uk') return uk;
  if (current === 'en') return en;
  return APP_I18N[current][en] ?? en;
}
